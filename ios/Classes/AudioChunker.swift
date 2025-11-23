import Foundation
import AVFoundation
import os.log

// MARK: - Audio Chunking Configuration

struct AudioChunkingConfiguration {
    let chunkDuration: TimeInterval          // Duration of each chunk in seconds
    let overlapDuration: TimeInterval        // Overlap between chunks
    let maxChunkSize: Int                   // Maximum chunk size in bytes
    let minChunkDuration: TimeInterval      // Minimum duration for a chunk
    let enableVADChunking: Bool             // Enable VAD-based chunking
    let enableSilenceDetection: Bool        // Enable silence-based splitting
    let silenceThreshold: Float             // Threshold for silence detection
    let maxSilenceDuration: TimeInterval   // Maximum silence within a chunk
    let enableSmartSplitting: Bool          // Enable intelligent splitting at speech boundaries
    let preserveContext: Bool               // Preserve audio context between chunks
    let adaptiveChunking: Bool              // Adapt chunk size based on content

    static let `default` = AudioChunkingConfiguration(
        chunkDuration: 30.0,                // 30-second chunks
        overlapDuration: 2.0,               // 2-second overlap
        maxChunkSize: 50 * 1024 * 1024,     // 50MB max
        minChunkDuration: 5.0,              // 5-second minimum
        enableVADChunking: true,
        enableSilenceDetection: true,
        silenceThreshold: 0.01,
        maxSilenceDuration: 3.0,
        enableSmartSplitting: true,
        preserveContext: true,
        adaptiveChunking: true
    )

    static let optimized = AudioChunkingConfiguration(
        chunkDuration: 20.0,                // 20-second chunks for better accuracy
        overlapDuration: 3.0,               // 3-second overlap for context
        maxChunkSize: 30 * 1024 * 1024,     // 30MB max
        minChunkDuration: 10.0,             // 10-second minimum
        enableVADChunking: true,
        enableSilenceDetection: true,
        silenceThreshold: 0.02,
        maxSilenceDuration: 2.0,
        enableSmartSplitting: true,
        preserveContext: true,
        adaptiveChunking: true
    )

    static let realtime = AudioChunkingConfiguration(
        chunkDuration: 10.0,                // 10-second chunks for real-time
        overlapDuration: 1.0,               // 1-second overlap
        maxChunkSize: 10 * 1024 * 1024,     // 10MB max
        minChunkDuration: 3.0,              // 3-second minimum
        enableVADChunking: true,
        enableSilenceDetection: true,
        silenceThreshold: 0.015,
        maxSilenceDuration: 1.5,
        enableSmartSplitting: true,
        preserveContext: true,
        adaptiveChunking: false
    )
}

// MARK: - Audio Chunk Information

struct AudioChunkInfo {
    let id: UUID
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let duration: TimeInterval
    let dataSize: Int
    let hasSpeech: Bool
    let confidence: Float               // Confidence that this chunk contains speech
    let contextOverlap: TimeInterval    // Amount of context overlap with previous chunk
    let chunkType: ChunkType

    enum ChunkType {
        case speech                       // Primarily speech
        case silence                      // Primarily silence
        case mixed                        // Mixed speech and silence
        case context                      // Context-only chunk
        case padding                      // Padding chunk

        var description: String {
            switch self {
            case .speech: return "Speech"
            case .silence: return "Silence"
            case .mixed: return "Mixed"
            case .context: return "Context"
            case .padding: return "Padding"
            }
        }
    }

    var description: String {
        return "Chunk \(index): \(chunkType.description) (\(String(format: "%.1f", duration))s, confidence: \(String(format: "%.2f", confidence)))"
    }
}

// MARK: - Audio Chunker Delegate

protocol AudioChunkerDelegate: AnyObject {
    func audioChunker(_ chunker: AudioChunker, didCreateChunk chunk: AudioChunkInfo, data: Data)
    func audioChunker(_ chunker: AudioChunker, didUpdateProgress progress: Float)
    func audioChunker(_ chunker: AudioChunker, didCompleteChunking chunks: [AudioChunkInfo])
    func audioChunker(_ chunker: AudioChunker, didEncounterError error: Error)
}

