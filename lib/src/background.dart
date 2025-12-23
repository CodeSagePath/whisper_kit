/// Background transcription utilities.
///
/// Handle transcription in the background while app is not in foreground.
library;

import 'dart:async';

/// Background processing state.
enum BackgroundState {
  /// Idle - no background task.
  idle,

  /// Running in background.
  running,

  /// Paused by system.
  paused,

  /// Completed.
  completed,

  /// Failed.
  failed,
}

/// Background task result.
class BackgroundResult {
  const BackgroundResult({
    required this.taskId,
    required this.state,
    this.result,
    this.error,
    this.progress,
  });

  /// Task ID.
  final String taskId;

  /// Current state.
  final BackgroundState state;

  /// Result data if completed.
  final String? result;

  /// Error message if failed.
  final String? error;

  /// Progress (0-100).
  final int? progress;
}

/// Background task configuration.
class BackgroundConfig {
  const BackgroundConfig({
    this.showNotification = true,
    this.notificationTitle,
    this.notificationBody,
    this.notificationIcon,
    this.keepAlive = true,
    this.allowOnBattery = true,
    this.requiresNetwork = false,
  });

  /// Show notification while processing.
  final bool showNotification;

  /// Notification title.
  final String? notificationTitle;

  /// Notification body.
  final String? notificationBody;

  /// Notification icon resource.
  final String? notificationIcon;

  /// Keep background task alive.
  final bool keepAlive;

  /// Allow on battery power.
  final bool allowOnBattery;

  /// Requires network connection.
  final bool requiresNetwork;
}

/// Background task callback.
typedef BackgroundCallback = Future<String?> Function(String taskId);

/// Abstract background handler interface.
abstract class BackgroundHandler {
  /// Initialize background processing.
  Future<void> initialize();

  /// Schedule a background task.
  Future<String> schedule(
    BackgroundConfig config,
    BackgroundCallback callback,
  );

  /// Cancel a background task.
  Future<bool> cancel(String taskId);

  /// Get task state.
  Future<BackgroundState?> getState(String taskId);

  /// Stream of state updates.
  Stream<BackgroundResult> get updates;
}

/// Background transcription manager.
class BackgroundTranscription {
  BackgroundTranscription._();

  static BackgroundTranscription? _instance;

  /// Singleton instance.
  static BackgroundTranscription get instance {
    _instance ??= BackgroundTranscription._();
    return _instance!;
  }

  BackgroundHandler? _handler;
  final Map<String, BackgroundConfig> _tasks = {};
  final _controller = StreamController<BackgroundResult>.broadcast();

  /// Set the background handler implementation.
  void setHandler(BackgroundHandler handler) {
    _handler = handler;
  }

  /// Start background transcription.
  Future<String?> startTranscription({
    required String audioPath,
    String? title,
    BackgroundConfig config = const BackgroundConfig(),
  }) async {
    if (_handler == null) return null;

    final taskId = await _handler!.schedule(
      BackgroundConfig(
        showNotification: config.showNotification,
        notificationTitle: title ?? 'Transcribing audio...',
        notificationBody: 'Processing in background',
        keepAlive: config.keepAlive,
      ),
      (id) async {
        // This would be called by the background handler
        _controller.add(BackgroundResult(
          taskId: id,
          state: BackgroundState.running,
          progress: 0,
        ));

        // Actual transcription would happen here
        return audioPath;
      },
    );

    _tasks[taskId] = config;
    return taskId;
  }

  /// Cancel background transcription.
  Future<bool> cancel(String taskId) async {
    if (_handler == null) return false;
    final result = await _handler!.cancel(taskId);
    _tasks.remove(taskId);
    return result;
  }

  /// Get state of a task.
  Future<BackgroundState?> getState(String taskId) async {
    return _handler?.getState(taskId);
  }

  /// Stream of background updates.
  Stream<BackgroundResult> get updates => _controller.stream;

  /// Get all active tasks.
  Set<String> get activeTasks => _tasks.keys.toSet();

  /// Check if any task is running.
  bool get hasActiveTasks => _tasks.isNotEmpty;

  /// Cancel all tasks.
  Future<void> cancelAll() async {
    for (final taskId in _tasks.keys.toList()) {
      await cancel(taskId);
    }
  }

  /// Dispose resources.
  void dispose() {
    _controller.close();
  }
}
