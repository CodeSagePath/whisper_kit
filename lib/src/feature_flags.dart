/// Feature flags for controlling functionality.
///
/// Enable/disable features at runtime without code changes.
library;

/// Feature flag definitions.
enum Feature {
  /// Enable experimental streaming support.
  streaming,

  /// Enable speaker diarization (experimental).
  diarization,

  /// Enable real-time transcription.
  realtime,

  /// Enable batch processing.
  batchProcessing,

  /// Enable translation features.
  translation,

  /// Enable caching.
  caching,

  /// Enable analytics/telemetry.
  analytics,

  /// Enable debug logging.
  debugLogging,

  /// Enable performance profiling.
  profiling,
}

/// Feature flag configuration.
class FeatureFlagConfig {
  const FeatureFlagConfig({
    this.enabledFeatures = const {},
    this.defaultEnabled = true,
  });

  /// Set of explicitly enabled features.
  final Set<Feature> enabledFeatures;

  /// Whether features are enabled by default.
  final bool defaultEnabled;

  /// Check if a feature is enabled.
  bool isEnabled(Feature feature) {
    if (enabledFeatures.contains(feature)) return true;
    return defaultEnabled;
  }
}

/// Feature flags manager.
class FeatureFlags {
  FeatureFlags._();

  static FeatureFlags? _instance;

  /// Singleton instance.
  static FeatureFlags get instance {
    _instance ??= FeatureFlags._();
    return _instance!;
  }

  final Map<Feature, bool> _flags = {};
  final Map<Feature, List<void Function(bool)>> _listeners = {};

  /// Enable a feature.
  void enable(Feature feature) {
    _flags[feature] = true;
    _notifyListeners(feature, true);
  }

  /// Disable a feature.
  void disable(Feature feature) {
    _flags[feature] = false;
    _notifyListeners(feature, false);
  }

  /// Toggle a feature.
  bool toggle(Feature feature) {
    final newValue = !isEnabled(feature);
    _flags[feature] = newValue;
    _notifyListeners(feature, newValue);
    return newValue;
  }

  /// Check if a feature is enabled.
  bool isEnabled(Feature feature) {
    return _flags[feature] ?? true; // Default to enabled
  }

  /// Set multiple features at once.
  void setAll(Map<Feature, bool> flags) {
    for (final entry in flags.entries) {
      _flags[entry.key] = entry.value;
      _notifyListeners(entry.key, entry.value);
    }
  }

  /// Add a listener for feature changes.
  void addListener(Feature feature, void Function(bool) listener) {
    _listeners.putIfAbsent(feature, () => []).add(listener);
  }

  /// Remove a listener.
  void removeListener(Feature feature, void Function(bool) listener) {
    _listeners[feature]?.remove(listener);
  }

  void _notifyListeners(Feature feature, bool enabled) {
    for (final listener in _listeners[feature] ?? []) {
      listener(enabled);
    }
  }

  /// Get all enabled features.
  List<Feature> get enabledFeatures {
    return Feature.values.where(isEnabled).toList();
  }

  /// Get all disabled features.
  List<Feature> get disabledFeatures {
    return Feature.values.where((f) => !isEnabled(f)).toList();
  }

  /// Reset all features to default (enabled).
  void reset() {
    _flags.clear();
  }

  /// Configure from a map (e.g., from remote config).
  void configureFromMap(Map<String, bool> config) {
    for (final entry in config.entries) {
      try {
        final feature = Feature.values.firstWhere(
          (f) => f.name == entry.key,
        );
        _flags[feature] = entry.value;
      } catch (_) {
        // Unknown feature, ignore
      }
    }
  }

  /// Export current configuration as a map.
  Map<String, bool> toMap() {
    return {
      for (final feature in Feature.values) feature.name: isEnabled(feature),
    };
  }
}

/// Convenience extension for checking features.
extension FeatureFlagsExtension on Feature {
  /// Check if this feature is enabled.
  bool get isEnabled => FeatureFlags.instance.isEnabled(this);

  /// Enable this feature.
  void enable() => FeatureFlags.instance.enable(this);

  /// Disable this feature.
  void disable() => FeatureFlags.instance.disable(this);
}
