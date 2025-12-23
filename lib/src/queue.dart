/// Queue management for batch transcription.
///
/// Provides priority queue and concurrent processing management.
library;

import 'dart:async';
import 'dart:collection';

import 'package:whisper_kit/whisper_kit.dart';

/// Priority levels for transcription queue items.
enum TranscriptionPriority {
  /// Low priority - processed last.
  low,

  /// Normal priority.
  normal,

  /// High priority - processed first.
  high,

  /// Urgent - processed immediately.
  urgent,
}

/// A queued transcription item.
class QueuedTranscription {
  QueuedTranscription({
    required this.id,
    required this.audioPath,
    this.priority = TranscriptionPriority.normal,
    this.request,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Unique identifier for this item.
  final String id;

  /// Path to the audio file.
  final String audioPath;

  /// Priority level.
  final TranscriptionPriority priority;

  /// Transcription request configuration.
  final TranscribeRequest? request;

  /// When this item was added to the queue.
  final DateTime createdAt;

  /// Compare by priority (higher priority first), then by creation time (older first).
  int compareTo(QueuedTranscription other) {
    final priorityDiff = other.priority.index - priority.index;
    if (priorityDiff != 0) return priorityDiff;
    return createdAt.compareTo(other.createdAt);
  }
}

/// Queue item status.
enum QueueItemStatus {
  /// Waiting in queue.
  pending,

  /// Currently processing.
  processing,

  /// Completed successfully.
  completed,

  /// Failed with error.
  failed,

  /// Cancelled by user.
  cancelled,
}

/// Result of a queued transcription.
class QueuedResult {
  const QueuedResult({
    required this.id,
    required this.status,
    this.response,
    this.error,
    this.processingTime,
  });

  /// Queue item ID.
  final String id;

  /// Final status.
  final QueueItemStatus status;

  /// Transcription response if successful.
  final WhisperTranscribeResponse? response;

  /// Error message if failed.
  final String? error;

  /// Time taken to process.
  final Duration? processingTime;
}

/// Transcription queue manager with priority support.
class TranscriptionQueue {
  TranscriptionQueue({
    this.maxConcurrent = 2,
    this.onItemCompleted,
    this.onItemFailed,
    this.onQueueEmpty,
  });

  /// Maximum concurrent transcriptions.
  final int maxConcurrent;

  /// Callback when an item completes.
  final void Function(QueuedResult)? onItemCompleted;

  /// Callback when an item fails.
  final void Function(QueuedResult)? onItemFailed;

  /// Callback when queue becomes empty.
  final void Function()? onQueueEmpty;

  final Queue<QueuedTranscription> _queue = Queue();
  final Map<String, QueueItemStatus> _status = {};
  final Map<String, QueuedResult> _results = {};

  int _activeCount = 0;
  bool _isPaused = false;
  Whisper? _whisper;

  /// Set the Whisper instance to use for transcription.
  void setWhisper(Whisper whisper) {
    _whisper = whisper;
  }

  /// Add an item to the queue.
  String add(
    String audioPath, {
    String? id,
    TranscriptionPriority priority = TranscriptionPriority.normal,
    TranscribeRequest? request,
  }) {
    final itemId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final item = QueuedTranscription(
      id: itemId,
      audioPath: audioPath,
      priority: priority,
      request: request,
    );

    // Insert in priority order
    final list = _queue.toList()..add(item);
    list.sort((a, b) => a.compareTo(b));
    _queue.clear();
    _queue.addAll(list);

    _status[itemId] = QueueItemStatus.pending;

    _processNext();
    return itemId;
  }

  /// Cancel a queued item.
  bool cancel(String id) {
    final status = _status[id];
    if (status == null || status == QueueItemStatus.processing) {
      return false;
    }

    _queue.removeWhere((item) => item.id == id);
    _status[id] = QueueItemStatus.cancelled;
    return true;
  }

  /// Pause queue processing.
  void pause() {
    _isPaused = true;
  }

  /// Resume queue processing.
  void resume() {
    _isPaused = false;
    _processNext();
  }

  /// Get status of an item.
  QueueItemStatus? getStatus(String id) => _status[id];

  /// Get result of a completed item.
  QueuedResult? getResult(String id) => _results[id];

  /// Get number of pending items.
  int get pendingCount => _queue.length;

  /// Get number of active transcriptions.
  int get activeCount => _activeCount;

  /// Check if queue is empty and not processing.
  bool get isEmpty => _queue.isEmpty && _activeCount == 0;

  /// Clear all pending items.
  void clearPending() {
    for (final item in _queue) {
      _status[item.id] = QueueItemStatus.cancelled;
    }
    _queue.clear();
  }

  void _processNext() {
    if (_isPaused || _whisper == null) return;
    if (_activeCount >= maxConcurrent) return;
    if (_queue.isEmpty) {
      if (_activeCount == 0) {
        onQueueEmpty?.call();
      }
      return;
    }

    final item = _queue.removeFirst();
    _status[item.id] = QueueItemStatus.processing;
    _activeCount++;

    _processItem(item);
  }

  Future<void> _processItem(QueuedTranscription item) async {
    final stopwatch = Stopwatch()..start();

    try {
      final request = item.request ?? TranscribeRequest(audio: item.audioPath);
      final response = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: item.audioPath,
          isTranslate: request.isTranslate,
          threads: request.threads,
          isVerbose: request.isVerbose,
          language: request.language,
          isNoTimestamps: request.isNoTimestamps,
        ),
      );

      stopwatch.stop();

      final result = QueuedResult(
        id: item.id,
        status: QueueItemStatus.completed,
        response: response,
        processingTime: stopwatch.elapsed,
      );

      _status[item.id] = QueueItemStatus.completed;
      _results[item.id] = result;
      onItemCompleted?.call(result);
    } catch (e) {
      stopwatch.stop();

      final result = QueuedResult(
        id: item.id,
        status: QueueItemStatus.failed,
        error: e.toString(),
        processingTime: stopwatch.elapsed,
      );

      _status[item.id] = QueueItemStatus.failed;
      _results[item.id] = result;
      onItemFailed?.call(result);
    } finally {
      _activeCount--;
      _processNext();
    }
  }
}
