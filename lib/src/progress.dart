/// Progress reporting callbacks for long-running operations.
///
/// Provides unified progress reporting for model downloads, transcription,
/// and audio processing operations.
library;

/// Represents the current progress of an operation.
class ProgressInfo {
  /// Creates a progress info instance.
  const ProgressInfo({
    required this.operation,
    required this.progress,
    this.currentStep,
    this.totalSteps,
    this.message,
    this.bytesProcessed,
    this.totalBytes,
  });

  /// The type of operation being performed.
  final ProgressOperation operation;

  /// Progress as a value between 0.0 and 1.0.
  final double progress;

  /// Current step number (optional, for multi-step operations).
  final int? currentStep;

  /// Total number of steps (optional, for multi-step operations).
  final int? totalSteps;

  /// Human-readable message describing current progress.
  final String? message;

  /// Bytes processed so far (for download/file operations).
  final int? bytesProcessed;

  /// Total bytes to process (for download/file operations).
  final int? totalBytes;

  /// Progress as a percentage (0-100).
  int get percentComplete => (progress * 100).round();

  /// Whether the operation is complete.
  bool get isComplete => progress >= 1.0;

  /// Creates a progress info for model download.
  factory ProgressInfo.download({
    required int bytesReceived,
    required int totalBytes,
    String? modelName,
  }) {
    final progress = totalBytes > 0 ? bytesReceived / totalBytes : 0.0;
    return ProgressInfo(
      operation: ProgressOperation.modelDownload,
      progress: progress,
      bytesProcessed: bytesReceived,
      totalBytes: totalBytes,
      message: modelName != null
          ? 'Downloading model: $modelName (${(bytesReceived / 1024 / 1024).toStringAsFixed(1)} MB)'
          : 'Downloading (${(bytesReceived / 1024 / 1024).toStringAsFixed(1)} MB)',
    );
  }

  /// Creates a progress info for transcription.
  factory ProgressInfo.transcription({
    required double progress,
    int? currentSegment,
    int? totalSegments,
  }) {
    return ProgressInfo(
      operation: ProgressOperation.transcription,
      progress: progress,
      currentStep: currentSegment,
      totalSteps: totalSegments,
      message: totalSegments != null && currentSegment != null
          ? 'Transcribing segment $currentSegment of $totalSegments'
          : 'Transcribing... ${(progress * 100).round()}%',
    );
  }

  /// Creates a progress info for audio processing.
  factory ProgressInfo.audioProcessing({
    required double progress,
    String? stage,
  }) {
    return ProgressInfo(
      operation: ProgressOperation.audioProcessing,
      progress: progress,
      message: stage ?? 'Processing audio... ${(progress * 100).round()}%',
    );
  }

  /// Creates a progress info for model loading.
  factory ProgressInfo.modelLoading({
    required double progress,
    String? modelName,
  }) {
    return ProgressInfo(
      operation: ProgressOperation.modelLoading,
      progress: progress,
      message:
          modelName != null ? 'Loading model: $modelName' : 'Loading model...',
    );
  }

  @override
  String toString() =>
      'ProgressInfo($operation: $percentComplete%${message != null ? ' - $message' : ''})';
}

/// Types of operations that can report progress.
enum ProgressOperation {
  /// Downloading a model file.
  modelDownload,

  /// Loading a model into memory.
  modelLoading,

  /// Transcribing audio to text.
  transcription,

  /// Processing/converting audio.
  audioProcessing,

  /// Recording audio.
  recording,
}

/// Callback type for progress updates.
typedef ProgressCallback = void Function(ProgressInfo progress);

/// Callback type for simple progress updates (received, total bytes).
typedef SimpleProgressCallback = void Function(int received, int total);

/// Extension to convert between callback types.
extension ProgressCallbackExtension on SimpleProgressCallback {
  /// Wraps this simple callback to work with [ProgressInfo].
  ProgressCallback toProgressCallback(ProgressOperation operation) {
    return (ProgressInfo info) {
      if (info.bytesProcessed != null && info.totalBytes != null) {
        this(info.bytesProcessed!, info.totalBytes!);
      }
    };
  }
}

/// Extension to convert ProgressCallback to SimpleProgressCallback for downloads.
extension ProgressInfoCallbackExtension on ProgressCallback {
  /// Creates a simple callback for download progress.
  SimpleProgressCallback toSimpleDownloadCallback([String? modelName]) {
    return (int received, int total) {
      this(ProgressInfo.download(
        bytesReceived: received,
        totalBytes: total,
        modelName: modelName,
      ));
    };
  }
}
