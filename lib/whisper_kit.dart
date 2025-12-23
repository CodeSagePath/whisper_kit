library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_kit/bean/_models.dart';
import 'package:whisper_kit/bean/whisper_dto.dart';
import 'package:whisper_kit/download_model.dart';
import 'package:whisper_kit/src/exceptions.dart';
import 'package:whisper_kit/whisper_bindings_generated.dart';

export 'package:whisper_kit/bean/_models.dart';
export 'package:whisper_kit/download_model.dart' show WhisperModel;
export 'package:whisper_kit/src/adaptive.dart';
export 'package:whisper_kit/src/batch.dart';
export 'package:whisper_kit/src/cache.dart';
export 'package:whisper_kit/src/cancellation.dart';
export 'package:whisper_kit/src/custom_model.dart';
export 'package:whisper_kit/src/database.dart';
export 'package:whisper_kit/src/exceptions.dart';
export 'package:whisper_kit/src/export.dart';
export 'package:whisper_kit/src/feature_flags.dart';
export 'package:whisper_kit/src/language.dart';
export 'package:whisper_kit/src/large_file.dart';
export 'package:whisper_kit/src/plugin.dart';
export 'package:whisper_kit/src/presets.dart';
export 'package:whisper_kit/src/progress.dart';
export 'package:whisper_kit/src/queue.dart';
export 'package:whisper_kit/src/security.dart';
export 'package:whisper_kit/src/timestamps.dart';
export 'package:whisper_kit/src/translation.dart';
export 'package:whisper_kit/src/widgets.dart';
export 'package:whisper_kit/src/whisper_kit_platform.dart';

/// Entry point of whisper_kit
class Whisper {
  /// [model] is required
  /// [modelDir] is path where downloaded model will be stored.
  /// Default to library directory
  /// [onDownloadProgress] callback for download progress (received bytes, total bytes)
  const Whisper({
    required this.model,
    this.modelDir,
    this.downloadHost,
    this.onDownloadProgress,
  });

  /// model used for transcription
  final WhisperModel model;

  /// override of model storage path
  final String? modelDir;

  /// override of model download host
  final String? downloadHost;

  /// callback for download progress
  final Function(int received, int total)? onDownloadProgress;

  DynamicLibrary _openLib() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libwhisper.so');
    } else {
      return DynamicLibrary.process();
    }
  }

  Future<String> _getModelDir() async {
    if (modelDir != null) {
      return modelDir!;
    }
    final Directory libraryDirectory = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    return libraryDirectory.path;
  }

  Future<void> _initModel() async {
    final String modelDir = await _getModelDir();
    final File modelFile = File(model.getPath(modelDir));
    final bool isModelExist = modelFile.existsSync();
    if (isModelExist) {
      if (kDebugMode) {
        debugPrint('Use existing model ${model.modelName}');
      }
      return;
    } else {
      // Download model without callback to avoid isolate issues
      await downloadModel(
        model: model,
        destinationPath: modelDir,
        downloadHost: downloadHost,
      );
    }
  }

  Future<Map<String, dynamic>> _request({
    required WhisperRequestDto whisperRequest,
  }) async {
    if (model != WhisperModel.none) {
      await _initModel();
    }
    return Isolate.run(
      () async {
        final Pointer<Utf8> data =
            whisperRequest.toRequestString().toNativeUtf8();
        final Pointer<Char> res =
            WhisperFlutterBindings(_openLib()).request(data.cast<Char>());
        final Map<String, dynamic> result = json.decode(
          res.cast<Utf8>().toDartString(),
        ) as Map<String, dynamic>;
        try {
          malloc.free(data);
          malloc.free(res);
        } catch (_) {}
        if (kDebugMode) {
          debugPrint('Result =  $result');
        }
        return result;
      },
    );
  }

  /// Transcribe audio file to text
  Future<WhisperTranscribeResponse> transcribe({
    required TranscribeRequest transcribeRequest,
  }) async {
    final String modelDir = await _getModelDir();
    final Map<String, dynamic> result = await _request(
      whisperRequest: TranscribeRequestDto.fromTranscribeRequest(
        transcribeRequest,
        model.getPath(modelDir),
      ),
    );
    if (kDebugMode) {
      debugPrint('Transcribe request $result');
    }
    if (result['text'] == null) {
      final errorMessage =
          result['message'] as String? ?? 'Unknown transcription error';
      if (kDebugMode) {
        debugPrint('Transcribe Exception $errorMessage');
      }
      throw TranscriptionException.processingFailed(errorMessage);
    }
    return WhisperTranscribeResponse.fromJson(result);
  }

  /// Get whisper version
  Future<String?> getVersion() async {
    final Map<String, dynamic> result = await _request(
      whisperRequest: const VersionRequest(),
    );

    final WhisperVersionResponse response = WhisperVersionResponse.fromJson(
      result,
    );
    return response.message;
  }
}
