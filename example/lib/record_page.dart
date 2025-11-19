import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:path_provider/path_provider.dart";
import "package:record/record.dart";

class RecordController extends StateNotifier<bool> {
  RecordController() : super(false) {
    // Initialize recorder
    _record = AudioRecorder();
  }

  late AudioRecorder _record;
  bool _isInitialized = false;

  @override
  void dispose() {
    // Ensure microphone is properly released when controller is disposed
    if (_isInitialized && state) {
      _record.stop().catchError((e) {
        if (kDebugMode) {
          debugPrint("Error stopping recorder during disposal: $e");
        }
        return null;
      });
    }
    _record.dispose();
    super.dispose();
  }

  Future<void> startRecord() async {
    try {
      // Ensure any existing recording is stopped first
      if (state) {
        await stopRecord();
      }

      // Check and request permission
      if (!await _record.hasPermission()) {
        if (kDebugMode) {
          debugPrint("Microphone permission denied");
        }
        return;
      }

      state = true;
      _isInitialized = true;

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputPath = "${appDirectory.path}/recorded.m4a";

      if (kDebugMode) {
        debugPrint("Starting recording to: $outputPath");
      }

      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );

      if (kDebugMode) {
        debugPrint("Recording started successfully");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error starting recording: $e");
      }
      state = false;
      _isInitialized = false;
    }
  }

  Future<String?> stopRecord() async {
    if (!state) {
      if (kDebugMode) {
        debugPrint("No active recording to stop");
      }
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint("Stopping recording...");
      }

      final String? path = await _record.stop();
      state = false;
      _isInitialized = false;

      if (kDebugMode) {
        debugPrint("Recording stopped. File path: $path");
      }

      return path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error stopping recording: $e");
      }
      state = false;
      _isInitialized = false;
      return null;
    }
  }

  Future<void> cancelRecord() async {
    if (!state) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint("Canceling recording...");
      }

      await _record.stop();
      state = false;
      _isInitialized = false;

      // Delete the recorded file if it exists
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final File recordedFile = File("${appDirectory.path}/recorded.m4a");
      if (await recordedFile.exists()) {
        await recordedFile.delete();
        if (kDebugMode) {
          debugPrint("Deleted canceled recording file");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error canceling recording: $e");
      }
      state = false;
      _isInitialized = false;
    }
  }
}

final recordControllerProvider =
    StateNotifierProvider.autoDispose<RecordController, bool>(
  (ref) => RecordController(),
);

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  static Future<String?> openRecordPage(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RecordPage(),
      ),
    );
  }

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  @override
  Widget build(BuildContext context) {
    final RecordController controller = ref.watch(
      recordControllerProvider.notifier,
    );
    final bool isRecording = ref.watch(recordControllerProvider);

    return PopScope(
      canPop: !isRecording,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop && isRecording) {
          await controller.cancelRecord();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F1E),
          elevation: 0,
          title: const Text(
            "Voice Recording",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Recording status indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFF16213E).withValues(alpha: 0.5),
                    border: Border.all(
                      color: isRecording
                          ? Colors.red.withValues(alpha: 0.8)
                          : const Color(0xFFE94560).withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    isRecording ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: isRecording
                        ? Colors.red.withValues(alpha: 0.8)
                        : const Color(0xFFE94560),
                  ),
                ),

                const SizedBox(height: 32),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isRecording ? "Recording..." : "Ready to record",
                    key: ValueKey(isRecording),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isRecording
                          ? Colors.red.withValues(alpha: 0.9)
                          : Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isRecording
                      ? "Tap stop when you're finished"
                      : "Tap start to begin recording",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),

                const SizedBox(height: 48),

                // Control buttons
                if (isRecording) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await controller.cancelRecord();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.cancel, color: Colors.white),
                          label: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final String? outputPath = await controller.stopRecord();

                            if (outputPath != null && mounted) {
                              if (kDebugMode) {
                                debugPrint("Recording saved to: $outputPath");
                              }
                              Navigator.of(context).pop(outputPath);
                            } else if (mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.stop, color: Colors.white),
                          label: const Text(
                            "Stop",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await controller.startRecord();
                      },
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      label: const Text(
                        "Start Recording",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94560),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE94560).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFFE94560).withValues(alpha: 0.7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Recording Tips",
                              style: TextStyle(
                                color: const Color(0xFFE94560).withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "• Speak clearly and close to your device\n"
                        "• Record in a quiet environment for best results\n"
                        "• Keep recordings under 5 minutes for optimal processing",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
