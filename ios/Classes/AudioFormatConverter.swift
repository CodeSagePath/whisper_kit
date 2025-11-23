import Foundation
import AVFoundation
import AudioToolbox
import os.log

enum AudioFormat {
    case wav
    case mp3
    case m4a
    case aac
    case flac
    case ogg
    case pcm

    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        case .aac: return "aac"
        case .flac: return "flac"
        case .ogg: return "ogg"
        case .pcm: return "pcm"
        }
    }

    var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .mp3: return "audio/mpeg"
        case .m4a: return "audio/mp4"
        case .aac: return "audio/aac"
        case .flac: return "audio/flac"
        case .ogg: return "audio/ogg"
        case .pcm: return "audio/pcm"
        }
    }

    var isCompressed: Bool {
        switch self {
        case .wav, .pcm: return false
        case .mp3, .m4a, .aac, .flac, .ogg: return true
        }
    }
}

struct AudioConversionSettings {
    let targetFormat: AudioFormat
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    let bitRate: Int? // For compressed formats
    let quality: AudioQuality

    enum AudioQuality: Int, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2
        case lossless = 3

        var description: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .lossless: return "Lossless"
            }
        }
    }

    static let whisperOptimal = AudioConversionSettings(
        targetFormat: .wav,
        sampleRate: 16000,
        channelCount: 1,
        bitDepth: 16,
        bitRate: nil,
        quality: .high
    )
}

enum AudioConverterError: LocalizedError {
    case unsupportedFormat
    case conversionFailed
    case fileNotFound
    case invalidSettings
    case insufficientDiskSpace
    case audioEngineUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .conversionFailed:
            return "Audio conversion failed"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidSettings:
            return "Invalid conversion settings"
        case .insufficientDiskSpace:
            return "Insufficient disk space for conversion"
        case .audioEngineUnavailable:
            return "Audio conversion engine is unavailable"
        }
    }
}

class AudioFormatConverter: NSObject {
    private let logger = Logger(subsystem: "com.whisper_kit", category: "AudioFormatConverter")
    private let processingQueue = DispatchQueue(label: "com.whisper_kit.audio.conversion", qos: .userInitiated)

    // MARK: - Public Interface

    /// Convert audio file from one format to another
    func convertAudioFile(
        from inputURL: URL,
        to outputURL: URL,
        settings: AudioConversionSettings,
        progressHandler: @escaping (Float) -> Void,
        completionHandler: @escaping (Result<URL, Error>) -> Void
    ) {
        processingQueue.async {
            self.performConversion(
                inputURL: inputURL,
                outputURL: outputURL,
                settings: settings,
                progressHandler: progressHandler,
                completionHandler: completionHandler
            )
        }
    }

    /// Convert audio data from one format to another
    func convertAudioData(
        data: Data,
        from inputFormat: AVAudioFormat,
        to settings: AudioConversionSettings,
        progressHandler: @escaping (Float) -> Void,
        completionHandler: @escaping (Result<Data, Error>) -> Void
    ) {
        processingQueue.async {
            self.performDataConversion(
                data: data,
                inputFormat: inputFormat,
                settings: settings,
                progressHandler: progressHandler,
                completionHandler: completionHandler
            )
        }
    }

