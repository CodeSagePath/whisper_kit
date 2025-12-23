# WhisperKit Flutter - Complete API Documentation

WhisperKit is a Flutter library for on-device speech-to-text transcription using OpenAI's Whisper models via whisper.cpp.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core API](#core-api)
3. [Model Management](#model-management)
4. [Transcription](#transcription)
5. [Export Formats](#export-formats)
6. [Batch Processing](#batch-processing)
7. [Caching](#caching)
8. [Language Support](#language-support)
9. [Widgets](#widgets)
10. [Advanced Features](#advanced-features)
11. [Testing Utilities](#testing-utilities)

---

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  whisper_kit: ^0.3.0
```

### Basic Usage

```dart
import 'package:whisper_kit/whisper_kit.dart';

// Initialize Whisper with a model
final whisper = Whisper(model: WhisperModel.base);

// Initialize the model (downloads if needed)
await whisper.initModel();

// Transcribe audio
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(audio: '/path/to/audio.wav'),
);

print(response.text);
```

### Supported Audio Formats

- WAV (recommended)
- MP3
- M4A
- FLAC
- OGG

---

## Core API

### `Whisper` Class

The main entry point for transcription.

```dart
const Whisper({
  required WhisperModel model,
  String? modelDir,
  Function(int, int)? onDownloadProgress,
})
```

**Parameters:**
- `model` - The Whisper model to use (tiny, base, small, medium, large)
- `modelDir` - Custom directory for model storage
- `onDownloadProgress` - Callback for download progress

**Methods:**

| Method | Description |
|--------|-------------|
| `initModel()` | Initialize/download the model |
| `transcribe(TranscribeRequest)` | Transcribe audio file |
| `getVersion()` | Get whisper.cpp version |

### `TranscribeRequest` Class

```dart
TranscribeRequest({
  required String audio,
  bool isTranslate = false,
  int threads = 4,
  bool isVerbose = false,
  String language = 'auto',
  bool isNoTimestamps = false,
})
```

**Parameters:**
- `audio` - Path to audio file
- `isTranslate` - Translate to English
- `threads` - Number of threads (2-8 recommended)
- `isVerbose` - Enable verbose logging
- `language` - Source language code or 'auto'
- `isNoTimestamps` - Disable timestamp generation

### `WhisperTranscribeResponse` Class

```dart
WhisperTranscribeResponse({
  required String type,
  required String text,
  List<WhisperTranscribeSegment>? segments,
})
```

**Properties:**
- `text` - Full transcribed text
- `segments` - List of segments with timestamps

### `WhisperTranscribeSegment` Class

```dart
WhisperTranscribeSegment({
  required Duration fromTs,
  required Duration toTs,
  required String text,
})
```

---

## Model Management

### Available Models

| Model | Size | Speed | Accuracy | Memory |
|-------|------|-------|----------|--------|
| `tiny` | 75MB | Fastest | Basic | ~300MB |
| `base` | 142MB | Fast | Good | ~500MB |
| `small` | 466MB | Medium | Better | ~1GB |
| `medium` | 1.5GB | Slow | Great | ~2.5GB |
| `large` | 3GB | Slowest | Best | ~5GB |

### Custom Model Loading

```dart
import 'package:whisper_kit/whisper_kit.dart';

// Load a custom model
final model = CustomModel(
  path: '/path/to/custom-model.bin',
  name: 'my-custom-model',
);

// Validate the model
final loader = ModelLoader();
final result = await loader.validate(model);

if (result.isValid) {
  print('Model type: ${result.modelType}');
}
```

### Model Verification

```dart
// Verify model integrity
final verification = await ModelSecurity.verifyModel(
  '/path/to/model.bin',
  expectedSize: 142000000,
);

if (verification.isValid) {
  print('Model is valid');
}
```

### Auto-Updates

```dart
final manager = ModelUpdateManager(
  config: AutoUpdateConfig(
    checkOnStartup: true,
    checkInterval: Duration(days: 7),
    wifiOnly: true,
  ),
);

// Check for updates
final result = await manager.checkForUpdate('base');
if (result.hasUpdate) {
  print('Update available: ${result.availableVersion?.version}');
}
```

---

## Transcription

### Basic Transcription

```dart
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: audioPath,
    language: 'en',
    threads: 4,
  ),
);
```

### With Timestamps

```dart
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: audioPath,
    isNoTimestamps: false,
  ),
);

for (final segment in response.segments ?? []) {
  print('[${segment.fromTs} - ${segment.toTs}] ${segment.text}');
}
```

### Translation

```dart
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: audioPath,
    isTranslate: true,  // Translates to English
  ),
);
```

### Progress Callbacks

```dart
// Track transcription progress
ProgressCallbacks.onTranscription = (info) {
  print('Progress: ${info.progressPercent}%');
};
```

### Cancellation

```dart
final source = CancellationTokenSource();

// Start transcription with cancellation support
final future = whisper.transcribe(
  transcribeRequest: TranscribeRequest(audio: audioPath),
).wrapWithCancellation(source.token);

// Cancel if needed
source.cancel('User requested cancellation');
```

---

## Export Formats

Export transcriptions to various formats:

```dart
final response = await whisper.transcribe(...);

// Export to SRT
final srt = TranscriptionExporter.toSRT(response);

// Export to VTT
final vtt = TranscriptionExporter.toVTT(response);

// Export to JSON
final json = TranscriptionExporter.toJSON(response);

// Export to plain text
final text = TranscriptionExporter.toPlainText(response);

// Extension methods
final srt2 = response.toSRT();
```

### SRT Format Example

```
1
00:00:00,000 --> 00:00:02,500
Hello, welcome to the presentation.

2
00:00:02,500 --> 00:00:05,000
Today we'll discuss speech recognition.
```

### VTT Format Example

```
WEBVTT

00:00:00.000 --> 00:00:02.500
Hello, welcome to the presentation.

00:00:02.500 --> 00:00:05.000
Today we'll discuss speech recognition.
```

---

## Batch Processing

Process multiple files efficiently:

```dart
final transcriber = BatchTranscriber(whisper);

final results = await transcriber.transcribeAll(
  ['/path/audio1.wav', '/path/audio2.wav'],
  options: BatchOptions(
    parallel: true,
    maxConcurrency: 2,
    retryCount: 2,
  ),
  onProgress: (progress) {
    print('Completed: ${progress.completed}/${progress.total}');
  },
);

for (final result in results) {
  if (result.success) {
    print('${result.audioPath}: ${result.response?.text}');
  }
}
```

---

## Caching

Cache transcription results:

```dart
final cache = TranscriptionCache(
  directory: '/path/to/cache',
  maxEntries: 100,
  expiration: Duration(days: 7),
);

// Store result
await cache.put(audioPath, response);

// Retrieve cached result
final cached = await cache.get(audioPath);
if (cached != null) {
  print('From cache: ${cached.text}');
}

// Clear old entries
await cache.cleanup();
```

---

## Language Support

WhisperKit supports 99 languages:

```dart
// Get all supported languages
final languages = WhisperLanguages.supported;
print('Supported: ${languages.length} languages');

// Check if language is supported
final isSupported = WhisperLanguages.isSupported('es');

// Get language name
final name = WhisperLanguages.getName('fr'); // "French"

// Detect language from transcription
// Use language: 'auto' in TranscribeRequest
```

### Supported Languages

English, Spanish, French, German, Italian, Portuguese, Russian, Chinese, Japanese, Korean, Arabic, Hindi, and 87 more...

---

## Widgets

Pre-built Flutter widgets for common UI patterns:

### TranscriptionDisplay

```dart
TranscriptionDisplay(
  text: transcriptionText,
  isLoading: isProcessing,
  style: TextStyle(fontSize: 16),
)
```

### RecordButton

```dart
RecordButton(
  isRecording: _isRecording,
  onPressed: _toggleRecording,
)
```

### AudioWaveform

```dart
AudioWaveform(
  amplitudes: _amplitudeData,
  color: Colors.blue,
  height: 100,
)
```

### ModelDownloadProgress

```dart
ModelDownloadProgress(
  progress: downloadProgress,
  modelName: 'base',
)
```

### LanguageSelector

```dart
LanguageSelector(
  selectedLanguage: _language,
  onChanged: (lang) => setState(() => _language = lang),
)
```

---

## Advanced Features

### Configuration Presets

```dart
// Quick configuration
final request = TranscriptionPreset.fast.toRequest('/audio.wav');
final request2 = TranscriptionPreset.accurate.toRequest('/audio.wav');

// Available presets:
// - fast: Quick transcription with tiny model
// - balanced: Good balance of speed and accuracy
// - accurate: Best accuracy with more threads
// - lowMemory: Optimized for low-memory devices
// - realtime: For real-time transcription
```

### Adaptive Processing

```dart
// Get device capabilities
final caps = await DeviceCapabilities.detect();
print('Processors: ${caps.processorCount}');

// Get optimized settings
final processor = AdaptiveProcessor();
final settings = processor.getOptimalSettings(caps);
print('Recommended model: ${settings.recommendedModel}');
print('Threads: ${settings.threads}');
```

### Speaker Diarization

```dart
// Identify different speakers
final result = SimpleDiarization.fromTranscription(
  response,
  gapThreshold: Duration(seconds: 2),
);

for (final speaker in result.speakers) {
  print('${speaker.name}: ${speaker.totalSpeakingTime}');
}
```

### Background Transcription

```dart
final bg = BackgroundTranscription.instance;

// Start background transcription
final taskId = await bg.startTranscription(
  audioPath: '/path/to/audio.wav',
  config: BackgroundConfig(
    showNotification: true,
    notificationTitle: 'Transcribing...',
  ),
);

// Listen for updates
bg.updates.listen((result) {
  print('State: ${result.state}');
});
```

### Telemetry

```dart
// Enable telemetry
Telemetry.instance.setEnabled(true);

// Track events
await Telemetry.instance.trackTranscriptionStart(
  modelName: 'base',
  language: 'en',
);
```

### Feature Flags

```dart
// Enable/disable features at runtime
FeatureFlags.instance.enable(Feature.caching);
FeatureFlags.instance.disable(Feature.analytics);

// Check feature
if (Feature.translation.isEnabled) {
  // Translation is enabled
}
```

---

## Testing Utilities

### Mock Transcription Builder

```dart
final mockResponse = MockTranscriptionBuilder()
  .withText('Hello world')
  .addSegment(
    text: 'Hello',
    from: Duration.zero,
    to: Duration(seconds: 1),
  )
  .build();
```

### Transcription Assertions

```dart
// Verify transcription quality
assert(TranscriptionAssertions.hasText(response));
assert(TranscriptionAssertions.hasSegments(response));
assert(TranscriptionAssertions.hasOrderedSegments(response));
```

### Stress Testing

```dart
final tester = StressTester(
  config: StressTestConfig(
    iterations: 100,
    concurrency: 4,
  ),
);

final result = await tester.run((i) async {
  await whisper.transcribe(...);
});

print('Success rate: ${result.successRate}%');
print('Throughput: ${result.throughput} ops/s');
```

---

## Error Handling

WhisperKit provides typed exceptions:

```dart
try {
  await whisper.transcribe(...);
} on ModelException catch (e) {
  print('Model error: ${e.message}');
} on AudioException catch (e) {
  print('Audio error: ${e.message}');
} on TranscriptionException catch (e) {
  print('Transcription error: ${e.message}');
} on PermissionException catch (e) {
  print('Permission error: ${e.message}');
}
```

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Full | API 21+ |
| iOS | ✅ Full | iOS 13+ |
| macOS | 🔄 Planned | - |
| Windows | 🔄 Planned | - |
| Linux | 🔄 Planned | - |
| Web | ❌ N/A | WASM not supported |

---

## Best Practices

1. **Choose the right model** - Start with `base` for balance
2. **Use appropriate threads** - 4-6 for most devices
3. **Cache results** - Avoid re-transcribing same audio
4. **Handle errors gracefully** - Use typed exceptions
5. **Clean up resources** - Dispose models when done
6. **Test on device** - Simulators may not reflect real performance

---

## License

MIT License - See LICENSE file for details.
