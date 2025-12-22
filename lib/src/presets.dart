/// Configuration presets for different transcription use cases.
///
/// Use these presets to quickly configure Whisper for common scenarios.
library;

import 'package:whisper_kit/bean/request_bean.dart';

/// Preset configurations for different transcription use cases.
///
/// Example usage:
/// ```dart
/// final request = TranscriptionPreset.fast.toRequest(audioPath);
/// final result = await whisper.transcribe(transcribeRequest: request);
/// ```
enum TranscriptionPreset {
  /// Fastest transcription with lower accuracy.
  ///
  /// Best for: Real-time applications, quick previews, low-power devices.
  /// Tradeoff: Lower accuracy, may miss some words in noisy audio.
  fast,

  /// Balanced speed and accuracy (default).
  ///
  /// Best for: Most use cases, general transcription, interviews.
  /// Tradeoff: Good balance between speed and quality.
  balanced,

  /// Highest accuracy with slower processing.
  ///
  /// Best for: Final transcriptions, professional content, archival.
  /// Tradeoff: Slower processing, higher CPU usage.
  accurate,

  /// Low memory usage for resource-constrained devices.
  ///
  /// Best for: Older devices, background processing, long recordings.
  /// Tradeoff: Slower processing to reduce memory footprint.
  lowMemory,

  /// Optimized for real-time streaming transcription.
  ///
  /// Best for: Live captions, voice assistants, real-time feedback.
  /// Tradeoff: May have slightly lower accuracy for fast response.
  realtime,
}

/// Extension methods for [TranscriptionPreset].
extension TranscriptionPresetExtension on TranscriptionPreset {
  /// Creates a [TranscribeRequest] with this preset's configuration.
  TranscribeRequest toRequest(String audioPath) {
    return TranscribeRequest(
      audio: audioPath,
      threads: threads,
      nProcessors: nProcessors,
      speedUp: speedUp,
      splitOnWord: splitOnWord,
      isNoTimestamps: isNoTimestamps,
    );
  }

  /// Creates a [TranscribeRequest] with this preset and additional options.
  TranscribeRequest toRequestWithOptions({
    required String audioPath,
    String language = 'auto',
    bool translate = false,
    bool verbose = false,
  }) {
    return TranscribeRequest(
      audio: audioPath,
      language: language,
      isTranslate: translate,
      isVerbose: verbose,
      threads: threads,
      nProcessors: nProcessors,
      speedUp: speedUp,
      splitOnWord: splitOnWord,
      isNoTimestamps: isNoTimestamps,
    );
  }

  /// Number of threads for this preset.
  int get threads {
    switch (this) {
      case TranscriptionPreset.fast:
        return 8; // Maximum parallelization
      case TranscriptionPreset.balanced:
        return 6; // Default
      case TranscriptionPreset.accurate:
        return 4; // More careful processing
      case TranscriptionPreset.lowMemory:
        return 2; // Reduced thread count
      case TranscriptionPreset.realtime:
        return 4; // Balance for low latency
    }
  }

  /// Number of processors for this preset.
  int get nProcessors {
    switch (this) {
      case TranscriptionPreset.fast:
        return 2;
      case TranscriptionPreset.balanced:
        return 1;
      case TranscriptionPreset.accurate:
        return 1;
      case TranscriptionPreset.lowMemory:
        return 1;
      case TranscriptionPreset.realtime:
        return 1;
    }
  }

  /// Whether to speed up processing.
  bool get speedUp {
    switch (this) {
      case TranscriptionPreset.fast:
        return true;
      case TranscriptionPreset.balanced:
        return false;
      case TranscriptionPreset.accurate:
        return false;
      case TranscriptionPreset.lowMemory:
        return false;
      case TranscriptionPreset.realtime:
        return true;
    }
  }

  /// Whether to split on word boundaries.
  bool get splitOnWord {
    switch (this) {
      case TranscriptionPreset.fast:
        return false;
      case TranscriptionPreset.balanced:
        return true;
      case TranscriptionPreset.accurate:
        return true;
      case TranscriptionPreset.lowMemory:
        return false;
      case TranscriptionPreset.realtime:
        return true;
    }
  }

  /// Whether to skip timestamps.
  bool get isNoTimestamps {
    switch (this) {
      case TranscriptionPreset.fast:
        return true; // Skip for speed
      case TranscriptionPreset.balanced:
        return false;
      case TranscriptionPreset.accurate:
        return false;
      case TranscriptionPreset.lowMemory:
        return true; // Skip to save memory
      case TranscriptionPreset.realtime:
        return false;
    }
  }

  /// Human-readable description of this preset.
  String get description {
    switch (this) {
      case TranscriptionPreset.fast:
        return 'Fast: Maximum speed, lower accuracy';
      case TranscriptionPreset.balanced:
        return 'Balanced: Good speed and accuracy (recommended)';
      case TranscriptionPreset.accurate:
        return 'Accurate: Best quality, slower processing';
      case TranscriptionPreset.lowMemory:
        return 'Low Memory: Reduced memory usage for older devices';
      case TranscriptionPreset.realtime:
        return 'Realtime: Optimized for live transcription';
    }
  }
}

/// Model selection recommendations based on device capabilities.
class ModelRecommendation {
  const ModelRecommendation._();

  /// Get recommended model based on available RAM (in MB).
  ///
  /// Returns the model name as a string.
  static String forRamMB(int ramMB) {
    if (ramMB >= 4096) {
      return 'medium'; // 4GB+ RAM
    } else if (ramMB >= 2048) {
      return 'small'; // 2-4GB RAM
    } else if (ramMB >= 1024) {
      return 'base'; // 1-2GB RAM
    } else {
      return 'tiny'; // <1GB RAM
    }
  }

  /// Get recommended model for a given preset and RAM.
  static String forPresetAndRam(TranscriptionPreset preset, int ramMB) {
    switch (preset) {
      case TranscriptionPreset.fast:
        return 'tiny';
      case TranscriptionPreset.balanced:
        return forRamMB(ramMB);
      case TranscriptionPreset.accurate:
        if (ramMB >= 4096) return 'medium';
        if (ramMB >= 2048) return 'small';
        return 'base';
      case TranscriptionPreset.lowMemory:
        return 'tiny';
      case TranscriptionPreset.realtime:
        return ramMB >= 2048 ? 'base' : 'tiny';
    }
  }
}
