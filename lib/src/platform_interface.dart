/// Platform interface for WhisperKit.
///
/// Defines the contract for platform-specific implementations.
library;

import 'dart:async';

/// Permission status for microphone and storage access.
enum PermissionStatus {
  /// Permission has not been requested yet.
  notDetermined,

  /// Permission has been granted.
  granted,

  /// Permission has been denied.
  denied,

  /// Permission is restricted (iOS only).
  restricted,

  /// Permission has been permanently denied.
  permanentlyDenied,
}

/// Result from stopping audio recording.
class RecordingResult {
  const RecordingResult({
    this.audioPath,
    this.audioData,
    this.duration,
    this.success = true,
    this.error,
  });

  /// Path to the saved audio file (if saved).
  final String? audioPath;

  /// Raw audio data as bytes.
  final List<int>? audioData;

  /// Duration of the recording in milliseconds.
  final int? duration;

  /// Whether the recording was successful.
  final bool success;

  /// Error message if recording failed.
  final String? error;

  factory RecordingResult.fromMap(Map<String, dynamic> map) {
    return RecordingResult(
      audioPath: map['audioURL'] as String? ?? map['audioPath'] as String?,
      duration: map['duration'] as int?,
      success: map['success'] as bool? ?? true,
      error: map['error'] as String?,
    );
  }
}

/// Information about a Whisper model.
class ModelInfo {
  const ModelInfo({
    required this.name,
    required this.size,
    this.path,
    this.isDownloaded = false,
  });

  /// Model name (e.g., "tiny", "base", "small").
  final String name;

  /// Model size in bytes.
  final int size;

  /// Local path to the model (if downloaded).
  final String? path;

  /// Whether the model is downloaded.
  final bool isDownloaded;

  factory ModelInfo.fromMap(Map<String, dynamic> map) {
    return ModelInfo(
      name: map['name'] as String? ?? 'unknown',
      size: map['size'] as int? ?? 0,
      path: map['path'] as String?,
      isDownloaded: map['isDownloaded'] as bool? ?? false,
    );
  }
}

/// Storage information for model management.
class StorageInfo {
  const StorageInfo({
    required this.totalSpace,
    required this.freeSpace,
    required this.usedByModels,
  });

  /// Total storage space in bytes.
  final int totalSpace;

  /// Free storage space in bytes.
  final int freeSpace;

  /// Space used by downloaded models in bytes.
  final int usedByModels;

  /// Free space as a percentage.
  double get freePercentage => totalSpace > 0 ? freeSpace / totalSpace : 0;

  factory StorageInfo.fromMap(Map<String, dynamic> map) {
    return StorageInfo(
      totalSpace: map['totalSpace'] as int? ?? 0,
      freeSpace: map['freeSpace'] as int? ?? 0,
      usedByModels: map['usedByModels'] as int? ?? 0,
    );
  }
}

/// Abstract interface for platform-specific WhisperKit functionality.
abstract class WhisperKitPlatformInterface {
  /// Get platform version string.
  Future<String> getPlatformVersion();

  // MARK: - Permissions

  /// Request microphone permission.
  Future<PermissionStatus> requestMicrophonePermission();

  /// Check current microphone permission status.
  Future<PermissionStatus> checkMicrophonePermission();

  /// Request storage permission (Android only).
  Future<PermissionStatus> requestStoragePermission();

  /// Open app settings for manual permission changes.
  Future<void> openAppSettings();

  // MARK: - Audio Recording

  /// Start audio recording.
  Future<bool> startRecording({bool saveToFile = true});

  /// Stop audio recording and get result.
  Future<RecordingResult> stopRecording();

  /// Get current audio data without stopping.
  Future<List<int>?> getAudioData();

  // MARK: - Model Management

  /// Get the directory path where models are stored.
  Future<String> getModelPath();

  /// Get list of available models that can be downloaded.
  Future<List<ModelInfo>> getAvailableModels();

  /// Get list of downloaded models.
  Future<List<ModelInfo>> getDownloadedModels();

  /// Check if a specific model is downloaded.
  Future<bool> isModelDownloaded(String modelName);

  /// Delete a downloaded model.
  Future<bool> deleteModel(String modelName);

  /// Validate a downloaded model.
  Future<bool> validateModel(String modelName);

  // MARK: - Storage

  /// Get storage information.
  Future<StorageInfo> getStorageInfo();

  /// Clean up unused model files.
  Future<void> cleanupModels();
}
