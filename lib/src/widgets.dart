/// Pre-built Flutter widgets for WhisperKit.
///
/// Provides ready-to-use UI components for transcription apps.
library;

import 'package:flutter/material.dart';
import 'package:whisper_kit/bean/response_bean.dart';

/// A widget that displays transcription text with segments highlighted.
class TranscriptionDisplay extends StatelessWidget {
  /// Create a transcription display.
  const TranscriptionDisplay({
    super.key,
    required this.response,
    this.style,
    this.segmentStyle,
    this.showTimestamps = false,
    this.highlightedSegmentIndex,
    this.highlightColor,
    this.onSegmentTap,
  });

  /// The transcription response to display.
  final WhisperTranscribeResponse response;

  /// Text style for the main text.
  final TextStyle? style;

  /// Text style for individual segments.
  final TextStyle? segmentStyle;

  /// Whether to show timestamps.
  final bool showTimestamps;

  /// Index of the currently highlighted segment.
  final int? highlightedSegmentIndex;

  /// Color for highlighted segment.
  final Color? highlightColor;

  /// Callback when a segment is tapped.
  final void Function(int index, WhisperTranscribeSegment segment)?
      onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final segments = response.segments;

    if (segments == null || segments.isEmpty) {
      return Text(response.text, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(segments.length, (index) {
        final segment = segments[index];
        final isHighlighted = highlightedSegmentIndex == index;

        return GestureDetector(
          onTap:
              onSegmentTap != null ? () => onSegmentTap!(index, segment) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: isHighlighted
                ? (highlightColor ??
                    Theme.of(context).primaryColor.withAlpha(50))
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTimestamps) ...[
                  SizedBox(
                    width: 60,
                    child: Text(
                      _formatTimestamp(segment.fromTs),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    segment.text.trim(),
                    style: segmentStyle ?? style,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatTimestamp(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// A button widget for recording with visual feedback.
class RecordButton extends StatelessWidget {
  /// Create a record button.
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    this.size = 64,
    this.recordingColor,
    this.idleColor,
    this.iconColor,
  });

  /// Whether currently recording.
  final bool isRecording;

  /// Callback when button is pressed.
  final VoidCallback onPressed;

  /// Button size.
  final double size;

  /// Color when recording.
  final Color? recordingColor;

  /// Color when idle.
  final Color? idleColor;

  /// Icon color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = recordingColor ?? Colors.red;
    final inactiveColor = idleColor ?? Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? activeColor : inactiveColor,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? activeColor : inactiveColor).withAlpha(100),
              blurRadius: isRecording ? 20 : 10,
              spreadRadius: isRecording ? 5 : 2,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          color: iconColor ?? Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// A simple audio waveform visualization.
class AudioWaveform extends StatelessWidget {
  /// Create an audio waveform.
  const AudioWaveform({
    super.key,
    required this.levels,
    this.width,
    this.height = 50,
    this.barWidth = 3,
    this.barSpacing = 2,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius,
  });

  /// Audio levels (0.0 - 1.0) for each bar.
  final List<double> levels;

  /// Widget width (defaults to fill available space).
  final double? width;

  /// Widget height.
  final double height;

  /// Width of each bar.
  final double barWidth;

  /// Spacing between bars.
  final double barSpacing;

  /// Color for active/filled bars.
  final Color? activeColor;

  /// Color for inactive/empty bars.
  final Color? inactiveColor;

  /// Border radius for bars.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          levels.length,
          (index) {
            final level = levels[index].clamp(0.0, 1.0);
            final barHeight = height * (0.2 + level * 0.8);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: barSpacing / 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: activeColor ?? Theme.of(context).primaryColor,
                  borderRadius:
                      borderRadius ?? BorderRadius.circular(barWidth / 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A progress indicator for model downloads.
class ModelDownloadProgress extends StatelessWidget {
  /// Create a model download progress indicator.
  const ModelDownloadProgress({
    super.key,
    required this.progress,
    required this.modelName,
    this.downloadedBytes,
    this.totalBytes,
    this.showPercentage = true,
    this.showBytes = true,
  });

  /// Download progress (0.0 - 1.0).
  final double progress;

  /// Name of the model being downloaded.
  final String modelName;

  /// Bytes downloaded so far.
  final int? downloadedBytes;

  /// Total bytes to download.
  final int? totalBytes;

  /// Whether to show percentage.
  final bool showPercentage;

  /// Whether to show bytes.
  final bool showBytes;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading $modelName',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (showPercentage)
              Text(
                '$percentage%',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress),
        if (showBytes && downloadedBytes != null && totalBytes != null) ...[
          const SizedBox(height: 4),
          Text(
            '${_formatBytes(downloadedBytes!)} / ${_formatBytes(totalBytes!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// A language selector dropdown.
class LanguageSelector extends StatelessWidget {
  /// Create a language selector.
  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.languages,
    this.includeAuto = true,
    this.decoration,
  });

  /// Currently selected language code.
  final String selectedLanguage;

  /// Callback when language changes.
  final void Function(String languageCode) onLanguageChanged;

  /// Available languages (defaults to common languages).
  final Map<String, String>? languages;

  /// Whether to include "Auto-detect" option.
  final bool includeAuto;

  /// Decoration for the dropdown.
  final InputDecoration? decoration;

  static const _defaultLanguages = {
    'auto': 'Auto-detect',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  @override
  Widget build(BuildContext context) {
    final langs = languages ?? _defaultLanguages;
    final items = includeAuto || langs.containsKey('auto')
        ? langs
        : {'auto': 'Auto-detect', ...langs};

    return InputDecorator(
      decoration: decoration ??
          const InputDecoration(
            labelText: 'Language',
            border: OutlineInputBorder(),
          ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLanguage,
          isDense: true,
          isExpanded: true,
          items: items.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onLanguageChanged(value);
          },
        ),
      ),
    );
  }
}
