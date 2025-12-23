/// Memory usage optimization utilities.
///
/// Monitor and optimize memory usage during transcription.
library;

import 'dart:io';

/// Memory usage information.
class MemoryInfo {
  const MemoryInfo({
    required this.usedMB,
    required this.freeMB,
    required this.totalMB,
  });

  /// Memory currently used in MB.
  final int usedMB;

  /// Free memory in MB.
  final int freeMB;

  /// Total memory in MB.
  final int totalMB;

  /// Usage as percentage (0-100).
  double get usagePercent => totalMB > 0 ? (usedMB / totalMB) * 100 : 0;

  /// Whether memory is low (<20% free).
  bool get isLow => usagePercent > 80;

  /// Whether memory is critical (<10% free).
  bool get isCritical => usagePercent > 90;

  @override
  String toString() =>
      'MemoryInfo(used: ${usedMB}MB, free: ${freeMB}MB, total: ${totalMB}MB)';
}

/// Memory optimization configuration.
class MemoryConfig {
  const MemoryConfig({
    this.maxModelCacheMB = 500,
    this.maxAudioBufferMB = 100,
    this.enableAggressive = false,
    this.lowMemoryThreshold = 200,
    this.criticalMemoryThreshold = 100,
  });

  /// Maximum memory for model cache in MB.
  final int maxModelCacheMB;

  /// Maximum memory for audio buffers in MB.
  final int maxAudioBufferMB;

  /// Enable aggressive memory optimization.
  final bool enableAggressive;

  /// Low memory threshold in MB.
  final int lowMemoryThreshold;

  /// Critical memory threshold in MB.
  final int criticalMemoryThreshold;
}

/// Memory optimization utilities.
class MemoryOptimizer {
  const MemoryOptimizer._();

  /// Estimate memory required for model.
  static int estimateModelMemory(String modelName) {
    // Approximate memory requirements
    final estimates = {
      'tiny': 75,
      'base': 150,
      'small': 500,
      'medium': 1500,
      'large': 3000,
    };
    return estimates[modelName.toLowerCase()] ?? 500;
  }

  /// Check if device can load a model.
  static bool canLoadModel(String modelName, int availableMemoryMB) {
    final required = estimateModelMemory(modelName);
    // Need at least 1.5x the model size for comfortable operation
    return availableMemoryMB >= (required * 1.5).round();
  }

  /// Get recommended model for available memory.
  static String recommendModel(int availableMemoryMB) {
    if (availableMemoryMB >= 4500) return 'large';
    if (availableMemoryMB >= 2250) return 'medium';
    if (availableMemoryMB >= 750) return 'small';
    if (availableMemoryMB >= 225) return 'base';
    return 'tiny';
  }

  /// Calculate optimal chunk size for audio processing.
  static int optimalChunkSize(int availableMemoryMB) {
    // Use 10% of available memory for audio chunk, max 50MB
    final optimal = (availableMemoryMB * 0.1).round();
    return optimal.clamp(5, 50);
  }

  /// Get memory optimization hints.
  static List<String> getOptimizationHints(MemoryInfo info) {
    final hints = <String>[];

    if (info.isLow) {
      hints.add('Memory is low. Consider using a smaller model.');
    }

    if (info.isCritical) {
      hints.add('Memory is critical. Free up memory before processing.');
      hints.add('Consider processing smaller audio chunks.');
    }

    if (info.usedMB > 1000) {
      hints.add('High memory usage detected. Clear unused caches.');
    }

    return hints;
  }
}

/// Threading configuration for optimized processing.
class ThreadingConfig {
  const ThreadingConfig({
    this.transcriptionThreads,
    this.audioProcessingThreads,
    this.modelLoadingThreads = 1,
    this.useIsolates = false,
  });

  /// Threads for transcription (null = auto).
  final int? transcriptionThreads;

  /// Threads for audio processing.
  final int? audioProcessingThreads;

  /// Threads for model loading.
  final int modelLoadingThreads;

  /// Whether to use Dart isolates.
  final bool useIsolates;

  /// Get recommended thread count based on device.
  static int recommendedThreads() {
    final cores = Platform.numberOfProcessors;
    // Use most cores but leave some for UI
    if (cores >= 8) return 6;
    if (cores >= 6) return 4;
    if (cores >= 4) return 3;
    return 2;
  }

  /// Create optimized config for device.
  factory ThreadingConfig.optimized() {
    final recommended = ThreadingConfig.recommendedThreads();
    return ThreadingConfig(
      transcriptionThreads: recommended,
      audioProcessingThreads: (recommended / 2).ceil(),
    );
  }
}

/// Performance profiler for tracking operation times.
class PerformanceProfiler {
  PerformanceProfiler._();

  static PerformanceProfiler? _instance;

  /// Singleton instance.
  static PerformanceProfiler get instance {
    _instance ??= PerformanceProfiler._();
    return _instance!;
  }

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<Duration>> _measurements = {};

  /// Start timing an operation.
  void start(String operation) {
    _timers[operation] = Stopwatch()..start();
  }

  /// Stop timing and record measurement.
  Duration? stop(String operation) {
    final timer = _timers.remove(operation);
    if (timer == null) return null;

    timer.stop();
    final duration = timer.elapsed;
    _measurements.putIfAbsent(operation, () => []).add(duration);
    return duration;
  }

  /// Get average duration for an operation.
  Duration? getAverage(String operation) {
    final measurements = _measurements[operation];
    if (measurements == null || measurements.isEmpty) return null;

    final totalMs = measurements.fold<int>(
      0,
      (sum, d) => sum + d.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ measurements.length);
  }

  /// Get all measurements for an operation.
  List<Duration> getMeasurements(String operation) {
    return List.unmodifiable(_measurements[operation] ?? []);
  }

  /// Clear all measurements.
  void clear() {
    _timers.clear();
    _measurements.clear();
  }

  /// Get summary of all operations.
  Map<String, Duration> getSummary() {
    return {
      for (final op in _measurements.keys)
        if (getAverage(op) != null) op: getAverage(op)!,
    };
  }
}
