/// Unified cross-platform API for WhisperKit.
///
/// Provides access to platform-specific features like permissions,
/// audio recording, and model management with consistent API across
/// Android and iOS.
library;

import 'package:whisper_kit/src/method_channel.dart';
import 'package:whisper_kit/src/platform_interface.dart';

// Re-export types for convenience
export 'package:whisper_kit/src/platform_interface.dart'
    show PermissionStatus, RecordingResult, ModelInfo, StorageInfo;

/// Singleton access to WhisperKit platform features.
///
/// Use this class to interact with platform-specific functionality
/// that isn't available through the FFI-based [Whisper] class.
///
/// Example:
/// ```dart
/// // Request microphone permission
/// final status = await WhisperKitPlatform.instance.requestMicrophonePermission();
/// if (status == PermissionStatus.granted) {
///   // Start recording
///   await WhisperKitPlatform.instance.startRecording();
///   // ... record audio ...
///   final result = await WhisperKitPlatform.instance.stopRecording();
///   print('Recorded to: ${result.audioPath}');
/// }
/// ```
class WhisperKitPlatform {
  WhisperKitPlatform._();

  static WhisperKitPlatform? _instance;

  /// Singleton instance of WhisperKitPlatform.
  static WhisperKitPlatform get instance {
    _instance ??= WhisperKitPlatform._();
    return _instance!;
  }

  /// The underlying platform implementation.
  final WhisperKitPlatformInterface _platform = WhisperKitMethodChannel();

  // MARK: - Platform Info

  /// Get the platform version string.
  Future<String> getPlatformVersion() => _platform.getPlatformVersion();

  // MARK: - Permissions

  /// Request microphone permission.
  ///
  /// Returns the permission status after the request.
  /// On iOS, shows the system permission dialog if not determined.
  /// On Android, requests runtime permission.
  Future<PermissionStatus> requestMicrophonePermission() =>
      _platform.requestMicrophonePermission();

  /// Check current microphone permission status without requesting.
  Future<PermissionStatus> checkMicrophonePermission() =>
      _platform.checkMicrophonePermission();

  /// Request storage permission (Android only).
  ///
  /// On iOS, returns [PermissionStatus.granted] as storage access
  /// is handled differently.
  Future<PermissionStatus> requestStoragePermission() =>
      _platform.requestStoragePermission();

  /// Open app settings for manual permission changes.
  ///
  /// Useful when permission is permanently denied.
  Future<void> openAppSettings() => _platform.openAppSettings();

  // MARK: - Audio Recording

  /// Start audio recording.
  ///
  /// [saveToFile] - Whether to save the recording to a file.
  /// Returns true if recording started successfully.
  Future<bool> startRecording({bool saveToFile = true}) =>
      _platform.startRecording(saveToFile: saveToFile);

  /// Stop audio recording and get the result.
  ///
  /// Returns a [RecordingResult] with the audio path and/or data.
  Future<RecordingResult> stopRecording() => _platform.stopRecording();

  /// Get current audio data without stopping the recording.
  ///
  /// Returns the audio data as bytes, or null if unavailable.
  Future<List<int>?> getAudioData() => _platform.getAudioData();

  // MARK: - Model Management

  /// Get the directory path where models are stored.
  Future<String> getModelPath() => _platform.getModelPath();

  /// Get list of available models that can be downloaded.
  Future<List<ModelInfo>> getAvailableModels() =>
      _platform.getAvailableModels();

  /// Get list of downloaded models.
  Future<List<ModelInfo>> getDownloadedModels() =>
      _platform.getDownloadedModels();

  /// Check if a specific model is downloaded.
  Future<bool> isModelDownloaded(String modelName) =>
      _platform.isModelDownloaded(modelName);

  /// Delete a downloaded model.
  ///
  /// Returns true if the model was deleted successfully.
  Future<bool> deleteModel(String modelName) =>
      _platform.deleteModel(modelName);

  /// Validate a downloaded model.
  ///
  /// Checks model integrity and returns true if valid.
  Future<bool> validateModel(String modelName) =>
      _platform.validateModel(modelName);

  // MARK: - Storage

  /// Get storage information.
  ///
  /// Returns total space, free space, and space used by models.
  Future<StorageInfo> getStorageInfo() => _platform.getStorageInfo();

  /// Clean up unused model files.
  ///
  /// Removes partial downloads and temporary files.
  Future<void> cleanupModels() => _platform.cleanupModels();
}
