/// Timestamp utilities for word-level and precise timestamps.
library;

import 'package:whisper_kit/bean/response_bean.dart';

/// A word with timing information.
class TimestampedWord {
  const TimestampedWord({
    required this.word,
    required this.start,
    required this.end,
    this.confidence,
  });

  /// The word text.
  final String word;

  /// Start time of the word.
  final Duration start;

  /// End time of the word.
  final Duration end;

  /// Confidence score (0.0 - 1.0).
  final double? confidence;

  /// Duration of the word.
  Duration get duration => end - start;

  @override
  String toString() =>
      'TimestampedWord("$word", ${_formatTime(start)}-${_formatTime(end)})';
}

/// A segment with word-level timestamps.
class TimestampedSegment {
  const TimestampedSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.words,
  });

  /// Full segment text.
  final String text;

  /// Segment start time.
  final Duration start;

  /// Segment end time.
  final Duration end;

  /// Words with individual timestamps.
  final List<TimestampedWord> words;

  /// Duration of the segment.
  Duration get duration => end - start;

  /// Create from a WhisperTranscribeSegment.
  factory TimestampedSegment.fromSegment(WhisperTranscribeSegment segment) {
    final words = _estimateWordTimestamps(
      segment.text,
      segment.fromTs,
      segment.toTs,
    );

    return TimestampedSegment(
      text: segment.text,
      start: segment.fromTs,
      end: segment.toTs,
      words: words,
    );
  }
}

/// Timestamp precision utilities.
class TimestampUtils {
  const TimestampUtils._();

  /// Convert transcription response to timestamped segments with word-level timing.
  static List<TimestampedSegment> toTimestampedSegments(
    WhisperTranscribeResponse response,
  ) {
    final segments = response.segments;
    if (segments == null || segments.isEmpty) {
      // Create a single segment from the full text
      return [
        TimestampedSegment.fromSegment(
          WhisperTranscribeSegment(
            fromTs: Duration.zero,
            toTs: const Duration(seconds: 1),
            text: response.text,
          ),
        ),
      ];
    }

    return segments.map(TimestampedSegment.fromSegment).toList();
  }

  /// Get all words with timestamps from a response.
  static List<TimestampedWord> getAllWords(
    WhisperTranscribeResponse response,
  ) {
    final segments = toTimestampedSegments(response);
    return segments.expand((s) => s.words).toList();
  }

  /// Find words within a time range.
  static List<TimestampedWord> getWordsInRange(
    WhisperTranscribeResponse response,
    Duration start,
    Duration end,
  ) {
    return getAllWords(response).where((word) {
      return word.start >= start && word.end <= end;
    }).toList();
  }

  /// Get the word at a specific time.
  static TimestampedWord? getWordAtTime(
    WhisperTranscribeResponse response,
    Duration time,
  ) {
    final words = getAllWords(response);
    for (final word in words) {
      if (time >= word.start && time <= word.end) {
        return word;
      }
    }
    return null;
  }
}

/// Estimate word timestamps by distributing time proportionally.
List<TimestampedWord> _estimateWordTimestamps(
  String text,
  Duration start,
  Duration end,
) {
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.isEmpty) return [];

  final totalDuration = end - start;
  final totalChars = words.fold<int>(0, (sum, w) => sum + w.length);

  if (totalChars == 0) {
    // All whitespace, create empty words
    final perWord = totalDuration ~/ words.length;
    return List.generate(words.length, (i) {
      return TimestampedWord(
        word: words[i],
        start: start + perWord * i,
        end: start + perWord * (i + 1),
      );
    });
  }

  final result = <TimestampedWord>[];
  var currentTime = start;

  for (final word in words) {
    // Proportional duration based on character count
    final proportion = word.length / totalChars;
    final wordDuration = Duration(
      milliseconds: (totalDuration.inMilliseconds * proportion).round(),
    );

    result.add(TimestampedWord(
      word: word,
      start: currentTime,
      end: currentTime + wordDuration,
    ));

    currentTime += wordDuration;
  }

  // Adjust last word to end exactly at segment end
  if (result.isNotEmpty) {
    final last = result.removeLast();
    result.add(TimestampedWord(
      word: last.word,
      start: last.start,
      end: end,
      confidence: last.confidence,
    ));
  }

  return result;
}

/// Format duration as MM:SS.mmm.
String _formatTime(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  final millis = duration.inMilliseconds % 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
}

/// Extension on WhisperTranscribeResponse for timestamp utilities.
extension TimestampExtension on WhisperTranscribeResponse {
  /// Get all segments with word-level timestamps.
  List<TimestampedSegment> get timestampedSegments =>
      TimestampUtils.toTimestampedSegments(this);

  /// Get all words with timestamps.
  List<TimestampedWord> get allWords => TimestampUtils.getAllWords(this);

  /// Get the word at a specific time.
  TimestampedWord? wordAt(Duration time) =>
      TimestampUtils.getWordAtTime(this, time);
}
