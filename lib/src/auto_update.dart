/// Auto-updating models support.
///
/// Check for and download model updates automatically.
library;

import 'dart:async';

/// Model version information.
class ModelVersion {
  const ModelVersion({
    required this.modelName,
    required this.version,
    required this.downloadUrl,
    this.releaseDate,
    this.fileSize,
    this.sha256Hash,
    this.releaseNotes,
    this.minAppVersion,
  });

  /// Model name (e.g., "tiny", "base").
  final String modelName;

  /// Version string (e.g., "1.0.0").
  final String version;

  /// URL to download the model.
  final String downloadUrl;

  /// When this version was released.
  final DateTime? releaseDate;

  /// File size in bytes.
  final int? fileSize;

  /// SHA-256 hash for verification.
  final String? sha256Hash;

  /// Release notes.
  final String? releaseNotes;

  /// Minimum app version required.
  final String? minAppVersion;

  /// Parse version string to comparable parts.
  List<int> get versionParts {
    return version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  /// Compare versions.
  int compareTo(ModelVersion other) {
    final a = versionParts;
    final b = other.versionParts;

    for (var i = 0; i < a.length || i < b.length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  /// Check if this version is newer than another.
  bool isNewerThan(ModelVersion other) => compareTo(other) > 0;

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'version': version,
        'downloadUrl': downloadUrl,
        'releaseDate': releaseDate?.toIso8601String(),
        'fileSize': fileSize,
        'sha256Hash': sha256Hash,
        'releaseNotes': releaseNotes,
        'minAppVersion': minAppVersion,
      };

  factory ModelVersion.fromJson(Map<String, dynamic> json) {
    return ModelVersion(
      modelName: json['modelName'] as String,
      version: json['version'] as String,
      downloadUrl: json['downloadUrl'] as String,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      fileSize: json['fileSize'] as int?,
      sha256Hash: json['sha256Hash'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
      minAppVersion: json['minAppVersion'] as String?,
    );
  }
}

/// Model update check result.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    this.currentVersion,
    this.availableVersion,
    this.error,
  });

  /// Whether an update is available.
  final bool hasUpdate;

  /// Currently installed version.
  final ModelVersion? currentVersion;

  /// Available version to update to.
  final ModelVersion? availableVersion;

  /// Error message if check failed.
  final String? error;

  factory UpdateCheckResult.noUpdate() =>
      const UpdateCheckResult(hasUpdate: false);

  factory UpdateCheckResult.updateAvailable(
    ModelVersion current,
    ModelVersion available,
  ) =>
      UpdateCheckResult(
        hasUpdate: true,
        currentVersion: current,
        availableVersion: available,
      );

  factory UpdateCheckResult.error(String error) =>
      UpdateCheckResult(hasUpdate: false, error: error);
}

/// Auto-update configuration.
class AutoUpdateConfig {
  const AutoUpdateConfig({
    this.enabled = true,
    this.checkOnStartup = true,
    this.checkInterval = const Duration(days: 7),
    this.autoDownload = false,
    this.wifiOnly = true,
    this.notifyUser = true,
  });

  /// Whether auto-update is enabled.
  final bool enabled;

  /// Check for updates on app startup.
  final bool checkOnStartup;

  /// How often to check for updates.
  final Duration checkInterval;

  /// Automatically download updates.
  final bool autoDownload;

  /// Only download on WiFi.
  final bool wifiOnly;

  /// Notify user about updates.
  final bool notifyUser;
}

/// Abstract interface for update source.
abstract class ModelUpdateSource {
  /// Fetch latest version info for a model.
  Future<ModelVersion?> getLatestVersion(String modelName);

  /// Fetch available versions for a model.
  Future<List<ModelVersion>> getAvailableVersions(String modelName);
}

/// Model update manager.
class ModelUpdateManager {
  ModelUpdateManager({
    this.config = const AutoUpdateConfig(),
    this.updateSource,
  });

  /// Configuration.
  final AutoUpdateConfig config;

  /// Source for update information.
  final ModelUpdateSource? updateSource;

  final Map<String, ModelVersion> _installedVersions = {};
  DateTime? _lastCheckTime;

  /// Register an installed model version.
  void registerInstalledVersion(ModelVersion version) {
    _installedVersions[version.modelName] = version;
  }

  /// Check if update check is due.
  bool get isCheckDue {
    if (_lastCheckTime == null) return true;
    return DateTime.now().difference(_lastCheckTime!) > config.checkInterval;
  }

  /// Check for updates for a specific model.
  Future<UpdateCheckResult> checkForUpdate(String modelName) async {
    if (updateSource == null) {
      return UpdateCheckResult.error('No update source configured');
    }

    try {
      final current = _installedVersions[modelName];
      final latest = await updateSource!.getLatestVersion(modelName);

      _lastCheckTime = DateTime.now();

      if (latest == null) {
        return UpdateCheckResult.noUpdate();
      }

      if (current == null || latest.isNewerThan(current)) {
        return UpdateCheckResult.updateAvailable(
          current ?? latest,
          latest,
        );
      }

      return UpdateCheckResult.noUpdate();
    } catch (e) {
      return UpdateCheckResult.error(e.toString());
    }
  }

  /// Check for updates for all installed models.
  Future<Map<String, UpdateCheckResult>> checkAllForUpdates() async {
    final results = <String, UpdateCheckResult>{};

    for (final modelName in _installedVersions.keys) {
      results[modelName] = await checkForUpdate(modelName);
    }

    return results;
  }

  /// Get installed version for a model.
  ModelVersion? getInstalledVersion(String modelName) {
    return _installedVersions[modelName];
  }

  /// Get all installed models.
  Map<String, ModelVersion> get installedVersions =>
      Map.unmodifiable(_installedVersions);
}
