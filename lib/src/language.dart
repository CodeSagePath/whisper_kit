/// Language identification utilities.
///
/// Detect the language of audio with confidence scores.
library;

/// Language detection result.
class LanguageDetectionResult {
  const LanguageDetectionResult({
    required this.languageCode,
    required this.confidence,
    this.alternativeLanguages,
  });

  /// ISO 639-1 language code (e.g., "en", "es", "fr").
  final String languageCode;

  /// Confidence score (0.0 - 1.0).
  final double confidence;

  /// Alternative languages with lower confidence.
  final List<LanguageDetectionResult>? alternativeLanguages;

  /// Confidence as percentage (0-100).
  int get confidencePercent => (confidence * 100).round();

  /// Get human-readable language name.
  String get languageName => _languageNames[languageCode] ?? languageCode;

  /// Whether confidence is high (>0.8).
  bool get isHighConfidence => confidence > 0.8;

  /// Whether confidence is medium (0.5-0.8).
  bool get isMediumConfidence => confidence >= 0.5 && confidence <= 0.8;

  /// Whether confidence is low (<0.5).
  bool get isLowConfidence => confidence < 0.5;

  @override
  String toString() =>
      'LanguageDetectionResult($languageCode: $confidencePercent%)';
}

/// Supported languages in Whisper.
class WhisperLanguages {
  const WhisperLanguages._();

  /// All languages supported by Whisper.
  static const List<String> all = [
    'en',
    'zh',
    'de',
    'es',
    'ru',
    'ko',
    'fr',
    'ja',
    'pt',
    'tr',
    'pl',
    'ca',
    'nl',
    'ar',
    'sv',
    'it',
    'id',
    'hi',
    'fi',
    'vi',
    'he',
    'uk',
    'el',
    'ms',
    'cs',
    'ro',
    'da',
    'hu',
    'ta',
    'no',
    'th',
    'ur',
    'hr',
    'bg',
    'lt',
    'la',
    'mi',
    'ml',
    'cy',
    'sk',
    'te',
    'fa',
    'lv',
    'bn',
    'sr',
    'az',
    'sl',
    'kn',
    'et',
    'mk',
    'br',
    'eu',
    'is',
    'hy',
    'ne',
    'mn',
    'bs',
    'kk',
    'sq',
    'sw',
    'gl',
    'mr',
    'pa',
    'si',
    'km',
    'sn',
    'yo',
    'so',
    'af',
    'oc',
    'ka',
    'be',
    'tg',
    'sd',
    'gu',
    'am',
    'yi',
    'lo',
    'uz',
    'fo',
    'ht',
    'ps',
    'tk',
    'nn',
    'mt',
    'sa',
    'lb',
    'my',
    'bo',
    'tl',
    'mg',
    'as',
    'tt',
    'haw',
    'ln',
    'ha',
    'ba',
    'jw',
    'su',
  ];

  /// Check if a language code is supported.
  static bool isSupported(String languageCode) =>
      all.contains(languageCode.toLowerCase());

  /// Get language name from code.
  static String getName(String languageCode) =>
      _languageNames[languageCode.toLowerCase()] ?? languageCode;
}

/// Language code to name mappings.
const Map<String, String> _languageNames = {
  'en': 'English',
  'zh': 'Chinese',
  'de': 'German',
  'es': 'Spanish',
  'ru': 'Russian',
  'ko': 'Korean',
  'fr': 'French',
  'ja': 'Japanese',
  'pt': 'Portuguese',
  'tr': 'Turkish',
  'pl': 'Polish',
  'ca': 'Catalan',
  'nl': 'Dutch',
  'ar': 'Arabic',
  'sv': 'Swedish',
  'it': 'Italian',
  'id': 'Indonesian',
  'hi': 'Hindi',
  'fi': 'Finnish',
  'vi': 'Vietnamese',
  'he': 'Hebrew',
  'uk': 'Ukrainian',
  'el': 'Greek',
  'ms': 'Malay',
  'cs': 'Czech',
  'ro': 'Romanian',
  'da': 'Danish',
  'hu': 'Hungarian',
  'ta': 'Tamil',
  'no': 'Norwegian',
  'th': 'Thai',
  'ur': 'Urdu',
  'hr': 'Croatian',
  'bg': 'Bulgarian',
  'lt': 'Lithuanian',
  'la': 'Latin',
  'mi': 'Maori',
  'ml': 'Malayalam',
  'cy': 'Welsh',
  'sk': 'Slovak',
  'te': 'Telugu',
  'fa': 'Persian',
  'lv': 'Latvian',
  'bn': 'Bengali',
  'sr': 'Serbian',
  'az': 'Azerbaijani',
  'sl': 'Slovenian',
  'kn': 'Kannada',
  'et': 'Estonian',
  'mk': 'Macedonian',
  'br': 'Breton',
  'eu': 'Basque',
  'is': 'Icelandic',
  'hy': 'Armenian',
  'ne': 'Nepali',
  'mn': 'Mongolian',
  'bs': 'Bosnian',
  'kk': 'Kazakh',
  'sq': 'Albanian',
  'sw': 'Swahili',
  'gl': 'Galician',
  'mr': 'Marathi',
  'pa': 'Punjabi',
  'si': 'Sinhala',
  'km': 'Khmer',
  'sn': 'Shona',
  'yo': 'Yoruba',
  'so': 'Somali',
  'af': 'Afrikaans',
  'oc': 'Occitan',
  'ka': 'Georgian',
  'be': 'Belarusian',
  'tg': 'Tajik',
  'sd': 'Sindhi',
  'gu': 'Gujarati',
  'am': 'Amharic',
  'yi': 'Yiddish',
  'lo': 'Lao',
  'uz': 'Uzbek',
  'fo': 'Faroese',
  'ht': 'Haitian Creole',
  'ps': 'Pashto',
  'tk': 'Turkmen',
  'nn': 'Norwegian Nynorsk',
  'mt': 'Maltese',
  'sa': 'Sanskrit',
  'lb': 'Luxembourgish',
  'my': 'Myanmar',
  'bo': 'Tibetan',
  'tl': 'Tagalog',
  'mg': 'Malagasy',
  'as': 'Assamese',
  'tt': 'Tatar',
  'haw': 'Hawaiian',
  'ln': 'Lingala',
  'ha': 'Hausa',
  'ba': 'Bashkir',
  'jw': 'Javanese',
  'su': 'Sundanese',
};
