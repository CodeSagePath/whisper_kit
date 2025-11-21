# Whisper Kit (Android Only)

A Flutter plugin that brings OpenAI's Whisper ASR (Automatic Speech Recognition) capabilities natively into your Android app. It supports offline speech-to-text transcription using Whisper models directly on the device.

---

## Features

- **Real-time Microphone Input and Transcription**: Capture audio directly from the microphone and get instant transcriptions with live feedback
- **Multiple Whisper Models**: Support for various Whisper model sizes (Tiny, Base, Small, Medium) with Tiny model included by default for a lightweight experience
- **Model Management**: Automatic downloading and management of Whisper models with progress tracking
- **Android Focused**: Thoroughly tested and confirmed to be working seamlessly only for Android devices
- **Offline Functionality**: No need for external APIs or cloud services – all processing happens directly on the device
- **Native Integration**: Efficiently integrates the native `whisper.cpp` library for optimal performance
- **Real-time Processing Timer**: Built-in elapsed time tracking for transcription processing
- **Language Support**: Automatic language detection and translation capabilities
- **Progress Indicators**: Visual feedback for recording, processing, and transcription states
- **Audio Management**: Built-in audio file handling and playback functionality

---

## Installation

1. **Add the dependency**:

    Open your `pubspec.yaml` file and add the following line under `dependencies`:

    ```yaml
    whisper_kit: ^latest_version  # Replace with the latest version (current 0.1.0)
    ```

2. **Get the packages**:

    Run the following command in your terminal within your Flutter project directory:

    ```bash
    flutter pub get
    ```

3. **Android Configuration**:

    Ensure your Android project has the necessary permissions and configuration:

    Add these permissions to your `android/app/src/main/AndroidManifest.xml`:

    ```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    ```

4. **Ensure CMake and NDK Support (Android)**:

    Make sure your Android project is configured to use CMake and the Android NDK. Flutter projects typically include this setup by default. If you encounter build issues related to native code, refer to the Flutter documentation on adding native code to your project.

---

## Platform Support

| Platform | Status     |
|----------|------------|
| Android  | Working    |
| iOS      | Planned    |
| Web      | Not yet    |

---

## Getting Started

### 1. Import the Package

In your Dart code, import the `whisper_kit` library:

```dart
import 'package:whisper_kit/whisper_kit.dart';
```

### 2. Basic Usage Example

Here's a comprehensive example of how to use the Whisper Kit for transcription:

#### Audio File Transcription

```dart
import 'package:whisper_kit/whisper_kit.dart';

class TranscriptionExample {
  Future<void> transcribeAudioFile() async {
    final String audioPath = '/path/to/your/audio.wav';

    try {
      final TranscriptionResult? result = await WhisperKit.transcribe(audioPath: audioPath);
      if (result != null && result.text.isNotEmpty) {
        print('Transcription: ${result.text}');
        print('Duration: ${result.duration}ms');
      } else {
        print('Transcription failed or returned an empty result.');
      }
    } catch (e) {
      print('Error during transcription: $e');
    }
  }
}
```

#### Real-time Microphone Transcription

```dart
import 'package:whisper_kit/whisper_kit.dart';

class RealTimeTranscription {
  late WhisperController _whisperController;

  Future<void> initializeWhisper() async {
    _whisperController = WhisperController();
    await _whisperController.initialize();
  }

  Future<void> startRecording() async {
    try {
      await _whisperController.startRecording();
      print('Recording started...');

      // Listen for real-time transcription results
      _whisperController.onResult.listen((TranscriptionResult result) {
        print('Live transcription: ${result.text}');
      });

    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    await _whisperController.stopRecording();
    print('Recording stopped');
  }
}
```

#### Model Management

