# Whisper Flutter (Android Only)

A Flutter plugin that brings OpenAI's Whisper ASR (Automatic Speech Recognition) capabilities natively into your Android app. It supports offline speech-to-text transcription using Whisper models directly on the device.

---

## Features

- Real-time Microphone Input and Transcription: Capture audio directly from the microphone and get instant transcriptions.
- Whisper Models: Leverages the power of Whisper models (Tiny model included by default for a lightweight experience).
- Android Focused: Thoroughly tested and confirmed to be working seamlessly only for Android devices.
- Offline Functionality: No need for external APIs or cloud services – all processing happens directly on the device.
- Native Integration: Efficiently integrates the native `whisper.cpp` library for optimal performance.

---

## Installation

1. Add the dependency:

    Open your `pubspec.yaml` file and add the following line under `dependencies`:

    ```yaml
    whisper_flutter: ^latest_version  # Replace with the latest version (current 0.1.0)
    ```

2. Get the packages:

    Run the following command in your terminal within your Flutter project directory:

    ```bash
    flutter pub get
    ```

3. Ensure CMake and NDK Support (Android):

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

1. Import the package:

    In your Dart code, import the `whisper_flutter` library:

    ```dart
    import 'package:whisper_flutter/whisper_flutter.dart';
    ```

2. Use the plugin for transcription:

    Here's a basic example of how to transcribe an audio file:

    ```dart
    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      final String audioPath = '/path/to/your/audio.wav';

      try {
        final TranscriptionResult? result = await WhisperFlutter.transcribe(audioPath: audioPath);
        if (result != null && result.text.isNotEmpty) {
          print('Transcription: ${result.text}');
        } else {
          print('Transcription failed or returned an empty result.');
        }
      } catch (e) {
        print('Error during transcription: \$e');
      }
    }
    ```

---

## Screenshots

<div align="center">

### Recording Interface
| Recording Screen | Transcription Progress |
|:---:|:---:|
| ![Main Interface](assets/screenshots/1.jpg) | ![Model Download Progress](assets/screenshots/2.jpg) |

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

## Project Structure

├── lib/  
│   └── whisper_flutter.dart         # Dart wrapper and plugin interface  
├── src/  
│   ├── main.cpp                     # Native C++ bindings  
├── android/  
│   ├── build.gradle  
│   ├── src/main/  
│   │   └── java/com/example/whisper_flutter/  # Android JNI bridge  
│   │   └── cpp/                     # Compiled native library output  
│   ├── CMakeLists.txt  
├── example/  
│   ├── lib/main.dart               # Sample Flutter usage project  
├── .gitignore  
└── README.md