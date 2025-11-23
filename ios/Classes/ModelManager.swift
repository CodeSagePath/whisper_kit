import Foundation
import os.log

class ModelManager {
  private let logger = Logger(subsystem: "com.whisper_kit", category: "ModelManager")
  private let fileManager = FileManager.default

  // Model configuration
  private let modelsDirectoryName = "whisper_models"
  private let tempModelsDirectoryName = "whisper_models_temp"

  // Known model sizes and URLs
  struct ModelInfo {
    let name: String
    let displayName: String
    let sizeBytes: Int64
    let sizeDescription: String
    let downloadURL: String
  }

  // Available models with their information
  static let availableModels: [String: ModelInfo] = [
    "tiny": ModelInfo(
      name: "tiny",
      displayName: "Tiny (75MB)",
      sizeBytes: 75 * 1024 * 1024,
      sizeDescription: "75 MB",
      downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    ),
    "base": ModelInfo(
      name: "base",
      displayName: "Base (142MB)",
      sizeBytes: 142 * 1024 * 1024,
      sizeDescription: "142 MB",
      downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
    ),
    "small": ModelInfo(
      name: "small",
      displayName: "Small (466MB)",
      sizeBytes: 466 * 1024 * 1024,
      sizeDescription: "466 MB",
      downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
    ),
    "medium": ModelInfo(
      name: "medium",
      displayName: "Medium (1.5GB)",
      sizeBytes: 1_500_000_000,
      sizeDescription: "1.5 GB",
      downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
    ),
    "large-v3": ModelInfo(
      name: "large-v3",
      displayName: "Large v3 (3.1GB)",
      sizeBytes: 3_100_000_000,
      sizeDescription: "3.1 GB",
      downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
    )
  ]

  private var modelsDirectory: URL {
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsPath.appendingPathComponent(modelsDirectoryName)
  }

  private var tempModelsDirectory: URL {
    let tempPath = fileManager.temporaryDirectory
    return tempPath.appendingPathComponent(tempModelsDirectoryName)
  }

  init() {
    setupDirectories()
  }

  // MARK: - Directory Setup

  private func setupDirectories() {
    createDirectoryIfNeeded(at: modelsDirectory)
    createDirectoryIfNeeded(at: tempModelsDirectory)
  }

