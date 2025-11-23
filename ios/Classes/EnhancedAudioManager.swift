import Foundation
import AVFoundation
import os.log

// MARK: - Enhanced Audio Configuration

struct EnhancedAudioConfiguration {
    let streamingConfig: StreamingAudioProcessor.Configuration
    let chunkingConfig: AudioChunkingConfiguration
    let preprocessingConfig: AudioPreprocessingSettings
    let vadConfig: VADConfiguration

    let enableRealTimeProcessing: Bool
    let enableAdaptiveProcessing: Bool
    let enableMultiFormatSupport: Bool
    let enableQualityOptimization: Bool

    static let `default` = EnhancedAudioConfiguration(
        streamingConfig: .default,
        chunkingConfig: .default,
        preprocessingConfig: .default,
        vadConfig: .default,
        enableRealTimeProcessing: true,
        enableAdaptiveProcessing: true,
        enableMultiFormatSupport: true,
        enableQualityOptimization: true
    )

    static let optimized = EnhancedAudioConfiguration(
        streamingConfig: .default,
        chunkingConfig: .optimized,
        preprocessingConfig: .aggressive,
        vadConfig: .sensitive,
        enableRealTimeProcessing: true,
        enableAdaptiveProcessing: true,
        enableMultiFormatSupport: true,
        enableQualityOptimization: true
    )

    static let realtime = EnhancedAudioConfiguration(
        streamingConfig: .default,
        chunkingConfig: .realtime,
        preprocessingConfig: .minimal,
        vadConfig: .sensitive,
        enableRealTimeProcessing: true,
        enableAdaptiveProcessing: false,
        enableMultiFormatSupport: false,
        enableQualityOptimization: false
    )
}

// MARK: - Enhanced Audio Manager Delegate

protocol EnhancedAudioManagerDelegate: AnyObject {
    func audioManager(_ manager: EnhancedAudioManager, didStartProcessing startTime: TimeInterval)
    func audioManager(_ manager: EnhancedAudioManager, didProcessChunk chunk: AudioChunk, transcription: TranscriptionResult?)
    func audioManager(_ manager: EnhancedAudioManager, didDetectVoiceActivity isActive: Bool, timestamp: TimeInterval)
    func audioManager(_ manager: EnhancedAudioManager, didUpdateProgress progress: Float)
    func audioManager(_ manager: EnhancedAudioManager, didCompleteProcessing finalResult: EnhancedAudioResult)
    func audioManager(_ manager: EnhancedAudioManager, didEncounterError error: Error)
    func audioManager(_ manager: EnhancedAudioManager, didChangeQuality quality: AudioQuality)
}

// MARK: - Enhanced Audio Result

struct EnhancedAudioResult {
    let text: String
    let segments: [EnhancedAudioSegment]
    let language: String?
    let confidence: Float
    let processingTime: TimeInterval
    let audioQuality: AudioQuality
    let metadata: AudioMetadata

    struct EnhancedAudioSegment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
        let chunkType: AudioChunkInfo.ChunkType
        let preprocessingApplied: Bool
        let audioQuality: AudioQuality
    }
}

enum AudioQuality {
    case excellent
    case good
    case fair
    case poor

    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    var score: Float {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.75
        case .fair: return 0.5
        case .poor: return 0.25
        }
    }
}

// MARK: - Enhanced Audio Manager

