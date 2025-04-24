import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:whisper_flutter/whisper_flutter.dart";

final modelProvider = StateProvider.autoDispose((ref) => WhisperModel.base);

final langProvider = StateProvider.autoDispose((ref) => "auto");

final translateProvider = StateProvider((ref) => false);

final withSegmentsProvider = StateProvider((ref) => false);

final splitWordsProvider = StateProvider((ref) => false);
