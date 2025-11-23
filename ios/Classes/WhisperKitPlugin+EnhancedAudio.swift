import Foundation
import Flutter
import AVFoundation
import os.log

// MARK: - WhisperKitPlugin Enhanced Audio Extension

extension WhisperKitPlugin {

    // MARK: - Enhanced Audio Methods

    func startEnhancedAudioProcessing(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Starting enhanced audio processing")

        guard let args = call.arguments as? [String: Any],
              let configDict = args["configuration"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing configuration", details: nil))
            return
        }

        do {
            let configuration = try parseEnhancedAudioConfiguration(from: configDict)

            // Initialize enhanced audio manager if needed
            if enhancedAudioManager == nil {
                enhancedAudioManager = EnhancedAudioManager(configuration: configuration)
                enhancedAudioManager?.delegate = self
            } else {
                enhancedAudioManager?.updateConfiguration(configuration)
            }

            try enhancedAudioManager?.startProcessing()

            result([
                "success": true,
                "message": "Enhanced audio processing started",
                "configuration": [
                    "enableRealTimeProcessing": configuration.enableRealTimeProcessing,
                    "enableMultiFormatSupport": configuration.enableMultiFormatSupport,
                    "enableQualityOptimization": configuration.enableQualityOptimization
                ]
            ])

        } catch {
            result(FlutterError(code: "ENHANCED_AUDIO_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func stopEnhancedAudioProcessing(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Stopping enhanced audio processing")

        enhancedAudioManager?.stopProcessing()

        let stats = enhancedAudioManager?.getProcessingStatistics()
        let audioQuality = enhancedAudioManager?.getCurrentAudioQuality()

        result([
            "success": true,
            "message": "Enhanced audio processing stopped",
            "statistics": stats?.description ?? "No statistics available",
            "finalAudioQuality": audioQuality?.description ?? "Unknown"
        ])
    }

    func processAudioFileEnhanced(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Processing audio file with enhanced features")

        guard let args = call.arguments as? [String: Any],
              let audioPath = args["audioPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio path", details: nil))
            return
        }

        let configDict = args["configuration"] as? [String: Any] ?? [:]
        let configuration = try? parseEnhancedAudioConfiguration(from: configDict)

        let audioURL = URL(fileURLWithPath: audioPath)

        enhancedAudioManager = EnhancedAudioManager(configuration: configuration ?? .default)
        enhancedAudioManager?.delegate = self

        enhancedAudioManager?.processAudioFile(url: audioURL) { [weak self] processingResult in
            DispatchQueue.main.async {
                switch processingResult {
                case .success(let enhancedResult):
                    let resultDict = self?.convertEnhancedResultToDict(enhancedResult)
                    result(resultDict)
                case .failure(let error):
                    result(FlutterError(code: "ENHANCED_PROCESSING_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    func convertAudioFormat(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Converting audio format")

        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String,
              let formatString = args["targetFormat"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }

        guard let audioFormat = AudioFormat.fromString(formatString) else {
            result(FlutterError(code: "UNSUPPORTED_FORMAT", message: "Unsupported audio format", details: nil))
            return
        }

        let settingsDict = args["settings"] as? [String: Any] ?? [:]
        let settings = parseAudioConversionSettings(from: settingsDict, targetFormat: audioFormat)

        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        formatConverter.convertAudioFile(
            from: inputURL,
            to: outputURL,
            settings: settings,
            progressHandler: { progress in
                // Send progress updates via a separate channel or as periodic callbacks
                self.logger.info("Audio conversion progress: \(progress * 100)%")
            },
            completionHandler: { conversionResult in
                DispatchQueue.main.async {
                    switch conversionResult {
                    case .success(let url):
                        result([
                            "success": true,
                            "outputPath": url.path,
                            "format": audioFormat.fileExtension
                        ])
                    case .failure(let error):
                        result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }
        )
    }

    func analyzeAudioQuality(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Analyzing audio quality")

        guard let args = call.arguments as? [String: Any],
              let audioPath = args["audioPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio path", details: nil))
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        let metadata = formatConverter.getAudioMetadata(url: audioURL)

        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData else {
                result(FlutterError(code: "INVALID_AUDIO_DATA", message: "Unable to read audio data", details: nil))
                return
            }

            let data = Data(bytes: channelData[0], count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
            let qualityAnalysis = audioPreprocessor.analyzeAudioQuality(data)

            result([
                "success": true,
                "qualityAnalysis": [
                    "signalToNoiseRatio": qualityAnalysis.signalToNoiseRatio,
                    "peakLevel": qualityAnalysis.peakLevel,
                    "rmsLevel": qualityAnalysis.rmsLevel,
                    "dynamicRange": qualityAnalysis.dynamicRange,
                    "qualityDescription": qualityAnalysis.qualityDescription,
                    "noiseLevelDescription": qualityAnalysis.noiseLevelDescription,
                    "recommendedSettings": qualityAnalysis.recommendedSettings == .default ? "default" :
                                     qualityAnalysis.recommendedSettings == .minimal ? "minimal" : "aggressive"
                ],
                "metadata": convertAudioMetadataToDict(metadata)
            ])

        } catch {
            result(FlutterError(code: "AUDIO_ANALYSIS_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func getAudioFormatMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Getting audio format metadata")

        guard let args = call.arguments as? [String: Any],
              let audioPath = args["audioPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio path", details: nil))
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        let metadata = formatConverter.getAudioMetadata(url: audioURL)

        if metadata != nil {
            result(convertAudioMetadataToDict(metadata!))
        } else {
            result(FlutterError(code: "METADATA_ERROR", message: "Unable to read audio metadata", details: nil))
        }
    }

    func getEnhancedProcessingStatistics(call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.info("Getting enhanced processing statistics")

        guard let manager = enhancedAudioManager else {
            result([
                "isProcessing": false,
                "message": "Enhanced audio manager not initialized"
            ])
            return
        }

        let stats = manager.getProcessingStatistics()
        result([
            "isProcessing": stats.isProcessing,
            "processingStartTime": stats.processingStartTime ?? 0,
            "totalTranscriptions": stats.totalTranscriptions,
            "averageConfidence": stats.averageConfidence,
            "currentAudioQuality": stats.currentAudioQuality.description,
            "audioFormat": stats.audioFormat.fileExtension,
            "streamingStats": [
                "chunksProcessed": stats.streamingStats.chunksProcessed,
                "transcriptionsGenerated": stats.streamingStats.transcriptionsGenerated,
                "averageLatency": stats.streamingStats.averageLatency
            ],
            "chunkingStats": [
                "totalChunks": stats.chunkingStats.totalChunks,
                "totalDuration": stats.chunkingStats.totalDuration,
                "speechChunks": stats.chunkingStats.speechChunks,
                "processingProgress": stats.chunkingStats.processingProgress
            ]
        ])
    }

    // MARK: - Enhanced Audio Configuration Parsing

    private func parseEnhancedAudioConfiguration(from dict: [String: Any]) throws -> EnhancedAudioConfiguration {
        let streamingConfig = parseStreamingConfiguration(from: dict["streamingConfig"] as? [String: Any] ?? [:])
        let chunkingConfig = parseChunkingConfiguration(from: dict["chunkingConfig"] as? [String: Any] ?? [:])
        let preprocessingConfig = parsePreprocessingSettings(from: dict["preprocessingConfig"] as? [String: Any] ?? [:])
        let vadConfig = parseVADConfiguration(from: dict["vadConfig"] as? [String: Any] ?? [:])

        return EnhancedAudioConfiguration(
            streamingConfig: streamingConfig,
            chunkingConfig: chunkingConfig,
            preprocessingConfig: preprocessingConfig,
            vadConfig: vadConfig,
            enableRealTimeProcessing: dict["enableRealTimeProcessing"] as? Bool ?? true,
            enableAdaptiveProcessing: dict["enableAdaptiveProcessing"] as? Bool ?? true,
            enableMultiFormatSupport: dict["enableMultiFormatSupport"] as? Bool ?? true,
            enableQualityOptimization: dict["enableQualityOptimization"] as? Bool ?? true
        )
    }

    private func parseStreamingConfiguration(from dict: [String: Any]) -> StreamingAudioProcessor.Configuration {
        return StreamingAudioProcessor.Configuration(
            chunkDuration: dict["chunkDuration"] as? Double ?? 2.0,
            overlapDuration: dict["overlapDuration"] as? Double ?? 0.5,
            silenceThreshold: dict["silenceThreshold"] as? Float ?? 0.01,
            maxSilenceDuration: dict["maxSilenceDuration"] as? Double ?? 3.0,
            vadEnabled: dict["vadEnabled"] as? Bool ?? true,
            vadThreshold: dict["vadThreshold"] as? Float ?? 0.01,
            maxConcurrentOperations: dict["maxConcurrentOperations"] as? Int ?? 2
        )
    }

    private func parseChunkingConfiguration(from dict: [String: Any]) -> AudioChunkingConfiguration {
        return AudioChunkingConfiguration(
            chunkDuration: dict["chunkDuration"] as? Double ?? 30.0,
            overlapDuration: dict["overlapDuration"] as? Double ?? 2.0,
            maxChunkSize: dict["maxChunkSize"] as? Int ?? 50 * 1024 * 1024,
            minChunkDuration: dict["minChunkDuration"] as? Double ?? 5.0,
            enableVADChunking: dict["enableVADChunking"] as? Bool ?? true,
            enableSilenceDetection: dict["enableSilenceDetection"] as? Bool ?? true,
            silenceThreshold: dict["silenceThreshold"] as? Float ?? 0.01,
            maxSilenceDuration: dict["maxSilenceDuration"] as? Double ?? 3.0,
            enableSmartSplitting: dict["enableSmartSplitting"] as? Bool ?? true,
            preserveContext: dict["preserveContext"] as? Bool ?? true,
            adaptiveChunking: dict["adaptiveChunking"] as? Bool ?? true
        )
    }

    private func parsePreprocessingSettings(from dict: [String: Any]) -> AudioPreprocessingSettings {
        let qualityString = dict["quality"] as? String ?? "default"
        let quality: AudioPreprocessingSettings.AudioQuality

        switch qualityString.lowercased() {
        case "minimal": quality = .minimal
        case "aggressive": quality = .aggressive
        default: quality = .default
        }

        return quality == .default ? AudioPreprocessingSettings.default :
               quality == .minimal ? AudioPreprocessingSettings.minimal :
               AudioPreprocessingSettings.aggressive
    }

    private func parseVADConfiguration(from dict: [String: Any]) -> VADConfiguration {
        let modeString = dict["mode"] as? String ?? "normal"
        let mode: VADConfiguration.VADMode

        switch modeString.lowercased() {
        case "lowbitrate": mode = .lowBitrate
        case "aggressive": mode = .aggressive
        case "veryaggressive": mode = .veryAggressive
        default: mode = .normal
        }

        let sensitivityString = dict["sensitivity"] as? String ?? "default"
        let configuration: VADConfiguration

        switch sensitivityString.lowercased() {
        case "sensitive": configuration = .sensitive
        default: configuration = .default
        }

        return VADConfiguration(
            sensitivity: dict["sensitivity"] as? Float ?? configuration.sensitivity,
            aggressiveness: dict["aggressiveness"] as? Int ?? configuration.aggressiveness,
            frameSizeMs: dict["frameSizeMs"] as? Int ?? configuration.frameSizeMs,
            vadMode: mode,
            enableEnergyBased: dict["enableEnergyBased"] as? Bool ?? configuration.enableEnergyBased,
            enableZeroCrossing: dict["enableZeroCrossing"] as? Bool ?? configuration.enableZeroCrossing,
            enableSpectral: dict["enableSpectral"] as? Bool ?? configuration.enableSpectral,
            enableMLDetection: dict["enableMLDetection"] as? Bool ?? configuration.enableMLDetection,
            minSpeechDurationMs: dict["minSpeechDurationMs"] as? Int ?? configuration.minSpeechDurationMs,
            maxSilenceDurationMs: dict["maxSilenceDurationMs"] as? Int ?? configuration.maxSilenceDurationMs,
            preSpeechPaddingMs: dict["preSpeechPaddingMs"] as? Int ?? configuration.preSpeechPaddingMs,
            postSpeechPaddingMs: dict["postSpeechPaddingMs"] as? Int ?? configuration.postSpeechPaddingMs
        )
    }

    private func parseAudioConversionSettings(from dict: [String: Any], targetFormat: AudioFormat) -> AudioConversionSettings {
        let qualityString = dict["quality"] as? String ?? "medium"
        let quality: AudioConversionSettings.AudioQuality

        switch qualityString.lowercased() {
        case "low": quality = .low
        case "high": quality = .high
        case "lossless": quality = .lossless
        default: quality = .medium
        }

        return AudioConversionSettings(
            targetFormat: targetFormat,
            sampleRate: dict["sampleRate"] as? Double ?? 16000,
            channelCount: dict["channelCount"] as? Int ?? 1,
            bitDepth: dict["bitDepth"] as? Int ?? 16,
            bitRate: dict["bitRate"] as? Int,
            quality: quality
        )
    }

    // MARK: - Result Conversion Methods

    private func convertEnhancedResultToDict(_ result: EnhancedAudioResult) -> [String: Any] {
        return [
            "text": result.text,
            "language": result.language ?? "unknown",
            "confidence": result.confidence,
            "processingTime": result.processingTime,
            "audioQuality": result.audioQuality.description,
            "audioQualityScore": result.audioQuality.score,
            "segments": result.segments.map { segment in
                [
                    "text": segment.text,
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "confidence": segment.confidence,
                    "chunkType": segment.chunkType.description,
                    "preprocessingApplied": segment.preprocessingApplied,
                    "audioQuality": segment.audioQuality.description
                ]
            },
            "metadata": convertAudioMetadataToDict(result.metadata)
        ]
    }

    private func convertAudioMetadataToDict(_ metadata: AudioMetadata) -> [String: Any] {
        return [
            "duration": metadata.duration,
            "durationDescription": metadata.durationDescription,
            "sampleRate": metadata.sampleRate,
            "sampleRateDescription": metadata.sampleRateDescription,
            "channelCount": metadata.channelCount,
            "channelDescription": metadata.channelDescription,
            "bitRate": metadata.bitRate,
            "bitRateDescription": metadata.bitRateDescription,
            "fileSize": metadata.fileSize,
            "fileSizeDescription": metadata.fileSizeDescription,
            "format": metadata.format.fileExtension
        ]
    }
}

// MARK: - AudioFormat Extension

extension AudioFormat {
    static func fromString(_ string: String) -> AudioFormat? {
        switch string.lowercased() {
        case "wav": return .wav
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "aac": return .aac
        case "flac": return .flac
        case "ogg": return .ogg
        case "pcm": return .pcm
        default: return nil
        }
    }
}