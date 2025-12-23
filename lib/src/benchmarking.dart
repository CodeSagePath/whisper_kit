/// Performance benchmarking utilities.
///
/// Measure and compare transcription performance.
library;

import 'dart:async';

/// Benchmark result.
class BenchmarkResult {
  const BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.totalDuration,
    this.minDuration,
    this.maxDuration,
    this.metadata,
  });

  /// Benchmark name.
  final String name;

  /// Number of iterations.
  final int iterations;

  /// Total duration.
  final Duration totalDuration;

  /// Minimum duration.
  final Duration? minDuration;

  /// Maximum duration.
  final Duration? maxDuration;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Average duration per iteration.
  Duration get averageDuration => Duration(
        microseconds: totalDuration.inMicroseconds ~/ iterations,
      );

  /// Operations per second.
  double get opsPerSecond => iterations / (totalDuration.inMilliseconds / 1000);

  @override
  String toString() => 'BenchmarkResult('
      'name: $name, '
      'iterations: $iterations, '
      'avg: ${averageDuration.inMilliseconds}ms, '
      'ops/s: ${opsPerSecond.toStringAsFixed(2)})';
}

/// Transcription benchmark configuration.
class TranscriptionBenchmarkConfig {
  const TranscriptionBenchmarkConfig({
    this.warmupRuns = 1,
    this.measurementRuns = 3,
    this.cooldownMs = 500,
    this.collectMemory = true,
  });

  /// Warmup runs before measurement.
  final int warmupRuns;

  /// Measurement runs.
  final int measurementRuns;

  /// Cooldown between runs in ms.
  final int cooldownMs;

  /// Collect memory statistics.
  final bool collectMemory;
}

/// Performance benchmarker.
class Benchmarker {
  Benchmarker({
    this.config = const TranscriptionBenchmarkConfig(),
  });

  /// Configuration.
  final TranscriptionBenchmarkConfig config;

  final List<BenchmarkResult> _results = [];

  /// Run a benchmark.
  Future<BenchmarkResult> run(
    String name,
    Future<void> Function() task, {
    int? iterations,
  }) async {
    final runs = iterations ?? config.measurementRuns;
    final durations = <Duration>[];

    // Warmup
    for (var i = 0; i < config.warmupRuns; i++) {
      await task();
      await Future.delayed(Duration(milliseconds: config.cooldownMs));
    }

    // Measurement
    for (var i = 0; i < runs; i++) {
      final stopwatch = Stopwatch()..start();
      await task();
      stopwatch.stop();
      durations.add(stopwatch.elapsed);

      if (i < runs - 1) {
        await Future.delayed(Duration(milliseconds: config.cooldownMs));
      }
    }

    final totalDuration = durations.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );

    final result = BenchmarkResult(
      name: name,
      iterations: runs,
      totalDuration: totalDuration,
      minDuration: durations.reduce((a, b) => a < b ? a : b),
      maxDuration: durations.reduce((a, b) => a > b ? a : b),
    );

    _results.add(result);
    return result;
  }

  /// Get all results.
  List<BenchmarkResult> get results => List.unmodifiable(_results);

  /// Clear results.
  void clear() => _results.clear();

  /// Generate report.
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Benchmark Report ===');
    buffer.writeln('');

    for (final result in _results) {
      buffer.writeln('${result.name}:');
      buffer.writeln('  Iterations: ${result.iterations}');
      buffer.writeln('  Average: ${result.averageDuration.inMilliseconds}ms');
      buffer.writeln('  Min: ${result.minDuration?.inMilliseconds}ms');
      buffer.writeln('  Max: ${result.maxDuration?.inMilliseconds}ms');
      buffer.writeln('  Ops/sec: ${result.opsPerSecond.toStringAsFixed(2)}');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// Model benchmark for comparing different Whisper models.
class ModelBenchmark {
  const ModelBenchmark({
    required this.modelName,
    required this.audioFile,
    required this.transcriptionTime,
    required this.audioDuration,
    this.wordCount,
    this.accuracy,
    this.memoryUsedMB,
  });

  /// Model name.
  final String modelName;

  /// Audio file used.
  final String audioFile;

  /// Time to transcribe.
  final Duration transcriptionTime;

  /// Audio duration.
  final Duration audioDuration;

  /// Number of words transcribed.
  final int? wordCount;

  /// Accuracy score (0-1) if reference available.
  final double? accuracy;

  /// Memory used in MB.
  final int? memoryUsedMB;

  /// Real-time factor (lower is better).
  double get realTimeFactor =>
      transcriptionTime.inMilliseconds / audioDuration.inMilliseconds;

  /// Words per second.
  double? get wordsPerSecond => wordCount != null
      ? wordCount! / (transcriptionTime.inMilliseconds / 1000)
      : null;

  @override
  String toString() => 'ModelBenchmark('
      'model: $modelName, '
      'RTF: ${realTimeFactor.toStringAsFixed(2)}, '
      'time: ${transcriptionTime.inSeconds}s)';
}

/// Benchmark comparison utility.
class BenchmarkComparison {
  const BenchmarkComparison._();

  /// Compare model benchmarks.
  static String compare(List<ModelBenchmark> benchmarks) {
    if (benchmarks.isEmpty) return 'No benchmarks to compare';

    final buffer = StringBuffer();
    buffer.writeln('=== Model Comparison ===');
    buffer.writeln('');
    buffer.writeln('| Model | RTF | Time | Memory |');
    buffer.writeln('|-------|-----|------|--------|');

    for (final b in benchmarks) {
      buffer.writeln('| ${b.modelName} | '
          '${b.realTimeFactor.toStringAsFixed(2)}x | '
          '${b.transcriptionTime.inSeconds}s | '
          '${b.memoryUsedMB ?? "N/A"}MB |');
    }

    return buffer.toString();
  }

  /// Find fastest model.
  static ModelBenchmark? findFastest(List<ModelBenchmark> benchmarks) {
    if (benchmarks.isEmpty) return null;
    return benchmarks
        .reduce((a, b) => a.realTimeFactor < b.realTimeFactor ? a : b);
  }

  /// Find most accurate model.
  static ModelBenchmark? findMostAccurate(List<ModelBenchmark> benchmarks) {
    final withAccuracy = benchmarks.where((b) => b.accuracy != null).toList();
    if (withAccuracy.isEmpty) return null;
    return withAccuracy.reduce((a, b) => a.accuracy! > b.accuracy! ? a : b);
  }
}