    /// Detect audio format from file
    func detectAudioFormat(url: URL) -> AudioFormat? {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "wav": return .wav
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "aac": return .aac
        case "flac": return .flac
        case "ogg": return .ogg
        default:
            // Try to detect from file data
            return detectFormatFromFileData(url: url)
        }
    }

    /// Get audio file metadata
    func getAudioMetadata(url: URL) -> AudioMetadata? {
        let asset = AVURLAsset(url: url)

        guard let duration = asset.duration.seconds,
              duration > 0 else { return nil }

        var sampleRate: Double = 0
        var channelCount: Int = 0
        var bitRate: Int = 0

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = audioTrack.formatDescriptions
            for formatDescription in formatDescriptions {
                if let streamDescription = formatDescription.streamBasicDescription {
                    sampleRate = streamDescription.pointee.mSampleRate
                    channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
                    break
                }
            }
        }

        bitRate = Int(asset.preferredTrackRate) // Approximation

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        return AudioMetadata(
            duration: duration,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitRate: bitRate,
            fileSize: fileSize,
            format: detectAudioFormat(url: url) ?? .wav
        )
    }

    // MARK: - Private Conversion Methods

    private func performConversion(
        inputURL: URL,
        outputURL: URL,
        settings: AudioConversionSettings,
        progressHandler: @escaping (Float) -> Void,
        completionHandler: @escaping (Result<URL, Error>) -> Void
    ) {
        do {
            // Check available disk space
            let availableSpace = getAvailableDiskSpace(for: outputURL.deletingLastPathComponent())
            if availableSpace < 100 * 1024 * 1024 { // 100MB minimum
                completionHandler(.failure(AudioConverterError.insufficientDiskSpace))
                return
            }

            // Create audio file reader
            let audioFile = try AVAudioFile(forReading: inputURL)
            let inputFormat = audioFile.processingFormat

            // Create target format
            let targetFormat = createTargetFormat(settings: settings)

            // Create audio file writer
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: targetFormat.settings)

            // Create audio converter
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                completionHandler(.failure(AudioConverterError.conversionFailed))
                return
            }

            // Configure converter
            converter.bitRate = settings.bitRate
            converter.sampleRateConverterQuality = .max

            // Perform conversion
            let bufferSize = AVAudioFrameCount(4096)
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: bufferSize)!

            var totalFrames: AVAudioFrameCount = 0
            var convertedFrames: AVAudioFrameCount = 0
            let totalAudioFrames = AVAudioFrameCount(audioFile.length)

            while totalFrames < totalAudioFrames {
                try audioFile.read(into: inputBuffer)

                let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: inputBuffer.frameLength)!

                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return inputBuffer
                }

                if status == .error {
                    completionHandler(.failure(error ?? AudioConverterError.conversionFailed))
                    return
                }

                try outputFile.write(from: outputBuffer)

                totalFrames += inputBuffer.frameLength
                convertedFrames += outputBuffer.frameLength

                // Report progress
                let progress = Float(totalFrames) / Float(totalAudioFrames)
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }

            logger.info("Audio conversion completed: \(inputURL.lastPathComponent) -> \(outputURL.lastPathComponent)")
            DispatchQueue.main.async {
                completionHandler(.success(outputURL))
            }

        } catch {
            logger.error("Audio conversion failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completionHandler(.failure(AudioConverterError.conversionFailed))
            }
        }
    }

    private func performDataConversion(
        data: Data,
        inputFormat: AVAudioFormat,
        settings: AudioConversionSettings,
        progressHandler: @escaping (Float) -> Void,
        completionHandler: @escaping (Result<Data, Error>) -> Void
    ) {
        do {
            // Create target format
            let targetFormat = createTargetFormat(settings: settings)

            // Create audio converter
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                completionHandler(.failure(AudioConverterError.conversionFailed))
                return
            }

            // Parse input data into PCM buffer
            let inputBuffer = try createPCMBuffer(from: data, format: inputFormat)
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: inputBuffer.frameLength)!

            // Convert
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if status == .error {
                completionHandler(.failure(error ?? AudioConverterError.conversionFailed))
                return
            }

            // Convert buffer back to data
            let outputData = convertPCMBufferToData(buffer: outputBuffer)

            DispatchQueue.main.async {
                progressHandler(1.0)
                completionHandler(.success(outputData))
            }

        } catch {
            logger.error("Audio data conversion failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completionHandler(.failure(AudioConverterError.conversionFailed))
            }
        }
    }

    // MARK: - Utility Methods

    private func createTargetFormat(settings: AudioConversionSettings) -> AVAudioFormat {
        switch settings.targetFormat {
        case .wav, .pcm:
            return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: settings.sampleRate, channels: settings.channelCount, interleaved: false)!
        case .m4a, .aac:
            return AVAudioFormat(settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: settings.sampleRate,
                AVNumberOfChannelsKey: settings.channelCount,
                AVEncoderBitRateKey: settings.bitRate ?? 128000,
                AVEncoderAudioQualityKey: settings.quality.rawValue
            ])!
        case .mp3:
            return AVAudioFormat(settings: [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVSampleRateKey: settings.sampleRate,
                AVNumberOfChannelsKey: settings.channelCount,
                AVEncoderBitRateKey: settings.bitRate ?? 128000
            ])!
        case .flac:
            return AVAudioFormat(settings: [
                AVFormatIDKey: kAudioFormatFLAC,
                AVSampleRateKey: settings.sampleRate,
                AVNumberOfChannelsKey: settings.channelCount,
                AVLinearPCMBitDepthKey: settings.bitDepth,
                AVEncoderAudioQualityKey: AudioQuality.lossless.rawValue
            ])!
        case .ogg:
            return AVAudioFormat(settings: [
                AVFormatIDKey: kAudioFormatOpus,
                AVSampleRateKey: settings.sampleRate,
                AVNumberOfChannelsKey: settings.channelCount,
                AVEncoderBitRateKey: settings.bitRate ?? 96000
            ])!
        }
    }

    private func detectFormatFromFileData(url: URL) -> AudioFormat? {
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count >= 12 else { return nil }

            // Check file signatures
            let bytes = data.prefix(12)

            // WAV signature: "RIFF" followed by "WAVE"
            if bytes.prefix(4) == Data([0x52, 0x49, 0x46, 0x46]) &&
               bytes.dropFirst(8).prefix(4) == Data([0x57, 0x41, 0x56, 0x45]) {
                return .wav
            }

            // MP3 signature (ID3v2)
            if bytes.prefix(3) == Data([0x49, 0x44, 0x33]) {
                return .mp3
            }

            // MP3 signature (MPEG audio)
            if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 {
                return .mp3
            }

            // M4A/AAC signature: "ftyp" box
            if bytes.dropFirst(4).prefix(4) == Data([0x66, 0x74, 0x79, 0x70]) {
                return .m4a
            }

            // FLAC signature: "fLaC"
            if bytes.prefix(4) == Data([0x66, 0x4C, 0x61, 0x43]) {
                return .flac
            }

            // OGG signature: "OggS"
            if bytes.prefix(4) == Data([0x4F, 0x67, 0x67, 0x53]) {
                return .ogg
            }

        } catch {
            logger.error("Failed to read file data for format detection: \(error.localizedDescription)")
        }

        return nil
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(data.count / (format.streamDescription.pointee.mBytesPerFrame))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!

        if let floatChannelData = buffer.floatChannelData {
            data.withUnsafeBytes { rawPointer in
                let floatPointer = rawPointer.bindMemory(to: Float.self)
                memcpy(floatChannelData[0], floatPointer.baseAddress!, data.count)
            }
        }

        buffer.frameLength = frameCount
        return buffer
    }

    private func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else { return Data() }

        let channelDataPointer = UnsafeMutablePointer<Float>(channelData[0])
        let dataPointer = UnsafeMutableRawPointer(channelDataPointer)
        return Data(bytesNoCopy: dataPointer, count: Int(buffer.frameLength) * MemoryLayout<Float>.size, deallocator: .none)
    }

    private func getAvailableDiskSpace(for directory: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: directory.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            logger.error("Failed to get available disk space: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - Audio Metadata

struct AudioMetadata {
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let bitRate: Int
    let fileSize: Int64
    let format: AudioFormat

    var durationDescription: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var fileSizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var sampleRateDescription: String {
        return "\(Int(sampleRate)) Hz"
    }

    var channelDescription: String {
        return channelCount == 1 ? "Mono" : "Stereo"
    }

    var bitRateDescription: String {
        if format.isCompressed {
            return "\(bitRate / 1000) kbps"
        } else {
            return "Lossless"
        }
    }
}