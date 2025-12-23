/// Unit test utilities for WhisperKit.
///
/// Mock classes and test helpers for unit and integration testing.
library;

import 'dart:async';

import 'package:whisper_kit/bean/response_bean.dart';

/// Mock transcription response builder.
class MockTranscriptionBuilder {
  String _text = 'Hello world';
  final List<WhisperTranscribeSegment> _segments = [];

  /// Set the transcription text.
  MockTranscriptionBuilder withText(String text) {
    _text = text;
    return this;
  }

  /// Add a segment.
  MockTranscriptionBuilder addSegment({
    required String text,
    required Duration from,
    required Duration to,
  }) {
    _segments.add(WhisperTranscribeSegment(
      text: text,
      fromTs: from,
      toTs: to,
    ));
    return this;
  }

  /// Add multiple segments from text.
  MockTranscriptionBuilder withSegments(
    List<String> texts, {
    Duration segmentDuration = const Duration(seconds: 2),
  }) {
    var offset = Duration.zero;
    for (final text in texts) {
      _segments.add(WhisperTranscribeSegment(
        text: text,
        fromTs: offset,
        toTs: offset + segmentDuration,
      ));
      offset += segmentDuration;
    }
    return this;
  }

  /// Build the response.
  WhisperTranscribeResponse build() {
    return WhisperTranscribeResponse(
      type: 'transcribeResponse',
      text: _text,
      segments: _segments.isNotEmpty ? _segments : null,
    );
  }
}

/// Test audio file generator.
class TestAudioGenerator {
  const TestAudioGenerator._();

  /// Generate a silent audio path (placeholder).
  static String silentAudio({Duration duration = const Duration(seconds: 5)}) {
    return 'test://silent_${duration.inSeconds}s.wav';
  }

  /// Generate speech audio path (placeholder).
  static String speechAudio(String text) {
    return 'test://speech_${text.hashCode}.wav';
  }
}

/// Test utilities for model mocking.
class MockModelInfo {
  const MockModelInfo({
    required this.name,
    required this.path,
    this.sizeMB = 100,
    this.version = '1.0.0',
  });

  final String name;
  final String path;
  final int sizeMB;
  final String version;

  static const tiny = MockModelInfo(
    name: 'tiny',
    path: 'test://models/tiny.bin',
    sizeMB: 75,
  );

  static const base = MockModelInfo(
    name: 'base',
    path: 'test://models/base.bin',
    sizeMB: 142,
  );

  static const small = MockModelInfo(
    name: 'small',
    path: 'test://models/small.bin',
    sizeMB: 466,
  );
}

/// Assertions for transcription testing.
class TranscriptionAssertions {
  const TranscriptionAssertions._();

  /// Check if response is not empty.
  static bool hasText(WhisperTranscribeResponse response) {
    return response.text.trim().isNotEmpty;
  }

  /// Check if response has segments.
  static bool hasSegments(WhisperTranscribeResponse response) {
    return response.segments != null && response.segments!.isNotEmpty;
  }

  /// Check if segments are ordered.
  static bool hasOrderedSegments(WhisperTranscribeResponse response) {
    if (response.segments == null || response.segments!.length < 2) {
      return true;
    }
    for (var i = 1; i < response.segments!.length; i++) {
      if (response.segments![i].fromTs < response.segments![i - 1].fromTs) {
        return false;
      }
    }
    return true;
  }

  /// Check if text matches expected pattern.
  static bool matchesPattern(
    WhisperTranscribeResponse response,
    RegExp pattern,
  ) {
    return pattern.hasMatch(response.text);
  }

  /// Check if word count is in range.
  static bool wordCountInRange(
    WhisperTranscribeResponse response,
    int min,
    int max,
  ) {
    final words = response.text.trim().split(RegExp(r'\s+'));
    return words.length >= min && words.length <= max;
  }
}

/// Test timeout wrapper.
class TestTimeout {
  const TestTimeout._();

  /// Run with timeout.
  static Future<T> run<T>(
    Future<T> Function() fn, {
    Duration timeout = const Duration(seconds: 30),
    T? defaultValue,
  }) async {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      if (defaultValue != null) return defaultValue;
      throw TestTimeoutException('Operation timed out after $timeout');
    }
  }
}

/// Test timeout exception.
class TestTimeoutException implements Exception {
  const TestTimeoutException(this.message);
  final String message;

  @override
  String toString() => 'TestTimeoutException: $message';
}

/// Integration test utilities.
class IntegrationTestUtils {
  const IntegrationTestUtils._();

  /// Wait for condition with polling.
  static Future<bool> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (condition()) return true;
      await Future.delayed(interval);
    }
    return false;
  }

  /// Retry function with exponential backoff.
  static Future<T> retry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) async {
    var delay = initialDelay;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw StateError('Unreachable');
  }
}
