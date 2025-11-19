import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:path_provider/path_provider.dart";
import "package:system_info2/system_info2.dart";
import "package:test_whisper/providers.dart";
import "package:test_whisper/whisper_audio_convert.dart";
import "package:test_whisper/whisper_result.dart";
import "package:whisper_kit/whisper_kit.dart";

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
    if (filePath.isEmpty) {
      state = AsyncError(
        StateError("No audio file selected"),
        StackTrace.current,
      );
      return;
    }

    final WhisperModel model = ref.read(modelProvider);
    if (model == WhisperModel.none) {
      state = AsyncError(
        StateError("No model selected"),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    try {
      // Validate input file
      final File audioFile = File(filePath);
      if (!audioFile.existsSync()) {
        state = AsyncError(
          StateError("Audio file not found: $filePath"),
          StackTrace.current,
        );
        return;
      }

      // Check file size
      final int fileSize = await audioFile.length();
      if (fileSize == 0) {
        state = AsyncError(
          StateError("Audio file is empty"),
          StackTrace.current,
        );
        return;
      }

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
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      );

      final DateTime start = DateTime.now();
      final String lang = ref.read(langProvider);
      final bool translate = ref.read(translateProvider);
      final bool withSegments = ref.read(withSegmentsProvider);
      final bool splitWords = ref.read(splitWordsProvider);

      if (kDebugMode) {
        debugPrint("[Whisper]Start transcription");
        debugPrint("[Whisper]Audio file: $filePath (${fileSize} bytes)");
        debugPrint("[Whisper]Model: ${model.modelName}");
        debugPrint("[Whisper]Language: $lang");
        debugPrint("[Whisper]Translate: $translate");
      }

      // Get Whisper version
      final String? whisperVersion = await whisper.getVersion();
      var cores = 2;
      try {
        cores = SysInfo.cores.length;
      } catch (_) {
        cores = 8;
      }

      // Conservative processor allocation to prevent crashes
      final int processorCount = cores.clamp(1, 8);
      final int threadCount = cores.clamp(1, 8);

      if (kDebugMode) {
        debugPrint("[Whisper]Number of cores = $cores");
        debugPrint("[Whisper]Using processors = $processorCount");
        debugPrint("[Whisper]Using threads = $threadCount");
        debugPrint("[Whisper]Whisper version = $whisperVersion");
      }

      // Mark download as completed
      ref.read(downloadStatusProvider.notifier).state =
          DownloadStatus.completed;

      // Start transcription processing timer
      ref.read(isTranscriptionProcessingProvider.notifier).state = true;

      // Ensure audio is in proper WAV format (16kHz, mono, 16-bit PCM) with error handling
      final Directory documentDirectory =
          await getApplicationDocumentsDirectory();
      final WhisperAudioconvert converter = WhisperAudioconvert(
        audioInput: audioFile,
        audioOutput: File("${documentDirectory.path}/convert.wav"),
      );

      File? convertedFile;
      try {
        convertedFile = await converter.convert();
        if (convertedFile != null && !convertedFile.existsSync()) {
          throw Exception("Audio conversion failed - output file not found");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("[Whisper]Audio conversion failed: $e");
        }
        // Fall back to original file if conversion fails
        convertedFile = null;
      }

      // Prepare transcription request with safety parameters
      final String audioFilePath = convertedFile?.path ?? filePath;
      final TranscribeRequest request = TranscribeRequest(
        audio: audioFilePath,
        language: lang,
        nProcessors: processorCount,
        threads: threadCount,
        isTranslate: translate,
        isNoTimestamps: !withSegments,
        splitOnWord: splitWords,
      );

      if (kDebugMode) {
        debugPrint("[Whisper]Starting transcription request");
        debugPrint("[Whisper]Audio path: $audioFilePath");
      }

      // Add timeout to prevent hanging
      final WhisperTranscribeResponse transcription =
          await whisper.transcribe(transcribeRequest: request).timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw Exception(
            "Transcription timed out after 10 minutes",
          );
        },
      );

      final Duration transcriptionDuration = DateTime.now().difference(start);
      if (kDebugMode) {
        debugPrint(
            "[Whisper]Transcription completed in $transcriptionDuration");
        debugPrint(
            "[Whisper]Transcription result length: ${transcription.text.length}");
      }

      // Stop transcription processing timer
      ref.read(isTranscriptionProcessingProvider.notifier).state = false;

      state = AsyncData(
        TranscribeResult(
          time: transcriptionDuration,
          transcription: transcription,
        ),
      );

      // Cleanup converted file
      try {
        if (convertedFile != null && convertedFile.path != filePath) {
          await convertedFile.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("[Whisper]Failed to cleanup converted file: $e");
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("[Whisper]Transcription failed: $e");
        debugPrint("[Whisper]Stack trace: $stackTrace");
      }

      ref.read(downloadStatusProvider.notifier).state = DownloadStatus.error;

      // Stop transcription processing timer in case of error
      ref.read(isTranscriptionProcessingProvider.notifier).state = false;

      // Provide user-friendly error messages
      String errorMessage = "Transcription failed";
      if (e.toString().contains("TimeoutException") ||
          e.toString().contains("timed out")) {
        errorMessage =
            "Transcription timed out. Please try with a shorter audio file.";
      } else if (e.toString().contains("SIGSEGV") ||
          e.toString().contains("native")) {
        errorMessage =
            "A system error occurred during transcription. Please try again.";
      } else if (e.toString().contains("Model") ||
          e.toString().contains("model")) {
        errorMessage = "Model loading failed. Please download the model again.";
      } else if (e.toString().contains("Audio") ||
          e.toString().contains("audio")) {
        errorMessage =
            "Audio processing failed. Please try with a different audio file.";
      } else {
        errorMessage = "Transcription failed: ${e.toString()}";
      }

      state = AsyncError(
        Exception(errorMessage),
        stackTrace,
      );
    }
  }
}

final whisperControllerProvider = StateNotifierProvider.autoDispose<
    WhisperController, AsyncValue<TranscribeResult?>>(
  (ref) => WhisperController(ref),
);
