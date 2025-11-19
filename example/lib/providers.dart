import "package:flutter_riverpod/legacy.dart";
import "package:whisper_flutter/whisper_flutter.dart";

final modelProvider = StateProvider.autoDispose((ref) => WhisperModel.base);

final langProvider = StateProvider.autoDispose((ref) => "auto");

final translateProvider = StateProvider((ref) => false);

final withSegmentsProvider = StateProvider((ref) => false);

final splitWordsProvider = StateProvider((ref) => false);

final downloadProgressProvider = StateProvider.autoDispose((ref) => 0.0);

final downloadStatusProvider =
    StateProvider.autoDispose((ref) => DownloadStatus.idle);

final downloadedSizeProvider = StateProvider.autoDispose((ref) => 0.0);

final totalSizeProvider = StateProvider.autoDispose((ref) => 0.0);

final selectedAudioFileProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final isConfigExpandedProvider = StateProvider.autoDispose((ref) => false);

enum DownloadStatus {
  idle,
  downloading,
  completed,
  error,
}