class EnhancedAudioManager: NSObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.whisper_kit", category: "EnhancedAudioManager")
    weak var delegate: EnhancedAudioManagerDelegate?

    // Configuration
    private var configuration: EnhancedAudioConfiguration

    // Core components
    private let audioRecorder = AudioRecorder()
    private let streamingProcessor: StreamingAudioProcessor
    private let audioChunker: AudioChunker
    private let audioPreprocessor: AudioPreprocessor
    private let vad: VoiceActivityDetector
    private let formatConverter = AudioFormatConverter()

    // Processing state
    private var isProcessing = false
    private var processingStartTime: TimeInterval?
    private var transcriptionResults: [TranscriptionResult] = []
    private var audioChunks: [AudioChunk] = []
    private var currentAudioQuality: AudioQuality = .good

    // Audio analysis
    private var qualityAnalysis: AudioQualityAnalysis?
    private var currentAudioFormat: AudioFormat = .wav

    // MARK: - Initialization

    init(configuration: EnhancedAudioConfiguration = .default, sampleRate: Double = 16000) {
        self.configuration = configuration
        self.streamingProcessor = StreamingAudioProcessor(configuration: configuration.streamingConfig)
        self.audioChunker = AudioChunker(configuration: configuration.chunkingConfig, sampleRate: sampleRate)
        self.audioPreprocessor = AudioPreprocessor(settings: configuration.preprocessingConfig, sampleRate: sampleRate)
        self.vad = VoiceActivityDetector(configuration: configuration.vadConfig, sampleRate: sampleRate)

        super.init()

        setupDelegates()
        logger.info("EnhancedAudioManager initialized")
    }

    // MARK: - Public Interface

    /// Start enhanced audio processing
    func startProcessing() throws {
        guard !isProcessing else {
            logger.warning("Audio processing is already active")
            return
        }

        logger.info("Starting enhanced audio processing")
        isProcessing = true
        processingStartTime = Date().timeIntervalSince1970
        transcriptionResults.removeAll()
        audioChunks.removeAll()

        // Start audio recording
        try audioRecorder.startRecording { [weak self] success, error in
            if success {
                self?.logger.info("Audio recording started successfully")
            } else if let error = error {
                self?.logger.error("Failed to start audio recording: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.delegate?.audioManager(self!, didEncounterError: error)
                }
            }
        }

        // Start streaming processor if enabled
        if configuration.enableRealTimeProcessing {
            try streamingProcessor.startProcessing()
        }

        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didStartProcessing: self.processingStartTime!)
        }
    }

    /// Stop enhanced audio processing
    func stopProcessing() {
        guard isProcessing else { return }

        logger.info("Stopping enhanced audio processing")
        isProcessing = false

        // Stop all components
        audioRecorder.stopRecording { _, _, _ in }
        streamingProcessor.stopProcessing()
        audioChunker.finalizeChunking()

        // Process remaining audio data
        processRemainingAudioData()

        // Create final result
        let finalResult = createFinalResult()

        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didCompleteProcessing: finalResult)
        }
    }

    /// Process audio file with enhanced processing
    func processAudioFile(url: URL, completion: @escaping (Result<EnhancedAudioResult, Error>) -> Void) {
        logger.info("Processing audio file: \(url.lastPathComponent)")

        // Detect audio format
        if configuration.enableMultiFormatSupport {
            currentAudioFormat = formatConverter.detectAudioFormat(url: url) ?? .wav
        }

        // Get audio metadata
        let metadata = formatConverter.getAudioMetadata(url: url)

        // Analyze audio quality
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData else {
                completion(.failure(EnhancedAudioError.invalidAudioData))
                return
            }

            let data = Data(bytes: channelData[0], count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
            qualityAnalysis = audioPreprocessor.analyzeAudioQuality(data)

            // Apply preprocessing if enabled
            let processedData: Data
            if configuration.enableQualityOptimization {
                processedData = try preprocessAudioData(data)
            } else {
                processedData = data
            }

            // Process through chunking system
            audioChunker.processAudioFile(url: url) { [weak self] result in
                switch result {
                case .success(let chunks):
                    self?.processChunks(chunks, data: processedData, metadata: metadata) { enhancedResult in
                        completion(.success(enhancedResult))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }

        } catch {
            completion(.failure(error))
        }
    }

    /// Update configuration
    func updateConfiguration(_ newConfiguration: EnhancedAudioConfiguration) {
        configuration = newConfiguration
        streamingProcessor.updateConfiguration(newConfiguration.streamingConfig)
        audioChunker.updateConfiguration(newConfiguration.chunkingConfig)
        audioPreprocessor.updateSettings(newConfiguration.preprocessingConfig)
        vad.updateConfiguration(newConfiguration.vadConfig)

        logger.info("Enhanced audio configuration updated")
    }

    /// Get current audio quality
    func getCurrentAudioQuality() -> AudioQuality {
        return currentAudioQuality
    }

    /// Get processing statistics
    func getProcessingStatistics() -> EnhancedProcessingStatistics {
        return EnhancedProcessingStatistics(
            isProcessing: isProcessing,
            processingStartTime: processingStartTime,
            totalTranscriptions: transcriptionResults.count,
            averageConfidence: calculateAverageConfidence(),
            currentAudioQuality: currentAudioQuality,
            audioFormat: currentAudioFormat,
            streamingStats: streamingProcessor.getProcessingStats(),
            chunkingStats: audioChunker.getStatistics(),
            vadStats: vad.getStatistics()
        )
    }

    // MARK: - Private Methods

    private func setupDelegates() {
        streamingProcessor.delegate = self
        audioChunker.delegate = self
        vad.delegate = self
    }

    private func preprocessAudioData(_ data: Data) throws -> Data {
        return try withUnsafeThrowingContinuation { continuation in
            audioPreprocessor.preprocessAudioData(data) { result in
                switch result {
                case .success(let processedData):
                    continuation.resume(returning: processedData)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func processChunks(_ chunks: [AudioChunkInfo], data: Data, metadata: AudioMetadata, completion: @escaping (EnhancedAudioResult) -> Void) {
        var enhancedSegments: [EnhancedAudioResult.EnhancedAudioSegment] = []
        var combinedText = ""
        var totalConfidence: Float = 0.0

        for chunk in chunks {
            // Simulate processing for each chunk
            let segmentText = "Processed chunk \(chunk.index) (\(chunk.duration)s)"
            let segmentConfidence = chunk.confidence

            enhancedSegments.append(EnhancedAudioResult.EnhancedAudioSegment(
                text: segmentText,
                startTime: chunk.startTime,
                endTime: chunk.endTime,
                confidence: segmentConfidence,
                chunkType: chunk.chunkType,
                preprocessingApplied: configuration.enableQualityOptimization,
                audioQuality: currentAudioQuality
            ))

            combinedText += (combinedText.isEmpty ? "" : " ") + segmentText
            totalConfidence += segmentConfidence
        }

        let averageConfidence = enhancedSegments.isEmpty ? 0.0 : totalConfidence / Float(enhancedSegments.count)
        let processingTime = Date().timeIntervalSince1970 - (processingStartTime ?? Date().timeIntervalSince1970)

        let result = EnhancedAudioResult(
            text: combinedText,
            segments: enhancedSegments,
            language: "en",
            confidence: averageConfidence,
            processingTime: processingTime,
            audioQuality: currentAudioQuality,
            metadata: metadata
        )

        completion(result)
    }

    private func processRemainingAudioData() {
        guard let audioData = audioRecorder.getAudioData() as Data?, !audioData.isEmpty else { return }

        // Process remaining audio through the pipeline
        if configuration.enableQualityOptimization {
            audioPreprocessor.preprocessAudioData(audioData) { [weak self] result in
                switch result {
                case .success(let processedData):
                    self?.audioChunker.addAudioData(processedData)
                case .failure(let error):
                    self?.logger.error("Failed to preprocess remaining audio: \(error.localizedDescription)")
                }
            }
        } else {
            audioChunker.addAudioData(audioData)
        }
    }

    private func createFinalResult() -> EnhancedAudioResult {
        let combinedText = transcriptionResults.map { $0.text }.joined(separator: " ")
        let averageConfidence = transcriptionResults.isEmpty ? 0.0 :
            transcriptionResults.map { $0.confidence }.reduce(0, +) / Float(transcriptionResults.count)

        let processingTime = processingStartTime.map { Date().timeIntervalSince1970 - $0 } ?? 0

        // Create enhanced segments from chunks and transcriptions
        var enhancedSegments: [EnhancedAudioResult.EnhancedAudioSegment] = []

        for (index, chunk) in audioChunks.enumerated() {
            let transcription = index < transcriptionResults.count ? transcriptionResults[index] : nil
            let text = transcription?.text ?? "No transcription available"

            enhancedSegments.append(EnhancedAudioResult.EnhancedAudioSegment(
                text: text,
                startTime: chunk.timestamp,
                endTime: chunk.timestamp + chunk.duration,
                confidence: transcription?.confidence ?? 0.0,
                chunkType: chunk.containsVoice ? .speech : .silence,
                preprocessingApplied: configuration.enableQualityOptimization,
                audioQuality: currentAudioQuality
            ))
        }

        // Create basic metadata
        let metadata = AudioMetadata(
            duration: processingTime,
            sampleRate: 16000,
            channelCount: 1,
            bitRate: 128000,
            fileSize: Int64(audioRecorder.getAudioData().count),
            format: currentAudioFormat
        )

        return EnhancedAudioResult(
            text: combinedText,
            segments: enhancedSegments,
            language: transcriptionResults.first?.language,
            confidence: averageConfidence,
            processingTime: processingTime,
            audioQuality: currentAudioQuality,
            metadata: metadata
        )
    }

    private func calculateAverageConfidence() -> Float {
        guard !transcriptionResults.isEmpty else { return 0.0 }
        return transcriptionResults.map { $0.confidence }.reduce(0, +) / Float(transcriptionResults.count)
    }
}

// MARK: - Enhanced Audio Manager Extensions

extension EnhancedAudioManager: StreamingAudioProcessorDelegate {
    func audioProcessorDidStartProcessing(_ processor: StreamingAudioProcessor) {
        logger.debug("Streaming audio processor started")
    }

    func audioProcessor(_ processor: StreamingAudioProcessor, didDetectVoiceActivity isActive: Bool) {
        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didDetectVoiceActivity: isActive, timestamp: Date().timeIntervalSince1970)
        }
    }

    func audioProcessor(_ processor: StreamingAudioProcessor, didProcessAudioChunk chunk: AudioChunk, transcription: TranscriptionResult?) {
        audioChunks.append(chunk)

        if let transcription = transcription {
            transcriptionResults.append(transcription)
        }

        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didProcessChunk: chunk, transcription: transcription)
        }
    }

    func audioProcessorDidCompleteProcessing(_ processor: StreamingAudioProcessor, finalTranscription: TranscriptionResult) {
        logger.debug("Streaming audio processor completed")
    }

    func audioProcessor(_ processor: StreamingAudioProcessor, didEncounterError error: Error) {
        logger.error("Streaming processor error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didEncounterError: error)
        }
    }
}

extension EnhancedAudioManager: AudioChunkerDelegate {
    func audioChunker(_ chunker: AudioChunker, didCreateChunk chunk: AudioChunkInfo, data: Data) {
        // Forward chunk to streaming processor if real-time processing is enabled
        if configuration.enableRealTimeProcessing {
            // Process chunk through VAD first
            vad.processAudioFrame(data)
        }
    }

    func audioChunker(_ chunker: AudioChunker, didUpdateProgress progress: Float) {
        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didUpdateProgress: progress)
        }
    }

    func audioChunker(_ chunker: AudioChunker, didCompleteChunking chunks: [AudioChunkInfo]) {
        logger.debug("Audio chunking completed with \(chunks.count) chunks")
    }

    func audioChunker(_ chunker: AudioChunker, didEncounterError error: Error) {
        logger.error("Audio chunker error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.delegate?.audioManager(self, didEncounterError: error)
        }
    }
}

