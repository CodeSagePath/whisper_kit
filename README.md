# Whisper Kit

On-device speech-to-text for Flutter using OpenAI Whisper via `whisper.cpp`. Transcribe audio locally (no cloud API required once models are downloaded).

---

## Features

- Offline transcription (models downloaded on first use)
- Multiple Whisper model sizes (`tiny`, `base`, `small`, `medium`, `large-v1`, `large-v2`)
- Language auto-detection or fixed language
- Optional translation to English
- Timestamped segments (optional)
- Download progress callback
- Typed exceptions (`ModelException`, `AudioException`, `TranscriptionException`, `PermissionException`)

## Stable API (recommended)

- `Whisper` + `TranscribeRequest` for transcription
- `downloadModel(...)` for manual downloads with progress
- Catch `WhisperKitException` (or its typed subclasses) for errors

## Experimental modules

This package exports a number of optional helpers under `whisper_kit/src/*` (batching, caching, telemetry, cloud storage, etc.). Consider them **experimental** unless explicitly documented as stable.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  whisper_kit: ^0.3.1
```

Then:

```bash
flutter pub get
```

### Android permissions

If you record audio from the mic, add:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Model download requires network access. After models are downloaded, transcription can run offline.

---

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | Working |
| iOS      | Working (beta) |
| macOS    | Experimental |

---

## Getting Started

### 1. Import the Package

In your Dart code, import the `whisper_kit` library:

```dart
import 'package:whisper_kit/whisper_kit.dart';
```

### 2. Basic Usage Example

Example of how to transcribe a WAV file:

#### Audio File Transcription

```dart
import 'package:whisper_kit/whisper_kit.dart';

class TranscriptionExample {
  Future<void> transcribeAudioFile() async {
    final String audioPath = '/path/to/your/audio.wav';

    // Create a Whisper instance with your preferred model
    final Whisper whisper = Whisper(
      model: WhisperModel.base,
      // Optional: custom download host (defaults to HuggingFace)
      downloadHost: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      // Optional: download progress (received bytes, total bytes)
      onDownloadProgress: (received, total) {
        final pct = total > 0 ? (received / total * 100).toStringAsFixed(1) : '?';
        print('Model download: $pct%');
      },
    );

    // Create a transcription request
    final TranscribeRequest request = TranscribeRequest(
      audio: audioPath,
      language: 'auto', // 'auto' for detection, or specify: 'en', 'es', 'fr', etc.
    );

    try {
      final WhisperTranscribeResponse result = await whisper.transcribe(
        transcribeRequest: request,
      );
      print('Transcription: ${result.text}');
      
      // Access segments if available
      if (result.segments != null) {
        for (final segment in result.segments!) {
          print('[${segment.fromTs} - ${segment.toTs}]: ${segment.text}');
        }
      }
    } on ModelException catch (e) {
      print('Model error: $e');
    } on AudioException catch (e) {
      print('Audio error: $e');
    } on TranscriptionException catch (e) {
      print('Transcription error: $e');
    }
  }
}
```

#### Transcription with Translation

```dart
import 'package:whisper_kit/whisper_kit.dart';

class TranslationExample {
  Future<void> transcribeAndTranslate() async {
    final Whisper whisper = Whisper(model: WhisperModel.small);

    // Enable translation to English
    final TranscribeRequest request = TranscribeRequest(
      audio: '/path/to/foreign_language_audio.wav',
      isTranslate: true, // Translates to English
      language: 'auto',  // Auto-detect source language
    );

    try {
      final WhisperTranscribeResponse result = await whisper.transcribe(
        transcribeRequest: request,
      );
      print('Translated text: ${result.text}');
    } catch (e) {
      print('Error: $e');
    }
  }
}
```

#### Model Download with Progress Tracking

```dart
import 'package:whisper_kit/whisper_kit.dart';
import 'package:whisper_kit/download_model.dart';

class ModelManager {
  Future<void> downloadModelWithProgress() async {
    try {
      await downloadModel(
        model: WhisperModel.base,
        destinationPath: '/path/to/model/directory',
        onDownloadProgress: (int received, int total) {
          final progress = (received / total * 100).toStringAsFixed(1);
          print('Download progress: $progress%');
        },
      );
      print('Model downloaded successfully!');
    } catch (e) {
      print('Error downloading model: $e');
    }
  }
}
```

> **Note:** The `Whisper` class automatically downloads the model if it doesn't exist locally when you call `transcribe()`. Manual download is only needed if you want progress tracking during download.

### 3. Advanced Configuration

```dart
import 'package:whisper_kit/whisper_kit.dart';

