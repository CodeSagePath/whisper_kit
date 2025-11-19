import "package:whisper_kit/whisper_kit.dart";

class TranscribeResult {
  const TranscribeResult({
    required this.transcription,
    required this.time,
  });

  final WhisperTranscribeResponse transcription;
  final Duration time;
}
