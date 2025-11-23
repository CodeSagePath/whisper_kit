import Foundation
import AVFoundation
import os.log

class AudioRecorder: NSObject {
  private let logger = Logger(subsystem: "com.whisper_kit", category: "AudioRecorder")

  private var audioEngine: AVAudioEngine?
  private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
  private var audioFile: AVAudioFile?
  private var recordingBuffer: AVAudioPCMBuffer?
  private var audioData: Data = Data()

  // Audio format configuration (16kHz, mono, 16-bit PCM for Whisper)
  private let recordingFormat: AVAudioFormat = {
    var settings = Settings.audioFormatSettings
    settings[AVLinearPCMIsBigEndianKey] = false
    settings[AVLinearPCMIsFloatKey] = false
    settings[AVLinearPCMBitDepthKey] = 16
    return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
  }()

  var isRecording: Bool = false
  var audioURL: URL?

  // MARK: - Audio Session Setup

  func setupAudioSession() throws {
    try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
    try audioSession.setActive(true)
    logger.info("Audio session configured successfully")
  }

  func deactivateAudioSession() throws {
    try audioSession.setActive(false)
    logger.info("Audio session deactivated")
  }

  // MARK: - Recording Methods

  func startRecording(url: URL? = nil, completion: @escaping (Bool, Error?) -> Void) {
    logger.info("Starting audio recording")

    do {
      try setupAudioSession()

      // Initialize audio engine
      audioEngine = AVAudioEngine()
      guard let audioEngine = audioEngine else {
        completion(false, WhisperAudioError.engineInitializationFailed)
        return
      }

      // Use provided URL or create a temporary one
      let recordingURL = url ?? generateTemporaryAudioURL()
      self.audioURL = recordingURL

      // Create audio file for recording
      audioFile = try AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)

      let inputNode = audioEngine.inputNode

      // Set up audio format conversion
      let format = inputNode.outputFormat(forBus: 0)
      let converter = AVAudioConverter(from: format, to: recordingFormat)!

      // Install tap on input node
      inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] (buffer, time) in
        guard let self = self else { return }

        // Convert audio format
        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.recordingFormat, frameCapacity: buffer.frameLength)!

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
          outStatus.pointee = .haveData
          return buffer
        }

        if status == .error {
          self.logger.error("Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
          return
        }

        // Write to file
        if let audioFile = self.audioFile {
          try? audioFile.write(from: convertedBuffer)
        }

        // Store audio data for real-time processing
        if let channelData = convertedBuffer.int16ChannelData {
          let frameLength = Int(convertedBuffer.frameLength)
          let audioBuffer = Data(bytes: channelData[0], count: frameLength * 2) // 2 bytes per int16
          self.audioData.append(audioBuffer)
        }
      }

      audioEngine.prepare()
      try audioEngine.start()

      isRecording = true
      logger.info("Recording started successfully")
      completion(true, nil)

    } catch {
      logger.error("Failed to start recording: \(error.localizedDescription)")
      completion(false, error)
    }
  }

  func stopRecording(completion: @escaping (URL?, Data?, Error?) -> Void) {
    logger.info("Stopping audio recording")

    guard let audioEngine = audioEngine else {
      completion(nil, nil, WhisperAudioError.engineNotInitialized)
      return
    }

    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)

    // Get final audio data
    let finalAudioData = audioData
    audioData.removeAll() // Reset for next recording

    do {
      try deactivateAudioSession()
      isRecording = false
      logger.info("Recording stopped successfully")
      completion(audioURL, finalAudioData, nil)
    } catch {
      logger.error("Error stopping recording: \(error.localizedDescription)")
      completion(audioURL, finalAudioData, error)
    }
  }

  // MARK: - Audio Data Processing

  func getAudioData() -> Data {
    return audioData
  }

  func clearAudioData() {
    audioData.removeAll()
  }

  // MARK: - File Management

  func generateTemporaryAudioURL() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "recording_\(Int(Date().timeIntervalSince1970)).wav"
    return tempDir.appendingPathComponent(fileName)
  }

  func saveAudioToDocuments(data: Data, fileName: String? = nil) -> URL? {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let audioDir = documentsPath.appendingPathComponent("whisper_audio")

    // Create directory if it doesn't exist
    do {
      try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true, attributes: nil)
    } catch {
      logger.error("Failed to create audio directory: \(error.localizedDescription)")
      return nil
    }

    let finalFileName = fileName ?? "audio_\(Int(Date().timeIntervalSince1970)).wav"
    let fileURL = audioDir.appendingPathComponent(finalFileName)

    do {
      try data.write(to: fileURL)
      logger.info("Audio file saved to: \(fileURL.path)")
      return fileURL
    } catch {
      logger.error("Failed to save audio file: \(error.localizedDescription)")
      return nil
    }
  }

  // MARK: - Audio Analysis

  func analyzeAudioLevel(data: Data) -> Float {
    guard !data.isEmpty else { return 0.0 }

    let samples = data.withUnsafeBytes { pointer in
      Array(pointer.bindMemory(to: Int16.self))
    }

    let sum = samples.reduce(0) { $0 + abs(Int($1)) }
    let average = Float(sum) / Float(samples.count)
    let normalizedLevel = min(average / 32767.0, 1.0)

    return normalizedLevel
  }
}

// MARK: - Audio Settings

extension AudioRecorder {
  struct Settings {
    static let audioFormatSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsNonInterleaved: false
    ]
  }
}

// MARK: - Error Types

enum WhisperAudioError: LocalizedError {
  case engineInitializationFailed
  case engineNotInitialized
  case audioSessionFailed
  case fileCreationFailed

  var errorDescription: String? {
    switch self {
    case .engineInitializationFailed:
      return "Failed to initialize audio engine"
    case .engineNotInitialized:
      return "Audio engine not initialized"
    case .audioSessionFailed:
      return "Failed to configure audio session"
    case .fileCreationFailed:
      return "Failed to create audio file"
    }
  }
}