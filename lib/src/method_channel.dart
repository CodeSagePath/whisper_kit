/// Method channel implementation of WhisperKit platform interface.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:whisper_kit/src/platform_interface.dart';

/// Method channel implementation for communicating with native platforms.
class WhisperKitMethodChannel implements WhisperKitPlatformInterface {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _channel = MethodChannel('whisper_kit');

  @override
  Future<String> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version ?? 'Unknown';
  }

  // MARK: - Permissions

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'requestMicrophonePermission',
      );
      return _parsePermissionStatus(result);
    } on PlatformException {
      return PermissionStatus.denied;
    }
  }

  @override
  Future<PermissionStatus> checkMicrophonePermission() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'checkMicrophonePermission',
      );
      return _parsePermissionStatus(result);
    } on PlatformException {
      return PermissionStatus.notDetermined;
    }
  }

  @override
  Future<PermissionStatus> requestStoragePermission() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'requestStoragePermission',
      );
      return _parsePermissionStatus(result);
    } on PlatformException {
      return PermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    await _channel.invokeMethod<void>('openAppSettings');
  }

  PermissionStatus _parsePermissionStatus(Map<Object?, Object?>? result) {
    if (result == null) return PermissionStatus.notDetermined;

    final granted = result['granted'] as bool? ?? false;
    if (granted) return PermissionStatus.granted;

    final status = result['status'] as String? ?? '';
    switch (status.toLowerCase()) {
      case 'authorized':
      case 'granted':
        return PermissionStatus.granted;
      case 'denied':
        return PermissionStatus.denied;
      case 'restricted':
        return PermissionStatus.restricted;
      case 'permanentlydenied':
        return PermissionStatus.permanentlyDenied;
      default:
        return PermissionStatus.notDetermined;
    }
  }

  // MARK: - Audio Recording

  @override
  Future<bool> startRecording({bool saveToFile = true}) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'startAudioCapture',
        {'shouldSave': saveToFile},
      );
      return result?['success'] as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<RecordingResult> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'stopAudioCapture',
      );
      if (result == null) {
        return const RecordingResult(success: false, error: 'No result');
      }
      return RecordingResult.fromMap(_convertMap(result));
    } on PlatformException catch (e) {
      return RecordingResult(success: false, error: e.message);
    }
  }

  @override
  Future<List<int>?> getAudioData() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getAudioData',
      );
      final base64Data = result?['audioData'] as String?;
      if (base64Data == null) return null;
      // Decode base64 to bytes
      return List<int>.from(base64Data.codeUnits);
    } on PlatformException {
      return null;
    }
  }

  // MARK: - Model Management

  @override
  Future<String> getModelPath() async {
    final path = await _channel.invokeMethod<String>('getModelPath');
    return path ?? '';
  }

  @override
  Future<List<ModelInfo>> getAvailableModels() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'getAvailableModels',
      );
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((m) => ModelInfo.fromMap(_convertMap(m)))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<List<ModelInfo>> getDownloadedModels() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'getDownloadedModels',
      );
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((m) => ModelInfo.fromMap(_convertMap(m)))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<bool> isModelDownloaded(String modelName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isModelDownloaded',
        {'modelName': modelName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> deleteModel(String modelName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'deleteModel',
        {'modelName': modelName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> validateModel(String modelName) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'validateModel',
        {'modelName': modelName},
      );
      return result?['valid'] as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  // MARK: - Storage

  @override
  Future<StorageInfo> getStorageInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getStorageInfo',
      );
      if (result == null) {
        return const StorageInfo(totalSpace: 0, freeSpace: 0, usedByModels: 0);
      }
      return StorageInfo.fromMap(_convertMap(result));
    } on PlatformException {
      return const StorageInfo(totalSpace: 0, freeSpace: 0, usedByModels: 0);
    }
  }

  @override
  Future<void> cleanupModels() async {
    await _channel.invokeMethod<void>('cleanupModels');
  }

  /// Helper to convert platform map to Dart map.
  Map<String, dynamic> _convertMap(Map<Object?, Object?> map) {
    return map.map((k, v) => MapEntry(k.toString(), v));
  }
}
