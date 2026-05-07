# whisper_kit example

Minimal demo app for `whisper_kit`.

## Getting Started

```bash
flutter pub get
flutter run
```

This demo transcribes one of the bundled WAV assets under `example/assets/` and shows model download progress.

Notes:
- The native core currently expects WAV input (16kHz, 16-bit PCM).
- No microphone permissions are required for this example (it does not record audio).