extension EnhancedAudioManager: VoiceActivityDetectorDelegate {
    func vadDetector(_ detector: VoiceActivityDetector, didUpdateState state: VADState) {
        logger.debug("VAD state updated: \(state.description)")
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectActivity result: VADResult) {
        // Use VAD results to optimize processing
        updateAudioQualityBasedOnVAD(result)
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechStart timestamp: TimeInterval) {
        logger.debug("Speech detected at \(timestamp)")
    }

    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechEnd timestamp: TimeInterval) {
        logger.debug("Speech ended at \(timestamp)")
    }

    func vadDetector(_ detector: VoiceActivityDetector, didEncounterError error: Error) {
        logger.error("VAD error: \(error.localizedDescription)")
    }

    private func updateAudioQualityBasedOnVAD(_ result: VADResult) {
        let newQuality: AudioQuality

        if result.isSpeech && result.confidence > 0.8 {
            newQuality = .excellent
        } else if result.isSpeech && result.confidence > 0.6 {
            newQuality = .good
        } else if result.isSpeech {
            newQuality = .fair
        } else {
            newQuality = .poor
        }

        if newQuality != currentAudioQuality {
            currentAudioQuality = newQuality
            DispatchQueue.main.async {
                self.delegate?.audioManager(self, didChangeQuality: newQuality)
            }
        }
    }
}

