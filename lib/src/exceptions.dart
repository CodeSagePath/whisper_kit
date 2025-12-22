/// Whisper Kit exception classes for better error handling.
///
/// All Whisper Kit exceptions extend [WhisperKitException] for easy catching.
library;

/// Base exception for all Whisper Kit errors.
///
/// Catch this to handle all Whisper Kit exceptions:
/// ```dart
/// try {
///   await whisper.transcribe(request: request);
/// } on WhisperKitException catch (e) {
///   print('Whisper Kit error: ${e.message}');
/// }
/// ```
class WhisperKitException implements Exception {
  /// Creates a Whisper Kit exception.
  const WhisperKitException(this.message, {this.code, this.details});

  /// Human-readable error message.
  final String message;

  /// Optional error code for programmatic handling.
  final String? code;

  /// Optional additional details about the error.
  final dynamic details;

  @override
  String toString() =>
      'WhisperKitException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when model operations fail.
///
/// This includes:
/// - Model download failures
/// - Model loading failures
/// - Model validation failures
/// - Model not found errors
class ModelException extends WhisperKitException {
  /// Creates a model exception.
  const ModelException(super.message,
      {super.code, super.details, this.modelName});

  /// The name of the model that caused the error, if available.
  final String? modelName;

  /// Model file was not found.
  factory ModelException.notFound(String modelName) => ModelException(
        'Model "$modelName" not found. Please download it first.',
        code: 'MODEL_NOT_FOUND',
        modelName: modelName,
      );

  /// Model download failed.
  factory ModelException.downloadFailed(String modelName, [String? reason]) =>
      ModelException(
        'Failed to download model "$modelName"${reason != null ? ': $reason' : ''}',
        code: 'MODEL_DOWNLOAD_FAILED',
        modelName: modelName,
        details: reason,
      );

  /// Model validation failed (corrupted or invalid).
  factory ModelException.validationFailed(String modelName) => ModelException(
        'Model "$modelName" validation failed. The model may be corrupted.',
        code: 'MODEL_VALIDATION_FAILED',
        modelName: modelName,
      );

  /// Model loading failed.
  factory ModelException.loadFailed(String modelName, [String? reason]) =>
      ModelException(
        'Failed to load model "$modelName"${reason != null ? ': $reason' : ''}',
        code: 'MODEL_LOAD_FAILED',
        modelName: modelName,
        details: reason,
      );

  @override
  String toString() =>
      'ModelException: $message${modelName != null ? ' [model: $modelName]' : ''}${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when audio operations fail.
///
/// This includes:
/// - Audio file not found
/// - Unsupported audio format
/// - Audio processing failures
/// - Recording failures
class AudioException extends WhisperKitException {
  /// Creates an audio exception.
  const AudioException(super.message,
      {super.code, super.details, this.audioPath});

  /// The path to the audio file that caused the error, if available.
  final String? audioPath;

  /// Audio file was not found.
  factory AudioException.fileNotFound(String path) => AudioException(
        'Audio file not found: $path',
        code: 'AUDIO_FILE_NOT_FOUND',
        audioPath: path,
      );

  /// Audio format is not supported.
  factory AudioException.unsupportedFormat(String format) => AudioException(
        'Unsupported audio format: $format. Supported formats: WAV (16kHz, mono, 16-bit PCM)',
        code: 'AUDIO_UNSUPPORTED_FORMAT',
        details: format,
      );

  /// Audio format is invalid (wrong sample rate, channels, etc).
  factory AudioException.invalidFormat(String reason) => AudioException(
        'Invalid audio format: $reason',
        code: 'AUDIO_INVALID_FORMAT',
        details: reason,
      );

  /// Audio processing failed.
  factory AudioException.processingFailed([String? reason]) => AudioException(
        'Audio processing failed${reason != null ? ': $reason' : ''}',
        code: 'AUDIO_PROCESSING_FAILED',
        details: reason,
      );

  /// Audio recording failed.
  factory AudioException.recordingFailed([String? reason]) => AudioException(
        'Audio recording failed${reason != null ? ': $reason' : ''}',
        code: 'AUDIO_RECORDING_FAILED',
        details: reason,
      );

  @override
  String toString() =>
      'AudioException: $message${audioPath != null ? ' [path: $audioPath]' : ''}${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when transcription fails.
///
/// This includes:
/// - Transcription processing errors
/// - Language detection failures
/// - Invalid transcription parameters
class TranscriptionException extends WhisperKitException {
  /// Creates a transcription exception.
  const TranscriptionException(super.message, {super.code, super.details});

  /// Transcription processing failed.
  factory TranscriptionException.processingFailed([String? reason]) =>
      TranscriptionException(
        'Transcription failed${reason != null ? ': $reason' : ''}',
        code: 'TRANSCRIPTION_FAILED',
        details: reason,
      );

  /// Language not supported.
  factory TranscriptionException.unsupportedLanguage(String language) =>
      TranscriptionException(
        'Language "$language" is not supported',
        code: 'TRANSCRIPTION_UNSUPPORTED_LANGUAGE',
        details: language,
      );

  /// Invalid parameters provided.
  factory TranscriptionException.invalidParameters(String reason) =>
      TranscriptionException(
        'Invalid transcription parameters: $reason',
        code: 'TRANSCRIPTION_INVALID_PARAMS',
        details: reason,
      );

  @override
  String toString() =>
      'TranscriptionException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when permissions are denied or unavailable.
///
/// This includes:
/// - Microphone permission denied
/// - Storage permission denied
class PermissionException extends WhisperKitException {
  /// Creates a permission exception.
  const PermissionException(super.message,
      {super.code, super.details, this.permissionType});

  /// The type of permission that was denied.
  final String? permissionType;

  /// Microphone permission denied.
  factory PermissionException.microphoneDenied() => const PermissionException(
        'Microphone permission denied. Please grant microphone access in settings.',
        code: 'PERMISSION_MICROPHONE_DENIED',
        permissionType: 'microphone',
      );

  /// Storage permission denied.
  factory PermissionException.storageDenied() => const PermissionException(
        'Storage permission denied. Please grant storage access in settings.',
        code: 'PERMISSION_STORAGE_DENIED',
        permissionType: 'storage',
      );

  @override
  String toString() =>
      'PermissionException: $message${permissionType != null ? ' [type: $permissionType]' : ''}${code != null ? ' (code: $code)' : ''}';
}
