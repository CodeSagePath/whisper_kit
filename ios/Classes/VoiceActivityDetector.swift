import Foundation
import AVFoundation
import Accelerate
import os.log

// MARK: - VAD Configuration

struct VADConfiguration {
    let sensitivity: Float            // 0.0 (least sensitive) to 1.0 (most sensitive)
    let aggressiveness: Int           // 0-3, higher means more aggressive VAD
    let frameSizeMs: Int             // Frame size in milliseconds (10, 20, 30)
    let vadMode: VADMode             // Detection mode
    let enableEnergyBased: Bool       // Enable energy-based detection
    let enableZeroCrossing: Bool      // Enable zero-crossing rate analysis
    let enableSpectral: Bool         // Enable spectral analysis
    let enableMLDetection: Bool      // Enable machine learning detection
    let minSpeechDurationMs: Int     // Minimum duration for speech detection
    let maxSilenceDurationMs: Int    // Maximum silence before speech end
    let preSpeechPaddingMs: Int      // Padding before speech detection
    let postSpeechPaddingMs: Int     // Padding after speech detection

    enum VADMode {
        case normal    // Balanced accuracy and speed
        case lowBitrate  // Optimized for low bitrate audio
        case aggressive  // More aggressive speech detection
        case veryAggressive // Very aggressive detection

        var frameSizeMs: Int {
            switch self {
            case .normal: return 30
            case .lowBitrate: return 20
            case .aggressive: return 30
            case .veryAggressive: return 30
            }
        }
    }

    static let `default` = VADConfiguration(
        sensitivity: 0.5,
        aggressiveness: 2,
        frameSizeMs: 30,
        vadMode: .normal,
        enableEnergyBased: true,
        enableZeroCrossing: true,
        enableSpectral: true,
        enableMLDetection: false,
        minSpeechDurationMs: 250,
        maxSilenceDurationMs: 1000,
        preSpeechPaddingMs: 150,
        postSpeechPaddingMs: 300
    )

    static let sensitive = VADConfiguration(
        sensitivity: 0.8,
        aggressiveness: 1,
        frameSizeMs: 20,
        vadMode: .normal,
        enableEnergyBased: true,
        enableZeroCrossing: true,
        enableSpectral: true,
        enableMLDetection: true,
        minSpeechDurationMs: 100,
        maxSilenceDurationMs: 500,
        preSpeechPaddingMs: 100,
        postSpeechPaddingMs: 200
    )
}

// MARK: - VAD Detection Results

struct VADResult {
    let isSpeech: Bool
    let confidence: Float          // Confidence in detection (0.0 to 1.0)
    let energy: Float             // Energy level
    let zeroCrossingRate: Float    // Zero-crossing rate
    let spectralCentroid: Float   // Spectral centroid
    let spectralRolloff: Float    // Spectral rolloff
    let timestamp: TimeInterval   // Timestamp of detection
    let frameDuration: TimeInterval // Duration of analyzed frame

    var description: String {
        if isSpeech {
            return "Speech detected (confidence: \(String(format: "%.2f", confidence)))"
        } else {
            return "Silence detected (confidence: \(String(format: "%.2f", 1.0 - confidence)))"
        }
    }
}

// MARK: - VAD State

enum VADState {
    case silence                    // Currently in silence
    case possibleSpeech            // Possible speech detected
    case speech                    // Speech confirmed
    case possibleSilence           // Possible silence during speech
    case extendedSilence           // Extended silence, speech ended

    var description: String {
        switch self {
        case .silence: return "Silence"
        case .possibleSpeech: return "Possible Speech"
        case .speech: return "Speech"
        case .possibleSilence: return "Possible Silence"
        case .extendedSilence: return "Extended Silence"
        }
    }
}

// MARK: - VAD Delegate

protocol VoiceActivityDetectorDelegate: AnyObject {
    func vadDetector(_ detector: VoiceActivityDetector, didUpdateState state: VADState)
    func vadDetector(_ detector: VoiceActivityDetector, didDetectActivity result: VADResult)
    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechStart timestamp: TimeInterval)
    func vadDetector(_ detector: VoiceActivityDetector, didDetectSpeechEnd timestamp: TimeInterval)
    func vadDetector(_ detector: VoiceActivityDetector, didEncounterError error: Error)
}

