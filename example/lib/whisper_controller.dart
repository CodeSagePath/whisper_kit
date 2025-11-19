import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:path_provider/path_provider.dart";
import "package:system_info2/system_info2.dart";
import "package:test_whisper/providers.dart";
import "package:test_whisper/whisper_audio_convert.dart";
import "package:test_whisper/whisper_result.dart";
import "package:whisper_flutter/whisper_flutter.dart";

class WhisperController extends StateNotifier<AsyncValue<TranscribeResult?>> {
  WhisperController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> _ensureModelDownloaded(WhisperModel model) async {
    if (model == WhisperModel.none) return;

    // Use the same path logic as Whisper library to ensure consistency
    final Directory modelDirectory = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    final String modelDir = modelDirectory.path;
    final File modelFile = File(model.getPath(modelDir));

    if (modelFile.existsSync()) {
      if (kDebugMode) {
        debugPrint(
            "Model already exists: ${model.modelName} at ${modelFile.path}");
      }
      // Mark as completed
      ref.read(downloadStatusProvider.notifier).state =
          DownloadStatus.completed;
      return;
    }

    // Download the model manually with progress tracking
    final downloadHost =
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

    if (kDebugMode) {
      debugPrint("Downloading model ${model.modelName} to $modelDir");
    }

    final httpClient = HttpClient();
    try {
      final modelUri = Uri.parse("$downloadHost/ggml-${model.modelName}.bin");
      final request = await httpClient.getUrl(modelUri);
      final response = await request.close();

      final contentLength = response.contentLength;
      if (contentLength > 0) {
        ref.read(totalSizeProvider.notifier).state = contentLength.toDouble();
      }

      final raf = modelFile.openSync(mode: FileMode.write);
      int receivedBytes = 0;

      await for (var chunk in response) {
        raf.writeFromSync(chunk);
        receivedBytes += chunk.length;

        // Update progress
        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          ref.read(downloadProgressProvider.notifier).state = progress;
          ref.read(downloadedSizeProvider.notifier).state =
              receivedBytes.toDouble();
        }
      }

      await raf.close();

      if (kDebugMode) {
        debugPrint("Model download completed: ${modelFile.path}");
      }

      // Mark as completed
      ref.read(downloadStatusProvider.notifier).state =
          DownloadStatus.completed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Model download failed: $e");
      }
      ref.read(downloadStatusProvider.notifier).state = DownloadStatus.error;
      rethrow;
    } finally {
      httpClient.close();
    }
  }

  Future<void> transcribe(String filePath) async {
    final WhisperModel model = ref.read(modelProvider);

    state = const AsyncLoading();

    // Reset download progress
    ref.read(downloadProgressProvider.notifier).state = 0.0;
    ref.read(downloadStatusProvider.notifier).state =
        DownloadStatus.downloading;
    ref.read(downloadedSizeProvider.notifier).state = 0.0;
    ref.read(totalSizeProvider.notifier).state = 0.0;

    // Handle model download manually to track progress
    await _ensureModelDownloaded(model);

    /// URL: https://huggingface.co/ggerganov/whisper.cpp/resolve/main
    final Whisper whisper = Whisper(
        model: model,
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");

    final DateTime start = DateTime.now();

    final String lang = ref.read(langProvider);

    final bool translate = ref.read(translateProvider);

    final bool withSegments = ref.read(withSegmentsProvider);

    final bool splitWords = ref.read(splitWordsProvider);

    try {
      if (kDebugMode) {
        debugPrint("[Whisper]Start");
      }
      final String? whisperVersion = await whisper.getVersion();
      var cores = 2;
      try {
        cores = SysInfo.cores.length;
      } catch (_) {
        cores = 8;
      }
      if (kDebugMode) {
        debugPrint("[Whisper]Number of core = ${cores}");
        debugPrint("[Whisper]Whisper version = $whisperVersion");
      }

      // Mark download as completed
      ref.read(downloadStatusProvider.notifier).state =
          DownloadStatus.completed;

      final Directory documentDirectory =
          await getApplicationDocumentsDirectory();
      final WhisperAudioconvert converter = WhisperAudioconvert(
        audioInput: File(filePath),
        audioOutput: File("${documentDirectory.path}/convert.wav"),
      );

      final File? convertedFile = await converter.convert();
      final WhisperTranscribeResponse transcription = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: convertedFile?.path ?? filePath,
          language: lang,
          nProcessors: (cores * 1.2).toInt(),
          threads: (cores * 1.2).toInt(),
          isTranslate: translate,
          isNoTimestamps: !withSegments,
          splitOnWord: splitWords,
        ),
      );

      final Duration transcriptionDuration = DateTime.now().difference(start);
      if (kDebugMode) {
        debugPrint("[Whisper]End = $transcriptionDuration");
      }
      state = AsyncData(
        TranscribeResult(
          time: transcriptionDuration,
          transcription: transcription,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[Whisper]Error = $e");
      }
      ref.read(downloadStatusProvider.notifier).state = DownloadStatus.error;
      state = const AsyncData(null);
    }
  }
}

final whisperControllerProvider = StateNotifierProvider.autoDispose<
    WhisperController, AsyncValue<TranscribeResult?>>(
  (ref) => WhisperController(ref),
);
