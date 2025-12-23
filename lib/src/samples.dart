/// Sample app templates for WhisperKit.
///
/// Pre-built components for common use cases.
library;

import 'package:flutter/material.dart';

/// Voice note app template component.
class VoiceNoteAppTemplate {
  const VoiceNoteAppTemplate._();

  /// Create a simple voice note card.
  static Widget noteCard({
    required String title,
    required String text,
    required DateTime createdAt,
    Duration? duration,
    VoidCallback? onPlay,
    VoidCallback? onDelete,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (duration != null || onPlay != null || onDelete != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (duration != null)
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const Spacer(),
                  if (onPlay != null)
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: onPlay,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

/// Meeting transcription app template.
class MeetingAppTemplate {
  const MeetingAppTemplate._();

  /// Create a meeting transcript view.
  static Widget transcriptView({
    required List<MeetingSpeakerEntry> entries,
    ScrollController? controller,
  }) {
    return ListView.builder(
      controller: controller,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: entry.speakerColor,
                radius: 16,
                child: Text(
                  entry.speakerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.speakerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.timestamp,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(entry.text),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Meeting speaker entry.
class MeetingSpeakerEntry {
  const MeetingSpeakerEntry({
    required this.speakerName,
    required this.text,
    required this.timestamp,
    this.speakerColor = Colors.blue,
  });

  final String speakerName;
  final String text;
  final String timestamp;
  final Color speakerColor;
}

/// Language learning app template.
class LanguageLearningTemplate {
  const LanguageLearningTemplate._();

  /// Create a pronunciation feedback widget.
  static Widget pronunciationFeedback({
    required String expectedText,
    required String spokenText,
    required double accuracy,
  }) {
    final color = accuracy >= 0.8
        ? Colors.green
        : accuracy >= 0.5
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expected:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(expectedText),
            const SizedBox(height: 12),
            const Text(
              'You said:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(spokenText),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: accuracy,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: ${(accuracy * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessibility app template.
class AccessibilityTemplate {
  const AccessibilityTemplate._();

  /// Create a real-time caption display.
  static Widget captionDisplay({
    required String text,
    double fontSize = 24,
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.isNotEmpty ? text : '...',
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Create a transcript history view.
  static Widget transcriptHistory({
    required List<String> lines,
    int maxLines = 5,
  }) {
    final displayLines = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayLines
          .map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 16),
                ),
              ))
          .toList(),
    );
  }
}