// MARK: - Enhanced Audio Error

enum EnhancedAudioError: LocalizedError {
    case invalidAudioData
    case processingFailed
    case configurationError
    case componentInitializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidAudioData:
            return "Invalid audio data provided"
        case .processingFailed:
            return "Audio processing failed"
        case .configurationError:
            return "Invalid enhanced audio configuration"
        case .componentInitializationFailed:
            return "Failed to initialize audio components"
        }
    }
}

// MARK: - Enhanced Processing Statistics

struct EnhancedProcessingStatistics {
    let isProcessing: Bool
    let processingStartTime: TimeInterval?
    let totalTranscriptions: Int
    let averageConfidence: Float
    let currentAudioQuality: AudioQuality
    let audioFormat: AudioFormat
    let streamingStats: (chunksProcessed: Int, transcriptionsGenerated: Int, averageLatency: TimeInterval)
    let chunkingStats: AudioChunkingStatistics
    let vadStats: VADStatistics

    var description: String {
        return """
        Enhanced Audio Processing Statistics:
        Status: \(isProcessing ? "Processing" : "Idle")
        Processing Start: \(processingStartTime != nil ? Date(timeIntervalSince1970: processingStartTime!).description : "N/A")
        Total Transcriptions: \(totalTranscriptions)
        Average Confidence: \(String(format: "%.2f", averageConfidence))
        Audio Quality: \(currentAudioQuality.description)
        Audio Format: \(audioFormat.fileExtension)
        Streaming Stats: \(streamingStats.chunksProcessed) chunks, \(streamingStats.transcriptionsGenerated) transcriptions
        Average Latency: \(String(format: "%.3f", streamingStats.averageLatency))s
        """
    }
}