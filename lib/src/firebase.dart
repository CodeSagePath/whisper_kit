/// Firebase integration utilities.
///
/// Helper classes for Firebase Storage and Firestore integration.
library;

import 'dart:async';

/// Firebase transcription record.
class FirebaseTranscription {
  const FirebaseTranscription({
    required this.id,
    required this.text,
    required this.audioUrl,
    required this.createdAt,
    this.userId,
    this.language,
    this.duration,
    this.segments,
    this.metadata,
  });

  /// Document ID.
  final String id;

  /// Transcribed text.
  final String text;

  /// Audio file URL in Firebase Storage.
  final String audioUrl;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Owner user ID.
  final String? userId;

  /// Detected language.
  final String? language;

  /// Audio duration in seconds.
  final double? duration;

  /// Segments with timestamps.
  final List<Map<String, dynamic>>? segments;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toFirestore() => {
        'text': text,
        'audioUrl': audioUrl,
        'createdAt': createdAt.toIso8601String(),
        'userId': userId,
        'language': language,
        'duration': duration,
        'segments': segments,
        'metadata': metadata,
      };

  factory FirebaseTranscription.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FirebaseTranscription(
      id: id,
      text: data['text'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      userId: data['userId'] as String?,
      language: data['language'] as String?,
      duration: (data['duration'] as num?)?.toDouble(),
      segments:
          (data['segments'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Firebase Storage configuration.
class FirebaseStorageConfig {
  const FirebaseStorageConfig({
    this.bucket,
    this.audioFolder = 'audio',
    this.modelFolder = 'models',
    this.maxUploadSize = 100 * 1024 * 1024, // 100MB
    this.cacheControl = 'public, max-age=31536000',
  });

  /// Storage bucket name.
  final String? bucket;

  /// Folder for audio files.
  final String audioFolder;

  /// Folder for model files.
  final String modelFolder;

  /// Maximum upload size in bytes.
  final int maxUploadSize;

  /// Cache control header.
  final String cacheControl;
}

/// Firebase Firestore configuration.
class FirestoreConfig {
  const FirestoreConfig({
    this.transcriptionCollection = 'transcriptions',
    this.userCollection = 'users',
    this.enableOffline = true,
    this.cacheSizeBytes = 40 * 1024 * 1024, // 40MB
  });

  /// Collection for transcriptions.
  final String transcriptionCollection;

  /// Collection for users.
  final String userCollection;

  /// Enable offline persistence.
  final bool enableOffline;

  /// Cache size in bytes.
  final int cacheSizeBytes;
}

/// Abstract Firebase service interface.
abstract class FirebaseTranscriptionService {
  /// Save a transcription to Firestore.
  Future<String> saveTranscription(FirebaseTranscription transcription);

  /// Get a transcription by ID.
  Future<FirebaseTranscription?> getTranscription(String id);

  /// Delete a transcription.
  Future<bool> deleteTranscription(String id);

  /// Get transcriptions for a user.
  Future<List<FirebaseTranscription>> getUserTranscriptions(
    String userId, {
    int? limit,
    String? startAfter,
  });

  /// Search transcriptions.
  Future<List<FirebaseTranscription>> searchTranscriptions(
    String query, {
    String? userId,
    int? limit,
  });

  /// Upload audio to Firebase Storage.
  Future<String> uploadAudio(
    String localPath, {
    String? customPath,
    void Function(double progress)? onProgress,
  });

  /// Download audio from Firebase Storage.
  Future<String> downloadAudio(
    String remotePath, {
    String? localPath,
    void Function(double progress)? onProgress,
  });
}

/// Firebase helper utilities.
class FirebaseHelpers {
  const FirebaseHelpers._();

  /// Generate a unique document ID.
  static String generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  /// Generate a storage path for audio.
  static String audioPath(String userId, String fileName) {
    return 'audio/$userId/$fileName';
  }

  /// Parse Firestore timestamp.
  static DateTime? parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.tryParse(timestamp);
    // Handle Firestore Timestamp type
    return null;
  }

  /// Format duration for display.
  static String formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