// MARK: - Audio Chunker

class AudioChunker: NSObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.whisper_kit", category: "AudioChunker")
    weak var delegate: AudioChunkerDelegate?

    // Configuration
    private var configuration: AudioChunkingConfiguration
    private let sampleRate: Double
    private let channelCount: Int

    // Processing state
    private var audioData: Data = Data()
    private var chunks: [AudioChunkInfo] = []
    private var currentChunkIndex: Int = 0
    private var lastProcessedTime: TimeInterval = 0
    private var contextBuffer: Data = Data()
    private var vad: VoiceActivityDetector?

    // Processing
    private let processingQueue = DispatchQueue(label: "com.whisper_kit.audio.chunking", qos: .userInitiated)

    // MARK: - Initialization

    init(configuration: AudioChunkingConfiguration = .default, sampleRate: Double = 16000, channelCount: Int = 1) {
        self.configuration = configuration
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        super.init()

        if configuration.enableVADChunking {
            vad = VoiceActivityDetector(configuration: .sensitive, sampleRate: sampleRate)
            vad?.delegate = self
        }

        logger.info("AudioChunker initialized with chunk duration: \(configuration.chunkDuration)s")
    }

    // MARK: - Public Interface

    /// Add audio data for chunking
    func addAudioData(_ data: Data, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        processingQueue.async {
            self.audioData.append(data)
            self.processAudioData(timestamp: timestamp)
        }
    }

    /// Process entire audio file for chunking
    func processAudioFile(url: URL, completion: @escaping (Result<[AudioChunkInfo], Error>) -> Void) {
        processingQueue.async {
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let audioFormat = audioFile.processingFormat
                let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!

                try audioFile.read(into: audioBuffer)

                guard let channelData = audioBuffer.floatChannelData else {
                    throw AudioChunkingError.invalidAudioFile
                }

                let data = Data(bytes: channelData[0], count: Int(audioBuffer.frameLength) * MemoryLayout<Float>.size)
                self.audioData = data

                let chunks = try self.createChunksFromData()
                DispatchQueue.main.async {
                    completion(.success(chunks))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Process audio buffer for chunking
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        processingQueue.async {
            guard let channelData = buffer.floatChannelData else {
                DispatchQueue.main.async {
                    self.delegate?.audioChunker(self, didEncounterError: AudioChunkingError.invalidAudioBuffer)
                }
                return
            }

            let frameLength = Int(buffer.frameLength)
            let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)

            self.addAudioData(data, timestamp: timestamp)
        }
    }

    /// Finalize chunking and process remaining data
    func finalizeChunking() {
        processingQueue.async {
            if !self.audioData.isEmpty {
                self.processRemainingData()
            }

            DispatchQueue.main.async {
                self.delegate?.audioChunker(self, didCompleteChunking: self.chunks)
            }

            self.logger.info("Audio chunking completed. Created \(self.chunks.count) chunks.")
        }
    }

    /// Reset chunker state
    func reset() {
        processingQueue.async {
            self.audioData.removeAll()
            self.chunks.removeAll()
            self.currentChunkIndex = 0
            self.lastProcessedTime = 0
            self.contextBuffer.removeAll()
            self.logger.info("AudioChunker state reset")
        }
    }

    /// Update chunking configuration
    func updateConfiguration(_ newConfiguration: AudioChunkingConfiguration) {
        processingQueue.async {
            self.configuration = newConfiguration

            if newConfiguration.enableVADChunking && self.vad == nil {
                self.vad = VoiceActivityDetector(configuration: .sensitive, sampleRate: self.sampleRate)
                self.vad?.delegate = self
            } else if !newConfiguration.enableVADChunking {
                self.vad = nil
            }

            self.logger.info("AudioChunker configuration updated")
        }
    }

    /// Get chunking statistics
    func getStatistics() -> AudioChunkingStatistics {
        let totalDuration = audioData.count > 0 ? Double(audioData.count) / (sampleRate * Double(MemoryLayout<Float>.size)) : 0.0
        let processedDuration = chunks.reduce(0) { $0 + $1.duration }

        return AudioChunkingStatistics(
            totalChunks: chunks.count,
            totalDuration: totalDuration,
            processedDuration: processedDuration,
            averageChunkDuration: chunks.isEmpty ? 0.0 : processedDuration / Double(chunks.count),
            speechChunks: chunks.filter { $0.hasSpeech }.count,
            silenceChunks: chunks.filter { $0.chunkType == .silence }.count,
            processingProgress: totalDuration > 0 ? processedDuration / totalDuration : 0.0
        )
    }

    // MARK: - Private Chunking Methods

    private func processAudioData(timestamp: TimeInterval) {
        let targetChunkSize = Int(configuration.chunkDuration * sampleRate * Double(MemoryLayout<Float>.size))

        while audioData.count >= targetChunkSize {
            let chunkData = Data(audioData.prefix(targetChunkSize))

            // Remove context overlap from processed data
            let overlapSize = Int(configuration.overlapDuration * sampleRate * Double(MemoryLayout<Float>.size))
            audioData.removeFirst(targetChunkSize - overlapSize)

            let chunkInfo = createChunkInfo(from: chunkData, startTime: lastProcessedTime)
            chunks.append(chunkInfo)

            DispatchQueue.main.async {
                self.delegate?.audioChunker(self, didCreateChunk: chunkInfo, data: chunkData)
            }

            lastProcessedTime += configuration.chunkDuration - configuration.overlapDuration
            currentChunkIndex += 1

            // Report progress
            let totalExpectedSize = targetChunkSize
            let progress = Float(lastProcessedTime) / Float(lastProcessedTime + Double(audioData.count) / (sampleRate * Double(MemoryLayout<Float>.size)))
            DispatchQueue.main.async {
                self.delegate?.audioChunker(self, didUpdateProgress: min(progress, 1.0))
            }
        }
    }

    private func createChunksFromData() throws -> [AudioChunkInfo] {
        var chunks: [AudioChunkInfo] = []
        let targetChunkSize = Int(configuration.chunkDuration * sampleRate * Double(MemoryLayout<Float>.size))
        let overlapSize = Int(configuration.overlapDuration * sampleRate * Double(MemoryLayout<Float>.size))
        var currentTime: TimeInterval = 0

        while audioData.count > overlapSize {
            let chunkData = Data(audioData.prefix(targetChunkSize))
            let chunkInfo = createChunkInfo(from: chunkData, startTime: currentTime)

            chunks.append(chunkInfo)
            currentTime += configuration.chunkDuration - configuration.overlapDuration

            audioData.removeFirst(targetChunkSize - overlapSize)
        }

        // Process remaining data
        if !audioData.isEmpty {
            let remainingChunkInfo = createChunkInfo(from: audioData, startTime: currentTime)
            chunks.append(remainingChunkInfo)
        }

        self.chunks = chunks
        return chunks
    }

    private func processRemainingData() {
        if !audioData.isEmpty {
            let remainingChunkInfo = createChunkInfo(from: audioData, startTime: lastProcessedTime)
            chunks.append(remainingChunkInfo)

            DispatchQueue.main.async {
                self.delegate?.audioChunker(self, didCreateChunk: remainingChunkInfo, data: self.audioData)
            }
        }
    }

    private func createChunkInfo(from data: Data, startTime: TimeInterval) -> AudioChunkInfo {
        let duration = Double(data.count) / (sampleRate * Double(MemoryLayout<Float>.size))
        let endTime = startTime + duration

        // Analyze chunk content
        let (hasSpeech, confidence, chunkType) = analyzeChunkContent(data: data)

        let chunkInfo = AudioChunkInfo(
            id: UUID(),
            index: currentChunkIndex,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            dataSize: data.count,
            hasSpeech: hasSpeech,
            confidence: confidence,
            contextOverlap: contextBuffer.count > 0 ? Double(contextBuffer.count) / (sampleRate * Double(MemoryLayout<Float>.size)) : 0.0,
            chunkType: chunkType
        )

        // Update context buffer if preserving context
        if configuration.preserveContext {
            updateContextBuffer(data: data)
        }

        return chunkInfo
    }

    private func analyzeChunkContent(data: Data) -> (hasSpeech: Bool, confidence: Float, chunkType: AudioChunkInfo.ChunkType) {
        guard !data.isEmpty else {
            return (false, 0.0, .silence)
        }

        let samples = data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Calculate audio level
        var sum: Float = 0.0
        vDSP_vsq(samples, 1, &sum, vDSP_Length(samples.count))
        let rmsLevel = sqrt(sum / Float(samples.count))

        // Zero crossing rate
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(samples.count)

        // Determine if chunk contains speech
        let hasSpeech = rmsLevel > configuration.silenceThreshold && zcr > 0.05
        let confidence = hasSpeech ? min(rmsLevel * 10.0, 1.0) : max(0.0, 1.0 - rmsLevel * 10.0)

        // Determine chunk type
        let chunkType: AudioChunkInfo.ChunkType
        if hasSpeech {
            if confidence > 0.8 {
                chunkType = .speech
            } else {
                chunkType = .mixed
            }
        } else {
            chunkType = .silence
        }

        return (hasSpeech, confidence, chunkType)
    }

    private func updateContextBuffer(data: Data) {
        let contextSize = Int(configuration.overlapDuration * sampleRate * Double(MemoryLayout<Float>.size))

        if data.count >= contextSize {
            contextBuffer = Data(data.suffix(contextSize))
        } else {
            contextBuffer.append(data)
            if contextBuffer.count > contextSize {
                contextBuffer = Data(contextBuffer.suffix(contextSize))
            }
        }
    }
}