  private func createDirectoryIfNeeded(at url: URL) {
    if !fileManager.fileExists(atPath: url.path) {
      do {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        logger.info("Created directory: \(url.path)")
      } catch {
        logger.error("Failed to create directory \(url.path): \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Model Management

  func getModelsDirectory() -> URL {
    return modelsDirectory
  }

  func getModelPath(modelName: String) -> URL? {
    let modelURL = modelsDirectory.appendingPathComponent("ggml-\(modelName).bin")
    return fileManager.fileExists(atPath: modelURL.path) ? modelURL : nil
  }

  func getAvailableModels() -> [ModelInfo] {
    return Array(ModelManager.availableModels.values)
  }

  func getModelInfo(modelName: String) -> ModelInfo? {
    return ModelManager.availableModels[modelName]
  }

  func getDownloadedModels() -> [ModelInfo] {
    var downloadedModels: [ModelInfo] = []

    for (_, modelInfo) in ModelManager.availableModels {
      if let _ = getModelPath(modelName: modelInfo.name) {
        downloadedModels.append(modelInfo)
      }
    }

    return downloadedModels.sorted { $0.sizeBytes < $1.sizeBytes }
  }

  func isModelDownloaded(modelName: String) -> Bool {
    return getModelPath(modelName: modelName) != nil
  }

  func getModelSize(modelName: String) -> Int64? {
    guard let modelURL = getModelPath(modelName: modelName) else { return nil }

    do {
      let attributes = try fileManager.attributesOfItem(atPath: modelURL.path)
      return attributes[.size] as? Int64
    } catch {
      logger.error("Failed to get model size: \(error.localizedDescription)")
      return nil
    }
  }

  // MARK: - Model Download

  func downloadModel(
    modelName: String,
    progressHandler: @escaping (Double) -> Void,
    completionHandler: @escaping (Result<URL, Error>) -> Void
  ) {
    guard let modelInfo = ModelManager.availableModels[modelName] else {
      completionHandler(.failure(ModelError.modelNotFound))
      return
    }

    logger.info("Starting download for model: \(modelName)")

    // Create download task
    let downloadTask = URLSession.shared.downloadTask(with: URL(string: modelInfo.downloadURL)!) { [weak self] temporaryURL, response, error in
      guard let self = self else { return }

      if let error = error {
        self.logger.error("Download failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
          completionHandler(.failure(error))
        }
        return
      }

      guard let temporaryURL = temporaryURL else {
        self.logger.error("Download failed: No temporary URL")
        DispatchQueue.main.async {
          completionHandler(.failure(ModelError.downloadFailed))
        }
        return
      }

      // Move temporary file to final location
      let finalURL = self.modelsDirectory.appendingPathComponent("ggml-\(modelName).bin")

      do {
        // Remove existing file if it exists
        if self.fileManager.fileExists(atPath: finalURL.path) {
          try self.fileManager.removeItem(at: finalURL)
        }

        try self.fileManager.moveItem(at: temporaryURL, to: finalURL)

        self.logger.info("Model downloaded successfully: \(finalURL.path)")
        DispatchQueue.main.async {
          completionHandler(.success(finalURL))
        }
      } catch {
        self.logger.error("Failed to move downloaded file: \(error.localizedDescription)")
        DispatchQueue.main.async {
          completionHandler(.failure(error))
        }
      }
    }

    // Add progress monitoring
    downloadTask.resume()

    // Monitor progress using observation
    let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
      DispatchQueue.main.async {
        progressHandler(progress.fractionCompleted)
      }
    }
  }

  // MARK: - Model Deletion

  func deleteModel(modelName: String, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
    guard let modelURL = getModelPath(modelName: modelName) else {
      completionHandler(.failure(ModelError.modelNotFound))
      return
    }

    do {
      try fileManager.removeItem(at: modelURL)
      logger.info("Model deleted successfully: \(modelName)")
      completionHandler(.success(true))
    } catch {
      logger.error("Failed to delete model: \(error.localizedDescription)")
      completionHandler(.failure(error))
    }
  }

  // MARK: - Storage Management

  func getTotalModelsSize() -> Int64 {
    var totalSize: Int64 = 0

    for (_, modelInfo) in ModelManager.availableModels {
      if let modelSize = getModelSize(modelName: modelInfo.name) {
        totalSize += modelSize
      }
    }

    return totalSize
  }

  func getAvailableDiskSpace() -> Int64 {
    do {
      let attributes = try fileManager.attributesOfFileSystem(forPath: modelsDirectory.path)
      return attributes[.systemFreeSize] as? Int64 ?? 0
    } catch {
      logger.error("Failed to get available disk space: \(error.localizedDescription)")
      return 0
    }
  }

  func canDownloadModel(modelName: String) -> (canDownload: Bool, reason: String?) {
    guard let modelInfo = ModelManager.availableModels[modelName] else {
      return (false, "Model not found")
    }

    let availableSpace = getAvailableDiskSpace()
    let modelSize = modelInfo.sizeBytes

    if availableSpace < modelSize {
      let requiredSpace = modelSize - availableSpace
      let requiredSpaceMB = requiredSpace / (1024 * 1024)
      return (false, "Not enough disk space. Need additional \(requiredSpaceMB) MB")
    }

    return (true, nil)
  }

  // MARK: - Model Validation

  func validateModel(modelName: String) -> Bool {
    guard let modelURL = getModelPath(modelName: modelName) else {
      return false
    }

    guard let modelInfo = ModelManager.availableModels[modelName] else {
      return false
    }

    // Check file size
    if let fileSize = getModelSize(modelName: modelName) {
      let expectedSize = modelInfo.sizeBytes
      let sizeDifference = abs(fileSize - expectedSize)
      let tolerance = expectedSize / 100 // Allow 1% difference

      if sizeDifference > tolerance {
        logger.error("Model file size validation failed for \(modelName)")
        return false
      }
    } else {
      return false
    }

    return true
  }

  func cleanupCorruptedModels(completionHandler: @escaping (Int) -> Void) {
    var removedCount = 0

    for (_, modelInfo) in ModelManager.availableModels {
      if !validateModel(modelName: modelInfo.name) {
        deleteModel(modelName: modelInfo.name) { _ in
          removedCount += 1
        }
      }
    }

    completionHandler(removedCount)
  }
}

// MARK: - Error Types

enum ModelError: LocalizedError {
  case modelNotFound
  case downloadFailed
  case insufficientSpace
  case corruptedModel

  var errorDescription: String? {
    switch self {
    case .modelNotFound:
      return "Model not found"
    case .downloadFailed:
      return "Failed to download model"
    case .insufficientSpace:
      return "Insufficient disk space"
    case .corruptedModel:
      return "Model file is corrupted"
    }
  }
}