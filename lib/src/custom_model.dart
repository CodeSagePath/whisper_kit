/// Custom model loading support.
///
/// Allows loading user-provided or fine-tuned Whisper models.
library;

import 'dart:io';

import 'package:whisper_kit/src/exceptions.dart';

/// Custom model configuration.
class CustomModel {
  /// Create a custom model configuration.
  const CustomModel({
    required this.path,
    this.name,
    this.validateOnLoad = true,
  });

  /// Absolute path to the model file.
  final String path;

  /// Custom name for the model.
  final String? name;

  /// Whether to validate the model before loading.
  final bool validateOnLoad;

  /// Get the model name (from path if not provided).
  String get modelName => name ?? path.split('/').last.replaceAll('.bin', '');

  /// Check if the model file exists.
  bool get exists => File(path).existsSync();

  /// Get the model file size in bytes.
  int get sizeBytes {
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : 0;
  }

  /// Get the model file size in MB.
  double get sizeMB => sizeBytes / 1024 / 1024;
}

/// Model validation result.
class ModelValidationResult {
  const ModelValidationResult({
    required this.isValid,
    this.error,
    this.modelType,
    this.fileSize,
  });

  /// Whether the model is valid.
  final bool isValid;

  /// Error message if invalid.
  final String? error;

  /// Detected model type (e.g., "tiny", "base").
  final String? modelType;

  /// Model file size in bytes.
  final int? fileSize;

  factory ModelValidationResult.valid({String? modelType, int? fileSize}) =>
      ModelValidationResult(
        isValid: true,
        modelType: modelType,
        fileSize: fileSize,
      );

  factory ModelValidationResult.invalid(String error) =>
      ModelValidationResult(isValid: false, error: error);
}

/// Model loader for custom models.
class ModelLoader {
  const ModelLoader._();

  /// Whisper model file magic bytes (GGML format).
  static const List<int> _ggmlMagic = [0x67, 0x67, 0x6D, 0x6C]; // "ggml"
  static const List<int> _ggufMagic = [0x47, 0x47, 0x55, 0x46]; // "GGUF"

  /// Validate a model file.
  static Future<ModelValidationResult> validate(String path) async {
    final file = File(path);

    // Check file exists
    if (!file.existsSync()) {
      return ModelValidationResult.invalid('Model file not found: $path');
    }

    // Check file size
    final size = file.lengthSync();
    if (size < 1024 * 1024) {
      return ModelValidationResult.invalid(
        'Model file too small (${size / 1024}KB). Expected at least 1MB.',
      );
    }

    // Check magic bytes
    try {
      final bytes = await file.openRead(0, 4).first;
      final isGgml = _matchesMagic(bytes, _ggmlMagic);
      final isGguf = _matchesMagic(bytes, _ggufMagic);

      if (!isGgml && !isGguf) {
        return ModelValidationResult.invalid(
          'Invalid model format. Expected GGML or GGUF format.',
        );
      }

      // Detect model type from file size
      final modelType = _detectModelType(size);

      return ModelValidationResult.valid(
        modelType: modelType,
        fileSize: size,
      );
    } catch (e) {
      return ModelValidationResult.invalid('Failed to read model file: $e');
    }
  }

  static bool _matchesMagic(List<int> bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  /// Detect model type from file size.
  static String _detectModelType(int sizeBytes) {
    final sizeMB = sizeBytes / 1024 / 1024;

    if (sizeMB < 100) return 'tiny';
    if (sizeMB < 200) return 'base';
    if (sizeMB < 500) return 'small';
    if (sizeMB < 1600) return 'medium';
    return 'large';
  }

  /// Load and validate a custom model.
  ///
  /// Throws [ModelException] if validation fails.
  static Future<CustomModel> load(String path, {bool validate = true}) async {
    final model = CustomModel(path: path, validateOnLoad: validate);

    if (!model.exists) {
      throw ModelException.notFound(path);
    }

    if (validate) {
      final result = await ModelLoader.validate(path);
      if (!result.isValid) {
        throw ModelException.validationFailed(path);
      }
    }

    return model;
  }
}
