import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_kit/src/exceptions.dart';

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
///
/// Throws [ModelException] if download fails.
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
  RandomAccessFile? raf;
  File? tempFile;

  try {
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

    await Directory(destinationPath).create(recursive: true);

    final request = await httpClient.getUrl(modelUri);
    final response = await request.close();

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ModelException.downloadFailed(
        model.modelName,
        'HTTP ${response.statusCode} ($modelUri)',
      );
    }

    final contentLength = response.contentLength;
    if (kDebugMode) {
      debugPrint('Content length: $contentLength bytes');
    }

    final targetPath = '$destinationPath/ggml-${model.modelName}.bin';
    final tempPath = '$targetPath.part';

    tempFile = File(tempPath);
    raf = tempFile.openSync(mode: FileMode.write);

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
    raf = null;

    // Validate downloaded file
    if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
      throw ModelException.downloadFailed(
        model.modelName,
        'Downloaded file is empty or missing ($modelUri -> $targetPath)',
      );
    }

    // Atomic-ish replace: rename temp into final.
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      try {
        targetFile.deleteSync();
      } catch (_) {}
    }
    tempFile.renameSync(targetPath);
    tempFile = null;

    if (kDebugMode) {
      debugPrint('Download Done . Path = $targetPath');
    }
    return targetPath;
  } on ModelException {
    rethrow;
  } on SocketException catch (e) {
    throw ModelException.downloadFailed(
      model.modelName,
      'Network error: ${e.message}',
    );
  } on HttpException catch (e) {
    throw ModelException.downloadFailed(
      model.modelName,
      'HTTP error: ${e.message}',
    );
  } catch (e) {
    throw ModelException.downloadFailed(
      model.modelName,
      '$e',
    );
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
    try {
      httpClient.close(force: true);
    } catch (_) {}
    if (tempFile != null && tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
      } catch (_) {}
    }
  }
}
