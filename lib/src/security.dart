/// Security utilities for model verification and cleanup.
///
/// Provides on-device model verification and secure file handling.
library;

import 'dart:io';
import 'dart:typed_data';

/// Model verification result.
class ModelVerificationResult {
  const ModelVerificationResult({
    required this.isValid,
    this.fileSize,
    this.magicBytes,
    this.error,
  });

  /// Whether the model passed verification.
  final bool isValid;

  /// File size in bytes.
  final int? fileSize;

  /// First few bytes of the file (magic bytes).
  final String? magicBytes;

  /// Error message if verification failed.
  final String? error;

  factory ModelVerificationResult.valid({int? fileSize, String? magicBytes}) =>
      ModelVerificationResult(
        isValid: true,
        fileSize: fileSize,
        magicBytes: magicBytes,
      );

  factory ModelVerificationResult.invalid(String error) =>
      ModelVerificationResult(isValid: false, error: error);
}

/// Model security utilities.
class ModelSecurity {
  const ModelSecurity._();

  /// Verify model integrity using file size and magic bytes.
  static Future<ModelVerificationResult> verifyModel(
    String modelPath, {
    int? expectedSize,
  }) async {
    final file = File(modelPath);

    if (!file.existsSync()) {
      return ModelVerificationResult.invalid('Model file not found');
    }

    try {
      final size = await file.length();

      // Models should be at least 1MB
      if (size < 1024 * 1024) {
        return ModelVerificationResult.invalid(
          'Model file too small: ${size / 1024}KB',
        );
      }

      // Check expected size if provided
      if (expectedSize != null && size != expectedSize) {
        return ModelVerificationResult.invalid(
          'Size mismatch: expected $expectedSize, got $size',
        );
      }

      // Read magic bytes to verify format
      final bytes = await file.openRead(0, 4).first;
      final magic =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // Check for GGML or GGUF format
      final isValidFormat = _isValidModelFormat(bytes);
      if (!isValidFormat) {
        return ModelVerificationResult.invalid(
          'Invalid model format (magic: $magic)',
        );
      }

      return ModelVerificationResult.valid(
        fileSize: size,
        magicBytes: magic,
      );
    } catch (e) {
      return ModelVerificationResult.invalid('Verification failed: $e');
    }
  }

  static bool _isValidModelFormat(List<int> bytes) {
    if (bytes.length < 4) return false;

    // GGML: 0x67 0x67 0x6D 0x6C
    if (bytes[0] == 0x67 &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x6D &&
        bytes[3] == 0x6C) {
      return true;
    }

    // GGUF: 0x47 0x47 0x55 0x46
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x47 &&
        bytes[2] == 0x55 &&
        bytes[3] == 0x46) {
      return true;
    }

    return false;
  }

  /// Get model file size for comparison.
  static Future<int?> getModelSize(String modelPath) async {
    final file = File(modelPath);
    if (!file.existsSync()) return null;
    return file.length();
  }
}

/// Temporary file cleanup utilities.
class SecureCleanup {
  const SecureCleanup._();

  /// Securely delete a file by overwriting with zeros.
  static Future<void> secureDelete(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    try {
      // Overwrite with zeros
      final length = await file.length();
      final zeros = Uint8List(4096);

      final raf = await file.open(mode: FileMode.write);
      var written = 0;
      while (written < length) {
        final toWrite = (length - written) > 4096 ? 4096 : (length - written);
        await raf.writeFrom(zeros, 0, toWrite);
        written += toWrite;
      }
      await raf.close();

      // Delete the file
      await file.delete();
    } catch (e) {
      // Fallback to normal delete
      await file.delete();
    }
  }

  /// Clean up temporary audio files in a directory.
  static Future<int> cleanupTempAudio(String directory) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return 0;

    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.toLowerCase();
        if (name.endsWith('.wav') ||
            name.endsWith('.tmp') ||
            name.contains('temp') ||
            name.contains('whisper_')) {
          await entity.delete();
          count++;
        }
      }
    }
    return count;
  }

  /// Clean up partial model downloads.
  static Future<int> cleanupPartialDownloads(String modelDir) async {
    final dir = Directory(modelDir);
    if (!dir.existsSync()) return 0;

    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.toLowerCase();
        if (name.endsWith('.part') ||
            name.endsWith('.download') ||
            name.endsWith('.tmp')) {
          await entity.delete();
          count++;
        }
      }
    }
    return count;
  }
}

/// Privacy-focused processing options.
class PrivacyOptions {
  const PrivacyOptions({
    this.deleteAfterProcessing = false,
    this.disableLogging = false,
    this.secureDelete = false,
    this.noCache = false,
  });

  /// Delete audio file after processing.
  final bool deleteAfterProcessing;

  /// Disable debug logging.
  final bool disableLogging;

  /// Use secure deletion for temp files.
  final bool secureDelete;

  /// Disable caching of results.
  final bool noCache;

  /// Strict privacy mode (all options enabled).
  static const strict = PrivacyOptions(
    deleteAfterProcessing: true,
    disableLogging: true,
    secureDelete: true,
    noCache: true,
  );
}
