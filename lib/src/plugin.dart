/// Plugin architecture for third-party extensions.
///
/// Enables extending WhisperKit functionality through plugins.
library;

import 'dart:async';

import 'package:whisper_kit/bean/response_bean.dart';

/// Base interface for all WhisperKit plugins.
abstract class WhisperKitPlugin {
  /// Unique identifier for this plugin.
  String get id;

  /// Human-readable name.
  String get name;

  /// Plugin version.
  String get version;

  /// Initialize the plugin.
  Future<void> initialize();

  /// Dispose plugin resources.
  Future<void> dispose();
}

/// Audio preprocessor plugin interface.
///
/// Called before audio is sent to Whisper for transcription.
abstract class AudioPreprocessorPlugin extends WhisperKitPlugin {
  /// Process audio data before transcription.
  ///
  /// Returns processed audio bytes.
  Future<List<int>> preprocess(List<int> audioData);
}

/// Post-processor plugin interface.
///
/// Called after transcription to modify results.
abstract class PostProcessorPlugin extends WhisperKitPlugin {
  /// Process transcription result.
  ///
  /// Returns modified response.
  Future<WhisperTranscribeResponse> postprocess(
    WhisperTranscribeResponse response,
  );
}

/// Text formatter plugin interface.
///
/// Formats transcription text output.
abstract class TextFormatterPlugin extends WhisperKitPlugin {
  /// Format the transcribed text.
  String format(String text);
}

/// Plugin registry for managing plugins.
class PluginRegistry {
  PluginRegistry._();

  static PluginRegistry? _instance;

  /// Singleton instance.
  static PluginRegistry get instance {
    _instance ??= PluginRegistry._();
    return _instance!;
  }

  final Map<String, WhisperKitPlugin> _plugins = {};
  final List<AudioPreprocessorPlugin> _preprocessors = [];
  final List<PostProcessorPlugin> _postprocessors = [];
  final List<TextFormatterPlugin> _formatters = [];

  /// Register a plugin.
  Future<void> register(WhisperKitPlugin plugin) async {
    if (_plugins.containsKey(plugin.id)) {
      throw PluginException('Plugin ${plugin.id} is already registered');
    }

    await plugin.initialize();
    _plugins[plugin.id] = plugin;

    if (plugin is AudioPreprocessorPlugin) {
      _preprocessors.add(plugin);
    }
    if (plugin is PostProcessorPlugin) {
      _postprocessors.add(plugin);
    }
    if (plugin is TextFormatterPlugin) {
      _formatters.add(plugin);
    }
  }

  /// Unregister a plugin.
  Future<void> unregister(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin == null) return;

    await plugin.dispose();

    _preprocessors.removeWhere((p) => p.id == pluginId);
    _postprocessors.removeWhere((p) => p.id == pluginId);
    _formatters.removeWhere((p) => p.id == pluginId);
  }

  /// Get a registered plugin by ID.
  WhisperKitPlugin? getPlugin(String id) => _plugins[id];

  /// Get all registered plugins.
  List<WhisperKitPlugin> get allPlugins => _plugins.values.toList();

  /// Get all audio preprocessors.
  List<AudioPreprocessorPlugin> get preprocessors =>
      List.unmodifiable(_preprocessors);

  /// Get all post-processors.
  List<PostProcessorPlugin> get postprocessors =>
      List.unmodifiable(_postprocessors);

  /// Get all text formatters.
  List<TextFormatterPlugin> get formatters => List.unmodifiable(_formatters);

  /// Run all preprocessors on audio data.
  Future<List<int>> runPreprocessors(List<int> audioData) async {
    var data = audioData;
    for (final plugin in _preprocessors) {
      data = await plugin.preprocess(data);
    }
    return data;
  }

  /// Run all post-processors on response.
  Future<WhisperTranscribeResponse> runPostprocessors(
    WhisperTranscribeResponse response,
  ) async {
    var result = response;
    for (final plugin in _postprocessors) {
      result = await plugin.postprocess(result);
    }
    return result;
  }

  /// Run all text formatters on text.
  String runFormatters(String text) {
    var result = text;
    for (final plugin in _formatters) {
      result = plugin.format(result);
    }
    return result;
  }

  /// Dispose all plugins and clear registry.
  Future<void> disposeAll() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();
    _preprocessors.clear();
    _postprocessors.clear();
    _formatters.clear();
  }
}

/// Exception thrown by plugin operations.
class PluginException implements Exception {
  const PluginException(this.message);
  final String message;

  @override
  String toString() => 'PluginException: $message';
}