// MARK: - Voice Activity Detector

class VoiceActivityDetector: NSObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.whisper_kit", category: "VoiceActivityDetector")
    weak var delegate: VoiceActivityDetectorDelegate?

    // Configuration
    private var configuration: VADConfiguration
    private let sampleRate: Double
    private let frameSize: Int

    // VAD state
    private var currentState: VADState = .silence
    private var speechStartTime: TimeInterval?
    private var lastSpeechTime: TimeInterval?
    private var consecutiveSpeechFrames: Int = 0
    private var consecutiveSilenceFrames: Int = 0

    // Feature extraction
    private var energyHistory: [Float] = []
    private var zcrHistory: [Float] = []
    private var spectralHistory: [Float] = []
    private let historySize = 20

    // Thresholds (adaptive)
    private var energyThreshold: Float = 0.01
    private var zcrThreshold: Float = 0.1
    private var spectralThreshold: Float = 0.5

    // Processing
    private let processingQueue = DispatchQueue(label: "com.whisper_kit.vad.processing", qos: .userInitiated)

    // MARK: - Initialization

    init(configuration: VADConfiguration = .default, sampleRate: Double = 16000) {
        self.configuration = configuration
        self.sampleRate = sampleRate
        self.frameSize = Int(sampleRate * Double(configuration.frameSizeMs) / 1000.0)
        super.init()

        setupThresholds()
        logger.info("VAD initialized with frame size: \(frameSize), sample rate: \(sampleRate)")
    }

    // MARK: - Public Interface

    /// Process audio frame for voice activity detection
    func processAudioFrame(_ audioData: Data, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        processingQueue.async {
            let result = self.detectVoiceActivity(audioData: audioData, timestamp: timestamp)
            self.processVADResult(result)
        }
    }

    /// Process audio buffer for voice activity detection
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        guard let channelData = buffer.floatChannelData else {
            logger.error("Invalid audio buffer provided to VAD")
            return
        }

        let frameLength = Int(buffer.frameLength)
        let audioData = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)

        processAudioFrame(audioData, timestamp: timestamp)
    }

    /// Reset VAD state
    func reset() {
        processingQueue.async {
            self.currentState = .silence
            self.speechStartTime = nil
            self.lastSpeechTime = nil
            self.consecutiveSpeechFrames = 0
            self.consecutiveSilenceFrames = 0
            self.energyHistory.removeAll()
            self.zcrHistory.removeAll()
            self.spectralHistory.removeAll()
            self.logger.info("VAD state reset")
        }
    }

    /// Update VAD configuration
    func updateConfiguration(_ newConfiguration: VADConfiguration) {
        processingQueue.async {
            self.configuration = newConfiguration
            self.setupThresholds()
            self.logger.info("VAD configuration updated")
        }
    }

    /// Get current VAD state
    func getCurrentState() -> VADState {
        return currentState
    }

    /// Get current statistics
    func getStatistics() -> VADStatistics {
        return VADStatistics(
            currentState: currentState,
            energyThreshold: energyThreshold,
            zcrThreshold: zcrThreshold,
            spectralThreshold: spectralThreshold,
            averageEnergy: energyHistory.isEmpty ? 0.0 : energyHistory.reduce(0, +) / Float(energyHistory.count),
            averageZCR: zcrHistory.isEmpty ? 0.0 : zcrHistory.reduce(0, +) / Float(zcrHistory.count)
        )
    }

    // MARK: - Private Detection Methods

    private func detectVoiceActivity(audioData: Data, timestamp: TimeInterval) -> VADResult {
        guard !audioData.isEmpty else {
            return VADResult(
                isSpeech: false,
                confidence: 0.0,
                energy: 0.0,
                zeroCrossingRate: 0.0,
                spectralCentroid: 0.0,
                spectralRolloff: 0.0,
                timestamp: timestamp,
                frameDuration: Double(configuration.frameSizeMs) / 1000.0
            )
        }

        // Convert to float samples
        let samples = audioData.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Extract features
        let energy = calculateEnergy(samples: samples)
        let zcr = calculateZeroCrossingRate(samples: samples)
        let (spectralCentroid, spectralRolloff) = calculateSpectralFeatures(samples: samples)

        // Update history
        updateHistory(energy: energy, zcr: zcr, spectral: (spectralCentroid + spectralRolloff) / 2.0)

        // Multi-feature decision
        var speechProbability: Float = 0.0
        var featureWeight: Float = 1.0 / 3.0

        if configuration.enableEnergyBased {
            let energyScore = (energy - energyThreshold) / max(energyThreshold, 0.001)
            speechProbability += max(0.0, min(1.0, energyScore)) * featureWeight
        }

        if configuration.enableZeroCrossing {
            let zcrScore = (zcr - zcrThreshold) / max(zcrThreshold, 0.001)
            speechProbability += max(0.0, min(1.0, zcrScore)) * featureWeight
        }

        if configuration.enableSpectral {
            let spectralScore = ((spectralCentroid + spectralRolloff) / 2.0 - spectralThreshold) / max(spectralThreshold, 0.001)
            speechProbability += max(0.0, min(1.0, spectralScore)) * featureWeight
        }

        // Apply sensitivity and aggressiveness
        speechProbability = applyAggressiveness(speechProbability)
        let isSpeech = speechProbability > configuration.sensitivity

        return VADResult(
            isSpeech: isSpeech,
            confidence: isSpeech ? speechProbability : 1.0 - speechProbability,
            energy: energy,
            zeroCrossingRate: zcr,
            spectralCentroid: spectralCentroid,
            spectralRolloff: spectralRolloff,
            timestamp: timestamp,
            frameDuration: Double(configuration.frameSizeMs) / 1000.0
        )
    }

    private func processVADResult(_ result: VADResult) {
        let previousState = currentState
        let currentTime = result.timestamp

        // Update counters
        if result.isSpeech {
            consecutiveSpeechFrames += 1
            consecutiveSilenceFrames = 0
            lastSpeechTime = currentTime

            if currentState == .silence {
                currentState = .possibleSpeech
            } else if currentState == .possibleSpeech && consecutiveSpeechFrames >= 2 {
                currentState = .speech
                speechStartTime = currentTime
                DispatchQueue.main.async {
                    self.delegate?.vadDetector(self, didDetectSpeechStart: currentTime)
                }
            } else if currentState == .possibleSilence {
                currentState = .speech
            }
        } else {
            consecutiveSilenceFrames += 1
            consecutiveSpeechFrames = 0

            if currentState == .speech {
                currentState = .possibleSilence
            } else if currentState == .possibleSilence && consecutiveSilenceFrames >= 3 {
                currentState = .extendedSilence
                if let startTime = speechStartTime {
                    DispatchQueue.main.async {
                        self.delegate?.vadDetector(self, didDetectSpeechEnd: currentTime)
                    }
                }
                speechStartTime = nil
            } else if currentState == .possibleSpeech {
                currentState = .silence
            } else if currentState == .extendedSilence {
                currentState = .silence
            }
        }

        // Notify state change
        if previousState != currentState {
            logger.debug("VAD state changed: \(previousState.description) -> \(currentState.description)")
            DispatchQueue.main.async {
                self.delegate?.vadDetector(self, didUpdateState: self.currentState)
            }
        }

        // Notify activity detection
        DispatchQueue.main.async {
            self.delegate?.vadDetector(self, didDetectActivity: result)
        }
    }

    // MARK: - Feature Extraction

    private func calculateEnergy(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        var sum: Float = 0.0
        vDSP_vsq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }

    private func calculateZeroCrossingRate(samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0.0 }

        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(samples.count - 1)
    }

    private func calculateSpectralFeatures(samples: [Float]) -> (centroid: Float, rolloff: Float) {
        guard !samples.isEmpty else { return (0.0, 0.0) }

        // Compute FFT
        let fftSize = nextPowerOfTwo(samples.count)
        var real = [Float](repeating: 0.0, count: fftSize / 2)
        var imag = [Float](repeating: 0.0, count: fftSize / 2)

        // Prepare input for FFT
        let paddedSamples = samples + [Float](repeating: 0.0, count: fftSize - samples.count)

        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: fftSize)
        defer { tempBuffer.deallocate() }

        // Copy samples to temp buffer
        paddedSamples.withUnsafeBufferPointer { buffer in
            tempBuffer.initialize(from: buffer)
        }

        // Perform FFT
        vDSP_fft_zrip(vDSP_create_fftsetup(vDSP_Length(log2(Double(fftSize))), FFTRadix(kFFTRadix2))!,
                      &splitComplex, 1, vDSP_Length(log2(Double(fftSize))))

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Calculate spectral centroid
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0

        for i in 0..<(fftSize / 2) {
            let frequency = Float(i) * Float(sampleRate) / Float(fftSize)
            weightedSum += frequency * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }

        let centroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0

        // Calculate spectral rolloff (95% of energy)
        let totalEnergy = magnitudeSum
        var cumulativeEnergy: Float = 0.0
        var rolloffIndex = 0

        for i in 0..<(fftSize / 2) {
            cumulativeEnergy += magnitudes[i]
            if cumulativeEnergy >= 0.95 * totalEnergy {
                rolloffIndex = i
                break
            }
        }

        let rolloff = Float(rolloffIndex) * Float(sampleRate) / Float(fftSize)

        return (centroid: centroid, rolloff: rolloff)
    }

    // MARK: - Adaptive Thresholding

    private func setupThresholds() {
        // Initial thresholds based on configuration
        energyThreshold = 0.01 + Float(1.0 - configuration.sensitivity) * 0.09
        zcrThreshold = 0.05 + Float(1.0 - configuration.sensitivity) * 0.15
        spectralThreshold = 0.3 + Float(1.0 - configuration.sensitivity) * 0.4
    }

    private func updateHistory(energy: Float, zcr: Float, spectral: Float) {
        energyHistory.append(energy)
        zcrHistory.append(zcr)
        spectralHistory.append(spectral)

        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }
        if zcrHistory.count > historySize {
            zcrHistory.removeFirst()
        }
        if spectralHistory.count > historySize {
            spectralHistory.removeFirst()
        }

        // Update adaptive thresholds
        if energyHistory.count >= historySize / 2 {
            updateAdaptiveThresholds()
        }
    }

    private func updateAdaptiveThresholds() {
        let energyMedian = calculateMedian(energyHistory)
        let zcrMedian = calculateMedian(zcrHistory)
        let spectralMedian = calculateMedian(spectralHistory)

        // Apply exponential smoothing to threshold updates
        let smoothingFactor: Float = 0.1
        energyThreshold = smoothingFactor * energyMedian + (1.0 - smoothingFactor) * energyThreshold
        zcrThreshold = smoothingFactor * zcrMedian + (1.0 - smoothingFactor) * zcrThreshold
        spectralThreshold = smoothingFactor * spectralMedian + (1.0 - smoothingFactor) * spectralThreshold
    }

    // MARK: - Utility Methods

    private func applyAggressiveness(_ probability: Float) -> Float {
        switch configuration.aggressiveness {
        case 0:
            return probability
        case 1:
            return probability * 1.1
        case 2:
            return probability * 1.2
        case 3:
            return probability * 1.3
        default:
            return probability
        }
    }

    private func calculateMedian(_ array: [Float]) -> Float {
        guard !array.isEmpty else { return 0.0 }

        let sorted = array.sorted()
        let count = sorted.count

        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        guard n > 0 else { return 1 }
        return 1 << (Int(ceil(log2(Double(n)))))
    }
}

// MARK: - VAD Statistics

struct VADStatistics {
    let currentState: VADState
    let energyThreshold: Float
    let zcrThreshold: Float
    let spectralThreshold: Float
    let averageEnergy: Float
    let averageZCR: Float

    var description: String {
        return """
        VAD Statistics:
        State: \(currentState.description)
        Energy Threshold: \(String(format: "%.4f", energyThreshold))
        ZCR Threshold: \(String(format: "%.4f", zcrThreshold))
        Spectral Threshold: \(String(format: "%.4f", spectralThreshold))
        Average Energy: \(String(format: "%.4f", averageEnergy))
        Average ZCR: \(String(format: "%.4f", averageZCR))
        """
    }
}