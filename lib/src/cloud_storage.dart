/// Cloud storage integration for remote audio files.
///
/// Abstract interface for various cloud storage providers.
library;

import 'dart:async';
import 'dart:io';

/// Cloud storage provider types.
enum CloudProvider {
  /// Amazon S3.
  s3,

  /// Google Cloud Storage.
  gcs,

  /// Microsoft Azure Blob Storage.
  azure,

  /// Firebase Storage.
  firebase,

  /// Dropbox.
  dropbox,

  /// Generic HTTP.
  http,
}

/// Cloud file metadata.
class CloudFile {
  const CloudFile({
    required this.path,
    required this.provider,
    this.bucket,
    this.region,
    this.size,
    this.contentType,
    this.lastModified,
    this.metadata,
  });

  /// File path in cloud storage.
  final String path;

  /// Cloud provider.
  final CloudProvider provider;

  /// Bucket/container name.
  final String? bucket;

  /// Region (if applicable).
  final String? region;

  /// File size in bytes.
  final int? size;

  /// Content type.
  final String? contentType;

  /// Last modified date.
  final DateTime? lastModified;

  /// Additional metadata.
  final Map<String, String>? metadata;

  /// Full cloud URL.
  String get url {
    switch (provider) {
      case CloudProvider.s3:
        return 'https://${bucket ?? "bucket"}.s3.${region ?? "us-east-1"}.amazonaws.com/$path';
      case CloudProvider.gcs:
        return 'https://storage.googleapis.com/${bucket ?? "bucket"}/$path';
      case CloudProvider.firebase:
        return 'gs://${bucket ?? "bucket"}/$path';
      default:
        return path;
    }
  }
}

/// Download progress info.
class DownloadProgress {
  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    this.speed,
  });

  final int bytesDownloaded;
  final int totalBytes;
  final int? speed; // bytes per second

  double get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : 0;
  int get percent => (progress * 100).round();

  Duration? get estimatedTimeRemaining {
    if (speed == null || speed! <= 0) return null;
    final remaining = totalBytes - bytesDownloaded;
    return Duration(seconds: remaining ~/ speed!);
  }
}

/// Abstract cloud storage interface.
abstract class CloudStorageProvider {
  /// Download a file from cloud storage.
  Future<File> download(
    CloudFile file, {
    String? localPath,
    void Function(DownloadProgress)? onProgress,
  });

  /// Check if a file exists.
  Future<bool> exists(CloudFile file);

  /// Get file metadata.
  Future<CloudFile?> getMetadata(String path);

  /// List files in a directory.
  Future<List<CloudFile>> list(String prefix, {int? maxResults});

  /// Upload a file to cloud storage.
  Future<CloudFile> upload(
    File localFile,
    String remotePath, {
    void Function(DownloadProgress)? onProgress,
    Map<String, String>? metadata,
  });

  /// Delete a file from cloud storage.
  Future<bool> delete(CloudFile file);

  /// Generate a signed URL for temporary access.
  Future<String> getSignedUrl(
    CloudFile file, {
    Duration expiration = const Duration(hours: 1),
  });
}

/// Cloud storage manager for handling remote audio files.
class CloudStorageManager {
  CloudStorageManager({
    this.cacheDir,
    this.maxCacheSizeMB = 500,
  });

  /// Local cache directory.
  final String? cacheDir;

  /// Maximum cache size in MB.
  final int maxCacheSizeMB;

  final Map<CloudProvider, CloudStorageProvider> _providers = {};
  final Map<String, File> _cache = {};

  /// Register a provider.
  void registerProvider(CloudProvider type, CloudStorageProvider provider) {
    _providers[type] = provider;
  }

  /// Get a provider.
  CloudStorageProvider? getProvider(CloudProvider type) => _providers[type];

  /// Download a cloud file for processing.
  Future<File?> downloadForProcessing(
    CloudFile file, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    // Check cache first
    final cacheKey = '${file.provider.name}:${file.path}';
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (cached.existsSync()) {
        return cached;
      }
      _cache.remove(cacheKey);
    }

    // Get provider
    final provider = _providers[file.provider];
    if (provider == null) return null;

    // Download
    final localPath =
        cacheDir != null ? '$cacheDir/${file.path.split('/').last}' : null;

    final localFile = await provider.download(
      file,
      localPath: localPath,
      onProgress: onProgress,
    );

    // Cache
    _cache[cacheKey] = localFile;
    return localFile;
  }

  /// Clear cached files.
  Future<int> clearCache() async {
    var count = 0;
    for (final file in _cache.values) {
      if (file.existsSync()) {
        await file.delete();
        count++;
      }
    }
    _cache.clear();
    return count;
  }

  /// Get cache size in MB.
  int getCacheSizeMB() {
    var size = 0;
    for (final file in _cache.values) {
      if (file.existsSync()) {
        size += file.lengthSync();
      }
    }
    return size ~/ (1024 * 1024);
  }
}
