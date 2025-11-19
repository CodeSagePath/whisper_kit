import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";
import "package:test_whisper/providers.dart";
import "package:whisper_flutter/whisper_flutter.dart";

class DownloadProgressWidget extends ConsumerStatefulWidget {
  const DownloadProgressWidget({super.key});

  @override
  ConsumerState<DownloadProgressWidget> createState() =>
      _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends ConsumerState<DownloadProgressWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _checkmarkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkmarkAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024)
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Future<bool> _isModelDownloaded() async {
    final model = ref.read(modelProvider);
    if (model == WhisperModel.none) return true;

    try {
      // Use the same path logic as Whisper library to ensure consistency
      final Directory modelDirectory = Platform.isAndroid
          ? await getApplicationSupportDirectory()
          : await getLibraryDirectory();

      final File modelFile = File(model.getPath(modelDirectory.path));
      final bool modelExists = modelFile.existsSync();

      if (kDebugMode) {
        debugPrint("Model detection check for ${model.modelName}:");
        debugPrint("- Directory: ${modelDirectory.path}");
        debugPrint("- Model file: ${modelFile.path}");
        debugPrint("- Exists: $modelExists");
      }

      return modelExists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error checking model existence: $e");
      }
      return false;
    }
  }

  Future<void> _downloadModel() async {
    final model = ref.read(modelProvider);
    if (model == WhisperModel.none) return;

    ref.read(downloadStatusProvider.notifier).state =
        DownloadStatus.downloading;
    ref.read(downloadProgressProvider.notifier).state = 0.0;
    ref.read(downloadedSizeProvider.notifier).state = 0.0;
    ref.read(totalSizeProvider.notifier).state = 0.0;

    try {
      final downloadHost =
          "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

      // Use the same path logic as Whisper library to ensure consistency
      final Directory modelDirectory = Platform.isAndroid
          ? await getApplicationSupportDirectory()
          : await getLibraryDirectory();
      final String modelDir = modelDirectory.path;
      final File modelFile = File(model.getPath(modelDir));

      if (kDebugMode) {
        debugPrint("Starting model download:");
        debugPrint("- Directory: $modelDir");
        debugPrint("- Model file: ${modelFile.path}");
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

          if (contentLength > 0) {
            final progress = receivedBytes / contentLength;
            ref.read(downloadProgressProvider.notifier).state = progress;
            ref.read(downloadedSizeProvider.notifier).state =
                receivedBytes.toDouble();
          }
        }

        await raf.close();
        ref.read(downloadStatusProvider.notifier).state =
            DownloadStatus.completed;
        _checkmarkController.forward();
      } finally {
        httpClient.close();
      }
    } catch (e) {
      ref.read(downloadStatusProvider.notifier).state = DownloadStatus.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadProgress = ref.watch(downloadProgressProvider);
    final downloadStatus = ref.watch(downloadStatusProvider);
    final downloadedSize = ref.watch(downloadedSizeProvider);
    final totalSize = ref.watch(totalSizeProvider);
    final model = ref.watch(modelProvider);

    return FutureBuilder<bool>(
      future: _isModelDownloaded(),
      builder: (context, snapshot) {
        final isModelDownloaded = snapshot.data ?? false;

        if (!isModelDownloaded && downloadStatus == DownloadStatus.idle) {
          // Show download button if model is not downloaded
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade600),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Model Required: ${model.modelName}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "This model needs to be downloaded before you can transcribe audio. The model size can be up to several hundred megabytes.",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _downloadModel,
                            icon: const Icon(Icons.download),
                            label: const Text("Download Model"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Show completed status if model is downloaded
        if (isModelDownloaded && downloadStatus == DownloadStatus.idle) {
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade600),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: _checkmarkAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Model Ready: ${model.modelName}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                "You can start transcribing audio now",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Show download progress when downloading
        if (downloadStatus == DownloadStatus.downloading) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }

        if (downloadStatus == DownloadStatus.idle && isModelDownloaded) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(downloadStatus),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getStatusText(downloadStatus),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _getStatusColor(downloadStatus),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (downloadStatus == DownloadStatus.downloading)
                    Text(
                      "${(downloadProgress * 100).toStringAsFixed(1)}%",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (downloadStatus == DownloadStatus.downloading) ...[
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: MediaQuery.of(context).size.width * downloadProgress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE94560), Color(0xFF0F3460)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Downloaded: ${_formatBytes(downloadedSize.toInt())}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade400,
                          ),
                    ),
                    Text(
                      "Total: ${_formatBytes(totalSize.toInt())}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade400,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return "Downloading Whisper Model...";
      case DownloadStatus.completed:
        return "Model Download Completed";
      case DownloadStatus.error:
        return "Download Failed";
      case DownloadStatus.idle:
        return "";
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.error:
        return Colors.red;
      case DownloadStatus.idle:
        return Colors.grey;
    }
  }
}
