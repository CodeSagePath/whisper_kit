import Foundation
import AVFoundation
import Accelerate
import os.log

protocol StreamingAudioProcessorDelegate: AnyObject {
    func audioProcessorDidStartProcessing(_ processor: StreamingAudioProcessor)
    func audioProcessor(_ processor: StreamingAudioProcessor, didDetectVoiceActivity isActive: Bool)
    func audioProcessor(_ processor: StreamingAudioProcessor, didProcessAudioChunk chunk: AudioChunk, transcription: TranscriptionResult?)
    func audioProcessorDidCompleteProcessing(_ processor: StreamingAudioProcessor, finalTranscription: TranscriptionResult)
    func audioProcessor(_ processor: StreamingAudioProcessor, didEncounterError error: Error)
}

struct AudioChunk {
    let id: UUID
    let data: Data
    let timestamp: TimeInterval
    let duration: TimeInterval
    let audioLevel: Float
    let containsVoice: Bool
    let sampleRate: Double
    let channelCount: Int

    init(data: Data, timestamp: TimeInterval, duration: TimeInterval, audioLevel: Float, containsVoice: Bool, sampleRate: Double = 16000, channelCount: Int = 1) {
        self.id = UUID()
        self.data = data
        self.timestamp = timestamp
        self.duration = duration
        self.audioLevel = audioLevel
        self.containsVoice = containsVoice
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let confidence: Float
    let language: String?
    let timestamp: TimeInterval
    let processingTime: TimeInterval

    init(text: String, segments: [TranscriptionSegment] = [], confidence: Float = 0.0, language: String? = nil, timestamp: TimeInterval = Date().timeIntervalSince1970, processingTime: TimeInterval = 0.0) {
        self.text = text
        self.segments = segments
        self.confidence = confidence
        self.language = language
        self.timestamp = timestamp
        self.processingTime = processingTime
    }
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
    let words: [TranscriptionWord]

    init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float = 0.0, words: [TranscriptionWord] = []) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.words = words
    }
}

struct TranscriptionWord {
    let word: String
    let start: TimeInterval
    let end: TimeInterval
    let confidence: Float

    init(word: String, start: TimeInterval, end: TimeInterval, confidence: Float = 0.0) {
        self.word = word
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

enum StreamingAudioProcessorError: LocalizedError {
    case audioEngineFailure
    case formatConversionFailed
    case processingQueueFull
    case modelNotLoaded
    case insufficientData
    case vadInitializationFailed

    var errorDescription: String? {
        switch self {
        case .audioEngineFailure:
            return "Failed to initialize audio engine"
        case .formatConversionFailed:
            return "Failed to convert audio format"
        case .processingQueueFull:
            return "Audio processing queue is full"
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .insufficientData:
            return "Insufficient audio data for processing"
        case .vadInitializationFailed:
            return "Failed to initialize Voice Activity Detection"
        }
    }
}

class StreamingAudioProcessor: NSObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.whisper_kit", category: "StreamingAudioProcessor")
    weak var delegate: StreamingAudioProcessorDelegate?

    // Audio configuration
    private let chunkDuration: TimeInterval // Duration of each audio chunk in seconds
    private let overlapDuration: TimeInterval // Overlap between chunks to maintain context
    private let silenceThreshold: Float
    private let maxSilenceDuration: TimeInterval
    private let sampleRate: Double = 16000
    private let channelCount: Int = 1

    // Audio processing
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingFormat: AVAudioFormat?
    private var targetFormat: AVAudioFormat?
    private var audioConverter: AVAudioConverter?

    // Voice Activity Detection
    private var vadEnabled: Bool = true
    private var vadThreshold: Float = 0.01
    private var voiceActivityHistory: [Bool] = []
    private let vadWindowSize = 10

    // Processing state
    private var isProcessing = false
    private var audioBuffer: Data = Data()
    private var currentChunkIndex = 0
    private var lastVoiceActivityTime: TimeInterval = 0
    private var processingQueue = DispatchQueue(label: "com.whisper_kit.streaming.processing", qos: .userInitiated)
    private var audioProcessingQueue = OperationQueue()

    // Chunk management
    private var pendingChunks: [AudioChunk] = []
    private var processedTranscriptions: [TranscriptionResult] = []

    // Configuration
    struct Configuration {
        let chunkDuration: TimeInterval
        let overlapDuration: TimeInterval
        let silenceThreshold: Float
        let maxSilenceDuration: TimeInterval
        let vadEnabled: Bool
        let vadThreshold: Float
        let maxConcurrentOperations: Int

        static let `default` = Configuration(
            chunkDuration: 2.0,          // 2-second chunks
            overlapDuration: 0.5,        // 500ms overlap
            silenceThreshold: 0.01,      // Audio level threshold for silence
            maxSilenceDuration: 3.0,     // 3 seconds of silence before stopping
            vadEnabled: true,            // Enable Voice Activity Detection
            vadThreshold: 0.01,          // VAD sensitivity threshold
            maxConcurrentOperations: 2    // Max concurrent transcription operations
        )
    }

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.chunkDuration = configuration.chunkDuration
        self.overlapDuration = configuration.overlapDuration
        self.silenceThreshold = configuration.silenceThreshold
        self.maxSilenceDuration = configuration.maxSilenceDuration
        self.vadEnabled = configuration.vadEnabled
        self.vadThreshold = configuration.vadThreshold

        super.init()

        setupAudioProcessing(configuration: configuration)
    }

