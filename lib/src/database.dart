/// Database integration for storing transcription results.
///
/// Abstract database layer supporting SQLite, IndexedDB, etc.
library;

import 'dart:async';

import 'package:whisper_kit/bean/response_bean.dart';

/// Stored transcription record.
class TranscriptionRecord {
  TranscriptionRecord({
    required this.id,
    required this.audioPath,
    required this.text,
    required this.createdAt,
    this.segments,
    this.language,
    this.modelName,
    this.duration,
    this.tags,
    this.metadata,
  });

  /// Unique record ID.
  final String id;

  /// Original audio path.
  final String audioPath;

  /// Transcribed text.
  final String text;

  /// When transcription was created.
  final DateTime createdAt;

  /// Segments with timestamps.
  final List<TranscriptionSegmentRecord>? segments;

  /// Detected/specified language.
  final String? language;

  /// Model used for transcription.
  final String? modelName;

  /// Audio duration in milliseconds.
  final int? duration;

  /// User-defined tags.
  final List<String>? tags;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Create from WhisperTranscribeResponse.
  factory TranscriptionRecord.fromResponse(
    WhisperTranscribeResponse response, {
    required String id,
    required String audioPath,
    String? language,
    String? modelName,
  }) {
    return TranscriptionRecord(
      id: id,
      audioPath: audioPath,
      text: response.text,
      createdAt: DateTime.now(),
      segments: response.segments?.map((s) {
        return TranscriptionSegmentRecord(
          text: s.text,
          startMs: s.fromTs.inMilliseconds,
          endMs: s.toTs.inMilliseconds,
        );
      }).toList(),
      language: language,
      modelName: modelName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioPath': audioPath,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'segments': segments?.map((s) => s.toJson()).toList(),
        'language': language,
        'modelName': modelName,
        'duration': duration,
        'tags': tags,
        'metadata': metadata,
      };

  factory TranscriptionRecord.fromJson(Map<String, dynamic> json) {
    return TranscriptionRecord(
      id: json['id'] as String,
      audioPath: json['audioPath'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      segments: (json['segments'] as List<dynamic>?)
          ?.map((s) =>
              TranscriptionSegmentRecord.fromJson(s as Map<String, dynamic>))
          .toList(),
      language: json['language'] as String?,
      modelName: json['modelName'] as String?,
      duration: json['duration'] as int?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Segment record for database storage.
class TranscriptionSegmentRecord {
  const TranscriptionSegmentRecord({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;

  Map<String, dynamic> toJson() => {
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory TranscriptionSegmentRecord.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegmentRecord(
      text: json['text'] as String,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
    );
  }
}

/// Query options for searching transcriptions.
class TranscriptionQuery {
  const TranscriptionQuery({
    this.searchText,
    this.language,
    this.tags,
    this.fromDate,
    this.toDate,
    this.limit,
    this.offset,
    this.orderBy,
    this.descending = true,
  });

  /// Text to search for.
  final String? searchText;

  /// Filter by language.
  final String? language;

  /// Filter by tags.
  final List<String>? tags;

  /// Filter by date range start.
  final DateTime? fromDate;

  /// Filter by date range end.
  final DateTime? toDate;

  /// Maximum results to return.
  final int? limit;

  /// Offset for pagination.
  final int? offset;

  /// Field to order by.
  final String? orderBy;

  /// Whether to order descending.
  final bool descending;
}

/// Abstract database interface for transcription storage.
abstract class TranscriptionDatabase {
  /// Initialize the database.
  Future<void> initialize();

  /// Close the database.
  Future<void> close();

  /// Save a transcription record.
  Future<void> save(TranscriptionRecord record);

  /// Get a transcription by ID.
  Future<TranscriptionRecord?> get(String id);

  /// Delete a transcription by ID.
  Future<bool> delete(String id);

  /// Query transcriptions.
  Future<List<TranscriptionRecord>> query(TranscriptionQuery query);

  /// Get all transcriptions.
  Future<List<TranscriptionRecord>> getAll({int? limit, int? offset});

  /// Count total records.
  Future<int> count();

  /// Search by text.
  Future<List<TranscriptionRecord>> search(String text, {int? limit});

  /// Clear all records.
  Future<void> clear();
}

/// In-memory implementation for testing.
class InMemoryTranscriptionDatabase implements TranscriptionDatabase {
  final Map<String, TranscriptionRecord> _records = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> save(TranscriptionRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<TranscriptionRecord?> get(String id) async {
    return _records[id];
  }

  @override
  Future<bool> delete(String id) async {
    return _records.remove(id) != null;
  }

  @override
  Future<List<TranscriptionRecord>> query(TranscriptionQuery query) async {
    var results = _records.values.toList();

    // Apply filters
    if (query.searchText != null) {
      results = results
          .where((r) =>
              r.text.toLowerCase().contains(query.searchText!.toLowerCase()))
          .toList();
    }
    if (query.language != null) {
      results = results.where((r) => r.language == query.language).toList();
    }
    if (query.fromDate != null) {
      results =
          results.where((r) => r.createdAt.isAfter(query.fromDate!)).toList();
    }
    if (query.toDate != null) {
      results =
          results.where((r) => r.createdAt.isBefore(query.toDate!)).toList();
    }

    // Sort
    results.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return query.descending ? -cmp : cmp;
    });

    // Paginate
    if (query.offset != null) {
      results = results.skip(query.offset!).toList();
    }
    if (query.limit != null) {
      results = results.take(query.limit!).toList();
    }

    return results;
  }

  @override
  Future<List<TranscriptionRecord>> getAll({int? limit, int? offset}) async {
    return query(TranscriptionQuery(limit: limit, offset: offset));
  }

  @override
  Future<int> count() async => _records.length;

  @override
  Future<List<TranscriptionRecord>> search(String text, {int? limit}) async {
    return query(TranscriptionQuery(searchText: text, limit: limit));
  }

  @override
  Future<void> clear() async => _records.clear();
}
