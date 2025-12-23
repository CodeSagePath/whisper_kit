/// Export transcriptions to various formats.
///
/// Supports SRT, VTT, JSON, and plain text formats.
library;

import 'dart:convert';
import 'package:whisper_kit/bean/response_bean.dart';

/// Supported export formats.
enum ExportFormat {
  /// SubRip subtitle format (.srt)
  srt,

  /// WebVTT subtitle format (.vtt)
  vtt,

  /// JSON format
  json,

  /// Plain text
  text,
}

/// Extension for export format file extensions.
extension ExportFormatExtension on ExportFormat {
  /// File extension for this format.
  String get extension {
    switch (this) {
      case ExportFormat.srt:
        return 'srt';
      case ExportFormat.vtt:
        return 'vtt';
      case ExportFormat.json:
        return 'json';
      case ExportFormat.text:
        return 'txt';
    }
  }

  /// MIME type for this format.
  String get mimeType {
    switch (this) {
      case ExportFormat.srt:
        return 'application/x-subrip';
      case ExportFormat.vtt:
        return 'text/vtt';
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.text:
        return 'text/plain';
    }
  }
}

/// Transcription exporter for converting results to various formats.
class TranscriptionExporter {
  const TranscriptionExporter._();

  /// Export transcription to the specified format.
  static String export(
    WhisperTranscribeResponse response,
    ExportFormat format,
  ) {
    switch (format) {
      case ExportFormat.srt:
        return toSrt(response);
      case ExportFormat.vtt:
        return toVtt(response);
      case ExportFormat.json:
        return toJson(response);
      case ExportFormat.text:
        return toPlainText(response);
    }
  }

  /// Convert to SRT (SubRip) format.
  ///
  /// ```
  /// 1
  /// 00:00:00,000 --> 00:00:02,500
  /// Hello world
  ///
  /// 2
  /// 00:00:02,500 --> 00:00:05,000
  /// How are you?
  /// ```
  static String toSrt(WhisperTranscribeResponse response) {
    final segments = response.segments;
    if (segments == null || segments.isEmpty) {
      return '1\n00:00:00,000 --> 00:00:01,000\n${response.text}\n';
    }

    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.writeln(i + 1);
      buffer.writeln(
          '${_formatSrtTime(segment.fromTs)} --> ${_formatSrtTime(segment.toTs)}');
      buffer.writeln(segment.text.trim());
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Convert to WebVTT format.
  ///
  /// ```
  /// WEBVTT
  ///
  /// 00:00:00.000 --> 00:00:02.500
  /// Hello world
  ///
  /// 00:00:02.500 --> 00:00:05.000
  /// How are you?
  /// ```
  static String toVtt(WhisperTranscribeResponse response) {
    final segments = response.segments;
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    if (segments == null || segments.isEmpty) {
      buffer.writeln('00:00:00.000 --> 00:00:01.000');
      buffer.writeln(response.text);
      return buffer.toString();
    }

    for (final segment in segments) {
      buffer.writeln(
          '${_formatVttTime(segment.fromTs)} --> ${_formatVttTime(segment.toTs)}');
      buffer.writeln(segment.text.trim());
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Convert to JSON format.
  static String toJson(WhisperTranscribeResponse response) {
    final data = {
      'text': response.text,
      'segments': response.segments
              ?.map((s) => {
                    'from': s.fromTs.inMilliseconds,
                    'to': s.toTs.inMilliseconds,
                    'text': s.text,
                  })
              .toList() ??
          [],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Convert to plain text.
  static String toPlainText(WhisperTranscribeResponse response) {
    return response.text;
  }

  /// Format duration as SRT timestamp (HH:MM:SS,mmm).
  static String _formatSrtTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds =
        (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  /// Format duration as VTT timestamp (HH:MM:SS.mmm).
  static String _formatVttTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds =
        (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}

/// Extension on WhisperTranscribeResponse for easy export.
extension TranscriptionExportExtension on WhisperTranscribeResponse {
  /// Export to SRT format.
  String toSrt() => TranscriptionExporter.toSrt(this);

  /// Export to VTT format.
  String toVtt() => TranscriptionExporter.toVtt(this);

  /// Export to JSON format.
  String toJsonFormat() => TranscriptionExporter.toJson(this);

  /// Export to plain text.
  String toPlainText() => TranscriptionExporter.toPlainText(this);

  /// Export to any supported format.
  String exportAs(ExportFormat format) =>
      TranscriptionExporter.export(this, format);
}
