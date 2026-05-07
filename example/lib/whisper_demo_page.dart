import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "package:test_whisper/animated_transcribe_button.dart";
import "package:whisper_kit/whisper_kit.dart";

class WhisperDemoPage extends StatefulWidget {
  const WhisperDemoPage({super.key});

  @override
  State<WhisperDemoPage> createState() => _WhisperDemoPageState();
}

class _WhisperDemoPageState extends State<WhisperDemoPage> {
  static const _assets = <String>[
    "assets/english.wav",
    "assets/french.wav",
    "assets/japanese.wav",
    "assets/marathi.wav",
    "assets/punjabi.wav",
    "assets/telugu.wav",
  ];

  static const _languages = <String>[
    "auto",
    "en",
    "fr",
    "ja",
    "mr",
    "pa",
    "te",
  ];

  WhisperModel _model = WhisperModel.base;
  String _assetPath = _assets.first;
  String _language = "auto";
  bool _translate = false;
  bool _withTimestamps = true;
  bool _splitOnWord = false;
  bool _diarize = false;
  bool _speedUp = false;
  int _threads = 4;
  int _processors = 1;

  bool _isWorking = false;
  double? _downloadProgress;
  String? _error;
  String? _text;
  List<WhisperTranscribeSegment>? _segments;

  Future<File> _materializeAsset(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final out = File("${dir.path}/${assetPath.split("/").last}");
    await out.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return out;
  }

  Future<void> _runTranscribe() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _downloadProgress = null;
      _error = null;
      _text = null;
      _segments = null;
    });

    try {
      final audioFile = await _materializeAsset(_assetPath);

      final whisper = Whisper(
        model: _model,
        onDownloadProgress: (received, total) {
          if (total <= 0) return;
          final progress = received / total;
          if (!mounted) return;
          setState(() => _downloadProgress = progress.clamp(0.0, 1.0));
        },
      );

      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioFile.path,
          language: _language,
          isTranslate: _translate,
          isNoTimestamps: !_withTimestamps,
          splitOnWord: _splitOnWord,
          diarize: _diarize,
          speedUp: _speedUp,
          threads: _threads,
          nProcessors: _processors,
        ),
      );

      setState(() {
        _text = response.text;
        _segments = response.segments;
      });
    } on WhisperKitException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Whisper Kit Demo")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            title: "Input",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Dropdown<String>(
                  label: "Bundled WAV",
                  value: _assetPath,
                  items: _assets,
                  toLabel: (v) => v.split("/").last,
                  onChanged: (v) => setState(() => _assetPath = v),
                ),
                const SizedBox(height: 12),
                _Dropdown<WhisperModel>(
                  label: "Model",
                  value: _model,
                  items: const [
                    WhisperModel.tiny,
                    WhisperModel.base,
                    WhisperModel.small,
                    WhisperModel.medium,
                    WhisperModel.largeV1,
                    WhisperModel.largeV2,
                  ],
                  toLabel: (m) => m.modelName,
                  onChanged: (m) => setState(() => _model = m),
                ),
                const SizedBox(height: 12),
                _Dropdown<String>(
                  label: "Language",
                  value: _language,
                  items: _languages,
                  toLabel: (v) => v,
                  onChanged: (v) => setState(() => _language = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: "Options",
            child: Column(
              children: [
                SwitchListTile(
                  value: _translate,
                  onChanged: _isWorking ? null : (v) => setState(() => _translate = v),
                  title: const Text("Translate to English"),
                ),
                SwitchListTile(
                  value: _withTimestamps,
                  onChanged: _isWorking ? null : (v) => setState(() => _withTimestamps = v),
                  title: const Text("Include timestamps"),
                ),
                SwitchListTile(
                  value: _splitOnWord,
                  onChanged: _isWorking ? null : (v) => setState(() => _splitOnWord = v),
                  title: const Text("Split on word (token timestamps)"),
                ),
                SwitchListTile(
                  value: _diarize,
                  onChanged: _isWorking ? null : (v) => setState(() => _diarize = v),
                  title: const Text("Speaker-turn detection (experimental)"),
                ),
                SwitchListTile(
                  value: _speedUp,
                  onChanged: _isWorking ? null : (v) => setState(() => _speedUp = v),
                  title: const Text("Speed up (quality tradeoff)"),
                ),
                const SizedBox(height: 8),
                _IntSlider(
                  label: "Threads",
                  value: _threads,
                  min: 1,
                  max: 8,
                  enabled: !_isWorking,
                  onChanged: (v) => setState(() => _threads = v),
                ),
                _IntSlider(
                  label: "Processors",
                  value: _processors,
                  min: 1,
                  max: 4,
                  enabled: !_isWorking,
                  onChanged: (v) => setState(() => _processors = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedTranscribeButton(
            isLoading: _isWorking,
            text: "Transcribe",
            icon: Icons.play_arrow,
            onPressed: _isWorking ? null : _runTranscribe,
          ),
          const SizedBox(height: 12),
          if (_downloadProgress != null) ...[
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 6),
            Text(
              "Model download: ${(_downloadProgress! * 100).toStringAsFixed(1)}%",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) _ErrorBox(message: _error!),
          if (_text != null) ...[
            _Card(
              title: "Transcript",
              child: SelectableText(_text!),
            ),
            if (_segments != null && _segments!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Card(
                title: "Segments",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _segments!
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "[${s.fromTs} - ${s.toTs}] ${s.text}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text(
              "Tip: This demo uses bundled WAV assets and writes them to a temp file before calling Whisper.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.toLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) toLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(toLabel(v))))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _IntSlider extends StatelessWidget {
  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toString()),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: enabled ? (v) => onChanged(v.round()) : null,
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade900.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

