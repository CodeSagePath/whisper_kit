import Foundation
import AVFoundation
import Accelerate
import os.log

struct AudioPreprocessingSettings {
    let enableNoiseReduction: Bool
    let enableNormalization: Bool
    let enableHighPassFilter: Bool
    let enableLowPassFilter: Bool
    let enableDynamicRangeCompression: Bool
    let enableVoiceEnhancement: Bool

    // Noise reduction settings
    let noiseGateThreshold: Float      // Threshold below which audio is considered noise
    let noiseReductionStrength: Float  // Strength of noise reduction (0.0 to 1.0)

    // Normalization settings
    let targetLevel: Float             // Target RMS level for normalization
    let peakLimit: Float              // Peak level limiting (0.0 to 1.0)

    // Filter settings
    let highPassFrequency: Float       // High-pass filter cutoff frequency
    let lowPassFrequency: Float        // Low-pass filter cutoff frequency

    // Voice enhancement settings
    let formantEmphasis: Float         // Emphasis on speech formants
    let presenceBoost: Float          // Boost for vocal presence

    static let `default` = AudioPreprocessingSettings(
        enableNoiseReduction: true,
        enableNormalization: true,
        enableHighPassFilter: true,
        enableLowPassFilter: false,
        enableDynamicRangeCompression: true,
        enableVoiceEnhancement: true,
        noiseGateThreshold: 0.02,
        noiseReductionStrength: 0.7,
        targetLevel: -12.0,            // -12 dBFS RMS
        peakLimit: 0.95,              // -0.5 dBFS peak
        highPassFrequency: 80.0,      // 80 Hz high-pass
        lowPassFrequency: 8000.0,     // 8 kHz low-pass
        formantEmphasis: 0.3,
        presenceBoost: 0.2
    )

    static let minimal = AudioPreprocessingSettings(
        enableNoiseReduction: false,
        enableNormalization: true,
        enableHighPassFilter: true,
        enableLowPassFilter: false,
        enableDynamicRangeCompression: false,
        enableVoiceEnhancement: false,
        noiseGateThreshold: 0.01,
        noiseReductionStrength: 0.5,
        targetLevel: -15.0,
        peakLimit: 0.9,
        highPassFrequency: 80.0,
        lowPassFrequency: 8000.0,
        formantEmphasis: 0.0,
        presenceBoost: 0.0
    )

    static let aggressive = AudioPreprocessingSettings(
        enableNoiseReduction: true,
        enableNormalization: true,
        enableHighPassFilter: true,
        enableLowPassFilter: true,
        enableDynamicRangeCompression: true,
        enableVoiceEnhancement: true,
        noiseGateThreshold: 0.03,
        noiseReductionStrength: 0.9,
        targetLevel: -10.0,
        peakLimit: 0.85,
        highPassFrequency: 100.0,
        lowPassFrequency: 6000.0,
        formantEmphasis: 0.5,
        presenceBoost: 0.4
    )
}

enum AudioPreprocessingError: LocalizedError {
    case invalidAudioData
    case processingFailed
    case filterInitializationFailed
    case insufficientMemory

    var errorDescription: String? {
        switch self {
        case .invalidAudioData:
            return "Invalid audio data provided"
        case .processingFailed:
            return "Audio processing failed"
        case .filterInitializationFailed:
            return "Failed to initialize audio filters"
        case .insufficientMemory:
            return "Insufficient memory for audio processing"
        }
    }
}

class AudioPreprocessor: NSObject {
    private let logger = Logger(subsystem: "com.whisper_kit", category: "AudioPreprocessor")
    private let processingQueue = DispatchQueue(label: "com.whisper_kit.audio.preprocessing", qos: .userInitiated)

    // Processing state
    private var settings: AudioPreprocessingSettings
    private var sampleRate: Double
    private var channelCount: Int

    // Filter components
    private var highPassFilter: BiquadFilter?
    private var lowPassFilter: BiquadFilter?
    private var noiseProfile: NoiseProfile?

    // MARK: - Initialization

    init(settings: AudioPreprocessingSettings = .default, sampleRate: Double = 16000, channelCount: Int = 1) {
        self.settings = settings
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        super.init()
        setupFilters()
    }

    // MARK: - Public Interface

