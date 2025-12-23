/// Speaker diarization utilities.
///
/// Identify and separate different speakers in audio.
library;

import 'package:whisper_kit/bean/response_bean.dart';

/// A detected speaker.
class Speaker {
  const Speaker({
    required this.id,
    this.name,
    this.color,
    this.segments = const [],
  });

  /// Unique speaker ID.
  final String id;

  /// Optional speaker name/label.
  final String? name;

  /// Display color for UI.
  final int? color;

  /// Segments spoken by this speaker.
  final List<SpeakerSegment> segments;

  /// Total speaking time.
  Duration get totalSpeakingTime => segments.fold(
        Duration.zero,
        (sum, s) => sum + s.duration,
      );

  /// Word count.
  int get wordCount => segments.fold(
        0,
        (sum, s) => sum + s.wordCount,
      );
}

/// A segment attributed to a speaker.
class SpeakerSegment {
  const SpeakerSegment({
    required this.speakerId,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.confidence,
  });

  /// Speaker ID.
  final String speakerId;

  /// Text spoken.
  final String text;

  /// Start time.
  final Duration startTime;

  /// End time.
  final Duration endTime;

  /// Confidence score (0-1).
  final double? confidence;

  /// Duration of this segment.
  Duration get duration => endTime - startTime;

  /// Word count.
  int get wordCount => text.trim().split(RegExp(r'\s+')).length;
}

/// Diarization result.
class DiarizationResult {
  const DiarizationResult({
    required this.speakers,
    required this.segments,
    this.audioDuration,
  });

  /// Detected speakers.
  final List<Speaker> speakers;

  /// All segments in order.
  final List<SpeakerSegment> segments;

  /// Total audio duration.
  final Duration? audioDuration;

  /// Number of speakers.
  int get speakerCount => speakers.length;

  /// Get segments for a specific speaker.
  List<SpeakerSegment> getSegmentsForSpeaker(String speakerId) {
    return segments.where((s) => s.speakerId == speakerId).toList();
  }

  /// Get speaker statistics.
  Map<String, double> getSpeakingTimePercentages() {
    if (audioDuration == null) return {};
    final totalMs = audioDuration!.inMilliseconds;
    if (totalMs == 0) return {};

    return {
      for (final speaker in speakers)
        speaker.id: (speaker.totalSpeakingTime.inMilliseconds / totalMs) * 100,
    };
  }
}

/// Diarization configuration.
class DiarizationConfig {
  const DiarizationConfig({
    this.minSpeakers = 1,
    this.maxSpeakers = 10,
    this.minSegmentDuration = const Duration(milliseconds: 500),
    this.mergeThreshold = const Duration(milliseconds: 300),
    this.speakerLabels,
  });

  /// Minimum expected speakers.
  final int minSpeakers;

  /// Maximum expected speakers.
  final int maxSpeakers;

  /// Minimum segment duration.
  final Duration minSegmentDuration;

  /// Merge segments closer than this.
  final Duration mergeThreshold;

  /// Custom speaker labels.
  final List<String>? speakerLabels;
}

/// Abstract diarization provider interface.
abstract class DiarizationProvider {
  /// Perform speaker diarization on audio.
  Future<DiarizationResult> diarize(
    String audioPath, {
    DiarizationConfig config = const DiarizationConfig(),
  });

  /// Combine transcription with diarization.
  Future<DiarizationResult> combineWithTranscription(
    WhisperTranscribeResponse transcription,
    String audioPath, {
    DiarizationConfig config = const DiarizationConfig(),
  });
}

/// Simple rule-based diarization (placeholder).
///
/// In production, use a proper diarization model like pyannote.
class SimpleDiarization {
  const SimpleDiarization._();

  /// Simulate diarization based on segment gaps.
  ///
  /// This is a placeholder - real diarization requires ML models.
  static DiarizationResult fromTranscription(
    WhisperTranscribeResponse response, {
    Duration gapThreshold = const Duration(seconds: 2),
  }) {
    final segments = response.segments ?? [];
    if (segments.isEmpty) {
      return const DiarizationResult(speakers: [], segments: []);
    }

    final speakerSegments = <SpeakerSegment>[];
    var currentSpeaker = 'speaker_1';
    var speakerCount = 1;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];

      // Check for speaker change based on gap
      if (i > 0) {
        final prevEnd = segments[i - 1].toTs;
        final gap = seg.fromTs - prevEnd;
        if (gap > gapThreshold) {
          speakerCount = speakerCount == 1 ? 2 : 1;
          currentSpeaker = 'speaker_$speakerCount';
        }
      }

      speakerSegments.add(SpeakerSegment(
        speakerId: currentSpeaker,
        text: seg.text,
        startTime: seg.fromTs,
        endTime: seg.toTs,
      ));
    }

    // Build speaker list
    final speakerIds = speakerSegments.map((s) => s.speakerId).toSet();
    final speakers = speakerIds
        .map((id) => Speaker(
              id: id,
              name: id.replaceAll('_', ' ').toUpperCase(),
              segments:
                  speakerSegments.where((s) => s.speakerId == id).toList(),
            ))
        .toList();

    return DiarizationResult(
      speakers: speakers,
      segments: speakerSegments,
    );
  }
}
