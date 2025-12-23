/// Secure model loading utilities.
///
/// Ensure models are loaded securely with validation.
library;

import 'dart:io';

import 'package:whisper_kit/src/security.dart';

/// Secure loading options.
class SecureLoadingOptions {
  const SecureLoadingOptions({
    this.verifyBeforeLoad = true,
    this.allowUntrusted = false,
    this.expectedSize,
    this.trustedSources,
    this.quarantineInvalid = true,
  });

  /// Verify model integrity before loading.
  final bool verifyBeforeLoad;

  /// Allow loading untrusted models.
  final bool allowUntrusted;

  /// Expected file size in bytes.
  final int? expectedSize;

  /// List of trusted download sources.
  final List<String>? trustedSources;

  /// Move invalid models to quarantine.
  final bool quarantineInvalid;
}

/// Secure loading result.
class SecureLoadResult {
  const SecureLoadResult({
    required this.success,
    this.modelPath,
    this.error,
    this.verification,
  });

  /// Whether loading was successful.
  final bool success;

  /// Path to loaded model.
  final String? modelPath;

  /// Error message if failed.
  final String? error;

  /// Verification result.
  final ModelVerificationResult? verification;

  factory SecureLoadResult.success(
          String path, ModelVerificationResult verification) =>
      SecureLoadResult(
        success: true,
        modelPath: path,
        verification: verification,
      );

  factory SecureLoadResult.failure(String error) =>
      SecureLoadResult(success: false, error: error);
}

/// Trusted model source.
class TrustedSource {
  const TrustedSource({
    required this.name,
    required this.urlPattern,
    this.isDefault = false,
  });

  /// Source name.
  final String name;

  /// URL pattern (regex).
  final String urlPattern;

  /// Whether this is a default trusted source.
  final bool isDefault;

  /// Check if URL matches this source.
  bool matches(String url) {
    return RegExp(urlPattern).hasMatch(url);
  }
}

/// Pre-defined trusted sources.
class TrustedSources {
  const TrustedSources._();

  /// Hugging Face model hub.
  static const huggingFace = TrustedSource(
    name: 'Hugging Face',
    urlPattern: r'^https://huggingface\.co/',
    isDefault: true,
  );

  /// GGML models repository.
  static const ggmlModels = TrustedSource(
    name: 'GGML Models',
    urlPattern: r'^https://ggml\.ai/',
    isDefault: true,
  );

  /// GitHub releases.
  static const github = TrustedSource(
    name: 'GitHub',
    urlPattern: r'^https://github\.com/.*releases/',
    isDefault: true,
  );

  /// All default trusted sources.
  static const defaultSources = [huggingFace, ggmlModels, github];
}

/// Secure model loader.
class SecureModelLoader {
  SecureModelLoader({
    this.options = const SecureLoadingOptions(),
    this.quarantineDir,
  });

  /// Loading options.
  final SecureLoadingOptions options;

  /// Directory for quarantined models.
  final String? quarantineDir;

  /// Securely load a model.
  Future<SecureLoadResult> loadModel(String modelPath) async {
    final file = File(modelPath);

    // Check file exists
    if (!file.existsSync()) {
      return SecureLoadResult.failure('Model file not found: $modelPath');
    }

    // Verify if required
    if (options.verifyBeforeLoad) {
      final verification = await ModelSecurity.verifyModel(
        modelPath,
        expectedSize: options.expectedSize,
      );

      if (!verification.isValid) {
        if (options.quarantineInvalid && quarantineDir != null) {
          await _quarantine(file);
        }
        return SecureLoadResult.failure(
          verification.error ?? 'Model verification failed',
        );
      }

      return SecureLoadResult.success(modelPath, verification);
    }

    // Load without verification
    return SecureLoadResult.success(
      modelPath,
      ModelVerificationResult.valid(),
    );
  }

  /// Check if a download URL is trusted.
  bool isUrlTrusted(String url) {
    final sources = options.trustedSources ??
        TrustedSources.defaultSources.map((s) => s.urlPattern).toList();

    for (final pattern in sources) {
      if (RegExp(pattern).hasMatch(url)) {
        return true;
      }
    }
    return false;
  }

  /// Validate model before download.
  Future<bool> validateBeforeDownload(String url) async {
    if (!options.allowUntrusted && !isUrlTrusted(url)) {
      return false;
    }
    return true;
  }

  Future<void> _quarantine(File file) async {
    final dir = Directory(quarantineDir!);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final quarantinePath = '$quarantineDir/${file.path.split('/').last}';
    await file.rename(quarantinePath);
  }
}
