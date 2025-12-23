/// Testing utilities for WhisperKit.
///
/// Stress testing, memory leak detection, and compatibility testing.
library;

import 'dart:async';

/// Stress test configuration.
class StressTestConfig {
  const StressTestConfig({
    this.iterations = 100,
    this.concurrency = 4,
    this.delayBetweenBatches = const Duration(milliseconds: 100),
    this.timeout = const Duration(minutes: 30),
    this.collectMemory = true,
    this.failFast = false,
  });

  /// Number of iterations.
  final int iterations;

  /// Concurrent operations.
  final int concurrency;

  /// Delay between batches.
  final Duration delayBetweenBatches;

  /// Overall timeout.
  final Duration timeout;

  /// Collect memory statistics.
  final bool collectMemory;

  /// Stop on first failure.
  final bool failFast;
}

/// Stress test result.
class StressTestResult {
  const StressTestResult({
    required this.totalIterations,
    required this.successCount,
    required this.failureCount,
    required this.totalDuration,
    this.averageLatency,
    this.minLatency,
    this.maxLatency,
    this.peakMemoryMB,
    this.errors,
  });

  /// Total iterations run.
  final int totalIterations;

  /// Successful iterations.
  final int successCount;

  /// Failed iterations.
  final int failureCount;

  /// Total test duration.
  final Duration totalDuration;

  /// Average latency per operation.
  final Duration? averageLatency;

  /// Minimum latency.
  final Duration? minLatency;

  /// Maximum latency.
  final Duration? maxLatency;

  /// Peak memory usage.
  final int? peakMemoryMB;

  /// Collected errors.
  final List<String>? errors;

  /// Success rate (0-100).
  double get successRate =>
      totalIterations > 0 ? (successCount / totalIterations) * 100 : 0;

  /// Throughput (operations per second).
  double get throughput => totalDuration.inMilliseconds > 0
      ? totalIterations / (totalDuration.inMilliseconds / 1000)
      : 0;

  @override
  String toString() => 'StressTestResult('
      'success: ${successRate.toStringAsFixed(1)}%, '
      'throughput: ${throughput.toStringAsFixed(2)} ops/s)';
}

/// Stress tester for WhisperKit.
class StressTester {
  StressTester({
    this.config = const StressTestConfig(),
  });

  final StressTestConfig config;

  /// Run a stress test.
  Future<StressTestResult> run(
    Future<void> Function(int iteration) task, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final latencies = <Duration>[];
    final errors = <String>[];
    var successCount = 0;
    var completed = 0;

    // Run in batches
    for (var batch = 0;
        batch < config.iterations;
        batch += config.concurrency) {
      final batchEnd = (batch + config.concurrency).clamp(0, config.iterations);
      final futures = <Future<void>>[];

      for (var i = batch; i < batchEnd; i++) {
        futures.add(_runSingle(i, task, latencies, errors));
      }

      final results = await Future.wait(
        futures,
        eagerError: config.failFast,
      );

      successCount += results.length;
      completed = batchEnd;
      onProgress?.call(completed, config.iterations);

      if (batch + config.concurrency < config.iterations) {
        await Future.delayed(config.delayBetweenBatches);
      }
    }

    stopwatch.stop();

    return StressTestResult(
      totalIterations: config.iterations,
      successCount: successCount - errors.length,
      failureCount: errors.length,
      totalDuration: stopwatch.elapsed,
      averageLatency: latencies.isNotEmpty
          ? Duration(
              microseconds:
                  latencies.fold<int>(0, (sum, d) => sum + d.inMicroseconds) ~/
                      latencies.length)
          : null,
      minLatency: latencies.isNotEmpty
          ? latencies.reduce((a, b) => a < b ? a : b)
          : null,
      maxLatency: latencies.isNotEmpty
          ? latencies.reduce((a, b) => a > b ? a : b)
          : null,
      errors: errors.isNotEmpty ? errors : null,
    );
  }

  Future<void> _runSingle(
    int iteration,
    Future<void> Function(int) task,
    List<Duration> latencies,
    List<String> errors,
  ) async {
    final sw = Stopwatch()..start();
    try {
      await task(iteration);
      sw.stop();
      latencies.add(sw.elapsed);
    } catch (e) {
      sw.stop();
      errors.add('Iteration $iteration: $e');
      if (config.failFast) rethrow;
    }
  }
}

/// Device compatibility information.
class DeviceCompatibility {
  const DeviceCompatibility({
    required this.deviceModel,
    required this.osVersion,
    required this.processorCount,
    required this.memoryMB,
    this.supportedModels,
    this.issues,
  });

  /// Device model.
  final String deviceModel;

  /// OS version.
  final String osVersion;

  /// Processor count.
  final int processorCount;

  /// Available memory in MB.
  final int memoryMB;

  /// Models known to work on this device.
  final List<String>? supportedModels;

  /// Known issues.
  final List<String>? issues;

  /// Check if device meets minimum requirements.
  bool get meetsMinimumRequirements => processorCount >= 2 && memoryMB >= 512;
}

/// Memory leak detector.
class MemoryLeakDetector {
  MemoryLeakDetector({
    this.sampleInterval = const Duration(seconds: 1),
    this.leakThresholdMB = 50,
  });

  /// Interval between memory samples.
  final Duration sampleInterval;

  /// Memory increase threshold to consider a leak.
  final int leakThresholdMB;

  final List<int> _samples = [];
  Timer? _timer;

  /// Start monitoring.
  void start() {
    _samples.clear();
    _timer = Timer.periodic(sampleInterval, (_) {
      // In real implementation, query actual memory
      // This is a placeholder
      _samples.add(0);
    });
  }

  /// Stop monitoring.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Analyze for leaks.
  MemoryLeakResult analyze() {
    if (_samples.length < 2) {
      return const MemoryLeakResult(
          hasLeak: false, message: 'Insufficient samples');
    }

    final first = _samples.first;
    final last = _samples.last;
    final increase = last - first;

    return MemoryLeakResult(
      hasLeak: increase > leakThresholdMB,
      message: increase > leakThresholdMB
          ? 'Memory increased by ${increase}MB'
          : 'Memory stable',
      samples: List.unmodifiable(_samples),
    );
  }
}

/// Memory leak detection result.
class MemoryLeakResult {
  const MemoryLeakResult({
    required this.hasLeak,
    this.message,
    this.samples,
  });

  /// Whether a leak was detected.
  final bool hasLeak;

  /// Diagnostic message.
  final String? message;

  /// Memory samples.
  final List<int>? samples;
}