    deinit {
        stopProcessing()
    }

    // MARK: - Setup

    private func setupAudioProcessing(configuration: Configuration) {
        audioProcessingQueue.maxConcurrentOperationCount = configuration.maxConcurrentOperations
        audioProcessingQueue.qualityOfService = .userInitiated

        // Setup target format for Whisper
        targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
    }

    // MARK: - Public Interface

    func startProcessing() throws {
        guard !isProcessing else { return }

        logger.info("Starting streaming audio processing")

        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            throw StreamingAudioProcessorError.audioEngineFailure
        }

        recordingFormat = inputNode.outputFormat(forBus: 0)

        // Setup audio converter if needed
        if let recordingFormat = recordingFormat,
           let targetFormat = targetFormat,
           recordingFormat.sampleRate != targetFormat.sampleRate || recordingFormat.channelCount != targetFormat.channelCount {
            audioConverter = AVAudioConverter(from: recordingFormat, to: targetFormat)
        }

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(sampleRate * 0.1), format: recordingFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer, atTime: time)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isProcessing = true
        lastVoiceActivityTime = Date().timeIntervalSince1970

        DispatchQueue.main.async {
            self.delegate?.audioProcessorDidStartProcessing(self)
        }

        logger.info("Streaming audio processing started")
    }

    func stopProcessing() {
        guard isProcessing else { return }

        logger.info("Stopping streaming audio processing")

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Process remaining audio data
        if !audioBuffer.isEmpty {
            let finalChunk = createAudioChunk(from: audioBuffer, timestamp: Date().timeIntervalSince1970)
            processChunk(finalChunk)
        }

        isProcessing = false

        // Create final transcription
        let finalTranscription = consolidateTranscriptions()
        DispatchQueue.main.async {
            self.delegate?.audioProcessorDidCompleteProcessing(self, finalTranscription: finalTranscription)
        }

        logger.info("Streaming audio processing stopped")
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, atTime time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let audioData = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)

        // Analyze audio level and voice activity
        let audioLevel = calculateAudioLevel(from: audioData)
        let containsVoice = vadEnabled ? detectVoiceActivity(audioData: audioData, level: audioLevel) : true

        // Update voice activity history
        if containsVoice {
            lastVoiceActivityTime = Date().timeIntervalSince1970
        }

        voiceActivityHistory.append(containsVoice)
        if voiceActivityHistory.count > vadWindowSize {
            voiceActivityHistory.removeFirst()
        }

        // Append to audio buffer
        audioBuffer.append(audioData)

        // Check if we have enough data for a chunk
        let chunkSize = Int(chunkDuration * sampleRate * MemoryLayout<Float>.size)
        if audioBuffer.count >= chunkSize {
            let chunkData = audioBuffer.prefix(chunkSize)
            audioBuffer.removeFirst(chunkSize - Int(overlapDuration * sampleRate * MemoryLayout<Float>.size))

            let chunk = AudioChunk(
                data: Data(chunkData),
                timestamp: time.timeIntervalSince1970,
                duration: chunkDuration,
                audioLevel: audioLevel,
                containsVoice: containsVoice
            )

            processChunk(chunk)
        }

        // Check for extended silence
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastVoiceActivityTime > maxSilenceDuration && !audioBuffer.isEmpty {
            // Auto-stop on extended silence
            DispatchQueue.main.async {
                self.delegate?.audioProcessor(self, didDetectVoiceActivity: false)
            }
        }
    }

    private func processChunk(_ chunk: AudioChunk) {
        DispatchQueue.main.async {
            self.delegate?.audioProcessor(self, didDetectVoiceActivity: chunk.containsVoice)
        }

        // Only process chunks containing voice if VAD is enabled
        if !vadEnabled || chunk.containsVoice {
            pendingChunks.append(chunk)
            transcribeChunk(chunk)
        }
    }

    private func transcribeChunk(_ chunk: AudioChunk) {
        let operation = BlockOperation { [weak self] in
            self?.performTranscription(chunk: chunk)
        }

        audioProcessingQueue.addOperation(operation)
    }

    private func performTranscription(chunk: AudioChunk) {
        let startTime = Date().timeIntervalSince1970

        // In a real implementation, this would call the C++ whisper.cpp integration
        // For now, we'll simulate the transcription
        simulateTranscription(for: chunk) { [weak self] result in
            let processingTime = Date().timeIntervalSince1970 - startTime

            if var transcriptionResult = result {
                transcriptionResult.processingTime = processingTime
                self?.processedTranscriptions.append(transcriptionResult)

                DispatchQueue.main.async {
                    self?.delegate?.audioProcessor(self!, didProcessAudioChunk: chunk, transcription: transcriptionResult)
                }
            } else {
                DispatchQueue.main.async {
                    self?.delegate?.audioProcessor(self!, didEncounterError: StreamingAudioProcessorError.modelNotLoaded)
                }
            }
        }
    }

    // MARK: - Utility Methods

    private func calculateAudioLevel(from data: Data) -> Float {
        guard !data.isEmpty else { return 0.0 }

        let samples = data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Calculate RMS (Root Mean Square)
        var sum: Float = 0.0
        vDSP_vsq(samples, 1, &sum, vDSP_Length(samples.count))
        let rms = sqrt(sum / Float(samples.count))

        return min(rms, 1.0)
    }

    private func detectVoiceActivity(audioData: Data, level: Float) -> Bool {
        guard vadEnabled else { return true }

        // Simple threshold-based VAD
        let hasSignal = level > vadThreshold

        // Enhanced VAD using spectral analysis (simplified)
        if hasSignal {
            return analyzeSpectralContent(audioData: audioData)
        }

        return false
    }

    private func analyzeSpectralContent(audioData: Data) -> Bool {
        // This is a simplified spectral analysis
        // In a production implementation, you would use FFT-based analysis
        guard !audioData.isEmpty else { return false }

        let samples = audioData.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Calculate zero-crossing rate as a simple VAD feature
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                zeroCrossings += 1
            }
        }

        let zeroCrossingRate = Float(zeroCrossings) / Float(samples.count)
        return zeroCrossingRate > 0.1 // Threshold for voice-like signals
    }

    private func createAudioChunk(from data: Data, timestamp: TimeInterval) -> AudioChunk {
        let audioLevel = calculateAudioLevel(from: data)
        let containsVoice = detectVoiceActivity(audioData: data, level: audioLevel)
        let duration = Double(data.count) / (sampleRate * Double(MemoryLayout<Float>.size))

        return AudioChunk(
            data: data,
            timestamp: timestamp,
            duration: duration,
            audioLevel: audioLevel,
            containsVoice: containsVoice
        )
    }

    private func simulateTranscription(for chunk: AudioChunk, completion: @escaping (TranscriptionResult?) -> Void) {
        // Simulate processing delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            // This is a placeholder - in reality, this would call the whisper.cpp integration
            let simulatedText = chunk.containsVoice ? "This is a simulated transcription for chunk \(chunk.id)" : ""
            let transcription = TranscriptionResult(
                text: simulatedText,
                confidence: chunk.containsVoice ? 0.85 : 0.1,
                language: "en",
                timestamp: chunk.timestamp
            )
            completion(chunk.containsVoice ? transcription : nil)
        }
    }

    private func consolidateTranscriptions() -> TranscriptionResult {
        let combinedText = processedTranscriptions.map { $0.text }.joined(separator: " ")
        let averageConfidence = processedTranscriptions.isEmpty ? 0.0 :
            processedTranscriptions.map { $0.confidence }.reduce(0, +) / Float(processedTranscriptions.count)

        let allSegments = processedTranscriptions.flatMap { $0.segments }
        let detectedLanguage = processedTranscriptions.first?.language

        return TranscriptionResult(
            text: combinedText,
            segments: allSegments,
            confidence: averageConfidence,
            language: detectedLanguage,
            timestamp: Date().timeIntervalSince1970
        )
    }

    // MARK: - Configuration

    func updateConfiguration(_ configuration: Configuration) {
        // Update configuration properties
        // This would require restarting processing if currently active
    }

    func setVADThreshold(_ threshold: Float) {
        vadThreshold = max(0.0, min(1.0, threshold))
    }

    func getAudioBufferInfo() -> (duration: TimeInterval, size: Int) {
        let duration = Double(audioBuffer.count) / (sampleRate * Double(MemoryLayout<Float>.size))
        return (duration: duration, size: audioBuffer.count)
    }

    func getProcessingStats() -> (chunksProcessed: Int, transcriptionsGenerated: Int, averageLatency: TimeInterval) {
        return (
            chunksProcessed: currentChunkIndex,
            transcriptionsGenerated: processedTranscriptions.count,
            averageLatency: processedTranscriptions.isEmpty ? 0.0 :
                processedTranscriptions.map { $0.processingTime }.reduce(0, +) / Double(processedTranscriptions.count)
        )
    }
}