```dart
import 'package:whisper_kit/whisper_kit.dart';

class ModelManager {
  Future<void> downloadModel() async {
    try {
      // Download a specific model with progress tracking
      await WhisperKit.downloadModel(
        modelSize: WhisperModel.base,
        onProgress: (double progress) {
          print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
        }
      );
    } catch (e) {
      print('Error downloading model: $e');
    }
  }

  Future<void> checkModelStatus() async {
    final bool isDownloaded = await WhisperKit.isModelDownloaded(WhisperModel.base);
    print('Model downloaded: $isDownloaded');
  }
}
```

### 3. Advanced Configuration

```dart
import 'package:whisper_kit/whisper_kit.dart';

class AdvancedTranscription {
  Future<void> transcribeWithCustomSettings() async {
    final TranscriptionConfig config = TranscriptionConfig(
      modelSize: WhisperModel.small,
      language: 'en', // Optional: specify language or leave null for auto-detection
      translate: false, // Set to true to translate to English
      enableVad: true, // Voice Activity Detection
      temperature: 0.0f, // Sampling temperature
    );

    try {
      final TranscriptionResult result = await WhisperKit.transcribe(
        audioPath: '/path/to/audio.wav',
        config: config,
      );

      print('Transcription: ${result.text}');
      print('Language detected: ${result.detectedLanguage}');
      print('Confidence: ${result.confidence}');
    } catch (e) {
      print('Error: $e');
    }
  }
}
```

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

#### `WhisperKit`
The main static class for transcription operations:

- `Future<TranscriptionResult?> transcribe(String audioPath, {TranscriptionConfig? config})` - Transcribe audio file
- `Future<void> downloadModel(WhisperModel modelSize, {Function(double)? onProgress})` - Download model
- `Future<bool> isModelDownloaded(WhisperModel modelSize)` - Check model download status

#### `WhisperController`
Controller for real-time transcription:

- `Future<void> initialize()` - Initialize the controller
- `Future<void> startRecording()` - Start microphone recording
- `Future<void> stopRecording()` - Stop microphone recording
- `Stream<TranscriptionResult> get onResult` - Stream of transcription results

#### `TranscriptionResult`
Contains the transcription result:

- `String text` - The transcribed text
- `Duration? duration` - Processing duration
- `String? detectedLanguage` - Detected language code
- `double? confidence` - Confidence score

#### `TranscriptionConfig`
Configuration for transcription:

- `WhisperModel modelSize` - Model size (tiny, base, small, medium)
- `String? language` - Language code or null for auto-detection
- `bool translate` - Whether to translate to English
- `bool enableVad` - Enable Voice Activity Detection
- `double temperature` - Sampling temperature

#### `WhisperModel`
Enum for available model sizes:

- `WhisperModel.tiny` - Fastest, least accurate (75MB)
- `WhisperModel.base` - Good balance (142MB)
- `WhisperModel.small` - Better accuracy (466MB)
- `WhisperModel.medium` - Best accuracy (1.5GB)

---

## Audio Requirements

### Supported Formats
- **WAV files** (recommended): 16kHz, mono, 16-bit PCM
- **Other formats**: May require conversion before processing

### Audio Quality Tips
- Use a quiet environment for best results
- Speak clearly at a normal pace
- Ensure proper microphone placement
- Audio should be at least 1 second long for optimal transcription

---

## Error Handling

Common errors and their solutions:

```dart
try {
  final result = await WhisperKit.transcribe(audioPath: audioPath);
} on WhisperModelNotFoundException {
  print('Model not found. Please download the required model first.');
} on AudioFormatException catch (e) {
  print('Invalid audio format: ${e.message}');
} on TranscriptionException catch (e) {
  print('Transcription failed: ${e.message}');
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

├── lib/
│   └── whisper_kit.dart           # Dart wrapper and plugin interface
├── src/
│   ├── main.cpp                   # Native C++ bindings
├── android/
│   ├── build.gradle
│   ├── src/main/
│   │   └── java/com/example/whisper_kit/   # Android JNI bridge
│   │   └── cpp/                   # Compiled native library output
│   ├── CMakeLists.txt
├── example/
│   ├── lib/main.dart             # Sample Flutter usage project
├── .gitignore
└── README.md

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