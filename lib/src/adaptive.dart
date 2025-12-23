/// Adaptive processing based on device capabilities.
library;

import 'dart:io';

import 'package:whisper_kit/download_model.dart';

/// Device capability detection for adaptive processing.
class DeviceCapabilities {
  DeviceCapabilities._({
    required this.availableMemoryMB,
    required this.processorCount,
    required this.isLowPowerMode,
  });

  /// Estimated available memory in MB.
  final int availableMemoryMB;

  /// Number of processor cores.
  final int processorCount;

  /// Whether device is in low power mode.
  final bool isLowPowerMode;

  /// Detect current device capabilities.
  static DeviceCapabilities detect() {
    return DeviceCapabilities._(
      availableMemoryMB: _estimateAvailableMemory(),
      processorCount: Platform.numberOfProcessors,
      isLowPowerMode: false, // Can't detect in pure Dart
    );
  }

  /// Estimate available memory (conservative estimate).
  static int _estimateAvailableMemory() {
    // Use processor count as a rough proxy for device tier
    final cores = Platform.numberOfProcessors;
    if (cores >= 8) return 4096; // High-end device
    if (cores >= 6) return 3072; // Mid-high device
    if (cores >= 4) return 2048; // Mid device
    return 1024; // Low-end device
  }
}

/// Adaptive processing configuration.
class AdaptiveConfig {
  const AdaptiveConfig({
    required this.recommendedModel,
    required this.threads,
    required this.useSpeedUp,
    required this.nProcessors,
  });

  /// Recommended model for this device.
  final WhisperModel recommendedModel;

  /// Recommended thread count.
  final int threads;

  /// Whether to use speed-up mode.
  final bool useSpeedUp;

  /// Number of processors to use.
  final int nProcessors;

  /// Get model name string.
  String get modelName => recommendedModel.modelName;
}

/// Adaptive processing utilities.
class AdaptiveProcessor {
  const AdaptiveProcessor._();

  /// Get recommended configuration based on device capabilities.
  static AdaptiveConfig getRecommendedConfig([DeviceCapabilities? caps]) {
    final capabilities = caps ?? DeviceCapabilities.detect();

    return AdaptiveConfig(
      recommendedModel: _selectModel(capabilities),
      threads: _selectThreads(capabilities),
      useSpeedUp: capabilities.availableMemoryMB < 2048,
      nProcessors: _selectProcessors(capabilities),
    );
  }

  /// Select best model for device.
  static WhisperModel _selectModel(DeviceCapabilities caps) {
    if (caps.isLowPowerMode) return WhisperModel.tiny;

    if (caps.availableMemoryMB >= 4096) {
      return WhisperModel.medium;
    } else if (caps.availableMemoryMB >= 2048) {
      return WhisperModel.small;
    } else if (caps.availableMemoryMB >= 1024) {
      return WhisperModel.base;
    } else {
      return WhisperModel.tiny;
    }
  }

  /// Select optimal thread count.
  static int _selectThreads(DeviceCapabilities caps) {
    // Use most cores, but leave some for UI
    final available = caps.processorCount;
    if (available >= 8) return 6;
    if (available >= 6) return 4;
    if (available >= 4) return 3;
    return 2;
  }

  /// Select number of processors.
  static int _selectProcessors(DeviceCapabilities caps) {
    return caps.availableMemoryMB >= 2048 ? 1 : 1;
  }

  /// Get device tier description.
  static String getDeviceTier([DeviceCapabilities? caps]) {
    final capabilities = caps ?? DeviceCapabilities.detect();

    if (capabilities.processorCount >= 8 &&
        capabilities.availableMemoryMB >= 4096) {
      return 'high-end';
    } else if (capabilities.processorCount >= 4 &&
        capabilities.availableMemoryMB >= 2048) {
      return 'mid-range';
    } else {
      return 'low-end';
    }
  }
}