// MARK: - AudioChunker Errors

enum AudioChunkingError: LocalizedError {
    case invalidAudioFile
    case invalidAudioBuffer
    case configurationError
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidAudioFile:
            return "Invalid audio file provided"
        case .invalidAudioBuffer:
            return "Invalid audio buffer provided"
        case .configurationError:
            return "Invalid chunking configuration"
        case .processingFailed:
            return "Audio chunking processing failed"
        }
    }
}

// MARK: - AudioChunker Statistics

struct AudioChunkingStatistics {
    let totalChunks: Int
    let totalDuration: TimeInterval
    let processedDuration: TimeInterval
    let averageChunkDuration: TimeInterval
    let speechChunks: Int
    let silenceChunks: Int
    let processingProgress: Float

    var speechPercentage: Float {
        return totalChunks > 0 ? Float(speechChunks) / Float(totalChunks) : 0.0
    }

    var description: String {
        return """
        Audio Chunking Statistics:
        Total Chunks: \(totalChunks)
        Total Duration: \(String(format: "%.1f", totalDuration))s
        Processed Duration: \(String(format: "%.1f", processedDuration))s
        Average Chunk Duration: \(String(format: "%.1f", averageChunkDuration))s
        Speech Chunks: \(speechChunks) (\(String(format: "%.1f", speechPercentage * 100))%)
        Silence Chunks: \(silenceChunks)
        Processing Progress: \(String(format: "%.1f", processingProgress * 100))%
        """
    }
}

// MARK: - AudioChunker VAD Delegate

extension AudioChunker: VoiceActivityDetectorDelegate {
    func vadDetector(_ detector: VoiceActivityDetector, didUpdateState state: VADState) {
        // Handle VAD state updates for adaptive chunking
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectActivity result: VADResult) {
        // Use VAD results for intelligent chunking
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechStart timestamp: TimeInterval) {
        // Start new chunk at speech boundary if smart splitting is enabled
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechEnd timestamp: TimeInterval) {
        // End current chunk at speech boundary if smart splitting is enabled
    }

    func vadDetector(_ detector: VoiceActivityDetector, didEncounterError error: Error) {
        logger.error("VAD error during audio chunking: \(error.localizedDescription)")
    }
}