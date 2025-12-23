/// Translation utilities and improvements.
///
/// Enhanced translation support for Whisper's translate-to-English feature.
library;

import 'package:whisper_kit/bean/request_bean.dart';

/// Translation configuration options.
class TranslationConfig {
  const TranslationConfig({
    this.sourceLanguage,
    this.preserveFormatting = true,
    this.postProcessing = true,
    this.detectLanguage = true,
  });

  /// Source language code (null for auto-detect).
  final String? sourceLanguage;

  /// Whether to preserve original text formatting.
  final bool preserveFormatting;

  /// Whether to apply post-processing improvements.
  final bool postProcessing;

  /// Whether to detect source language.
  final bool detectLanguage;
}

/// Translation result with metadata.
class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    this.sourceLanguage,
    this.confidence,
  });

  /// Original text before translation.
  final String originalText;

  /// Translated text (to English).
  final String translatedText;

  /// Detected or specified source language.
  final String? sourceLanguage;

  /// Confidence score (0.0 - 1.0).
  final double? confidence;
}

/// Translation post-processor for improving output quality.
class TranslationPostProcessor {
  const TranslationPostProcessor._();

  /// Apply post-processing to translated text.
  static String process(String text) {
    var result = text;

    // Fix common punctuation issues
    result = _fixPunctuation(result);

    // Fix common capitalization issues
    result = _fixCapitalization(result);

    // Remove excessive whitespace
    result = _normalizeWhitespace(result);

    return result;
  }

  /// Fix punctuation issues.
  static String _fixPunctuation(String text) {
    var result = text;

    // Fix multiple punctuation
    result = result.replaceAll(RegExp(r'\.{2,}'), '...');
    result = result.replaceAll(RegExp(r'\?{2,}'), '?');
    result = result.replaceAll(RegExp(r'!{2,}'), '!');

    // Fix space before punctuation
    result = result.replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');

    // Add space after punctuation if missing
    result = result.replaceAll(RegExp(r'([.,!?;:])([A-Za-z])'), r'$1 $2');

    return result;
  }

  /// Fix capitalization issues.
  static String _fixCapitalization(String text) {
    if (text.isEmpty) return text;

    // Capitalize first letter
    var result = text[0].toUpperCase() + text.substring(1);

    // Capitalize after sentence-ending punctuation
    result = result.replaceAllMapped(
      RegExp(r'([.!?]\s+)([a-z])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );

    return result;
  }

  /// Normalize whitespace.
  static String _normalizeWhitespace(String text) {
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

/// Helper extension for creating translation requests.
extension TranslationRequestExtension on TranscribeRequest {
  /// Create a translation request (translate to English).
  TranscribeRequest asTranslation({String? sourceLanguage}) {
    return TranscribeRequest(
      audio: audio,
      isTranslate: true,
      language: sourceLanguage ?? language,
      threads: threads,
      isVerbose: isVerbose,
      isNoTimestamps: isNoTimestamps,
      nProcessors: nProcessors,
      splitOnWord: splitOnWord,
      speedUp: speedUp,
    );
  }
}
