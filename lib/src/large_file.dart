/// Large file handling utilities.
///
/// Supports processing audio files larger than 100MB.
library;

import 'dart:io';

/// File size thresholds.
class FileSizeThresholds {
  const FileSizeThresholds._();

  /// Small file threshold (10MB).
  static const int small = 10 * 1024 * 1024;

  /// Medium file threshold (50MB).
  static const int medium = 50 * 1024 * 1024;

  /// Large file threshold (100MB).
  static const int large = 100 * 1024 * 1024;

  /// Very large file threshold (500MB).
  static const int veryLarge = 500 * 1024 * 1024;
}

/// File size category.
enum FileSizeCategory {
  /// Under 10MB.
  small,

  /// 10MB - 50MB.
  medium,

  /// 50MB - 100MB.
  large,

  /// Over 100MB.
  veryLarge,
}

/// Chunked audio file for processing large files.
class AudioChunk {
  const AudioChunk({
    required this.index,
    required this.path,
    required this.startTime,
    required this.endTime,
    required this.size,
  });

  /// Chunk index (0-based).
  final int index;

  /// Path to chunk file.
  final String path;

  /// Start time in the original file.
  final Duration startTime;

  /// End time in the original file.
  final Duration endTime;

  /// Chunk size in bytes.
  final int size;

  /// Duration of this chunk.
  Duration get duration => endTime - startTime;
}

/// Large file processing configuration.
class LargeFileConfig {
  const LargeFileConfig({
    this.chunkDuration = const Duration(minutes: 10),
    this.overlapDuration = const Duration(seconds: 5),
    this.maxChunkSize = 50 * 1024 * 1024,
    this.cleanupChunks = true,
  });

  /// Duration of each chunk.
  final Duration chunkDuration;

  /// Overlap between chunks for context.
  final Duration overlapDuration;

  /// Maximum chunk size in bytes.
  final int maxChunkSize;

  /// Whether to cleanup chunk files after processing.
  final bool cleanupChunks;
}

/// Large file handler utilities.
class LargeFileHandler {
  const LargeFileHandler._();

  /// Get file size category.
  static FileSizeCategory categorize(int sizeBytes) {
    if (sizeBytes < FileSizeThresholds.small) {
      return FileSizeCategory.small;
    } else if (sizeBytes < FileSizeThresholds.medium) {
      return FileSizeCategory.medium;
    } else if (sizeBytes < FileSizeThresholds.large) {
      return FileSizeCategory.large;
    } else {
      return FileSizeCategory.veryLarge;
    }
  }

  /// Check if file needs chunking.
  static bool needsChunking(String filePath,
      {int threshold = FileSizeThresholds.large}) {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    return file.lengthSync() >= threshold;
  }

  /// Calculate number of chunks needed.
  static int calculateChunkCount(
    int fileSizeBytes,
    int maxChunkSizeBytes,
  ) {
    return (fileSizeBytes / maxChunkSizeBytes).ceil();
  }

  /// Estimate processing time based on file size.
  static Duration estimateProcessingTime(
    int fileSizeBytes, {
    double bytesPerSecond = 100000, // ~100KB/s for real-time
  }) {
    final seconds = fileSizeBytes / bytesPerSecond;
    return Duration(seconds: seconds.round());
  }

  /// Get recommended configuration based on file size.
  static LargeFileConfig getRecommendedConfig(int fileSizeBytes) {
    final category = categorize(fileSizeBytes);

    switch (category) {
      case FileSizeCategory.small:
        return const LargeFileConfig(
          chunkDuration: Duration(minutes: 30),
          overlapDuration: Duration.zero,
        );
      case FileSizeCategory.medium:
        return const LargeFileConfig(
          chunkDuration: Duration(minutes: 15),
          overlapDuration: Duration(seconds: 3),
        );
      case FileSizeCategory.large:
        return const LargeFileConfig(
          chunkDuration: Duration(minutes: 10),
          overlapDuration: Duration(seconds: 5),
        );
      case FileSizeCategory.veryLarge:
        return const LargeFileConfig(
          chunkDuration: Duration(minutes: 5),
          overlapDuration: Duration(seconds: 5),
        );
    }
  }

  /// Calculate memory requirements for file size.
  static int estimateMemoryRequired(int fileSizeBytes) {
    // Rule of thumb: 2x file size for processing buffer
    return fileSizeBytes * 2;
  }

  /// Check if device has sufficient memory.
  static bool hasSufficientMemory(int fileSizeBytes, int availableMemoryMB) {
    final requiredMB = estimateMemoryRequired(fileSizeBytes) ~/ (1024 * 1024);
    return availableMemoryMB >= requiredMB;
  }
}

/// Resource cleanup utilities.
class ResourceCleanup {
  const ResourceCleanup._();

  /// Clean up audio chunks after processing.
  static Future<int> cleanupChunks(List<AudioChunk> chunks) async {
    var count = 0;
    for (final chunk in chunks) {
      final file = File(chunk.path);
      if (file.existsSync()) {
        await file.delete();
        count++;
      }
    }
    return count;
  }

  /// Clean up temporary directory.
  static Future<int> cleanupDirectory(
    String dirPath, {
    Duration? olderThan,
    List<String>? extensions,
  }) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;

    var count = 0;
    final now = DateTime.now();

    await for (final entity in dir.list()) {
      if (entity is File) {
        // Check age if specified
        if (olderThan != null) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) < olderThan) continue;
        }

        // Check extension if specified
        if (extensions != null && extensions.isNotEmpty) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (!extensions.contains(ext)) continue;
        }

        await entity.delete();
        count++;
      }
    }
    return count;
  }

  /// Get directory size in bytes.
  static Future<int> getDirectorySize(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;

    var size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// Format bytes as human readable string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
