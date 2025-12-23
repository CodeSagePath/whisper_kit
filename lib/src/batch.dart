/// Batch transcription for processing multiple audio files.
library;

import 'dart:async';
import 'package:whisper_kit/whisper_kit.dart';

/// Result of a single batch item transcription.
class BatchTranscriptionResult {
  const BatchTranscriptionResult({
    required this.audioPath,
    required this.success,
    this.response,
    this.error,
  });

  /// Path to the audio file.
  final String audioPath;

  /// Whether transcription succeeded.
  final bool success;

  /// Transcription result if successful.
  final WhisperTranscribeResponse? response;

  /// Error message if failed.
  final String? error;
}

/// Batch transcription progress information.
class BatchProgress {
  const BatchProgress({
    required this.completed,
    required this.total,
    required this.currentFile,
    this.currentProgress,
  });

  /// Number of completed transcriptions.
  final int completed;

  /// Total number of audio files.
  final int total;

  /// Current file being processed.
  final String currentFile;

  /// Progress of current file (0.0 - 1.0).
  final double? currentProgress;

  /// Overall progress (0.0 - 1.0).
  double get overallProgress => total > 0 ? completed / total : 0;
}

/// Batch transcription options.
class BatchOptions {
  const BatchOptions({
    this.parallel = false,
    this.maxConcurrent = 2,
    this.stopOnError = false,
    this.retryCount = 0,
  });

  /// Whether to process files in parallel.
  final bool parallel;

  /// Maximum concurrent transcriptions (if parallel).
  final int maxConcurrent;

  /// Stop processing if an error occurs.
  final bool stopOnError;

  /// Number of retries for failed transcriptions.
  final int retryCount;
}

/// Batch transcription processor.
class BatchTranscriber {
  BatchTranscriber(this._whisper);

  final Whisper _whisper;

  /// Transcribe multiple audio files.
  ///
  /// [audioPaths] - List of audio file paths to transcribe.
  /// [options] - Batch processing options.
  /// [onProgress] - Callback for progress updates.
  /// [cancellationToken] - Token to cancel batch processing.
  ///
  /// Returns a list of results for each audio file.
  Future<List<BatchTranscriptionResult>> transcribeBatch({
    required List<String> audioPaths,
    TranscribeRequest? baseRequest,
    BatchOptions options = const BatchOptions(),
    void Function(BatchProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (audioPaths.isEmpty) return [];

    final results = <BatchTranscriptionResult>[];

    if (options.parallel) {
      results.addAll(await _processParallel(
        audioPaths: audioPaths,
        baseRequest: baseRequest,
        options: options,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      ));
    } else {
      results.addAll(await _processSequential(
        audioPaths: audioPaths,
        baseRequest: baseRequest,
        options: options,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      ));
    }

    return results;
  }

  Future<List<BatchTranscriptionResult>> _processSequential({
    required List<String> audioPaths,
    TranscribeRequest? baseRequest,
    required BatchOptions options,
    void Function(BatchProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final results = <BatchTranscriptionResult>[];

    for (var i = 0; i < audioPaths.length; i++) {
      // Check cancellation
      if (cancellationToken?.isCancelled ?? false) break;

      final audioPath = audioPaths[i];

      // Report progress
      onProgress?.call(BatchProgress(
        completed: i,
        total: audioPaths.length,
        currentFile: audioPath,
      ));

      final result = await _transcribeWithRetry(
        audioPath: audioPath,
        baseRequest: baseRequest,
        retryCount: options.retryCount,
      );

      results.add(result);

      if (!result.success && options.stopOnError) break;
    }

    // Final progress
    onProgress?.call(BatchProgress(
      completed: results.length,
      total: audioPaths.length,
      currentFile: '',
    ));

    return results;
  }

  Future<List<BatchTranscriptionResult>> _processParallel({
    required List<String> audioPaths,
    TranscribeRequest? baseRequest,
    required BatchOptions options,
    void Function(BatchProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final results = <BatchTranscriptionResult>[];
    var completed = 0;

    // Process in batches of maxConcurrent
    for (var i = 0; i < audioPaths.length; i += options.maxConcurrent) {
      if (cancellationToken?.isCancelled ?? false) break;

      final batch = audioPaths.skip(i).take(options.maxConcurrent);

      final batchResults = await Future.wait(
        batch.map((path) async {
          onProgress?.call(BatchProgress(
            completed: completed,
            total: audioPaths.length,
            currentFile: path,
          ));

          final result = await _transcribeWithRetry(
            audioPath: path,
            baseRequest: baseRequest,
            retryCount: options.retryCount,
          );

          completed++;
          return result;
        }),
      );

      results.addAll(batchResults);

      if (options.stopOnError && batchResults.any((r) => !r.success)) break;
    }

    return results;
  }

  Future<BatchTranscriptionResult> _transcribeWithRetry({
    required String audioPath,
    TranscribeRequest? baseRequest,
    required int retryCount,
  }) async {
    var attempts = 0;

    while (true) {
      try {
        final request = TranscribeRequest(
          audio: audioPath,
          isTranslate: baseRequest?.isTranslate ?? false,
          threads: baseRequest?.threads ?? 6,
          isVerbose: baseRequest?.isVerbose ?? false,
          language: baseRequest?.language ?? 'auto',
          isNoTimestamps: baseRequest?.isNoTimestamps ?? false,
        );

        final response = await _whisper.transcribe(transcribeRequest: request);
        return BatchTranscriptionResult(
          audioPath: audioPath,
          success: true,
          response: response,
        );
      } catch (e) {
        attempts++;
        if (attempts > retryCount) {
          return BatchTranscriptionResult(
            audioPath: audioPath,
            success: false,
            error: e.toString(),
          );
        }
        // Wait briefly before retry
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }
}

/// Extension on Whisper for batch transcription.
extension BatchTranscriptionExtension on Whisper {
  /// Create a batch transcriber for this Whisper instance.
  BatchTranscriber get batch => BatchTranscriber(this);
}
