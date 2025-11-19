import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";
import "package:test_whisper/download_progress_widget.dart";
import "package:test_whisper/providers.dart";
import "package:test_whisper/record_page.dart";
import "package:test_whisper/whisper_controller.dart";
import "package:test_whisper/whisper_result.dart";
import "package:whisper_flutter/whisper_flutter.dart";

class MyHomePage extends ConsumerWidget {
  const MyHomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WhisperModel model = ref.watch(modelProvider);
    final String lang = ref.watch(langProvider);
    final bool translate = ref.watch(translateProvider);
    final bool withSegments = ref.watch(withSegmentsProvider);
    final bool splitWords = ref.watch(splitWordsProvider);

    final WhisperController controller = ref.watch(
      whisperControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(
          "Whisper Audio Transcribe",
        ),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCollapsibleConfigurationCard(context, ref, model, lang,
                  translate, withSegments, splitWords),
              const SizedBox(height: 20),
              _buildImprovedAudioFilesCard(context, ref, controller),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, _) {
                  final AsyncValue<TranscribeResult?> transcriptionAsync =
                      ref.watch(
                    whisperControllerProvider,
                  );

                  return transcriptionAsync.maybeWhen(
                    skipLoadingOnRefresh: true,
                    skipLoadingOnReload: true,
                    data: (TranscribeResult? transcriptionResult) {
                      if (transcriptionResult != null) {
                        return _buildTranscriptionResultCard(
                            context, transcriptionResult);
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 20),
              const DownloadProgressWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleConfigurationCard(
    BuildContext context,
    WidgetRef ref,
    WhisperModel model,
    String lang,
    bool translate,
    bool withSegments,
    bool splitWords,
  ) {
    final isExpanded = ref.watch(isConfigExpandedProvider);

    return Hero(
      tag: "config_card",
      child: Container(
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
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(isConfigExpandedProvider.notifier).state =
                      !isExpanded;
                },
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                splashFactory: InkRipple.splashFactory,
                splashColor: const Color(0xFFE94560).withValues(alpha: 0.2),
                highlightColor: const Color(0xFFE94560).withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: isExpanded ? 1.1 + 0.05 * value : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? const Color(0xFFE94560)
                                        .withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.tune,
                                color: isExpanded
                                    ? const Color(0xFFE94560)
                                    : const Color(0xFFE94560),
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Configuration",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? const Color(0xFFE94560).withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.expand_more,
                            color: isExpanded
                                ? const Color(0xFFE94560)
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: isExpanded
                  ? Padding(
                      key: const ValueKey("expanded"),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          const Divider(height: 1, color: Colors.grey),
                          const SizedBox(height: 20),
                          _buildDropdownField(
                            context,
                            "Model",
                            model,
                            WhisperModel.values
                                .map((model) => DropdownMenuItem(
                                      value: model,
                                      child: Text(model.modelName),
                                    ))
                                .toList(),
                            (WhisperModel? value) {
                              if (value != null) {
                                ref.read(modelProvider.notifier).state = value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            context,
                            "Language",
                            lang,
                            ["auto", "en"]
                                .map((lang) => DropdownMenuItem(
                                      value: lang,
                                      child: Text(lang),
                                    ))
                                .toList(),
                            (String? value) {
                              if (value != null) {
                                ref.read(langProvider.notifier).state = value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            context,
                            "Translate Result",
                            translate,
                            [
                              const DropdownMenuItem(
                                  value: false, child: Text("No")),
                              const DropdownMenuItem(
                                  value: true, child: Text("Yes")),
                            ],
                            (bool? value) {
                              if (value != null) {
                                ref.read(translateProvider.notifier).state =
                                    value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            context,
                            "With Segments",
                            withSegments,
                            [
                              const DropdownMenuItem(
                                  value: false, child: Text("No")),
                              const DropdownMenuItem(
                                  value: true, child: Text("Yes")),
                            ],
                            (bool? value) {
                              if (value != null) {
                                ref.read(withSegmentsProvider.notifier).state =
                                    value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            context,
                            "Split Words",
                            splitWords,
                            [
                              const DropdownMenuItem(
                                  value: false, child: Text("No")),
                              const DropdownMenuItem(
                                  value: true, child: Text("Yes")),
                            ],
                            (bool? value) {
                              if (value != null) {
                                ref.read(splitWordsProvider.notifier).state =
                                    value;
                              }
                            },
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey("collapsed")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovedAudioFilesCard(
      BuildContext context, WidgetRef ref, WhisperController controller) {
    final selectedAudioFile = ref.watch(selectedAudioFileProvider);

    return Container(
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
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + 0.1 * value,
                    child: Icon(
                      Icons.library_music,
                      color: const Color(0xFFE94560),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                "Audio Files",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grid layout for audio files with staggered animations
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.0,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              final fileName = [
                "punjabi.wav",
                "marathi.wav",
                "english.wav",
                "telugu.wav",
                "french.wav",
                "japanese.wav",
              ][index];

              final isSelected = selectedAudioFile?.split("/").last == fileName;

              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: SlideTransition(
                      position: AlwaysStoppedAnimation<Offset>(
                        Offset(0, (1 - value) * 0.3),
                      ),
                      child: AnimatedOpacity(
                        opacity: value,
                        duration: const Duration(milliseconds: 300),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final Directory documentDirectory =
                                  await getApplicationDocumentsDirectory();
                              final ByteData documentBytes =
                                  await rootBundle.load("assets/$fileName");
                              final String audioPath =
                                  "${documentDirectory.path}/$fileName";
                              await File(audioPath).writeAsBytes(
                                  documentBytes.buffer.asUint8List());
                              ref
                                  .read(selectedAudioFileProvider.notifier)
                                  .state = audioPath;
                            },
                            borderRadius: BorderRadius.circular(12),
                            splashFactory: InkRipple.splashFactory,
                            splashColor:
                                const Color(0xFFE94560).withValues(alpha: 0.3),
                            highlightColor:
                                const Color(0xFFE94560).withValues(alpha: 0.2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE94560)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFF16213E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFE94560)
                                      : Colors.grey.shade600,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFE94560)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedRotation(
                                    turns: isSelected ? 0.25 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      Icons.audio_file,
                                      color: isSelected
                                          ? const Color(0xFFE94560)
                                          : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFFE94560)
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    TweenAnimationBuilder<double>(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Icon(
                                            Icons.check_circle,
                                            color: const Color(0xFFE94560),
                                            size: 14,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // Action buttons with animations
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - value) * 20),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final String? recordFilePath =
                              await RecordPage.openRecordPage(context);
                          if (recordFilePath != null) {
                            ref.read(selectedAudioFileProvider.notifier).state =
                                recordFilePath;
                          }
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(
                            Icons.mic,
                            key: ValueKey("mic"),
                          ),
                        ),
                        label: const Text("Record Audio"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3460),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor:
                              const Color(0xFF0F3460).withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (selectedAudioFile != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, (1 - value) * 20),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            await controller.transcribe(selectedAudioFile);
                          },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(
                              Icons.play_arrow,
                              key: ValueKey("play"),
                            ),
                          ),
                          label: const Text("Transcribe"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),

          if (selectedAudioFile != null) ...[
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE94560).withValues(alpha: 0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE94560).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                                scale: 1.0 + 0.2 * value,
                                child: Icon(
                                  Icons.check_circle,
                                  color: const Color(0xFFE94560),
                                  size: 20,
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
                                  "Selected File:",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey.shade400,
                                      ),
                                ),
                                Text(
                                  selectedAudioFile.split("/").last,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFE94560),
                                        fontWeight: FontWeight.bold,
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(
    BuildContext context,
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade300,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: const Color(0xFF16213E),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            underline: const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptionResultCard(
      BuildContext context, TranscribeResult result) {
    return Container(
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
              const Icon(Icons.transcribe, color: Color(0xFFE94560)),
              const SizedBox(width: 8),
              Text(
                "Transcription Result",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Text(
              result.transcription.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Processing Time: ${result.time.toString()}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade300,
                  ),
            ),
          ),
          if (result.transcription.segments != null) ...[
            const SizedBox(height: 20),
            Text(
              "Segments",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                itemCount: result.transcription.segments!.length,
                itemBuilder: (context, index) {
                  final WhisperTranscribeSegment segment =
                      result.transcription.segments![index];
                  final Duration fromTs = segment.fromTs;
                  final Duration toTs = segment.toTs;
                  final String text = segment.text;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "[$fromTs - $toTs]",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
