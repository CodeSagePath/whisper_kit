/// Telemetry integration for usage analytics.
///
/// Privacy-respecting telemetry for improving the library.
library;

import 'dart:async';

/// Telemetry event types.
enum TelemetryEventType {
  /// Transcription started.
  transcriptionStarted,

  /// Transcription completed.
  transcriptionCompleted,

  /// Transcription failed.
  transcriptionFailed,

  /// Model downloaded.
  modelDownloaded,

  /// Model loaded.
  modelLoaded,

  /// Recording started.
  recordingStarted,

  /// Recording stopped.
  recordingStopped,

  /// Feature used.
  featureUsed,

  /// Error occurred.
  error,
}

/// A telemetry event.
class TelemetryEvent {
  TelemetryEvent({
    required this.type,
    DateTime? timestamp,
    this.properties,
    this.duration,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Event type.
  final TelemetryEventType type;

  /// When the event occurred.
  final DateTime timestamp;

  /// Additional properties.
  final Map<String, dynamic>? properties;

  /// Duration for timed events.
  final Duration? duration;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
        'durationMs': duration?.inMilliseconds,
      };
}

/// Abstract telemetry provider interface.
abstract class TelemetryProvider {
  /// Track an event.
  Future<void> track(TelemetryEvent event);

  /// Flush pending events.
  Future<void> flush();

  /// Enable/disable telemetry.
  void setEnabled(bool enabled);

  /// Check if telemetry is enabled.
  bool get isEnabled;
}

/// Telemetry manager for collecting usage data.
class Telemetry {
  Telemetry._();

  static Telemetry? _instance;

  /// Singleton instance.
  static Telemetry get instance {
    _instance ??= Telemetry._();
    return _instance!;
  }

  TelemetryProvider? _provider;
  bool _enabled = false;
  final List<TelemetryEvent> _pendingEvents = [];
  final Map<String, Stopwatch> _timers = {};

  /// Set the telemetry provider.
  void setProvider(TelemetryProvider provider) {
    _provider = provider;
    _flushPending();
  }

  /// Enable or disable telemetry.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _provider?.setEnabled(enabled);
  }

  /// Check if telemetry is enabled.
  bool get isEnabled => _enabled;

  /// Track an event.
  Future<void> track(
    TelemetryEventType type, {
    Map<String, dynamic>? properties,
    Duration? duration,
  }) async {
    if (!_enabled) return;

    final event = TelemetryEvent(
      type: type,
      properties: properties,
      duration: duration,
    );

    if (_provider != null) {
      await _provider!.track(event);
    } else {
      _pendingEvents.add(event);
    }
  }

  /// Start a timer for tracking duration.
  void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  /// Stop a timer and track the event.
  Future<void> stopTimer(
    String name,
    TelemetryEventType type, {
    Map<String, dynamic>? properties,
  }) async {
    final stopwatch = _timers.remove(name);
    if (stopwatch == null) return;

    stopwatch.stop();
    await track(type, properties: properties, duration: stopwatch.elapsed);
  }

  /// Track transcription start.
  Future<void> trackTranscriptionStart({
    String? modelName,
    String? language,
  }) async {
    startTimer('transcription');
    await track(
      TelemetryEventType.transcriptionStarted,
      properties: {
        if (modelName != null) 'model': modelName,
        if (language != null) 'language': language,
      },
    );
  }

  /// Track transcription completion.
  Future<void> trackTranscriptionComplete({
    int? audioLengthMs,
    int? wordCount,
  }) async {
    await stopTimer(
      'transcription',
      TelemetryEventType.transcriptionCompleted,
      properties: {
        if (audioLengthMs != null) 'audioLengthMs': audioLengthMs,
        if (wordCount != null) 'wordCount': wordCount,
      },
    );
  }

  /// Track an error.
  Future<void> trackError(String error, {String? context}) async {
    await track(
      TelemetryEventType.error,
      properties: {
        'error': error,
        if (context != null) 'context': context,
      },
    );
  }

  /// Flush pending events to provider.
  Future<void> flush() async {
    await _provider?.flush();
  }

  void _flushPending() {
    if (_provider == null) return;
    for (final event in _pendingEvents) {
      _provider!.track(event);
    }
    _pendingEvents.clear();
  }
}
