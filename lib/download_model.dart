import 'dart:io';

import 'package:flutter/foundation.dart';

/// Available whisper models
enum WhisperModel {
  // no model
  none(''),

  /// tiny model for all languages
  tiny('tiny'),

  /// base model for all languages
  base('base'),

  /// small model for all languages
  small('small'),

  /// medium model for all languages
  medium('medium'),

  /// large model for all languages
  largeV1('large-v1'),
  largeV2('large-v2');

  const WhisperModel(this.modelName);

  /// Public name of model
  final String modelName;

  /// Get local path of model file
  String getPath(String dir) {
    return '$dir/ggml-$modelName.bin';
  }
}

/// Download [model] to [destinationPath]
Future<String> downloadModel({
  required WhisperModel model,
  required String destinationPath,
  String? downloadHost,
  Function(int received, int total)? onDownloadProgress,
}) async {
  if (kDebugMode) {
    debugPrint('Download model ${model.modelName}');
  }
  final httpClient = HttpClient();

  Uri modelUri;

  if (downloadHost == null || downloadHost.isEmpty) {
    /// Huggingface url to download model
    modelUri = Uri.parse(
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${model.modelName}.bin',
    );
  } else {
    modelUri = Uri.parse(
      '$downloadHost/ggml-${model.modelName}.bin',
    );
  }

  final request = await httpClient.getUrl(modelUri);
  final response = await request.close();

  final contentLength = response.contentLength;
  if (kDebugMode) {
    debugPrint('Content length: $contentLength bytes');
  }

  final file = File('$destinationPath/ggml-${model.modelName}.bin');
  final raf = file.openSync(mode: FileMode.write);

  int receivedBytes = 0;
  await for (var chunk in response) {
    raf.writeFromSync(chunk);
    receivedBytes += chunk.length;

    // Call progress callback if provided
    if (onDownloadProgress != null && contentLength > 0) {
      onDownloadProgress(receivedBytes, contentLength);
    }
  }

  await raf.close();

  if (kDebugMode) {
    debugPrint('Download Done . Path = ${file.path}');
  }
  return file.path;
}
