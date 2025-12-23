/// Transcription caching for storing and retrieving results.
library;

import 'dart:convert';
import 'dart:io';

import 'package:whisper_kit/bean/response_bean.dart';

/// Cached transcription entry.
class CachedTranscription {
  CachedTranscription({
    required this.audioPath,
    required this.response,
    required this.createdAt,
    this.audioHash,
    this.modelName,
    this.language,
  });

  /// Path to the original audio file.
  final String audioPath;

  /// The transcription response.
  final WhisperTranscribeResponse response;

  /// When the transcription was created.
  final DateTime createdAt;

  /// Hash of the audio file for validation.
  final String? audioHash;

  /// Model used for transcription.
  final String? modelName;

  /// Language used/detected.
  final String? language;

  /// Age of the cache entry.
  Duration get age => DateTime.now().difference(createdAt);

  /// Whether the cache entry is expired.
  bool isExpired(Duration maxAge) => age > maxAge;

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'response': {
          '@type': response.type,
          'text': response.text,
          'segments': response.segments
              ?.map((s) => {
                    'from_ts': s.fromTs.inMilliseconds ~/ 10,
                    'to_ts': s.toTs.inMilliseconds ~/ 10,
                    'text': s.text,
                  })
              .toList(),
        },
        'createdAt': createdAt.toIso8601String(),
        'audioHash': audioHash,
        'modelName': modelName,
        'language': language,
      };

  factory CachedTranscription.fromJson(Map<String, dynamic> json) {
    return CachedTranscription(
      audioPath: json['audioPath'] as String,
      response: WhisperTranscribeResponse.fromJson(
        json['response'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      audioHash: json['audioHash'] as String?,
      modelName: json['modelName'] as String?,
      language: json['language'] as String?,
    );
  }
}

/// Simple file-based transcription cache.
class TranscriptionCache {
  TranscriptionCache({
    required this.cacheDir,
    this.maxAge = const Duration(days: 7),
    this.maxEntries = 100,
  });

  /// Directory to store cache files.
  final String cacheDir;

  /// Maximum age of cache entries.
  final Duration maxAge;

  /// Maximum number of cached entries.
  final int maxEntries;

  /// Get cache file path for an audio file.
  String _getCachePath(String audioPath) {
    final hash = audioPath.hashCode.toRadixString(16);
    return '$cacheDir/cache_$hash.json';
  }

  /// Get cached transcription for an audio file.
  Future<CachedTranscription?> get(String audioPath) async {
    final cachePath = _getCachePath(audioPath);
    final file = File(cachePath);

    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final cached = CachedTranscription.fromJson(json);

      // Check if expired
      if (cached.isExpired(maxAge)) {
        await file.delete();
        return null;
      }

      return cached;
    } catch (e) {
      // Invalid cache file, delete it
      await file.delete();
      return null;
    }
  }

  /// Store transcription in cache.
  Future<void> put(CachedTranscription entry) async {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final cachePath = _getCachePath(entry.audioPath);
    final file = File(cachePath);
    await file.writeAsString(jsonEncode(entry.toJson()));

    // Clean up old entries if needed
    await _cleanupIfNeeded();
  }

  /// Remove cached transcription.
  Future<void> remove(String audioPath) async {
    final cachePath = _getCachePath(audioPath);
    final file = File(cachePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Clear all cached transcriptions.
  Future<void> clear() async {
    final dir = Directory(cacheDir);
    if (dir.existsSync()) {
      await for (final entity in dir.list()) {
        if (entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    }
  }

  /// Get all cached entries.
  Future<List<CachedTranscription>> getAll() async {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) return [];

    final entries = <CachedTranscription>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          entries.add(CachedTranscription.fromJson(json));
        } catch (_) {
          // Skip invalid files
        }
      }
    }
    return entries;
  }

  /// Clean up expired and excess entries.
  Future<void> _cleanupIfNeeded() async {
    final entries = await getAll();

    // Remove expired entries
    final valid = entries.where((e) => !e.isExpired(maxAge)).toList();

    // If still too many, remove oldest
    if (valid.length > maxEntries) {
      valid.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (var i = 0; i < valid.length - maxEntries; i++) {
        await remove(valid[i].audioPath);
      }
    }
  }
}