    /// Preprocess audio data with current settings
    func preprocessAudioData(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        processingQueue.async {
            do {
                let processedData = try self.performPreprocessing(data)
                DispatchQueue.main.async {
                    completion(.success(processedData))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Preprocess audio buffer
    func preprocessAudioBuffer(_ buffer: AVAudioPCMBuffer, completion: @escaping (Result<AVAudioPCMBuffer, Error>) -> Void) {
        processingQueue.async {
            do {
                let processedBuffer = try self.processAudioBuffer(buffer)
                DispatchQueue.main.async {
                    completion(.success(processedBuffer))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Update preprocessing settings
    func updateSettings(_ newSettings: AudioPreprocessingSettings) {
        processingQueue.async {
            self.settings = newSettings
            self.setupFilters()
        }
    }

    /// Analyze audio quality and suggest optimal settings
    func analyzeAudioQuality(_ data: Data) -> AudioQualityAnalysis {
        guard !data.isEmpty else {
            return AudioQualityAnalysis(
                signalToNoiseRatio: 0.0,
                peakLevel: 0.0,
                rmsLevel: 0.0,
                dynamicRange: 0.0,
                recommendedSettings: .minimal
            )
        }

        let samples = data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Calculate audio metrics
        let peakLevel = calculatePeakLevel(samples: samples)
        let rmsLevel = calculateRMSLevel(samples: samples)
        let dynamicRange = calculateDynamicRange(samples: samples)
        let snr = estimateSNR(samples: samples)

        // Determine optimal settings
        let recommendedSettings = determineOptimalSettings(
            snr: snr,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            dynamicRange: dynamicRange
        )

        return AudioQualityAnalysis(
            signalToNoiseRatio: snr,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            dynamicRange: dynamicRange,
            recommendedSettings: recommendedSettings
        )
    }

    // MARK: - Private Processing Methods

    private func performPreprocessing(_ data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw AudioPreprocessingError.invalidAudioData
        }

        // Convert to float samples
        var samples = data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }

        // Apply preprocessing steps
        if settings.enableNoiseReduction {
            samples = try applyNoiseReduction(samples: samples)
        }

        if settings.enableHighPassFilter {
            samples = applyHighPassFilter(samples: samples)
        }

        if settings.enableLowPassFilter {
            samples = applyLowPassFilter(samples: samples)
        }

        if settings.enableVoiceEnhancement {
            samples = applyVoiceEnhancement(samples: samples)
        }

        if settings.enableDynamicRangeCompression {
            samples = applyDynamicRangeCompression(samples: samples)
        }

        if settings.enableNormalization {
            samples = applyNormalization(samples: samples)
        }

        // Apply peak limiting
        samples = applyPeakLimiting(samples: samples, limit: settings.peakLimit)

        // Convert back to Data
        return samples.withUnsafeBytes { Data($0) }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else {
            throw AudioPreprocessingError.invalidAudioData
        }

        let sampleCount = Int(buffer.frameLength)
        var samples = Array(UnsafeBufferPointer(start: channelData[0], count: sampleCount))

        // Apply preprocessing steps
        if settings.enableNoiseReduction {
            samples = try applyNoiseReduction(samples: samples)
        }

        if settings.enableHighPassFilter {
            samples = applyHighPassFilter(samples: samples)
        }

        if settings.enableLowPassFilter {
            samples = applyLowPassFilter(samples: samples)
        }

        if settings.enableVoiceEnhancement {
            samples = applyVoiceEnhancement(samples: samples)
        }

        if settings.enableDynamicRangeCompression {
            samples = applyDynamicRangeCompression(samples: samples)
        }

        if settings.enableNormalization {
            samples = applyNormalization(samples: samples)
        }

        samples = applyPeakLimiting(samples: samples, limit: settings.peakLimit)

        // Copy processed samples back to buffer
        memcpy(channelData[0], samples, samples.count * MemoryLayout<Float>.size)

        return buffer
    }

    // MARK: - Noise Reduction

    private func applyNoiseReduction(samples: [Float]) throws -> [Float] {
        guard settings.enableNoiseReduction else { return samples }

        // Implement spectral subtraction for noise reduction
        let noiseThreshold = settings.noiseGateThreshold
        let strength = settings.noiseReductionStrength

        // Update noise profile
        updateNoiseProfile(samples: samples)

        return samples.map { sample in
            let magnitude = abs(sample)
            if magnitude < noiseThreshold {
                // Apply noise reduction
                return sample * (1.0 - strength)
            }
            return sample
        }
    }

    private func updateNoiseProfile(samples: [Float]) {
        // Simple noise profile estimation
        let recentSamples = Array(samples.suffix(min(1024, samples.count)))
        let averageNoiseLevel = recentSamples.map { abs($0) }.reduce(0, +) / Float(recentSamples.count)

        if noiseProfile == nil {
            noiseProfile = NoiseProfile(averageLevel: averageNoiseLevel, variance: 0.0)
        } else {
            noiseProfile?.update(with: averageNoiseLevel)
        }
    }

    // MARK: - Filtering

    private func applyHighPassFilter(samples: [Float]) -> [Float] {
        guard let filter = highPassFilter else { return samples }

        return samples.map { filter.process($0) }
    }

    private func applyLowPassFilter(samples: [Float]) -> [Float] {
        guard let filter = lowPassFilter else { return samples }

        return samples.map { filter.process($0) }
    }

    // MARK: - Voice Enhancement

    private func applyVoiceEnhancement(samples: [Float]) -> [Float] {
        guard settings.enableVoiceEnhancement else { return samples }

        // Apply formant emphasis for speech enhancement
        let formantFreq1: Float = 500.0
        let formantFreq2: Float = 1500.0
        let formantFreq3: Float = 2500.0

        return samples.enumerated().map { index, sample in
            let time = Float(index) / Float(sampleRate)
            let enhanced = sample +
                sin(2.0 * Float.pi * formantFreq1 * time) * settings.formantEmphasis * 0.1 +
                sin(2.0 * Float.pi * formantFreq2 * time) * settings.formantEmphasis * 0.05 +
                sin(2.0 * Float.pi * formantFreq3 * time) * settings.formantEmphasis * 0.025

            // Add presence boost for vocal clarity
            return enhanced * (1.0 + settings.presenceBoost)
        }
    }

    // MARK: - Dynamic Range Compression

    private func applyDynamicRangeCompression(samples: [Float]) -> [Float] {
        guard settings.enableDynamicRangeCompression else { return samples }

        // Simple compressor with 4:1 ratio
        let threshold: Float = -12.0 // dB
        let ratio: Float = 4.0
        let attackTime: Float = 0.003 // 3ms
        let releaseTime: Float = 0.1 // 100ms

        var envelope: Float = 0.0
        let sampleRateFloat = Float(sampleRate)

        return samples.map { sample in
            let inputLevel = 20.0 * log10(abs(sample) + 1e-10) // Convert to dB

            if inputLevel > threshold {
                let amountOverThreshold = inputLevel - threshold
                let compressedLevel = threshold + amountOverThreshold / ratio
                let gainReduction = compressedLevel - inputLevel

                // Apply attack/release smoothing
                let targetEnvelope = gainReduction
                let timeConstant = targetEnvelope > envelope ? attackTime : releaseTime
                let coefficient = exp(-1.0 / (timeConstant * sampleRateFloat))
                envelope = coefficient * envelope + (1.0 - coefficient) * targetEnvelope

                return sample * pow(10.0, envelope / 20.0)
            } else {
                envelope *= exp(-1.0 / (releaseTime * sampleRateFloat))
                return sample * pow(10.0, envelope / 20.0)
            }
        }
    }

    // MARK: - Normalization

    private func applyNormalization(samples: [Float]) -> [Float] {
        guard settings.enableNormalization else { return samples }

        let currentRMS = calculateRMSLevel(samples: samples)
        let targetRMS = pow(10.0, settings.targetLevel / 20.0) // Convert dB to linear

        guard currentRMS > 0 else { return samples }

        let gainFactor = targetRMS / currentRMS
        return samples.map { $0 * gainFactor }
    }

    // MARK: - Peak Limiting

    private func applyPeakLimiting(samples: [Float], limit: Float) -> [Float] {
        return samples.map { sample in
            let magnitude = abs(sample)
            if magnitude > limit {
                return limit * (sample / magnitude)
            }
            return sample
        }
    }

    // MARK: - Audio Analysis

    private func calculatePeakLevel(samples: [Float]) -> Float {
        return samples.map { abs($0) }.max() ?? 0.0
    }

    private func calculateRMSLevel(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        var sum: Float = 0.0
        vDSP_vsq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }

    private func calculateDynamicRange(samples: [Float]) -> Float {
        let peak = calculatePeakLevel(samples: samples)
        let rms = calculateRMSLevel(samples: samples)

        guard rms > 0 && peak > 0 else { return 0.0 }

        let peakDb = 20.0 * log10(peak)
        let rmsDb = 20.0 * log10(rms)
        return peakDb - rmsDb
    }

    private func estimateSNR(samples: [Float]) -> Float {
        // Simple SNR estimation based on signal vs noise levels
        let signalLevel = calculateRMSLevel(samples: samples)

        // Estimate noise level from quiet portions
        let quietSamples = samples.filter { abs($0) < 0.01 }
        let noiseLevel = quietSamples.isEmpty ? 0.001 : calculateRMSLevel(samples: quietSamples)

        guard noiseLevel > 0 else { return 60.0 } // High SNR

        return 20.0 * log10(signalLevel / noiseLevel)
    }

    private func determineOptimalSettings(snr: Float, peakLevel: Float, rmsLevel: Float, dynamicRange: Float) -> AudioPreprocessingSettings {
        if snr < 10 {
            return .aggressive // High noise level
        } else if snr < 20 || peakLevel > 0.9 || rmsLevel < 0.1 {
            return .default // Moderate quality
        } else {
            return .minimal // Good quality
        }
    }

    // MARK: - Filter Setup

    private func setupFilters() {
        if settings.enableHighPassFilter {
            highPassFilter = BiquadFilter(
                type: .highPass,
                frequency: settings.highPassFrequency,
                sampleRate: sampleRate,
                q: 0.7
            )
        }

        if settings.enableLowPassFilter {
            lowPassFilter = BiquadFilter(
                type: .lowPass,
                frequency: settings.lowPassFrequency,
                sampleRate: sampleRate,
                q: 0.7
            )
        }
    }
}

// MARK: - Supporting Classes

private class NoiseProfile {
    var averageLevel: Float
    var variance: Float
    var updateCount: Int

    init(averageLevel: Float, variance: Float) {
        self.averageLevel = averageLevel
        self.variance = variance
        self.updateCount = 1
    }

    func update(with newLevel: Float) {
        let alpha: Float = 0.1 // Smoothing factor
        averageLevel = alpha * newLevel + (1.0 - alpha) * averageLevel
        updateCount += 1
    }
}

private class BiquadFilter {
    enum FilterType {
        case lowPass
        case highPass
        case bandPass
        case notch
    }

    private var type: FilterType
    private var frequency: Float
    private var sampleRate: Double
    private var q: Float

    private var b0: Float = 0.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0

    init(type: FilterType, frequency: Float, sampleRate: Double, q: Float = 0.707) {
        self.type = type
        self.frequency = frequency
        self.sampleRate = sampleRate
        self.q = q
        calculateCoefficients()
    }

    private func calculateCoefficients() {
        let sampleRateFloat = Float(sampleRate)
        let omega = 2.0 * Float.pi * frequency / sampleRateFloat
        let sinW = sin(omega)
        let cosW = cos(omega)
        let alpha = sinW / (2.0 * q)

        switch type {
        case .lowPass:
            b0 = (1.0 - cosW) / 2.0
            b1 = 1.0 - cosW
            b2 = (1.0 - cosW) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW
            a2 = 1.0 - alpha

        case .highPass:
            b0 = (1.0 + cosW) / 2.0
            b1 = -(1.0 + cosW)
            b2 = (1.0 + cosW) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW
            a2 = 1.0 - alpha

        case .bandPass, .notch:
            b0 = 1.0
            b1 = -2.0 * cosW
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW
            a2 = 1.0 - alpha
        }

        // Normalize coefficients
        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
    }

    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        // Update delay lines
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }
}

// MARK: - Audio Quality Analysis

struct AudioQualityAnalysis {
    let signalToNoiseRatio: Float
    let peakLevel: Float
    let rmsLevel: Float
    let dynamicRange: Float
    let recommendedSettings: AudioPreprocessingSettings

    var qualityDescription: String {
        if signalToNoiseRatio > 30 {
            return "Excellent"
        } else if signalToNoiseRatio > 20 {
            return "Good"
        } else if signalToNoiseRatio > 10 {
            return "Fair"
        } else {
            return "Poor"
        }
    }

    var noiseLevelDescription: String {
        if signalToNoiseRatio < 10 {
            return "High noise detected - aggressive noise reduction recommended"
        } else if signalToNoiseRatio < 20 {
            return "Moderate noise - standard noise reduction recommended"
        } else {
            return "Low noise - minimal processing required"
        }
    }
}