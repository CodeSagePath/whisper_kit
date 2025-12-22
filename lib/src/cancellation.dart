/// Cancellation token support for long-running operations.
///
/// Allows cancelling transcription, model downloads, and audio processing.
library;

import 'dart:async';

/// A token that can be used to cancel long-running operations.
///
/// Example usage:
/// ```dart
/// final token = CancellationToken();
///
/// // Start operation with token
/// final future = whisper.transcribe(
///   transcribeRequest: request,
///   cancellationToken: token,
/// );
///
/// // Cancel after 5 seconds
/// Timer(Duration(seconds: 5), () => token.cancel());
///
/// try {
///   final result = await future;
/// } on OperationCancelledException catch (e) {
///   print('Operation was cancelled: ${e.message}');
/// }
/// ```
class CancellationToken {
  bool _isCancelled = false;
  final Completer<void> _completer = Completer<void>();
  String? _reason;

  /// Whether this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// The reason for cancellation, if provided.
  String? get reason => _reason;

  /// A future that completes when the token is cancelled.
  ///
  /// Useful for racing against the main operation.
  Future<void> get whenCancelled => _completer.future;

  /// Cancels the associated operation.
  ///
  /// [reason] - Optional reason for cancellation.
  void cancel([String? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Throws [OperationCancelledException] if the token is cancelled.
  ///
  /// Call this at checkpoint locations in long-running operations.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw OperationCancelledException(reason);
    }
  }

  /// Resets the token to non-cancelled state for reuse.
  ///
  /// Note: This creates a new completer, so previous `whenCancelled`
  /// futures will not complete.
  void reset() {
    _isCancelled = false;
    _reason = null;
  }
}

/// Exception thrown when an operation is cancelled.
class OperationCancelledException implements Exception {
  /// Creates an operation cancelled exception.
  const OperationCancelledException([this.message]);

  /// The reason for cancellation.
  final String? message;

  @override
  String toString() =>
      'OperationCancelledException: ${message ?? 'Operation was cancelled'}';
}

/// A cancellation token source that manages a cancellation token.
///
/// Provides additional control over token lifecycle.
class CancellationTokenSource {
  /// Creates a new cancellation token source with a fresh token.
  CancellationTokenSource() : _token = CancellationToken();

  final CancellationToken _token;

  /// The cancellation token managed by this source.
  CancellationToken get token => _token;

  /// Whether the token has been cancelled.
  bool get isCancelled => _token.isCancelled;

  /// Cancels the token.
  void cancel([String? reason]) => _token.cancel(reason);

  /// Creates a linked cancellation token source.
  ///
  /// The returned source's token will be cancelled when any of the
  /// provided tokens are cancelled.
  static CancellationTokenSource linked(List<CancellationToken> tokens) {
    final source = CancellationTokenSource();

    for (final token in tokens) {
      if (token.isCancelled) {
        source.cancel(token.reason);
        break;
      }

      token.whenCancelled.then((_) {
        if (!source.isCancelled) {
          source.cancel(token.reason);
        }
      });
    }

    return source;
  }

  /// Creates a cancellation token that auto-cancels after a timeout.
  static CancellationTokenSource withTimeout(Duration timeout) {
    final source = CancellationTokenSource();
    Timer(timeout, () {
      if (!source.isCancelled) {
        source.cancel('Operation timed out after ${timeout.inSeconds} seconds');
      }
    });
    return source;
  }
}

/// Extension methods for using cancellation tokens with Futures.
extension CancellationTokenFutureExtension<T> on Future<T> {
  /// Wraps this future to support cancellation.
  ///
  /// Returns a future that completes with the result of this future,
  /// or throws [OperationCancelledException] if the token is cancelled first.
  Future<T> withCancellation(CancellationToken token) {
    if (token.isCancelled) {
      return Future.error(OperationCancelledException(token.reason));
    }

    final completer = Completer<T>();

    // Race between the main operation and cancellation
    token.whenCancelled.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(OperationCancelledException(token.reason));
      }
    });

    then((value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }
}
