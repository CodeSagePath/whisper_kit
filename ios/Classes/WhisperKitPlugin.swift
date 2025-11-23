import Flutter
import UIKit
import AVFoundation
import os.log
import Foundation

// C function declarations from the C++ bridge
@_silgen_name("request")
func request(_ body: UnsafeMutablePointer<CChar>) -> UnsafeMutablePointer<CChar>?

public class WhisperKitPlugin: NSObject, FlutterPlugin {
  private let logger = Logger(subsystem: "com.whisper_kit", category: "Plugin")
  private let audioRecorder = AudioRecorder()
  private let permissionManager = PermissionManager()
  private let modelManager = ModelManager()
  private let audioPreprocessor = AudioPreprocessor()
  private let formatConverter = AudioFormatConverter()

  // Enhanced audio processing
  var enhancedAudioManager: EnhancedAudioManager?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "whisper_kit", binaryMessenger: registrar.messenger())
    let instance = WhisperKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    logger.info("Received method call: \(call.method)")

    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "requestMicrophonePermission":
      requestMicrophonePermission(result: result)
    case "checkMicrophonePermission":
      checkMicrophonePermission(result: result)
    case "requestDocumentsPermission":
      requestDocumentsPermission(result: result)
    case "checkDocumentsPermission":
      checkDocumentsPermission(result: result)
    case "checkAllPermissions":
      checkAllPermissions(result: result)
    case "requestAllPermissions":
      requestAllPermissions(result: result)
    case "openAppSettings":
      openAppSettings(result: result)
    case "startAudioCapture":
      startAudioCapture(call: call, result: result)
    case "stopAudioCapture":
      stopAudioCapture(result: result)
    case "getAudioData":
      getAudioData(result: result)
    case "saveAudioData":
      saveAudioData(call: call, result: result)
    case "processAudioFile":
      processAudioFile(call: call, result: result)
    case "getModelPath":
      getModelPath(result: result)
    case "downloadModel":
      downloadModel(call: call, result: result)
    case "deleteModel":
      deleteModel(call: call, result: result)
    case "getAvailableModels":
      getAvailableModels(result: result)
    case "getDownloadedModels":
      getDownloadedModels(result: result)
    case "isModelDownloaded":
      isModelDownloaded(call: call, result: result)
    case "getStorageInfo":
      getStorageInfo(result: result)
    case "validateModel":
      validateModel(call: call, result: result)
    case "cleanupModels":
      cleanupModels(result: result)
    // Enhanced Audio Processing Methods
    case "startEnhancedAudioProcessing":
      startEnhancedAudioProcessing(call: call, result: result)
    case "stopEnhancedAudioProcessing":
      stopEnhancedAudioProcessing(call: call, result: result)
    case "processAudioFileEnhanced":
      processAudioFileEnhanced(call: call, result: result)
    case "convertAudioFormat":
      convertAudioFormat(call: call, result: result)
    case "analyzeAudioQuality":
      analyzeAudioQuality(call: call, result: result)
    case "getAudioFormatMetadata":
      getAudioFormatMetadata(call: call, result: result)
    case "getEnhancedProcessingStatistics":
      getEnhancedProcessingStatistics(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Permissions

  private func requestMicrophonePermission(result: @escaping FlutterResult) {
    permissionManager.requestMicrophonePermission { status in
      result([
        "status": status.description,
        "granted": status == .authorized
      ])
    }
  }

  private func checkMicrophonePermission(result: @escaping FlutterResult) {
    let status = permissionManager.getMicrophonePermissionStatus()
    result([
      "status": status.description,
      "granted": status == .authorized,
      "shouldShowRationale": self.permissionManager.shouldShowPermissionRationale(for: .microphone)
    ])
  }

  private func requestDocumentsPermission(result: @escaping FlutterResult) {
    permissionManager.requestDocumentsPermission { granted in
      result([
        "status": granted ? "Authorized" : "Denied",
        "granted": granted
      ])
    }
  }

  private func checkDocumentsPermission(result: @escaping FlutterResult) {
    let status = permissionManager.getDocumentsPermissionStatus()
    result([
      "status": status.description,
      "granted": status == .authorized,
      "shouldShowRationale": self.permissionManager.shouldShowPermissionRationale(for: .documents)
    ])
  }

  private func checkAllPermissions(result: @escaping FlutterResult) {
    let permissions = permissionManager.checkAllRequiredPermissions()
    let permissionsDict = permissions.mapValues { status in
      [
        "status": status.description,
        "granted": status == .authorized
      ]
    }
    result(permissionsDict)
  }

  private func requestAllPermissions(result: @escaping FlutterResult) {
    permissionManager.requestAllRequiredPermissions { permissions in
      let permissionsDict = permissions.mapValues { status in
        [
          "status": status.description,
          "granted": status == .authorized
        ]
      }
      result(permissionsDict)
    }
  }

  private func openAppSettings(result: @escaping FlutterResult) {
    permissionManager.openAppSettings()
    result(true)
  }

  // MARK: - Audio Capture

  private func startAudioCapture(call: FlutterMethodCall, result: @escaping FlutterResult) {
    logger.info("Starting audio capture")

    guard let args = call.arguments as? [String: Any],
          let shouldSave = args["shouldSave"] as? Bool else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }

    let audioURL = shouldSave ? audioRecorder.generateTemporaryAudioURL() : nil

    audioRecorder.startRecording(url: audioURL) { success, error in
      DispatchQueue.main.async {
        if success {
          result([
            "isRecording": true,
            "audioURL": self.audioRecorder.audioURL?.absoluteString
          ])
        } else {
          result(FlutterError(code: "AUDIO_CAPTURE_ERROR", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopAudioCapture(result: @escaping FlutterResult) {
    logger.info("Stopping audio capture")

    audioRecorder.stopRecording { audioURL, audioData, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "AUDIO_CAPTURE_ERROR", message: error.localizedDescription, details: nil))
        } else {
          let response: [String: Any] = [
            "isRecording": false,
            "audioURL": audioURL?.absoluteString ?? "",
            "audioDataLength": audioData?.count ?? 0
          ]
          result(response)
        }
      }
    }
  }

  private func getAudioData(result: @escaping FlutterResult) {
    let audioData = audioRecorder.getAudioData()
    let base64Data = audioData.base64EncodedString()
    result([
      "audioData": base64Data,
      "length": audioData.count,
      "audioLevel": audioRecorder.analyzeAudioLevel(data: audioData)
    ])
  }

  private func saveAudioData(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let fileName = args["fileName"] as? String? else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }

    let audioData = audioRecorder.getAudioData()
    guard let savedURL = audioRecorder.saveAudioToDocuments(data: audioData, fileName: fileName) else {
      result(FlutterError(code: "SAVE_ERROR", message: "Failed to save audio data", details: nil))
      return
    }

    result([
      "savedURL": savedURL.absoluteString,
      "fileName": savedURL.lastPathComponent
    ])
  }

  // MARK: - Audio File Processing

  private func processAudioFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
    logger.info("Processing audio file")

    guard let args = call.arguments as? [String: Any],
          let audioPath = args["audioPath"] as? String,
          let modelPath = args["modelPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }

    // Extract options from arguments
    let options = args["options"] as? [String: Any] ?? [:]

    logger.info("Processing audio file: \(audioPath) with model: \(modelPath)")

    // Process audio using the C++ whisper implementation
    guard let jsonResponse = self.processAudioWithModel(audioPath, modelPath: modelPath, options: options) else {
      result(FlutterError(code: "PROCESSING_ERROR", message: "Failed to process audio file", details: nil))
      return
    }

    // Parse JSON response
    do {
      let jsonData = jsonResponse.data(using: .utf8)
      let parsedResponse = try JSONSerialization.jsonObject(with: jsonData!, options: [])
      result(parsedResponse)
    } catch {
      logger.error("Failed to parse JSON response: \(error.localizedDescription)")
      result(FlutterError(code: "JSON_PARSE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - C++ Integration

  private func processAudioWithModel(_ audioPath: String, modelPath: String, options: [String: Any]) -> String? {
    // Create JSON request for C++ function
    var requestDict: [String: Any] = [
      "model": modelPath,
      "audio": audioPath,
      "threads": options["threads"] ?? 4,
      "language": options["language"] ?? "auto",
      "is_verbose": options["isVerbose"] ?? false,
      "is_translate": options["isTranslate"] ?? false,
      "is_no_timestamps": options["isNoTimestamps"] ?? false,
      "is_special_tokens": options["isSpecialTokens"] ?? false,
      "split_on_word": options["splitOnWord"] ?? false
    ]

    // Convert to JSON string
    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict, options: []),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      logger.error("Failed to create JSON request")
      return nil
    }

    // Convert to C string
    let cString = jsonString.cString(using: .utf8)
    let mutableString = strdup(cString!)

    guard let resultC = request(mutableString) else {
      logger.error("C++ request function returned nil")
      free(mutableString)
      return nil
    }

    // Convert result back to Swift string
    let resultString = String(cString: resultC)
    free(resultC)
    free(mutableString)

    return resultString
  }

  // MARK: - Model Management

  private func getModelPath(result: @escaping FlutterResult) {
    let path = modelManager.getModelsDirectory().path
    result(path)
  }

  private func downloadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelName = args["modelName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
      return
    }

    // Check if model can be downloaded
    let (canDownload, reason) = modelManager.canDownloadModel(modelName: modelName)
    if !canDownload {
      result(FlutterError(code: "INSUFFICIENT_SPACE", message: reason, details: nil))
      return
    }

    modelManager.downloadModel(modelName: modelName) { progress in
      // Send progress update back to Flutter
      DispatchQueue.main.async {
        self.logger.info("Download progress for \(modelName): \(progress * 100)%")
        // You could implement a separate progress channel here
      }
    } completionHandler: { downloadResult in
      DispatchQueue.main.async {
        switch downloadResult {
        case .success(let url):
          result([
            "success": true,
            "modelPath": url.path,
            "modelName": modelName
          ])
        case .failure(let error):
          result(FlutterError(code: "DOWNLOAD_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func deleteModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelName = args["modelName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
      return
    }

    modelManager.deleteModel(modelName: modelName) { deleteResult in
      DispatchQueue.main.async {
        switch deleteResult {
        case .success:
          result([
            "success": true,
            "modelName": modelName,
            "message": "Model deleted successfully"
          ])
        case .failure(let error):
          result(FlutterError(code: "DELETE_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func getAvailableModels(result: @escaping FlutterResult) {
    let models = modelManager.getAvailableModels()
    let modelsArray = models.map { model in
      [
        "name": model.name,
        "displayName": model.displayName,
        "sizeBytes": model.sizeBytes,
        "sizeDescription": model.sizeDescription,
        "downloadURL": model.downloadURL
      ]
    }
    result(modelsArray)
  }

  private func getDownloadedModels(result: @escaping FlutterResult) {
    let models = modelManager.getDownloadedModels()
    let modelsArray = models.map { model in
      var modelDict: [String: Any] = [
        "name": model.name,
        "displayName": model.displayName,
        "sizeBytes": model.sizeBytes,
        "sizeDescription": model.sizeDescription
      ]

      if let actualSize = modelManager.getModelSize(modelName: model.name) {
        modelDict["actualSizeBytes"] = actualSize
      }

      modelDict["isValid"] = modelManager.validateModel(modelName: model.name)

      return modelDict
    }
    result(modelsArray)
  }

  private func isModelDownloaded(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelName = args["modelName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
      return
    }

    let isDownloaded = modelManager.isModelDownloaded(modelName: modelName)
    let isValid = isDownloaded ? modelManager.validateModel(modelName: modelName) : false

    result([
      "isDownloaded": isDownloaded,
      "isValid": isValid,
      "modelPath": isDownloaded ? modelManager.getModelPath(modelName: modelName)?.path : nil
    ])
  }

  private func getStorageInfo(result: @escaping FlutterResult) {
    let totalModelsSize = modelManager.getTotalModelsSize()
    let availableSpace = modelManager.getAvailableDiskSpace()

    result([
      "totalModelsSize": totalModelsSize,
      "totalModelsSizeMB": totalModelsSize / (1024 * 1024),
      "availableSpace": availableSpace,
      "availableSpaceMB": availableSpace / (1024 * 1024),
      "modelsDirectory": modelManager.getModelsDirectory().path
    ])
  }

  private func validateModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelName = args["modelName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
      return
    }

    let isValid = modelManager.validateModel(modelName: modelName)
    result(["isValid": isValid, "modelName": modelName])
  }

  private func cleanupModels(result: @escaping FlutterResult) {
    modelManager.cleanupCorruptedModels { removedCount in
      DispatchQueue.main.async {
        result([
          "success": true,
          "removedCount": removedCount,
          "message": "Cleaned up \(removedCount) corrupted models"
        ])
      }
    }
  }
}