class AdvancedTranscription {
  Future<void> transcribeWithCustomSettings() async {
    final Whisper whisper = Whisper(
      model: WhisperModel.small,
      // Optional: specify custom model storage directory
      modelDir: '/custom/path/to/models',
    );

    final TranscribeRequest request = TranscribeRequest(
      audio: '/path/to/audio.wav',
      language: 'en',           // Specify language or 'auto' for detection
      isTranslate: false,       // Set to true to translate to English
      isNoTimestamps: false,    // Set to true to skip segment timestamps
      splitOnWord: true,        // Split segments on word boundaries
      threads: 4,               // Number of threads to use
      nProcessors: 2,           // Number of processors to use
      isVerbose: true,          // Enable verbose output
    );

    try {
      final WhisperTranscribeResponse result = await whisper.transcribe(
        transcribeRequest: request,
      );

      print('Transcription: ${result.text}');
      
      // Process segments with timestamps
      if (result.segments != null) {
        for (final segment in result.segments!) {
          print('${segment.fromTs} -> ${segment.toTs}: ${segment.text}');
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> getWhisperVersion() async {
    final Whisper whisper = Whisper(model: WhisperModel.none);
    final String? version = await whisper.getVersion();
    print('Whisper version: $version');
  }
}

---

## Screenshots

<div align="center">

### Recording Interface
| Recording Screen | Configuration Options | Model Download Progress |
|:---:|:---:|:---:|
| ![Main Interface](assets/screenshots/1.jpg) | ![Configuration Options](assets/screenshots/10.jpg) | ![Model Download Progress](assets/screenshots/2.jpg) |

### Transcription Results
| Result Display | Model Download |
|:---:|:---:|
| ![Transcription Progress](assets/screenshots/3.jpg) | ![Transcription Result (original language)](assets/screenshots/4.jpg) |

### Additional Features
| Audio Management | Status Indicators |
|:---:|:---:|
| ![Transcription Result (translated to english)](assets/screenshots/5.jpg) | ![Recording Screen](assets/screenshots/6.jpg) |

| Progress Widgets | Processing Display |
|:---:|:---:|
| ![Recording Progress](assets/screenshots/7.jpg) | ![Recorded Audio Result](assets/screenshots/8.jpg) |

| Main Interface |
|:---:|
| ![English file (already existing) result](assets/screenshots/9.jpg) |

</div>

---

## API Reference

### Core Classes

#### `Whisper`
The main class for transcription operations:

```dart
const Whisper({
  required WhisperModel model,  // Required: the model to use
  String? modelDir,             // Optional: custom model storage directory
  String? downloadHost,         // Optional: custom model download URL
  Function(int, int)? onDownloadProgress,  // Optional: download progress callback
});
```

**Methods:**
- `Future<WhisperTranscribeResponse> transcribe({required TranscribeRequest transcribeRequest})` - Transcribe audio file
- `Future<String?> getVersion()` - Get the Whisper library version

#### `TranscribeRequest`
Configuration for a transcription request:

```dart
factory TranscribeRequest({
  required String audio,        // Path to audio file (WAV format recommended)
  bool isTranslate = false,     // Translate to English
  int threads = 6,              // Number of threads
  bool isVerbose = false,       // Verbose output
  String language = 'auto',     // Language code or 'auto' for detection
  bool isSpecialTokens = false, // Include special tokens
  bool isNoTimestamps = false,  // Skip timestamp generation
  int nProcessors = 1,          // Number of processors
  bool splitOnWord = false,     // Split on word boundaries
  bool noFallback = false,      // Disable fallback
  bool diarize = false,         // Speaker-turn detection (tinydiarize)
  bool speedUp = false,         // Speed up processing (quality tradeoff)
});
```

#### `WhisperTranscribeResponse`
The transcription result:

- `String text` - The transcribed text
- `List<WhisperTranscribeSegment>? segments` - Timestamped segments (if timestamps enabled)

#### `WhisperTranscribeSegment`
A segment of the transcription with timestamps:

- `Duration fromTs` - Start timestamp
- `Duration toTs` - End timestamp
- `String text` - The segment text

#### `WhisperModel`
Enum for available model sizes:

- `WhisperModel.none` - No model (for version check only)
- `WhisperModel.tiny` - Fastest, least accurate (~75MB)
- `WhisperModel.base` - Good balance (~142MB)
- `WhisperModel.small` - Better accuracy (~466MB)
- `WhisperModel.medium` - Best accuracy (~1.5GB)

#### `downloadModel` Function
Standalone function to download models with progress tracking:

```dart
Future<void> downloadModel({
  required WhisperModel model,
  required String destinationPath,
  String? downloadHost,
  Function(int received, int total)? onDownloadProgress,
});
```

---

## Audio Requirements

### Supported Formats
- **WAV (required by native core today)**: 16kHz, 16-bit PCM, mono or stereo
- Other formats (mp3/m4a/flac/ogg) must be converted to WAV before calling `transcribe()`.

## Limitations

- The native core currently accepts WAV input only (16kHz, 16-bit PCM, mono/stereo). Other formats must be converted before transcription.

### Audio Quality Tips
- Use a quiet environment for best results
- Speak clearly at a normal pace
- Ensure proper microphone placement
- Audio should be at least 1 second long for optimal transcription

---

## Error Handling
Catch typed exceptions for reliable handling:

```dart
try {
  final result = await whisper.transcribe(transcribeRequest: request);
  print(result.text);
} on ModelException catch (e) {
  // Download/validation/model path issues
  print(e);
} on AudioException catch (e) {
  // WAV requirements not met, file missing, etc
  print(e);
} on TranscriptionException catch (e) {
  // Native processing errors
  print(e);
}
```

---

## Performance Considerations

- **Model Size**: Larger models provide better accuracy but require more processing time and memory
- **Device Requirements**: Minimum 4GB RAM recommended for smooth operation
- **Battery Usage**: Continuous transcription can be battery-intensive
- **Storage**: Ensure sufficient space for downloaded models (75MB - 1.5GB per model)

---

## Project Structure

├── lib/                          # Public Dart API
│   ├── whisper_kit.dart           # Main entrypoint
│   └── download_model.dart        # Model download helper
├── src/                          # Native whisper.cpp bridge (C/C++)
├── ios/src/                      # iOS native whisper.cpp bridge (C/C++)
├── ios/Classes/                  # iOS method-channel implementation
├── android/                      # Android build scaffolding for the FFI plugin
└── example/                      # Minimal demo app using bundled WAV assets

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Clone the repository
2. Run `flutter pub get` in the root directory
3. Navigate to the example app: `cd example`
4. Run the example: `flutter run`

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) for the original speech recognition model
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for the efficient C++ implementation
- Flutter community for feedback and support

## Documentation

- `doc/GETTING_STARTED.md`
- `doc/API_REFERENCE.md`
- `doc/PERFORMANCE_GUIDE.md`
