# WhisperKit Examples

This directory contains example code demonstrating various WhisperKit features.

## Quick Start

```dart
import 'package:whisper_kit/whisper_kit.dart';

void main() async {
  // Initialize Whisper
  final whisper = Whisper(model: WhisperModel.base);
  
  // Transcribe audio
  final response = await whisper.transcribe(
    transcribeRequest: TranscribeRequest(audio: 'audio.wav'),
  );
  
  print(response.text);
}
```

## Examples by Feature

### Basic Transcription

```dart
// Simple transcription
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: '/path/to/audio.wav',
    language: 'en',
    threads: 4,
  ),
);
print('Transcription: ${response.text}');
```

### Configuration Presets

```dart
// Use presets for quick configuration
final request = TranscriptionPreset.fast.toRequest('/path/to/audio.wav');
final request2 = TranscriptionPreset.accurate.toRequest('/path/to/audio.wav');
```

### Batch Transcription

```dart
final transcriber = BatchTranscriber(whisper);

final results = await transcriber.transcribeAll(
  ['/audio1.wav', '/audio2.wav', '/audio3.wav'],
  options: BatchOptions(parallel: true, maxConcurrency: 2),
  onProgress: (p) => print('${p.completed}/${p.total}'),
);
```

### Export Formats

```dart
// Export to different formats
final srt = response.toSRT();
final vtt = response.toVTT();
final json = response.toJSON();

// Save to file
File('transcript.srt').writeAsStringSync(srt);
```

### Caching

```dart
final cache = TranscriptionCache(
  directory: '/path/to/cache',
  expiration: Duration(days: 7),
);

// Check cache first
var result = await cache.get(audioPath);
if (result == null) {
  result = await whisper.transcribe(...);
  await cache.put(audioPath, result);
}
```

### Language Detection

```dart
// Auto-detect language
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: audioPath,
    language: 'auto',
  ),
);

// Check all supported languages
print('Supported: ${WhisperLanguages.supported.length} languages');
```

### Translation

```dart
// Translate to English
final response = await whisper.transcribe(
  transcribeRequest: TranscribeRequest(
    audio: audioPath,
    isTranslate: true,
  ),
);
```

### Error Handling

```dart
try {
  await whisper.transcribe(...);
} on ModelException catch (e) {
  print('Model error: ${e.message}');
} on AudioException catch (e) {
  print('Audio format error: ${e.message}');
} on TranscriptionException catch (e) {
  print('Transcription failed: ${e.message}');
}
```

### Cancellation

```dart
final source = CancellationTokenSource();

// Start transcription with cancellation support
final future = whisper.transcribe(...).wrapWithCancellation(source.token);

// Cancel if needed
source.cancel('User cancelled');
```

### Progress Tracking

```dart
// Download progress
final whisper = Whisper(
  model: WhisperModel.base,
  onDownloadProgress: (received, total) {
    print('Download: ${(received / total * 100).toStringAsFixed(1)}%');
  },
);
```

### Custom Models

```dart
final model = CustomModel(
  path: '/path/to/my-model.bin',
  name: 'custom-whisper',
);

final loader = ModelLoader();
final result = await loader.validate(model);
print('Valid: ${result.isValid}');
```

### Queue Processing

```dart
final queue = TranscriptionQueue(maxConcurrent: 2);

queue.add('/urgent.wav', priority: TranscriptionPriority.urgent);
queue.add('/normal.wav', priority: TranscriptionPriority.normal);

queue.onItemCompleted = (result) {
  print('Completed: ${result.id}');
};
```

### Widgets

```dart
// Use pre-built widgets
TranscriptionDisplay(
  text: transcriptionText,
  isLoading: isProcessing,
)

RecordButton(
  isRecording: _isRecording,
  onPressed: _toggleRecording,
)

LanguageSelector(
  selectedLanguage: _language,
  onChanged: (lang) => setState(() => _language = lang),
)
```

### Privacy-Focused Processing

```dart
final privacyOptions = PrivacyOptions(
  deleteAudioAfterProcessing: true,
  disableTelemetry: true,
  localStorageOnly: true,
);
```

### Benchmarking

```dart
final benchmarker = Benchmarker();
final result = await benchmarker.run('transcription_test', () async {
  await whisper.transcribe(...);
});
print('Average: ${result.averageDuration}');
```

## Running the Example App

```bash
cd example
flutter run
```

## More Information

- [API Reference](../doc/API_REFERENCE.md)
- [Performance Guide](../doc/PERFORMANCE_GUIDE.md)
- [GDPR Compliance](../doc/GDPR_COMPLIANCE.md)
