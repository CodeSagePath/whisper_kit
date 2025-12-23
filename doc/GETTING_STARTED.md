# Getting Started with WhisperKit

This guide will help you integrate WhisperKit into your Flutter app in just a few minutes.

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Common Use Cases](#common-use-cases)
5. [Troubleshooting](#troubleshooting)

---

## Installation

### 1. Add Dependency

Add WhisperKit to your `pubspec.yaml`:

```yaml
dependencies:
  whisper_kit: ^0.3.0
```

### 2. Install

```bash
flutter pub get
```

### 3. Platform Setup

#### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Ensure minimum SDK version in `android/app/build.gradle`:

```gradle
minSdkVersion 21
```

#### iOS

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for speech recognition</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We use speech recognition to transcribe audio</string>
```

---

## Quick Start

### Minimal Example

```dart
import 'package:whisper_kit/whisper_kit.dart';

Future<void> transcribeAudio(String audioPath) async {
  // Create Whisper instance
  final whisper = Whisper(model: WhisperModel.base);
  
  // Transcribe
  final result = await whisper.transcribe(
    transcribeRequest: TranscribeRequest(audio: audioPath),
  );
  
  // Output
  print(result.text);
}
```

### With Error Handling

```dart
import 'package:whisper_kit/whisper_kit.dart';

Future<String?> safeTranscribe(String audioPath) async {
  final whisper = Whisper(model: WhisperModel.base);
  
  try {
    final result = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(audio: audioPath),
    );
    return result.text;
  } on ModelException catch (e) {
    print('Model error: ${e.message}');
    return null;
  } on AudioException catch (e) {
    print('Audio error: ${e.message}');
    return null;
  }
}
```

---

## Configuration

### Choosing a Model

| Model | Speed | Quality | Size | Best For |
|-------|-------|---------|------|----------|
| `tiny` | ⚡⚡⚡⚡ | ⭐ | 75MB | Real-time, testing |
| `base` | ⚡⚡⚡ | ⭐⭐ | 142MB | General use |
| `small` | ⚡⚡ | ⭐⭐⭐ | 466MB | Better accuracy |
| `medium` | ⚡ | ⭐⭐⭐⭐ | 1.5GB | High quality |

**Recommendation:** Start with `base` for most apps.

### Using Presets

```dart
// Quick configurations
final fastRequest = TranscriptionPreset.fast.toRequest(audioPath);
final accurateRequest = TranscriptionPreset.accurate.toRequest(audioPath);
```

### Custom Configuration

```dart
final request = TranscribeRequest(
  audio: audioPath,
  language: 'en',        // Language code or 'auto'
  threads: 4,            // CPU threads
  isTranslate: false,    // Translate to English
  isNoTimestamps: false, // Include timestamps
);
```

---

## Common Use Cases

### Voice Notes App

```dart
class VoiceNotesController {
  final whisper = Whisper(model: WhisperModel.base);
  final cache = TranscriptionCache();
  
  Future<String> transcribeNote(String audioPath) async {
    // Check cache first
    final cached = await cache.get(audioPath);
    if (cached != null) return cached.text;
    
    // Transcribe
    final result = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(audio: audioPath),
    );
    
    // Cache result
    await cache.put(audioPath, result);
    
    return result.text;
  }
}
```

### Meeting Transcription

```dart
class MeetingTranscriber {
  final whisper = Whisper(model: WhisperModel.small);
  
  Future<String> transcribeMeeting(String audioPath) async {
    final result = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: 'auto',
        isNoTimestamps: false,
      ),
    );
    
    // Export to SRT for subtitles
    final srt = result.toSRT();
    await File('meeting.srt').writeAsString(srt);
    
    return result.text;
  }
}
```

### Real-Time Captions

```dart
class CaptionController {
  final whisper = Whisper(model: WhisperModel.tiny);
  
  Future<void> processChunk(String chunkPath) async {
    final result = await whisper.transcribe(
      transcribeRequest: TranscriptionPreset.realtime.toRequest(chunkPath),
    );
    updateCaptions(result.text);
  }
}
```

### Batch Processing

```dart
class BatchProcessor {
  final whisper = Whisper(model: WhisperModel.base);
  
  Future<void> processFolder(List<String> files) async {
    final transcriber = BatchTranscriber(whisper);
    
    final results = await transcriber.transcribeAll(
      files,
      options: BatchOptions(parallel: true, maxConcurrency: 2),
      onProgress: (p) {
        print('Progress: ${p.completed}/${p.total}');
      },
    );
    
    for (final result in results) {
      if (result.success) {
        print('${result.audioPath}: OK');
      } else {
        print('${result.audioPath}: FAILED - ${result.error}');
      }
    }
  }
}
```

---

## Troubleshooting

### Model Download Failed

**Problem:** Model fails to download.

**Solutions:**
1. Check internet connection
2. Ensure enough storage space
3. Try a smaller model first
4. Check for firewall/proxy issues

```dart
// Monitor download progress
final whisper = Whisper(
  model: WhisperModel.base,
  onDownloadProgress: (received, total) {
    if (received == 0) {
      print('Download starting...');
    }
    print('${(received / total * 100).toStringAsFixed(1)}%');
  },
);
```

### Out of Memory

**Problem:** App crashes with large files or models.

**Solutions:**
1. Use a smaller model (`tiny` or `base`)
2. Reduce thread count
3. Process in chunks

```dart
// Use memory-optimized preset
final request = TranscriptionPreset.lowMemory.toRequest(audioPath);
```

### Audio Format Issues

**Problem:** Transcription fails with audio errors.

**Solutions:**
1. Convert to WAV format (16kHz, mono, 16-bit PCM)
2. Ensure file is not corrupted
3. Check file permissions

```dart
// Validate audio before processing
final validation = await AudioValidator.validate(audioPath);
if (!validation.isValid) {
  print('Audio issue: ${validation.error}');
}
```

### Slow Transcription

**Problem:** Transcription takes too long.

**Solutions:**
1. Use a faster model (`tiny`)
2. Increase thread count
3. Use the `fast` preset

```dart
// Fastest configuration
final whisper = Whisper(model: WhisperModel.tiny);
final request = TranscriptionPreset.fast.toRequest(audioPath);
```

---

## Next Steps

- [API Reference](API_REFERENCE.md) - Complete API documentation
- [Performance Guide](PERFORMANCE_GUIDE.md) - Optimization tips
- [Examples](EXAMPLES.md) - More code examples
- [GDPR Compliance](GDPR_COMPLIANCE.md) - Privacy guidelines

---

## Need Help?

- [GitHub Issues](https://github.com/CodeSagePath/whisper_kit/issues)
- [Discussions](https://github.com/CodeSagePath/whisper_kit/discussions)
