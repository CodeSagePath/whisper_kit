# Changelog

All notable changes to the WhisperKit Flutter package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2024-12-23

### Added

#### Core Features
- **Unified Platform API** - Consistent cross-platform interface
- **Typed Exceptions** - `ModelException`, `AudioException`, `TranscriptionException`, `PermissionException`
- **Configuration Presets** - Quick configs: `fast`, `balanced`, `accurate`, `lowMemory`, `realtime`
- **Progress Callbacks** - Unified progress reporting for downloads and transcription
- **Cancellation Tokens** - Cancel long-running operations

#### Transcription Features
- **Batch Transcription** - Process multiple files with concurrent/sequential modes
- **Export Formats** - Export to SRT, VTT, JSON, plain text
- **Transcription Caching** - File-based caching with expiration
- **Timestamp Precision** - Word-level timestamp estimation
- **Translation Improvements** - Post-processing for better quality

#### Advanced Features
- **Language Identification** - Support for 99 languages
- **Custom Model Loading** - Load user-provided GGML/GGUF models
- **Adaptive Processing** - Device capability detection and optimal settings
- **Speaker Diarization** - Identify different speakers
- **Background Transcription** - Process audio in background

#### Enterprise Features
- **Queue Management** - Priority queue for batch processing
- **Large File Handling** - Process files >100MB with chunking
- **Database Integration** - Abstract database interface
- **Cloud Storage** - Integration with S3, GCS, Firebase Storage
- **WebSocket Support** - Real-time transcription streaming
- **REST API Wrapper** - Integrate with remote transcription APIs

#### Security & Privacy
- **Model Security** - On-device model verification
- **Secure Model Loading** - Trusted sources, quarantine invalid models
- **Privacy Options** - GDPR-compliant processing modes

#### Production Features
- **Telemetry** - Usage analytics integration
- **Crash Reporting** - Error tracking and breadcrumbs
- **A/B Testing** - Experiment framework with variants
- **Feature Flags** - Runtime feature toggling
- **Auto-Update** - Model version management

#### Developer Experience
- **Flutter Widgets** - Pre-built UI components
- **Plugin Architecture** - Extensible third-party integration
- **Memory Optimization** - Memory monitoring and thread config
- **Benchmarking** - Performance measurement tools
- **Testing Utilities** - Mock builders and assertions
- **Sample Templates** - Ready-to-use app templates
- **Firebase Integration** - Firestore and Storage utilities

### Documentation
- API reference guide (`doc/API_REFERENCE.md`)
- Performance optimization guide (`doc/PERFORMANCE_GUIDE.md`)
- GDPR compliance documentation (`doc/GDPR_COMPLIANCE.md`)

---

## [0.2.0] - 2024-12-01

### Added
- iOS native implementation (beta)
- Enhanced audio handling on Android
- Improved error handling

### Fixed
- Memory leaks on repeated transcriptions
- Crash on invalid audio format

---

## [0.1.0] - 2024-11-15

### Added
- Initial release
- Android platform support
- Basic transcription API
- Model download with progress tracking
- Support for Tiny, Base, Small, Medium models
- Language detection and translation to English
- Timestamped segments

---

## Migration Guide: 0.2.x to 0.3.x

### Using Typed Exceptions

```dart
// Before (0.2.x)
try {
  await whisper.transcribe(...);
} catch (e) {
  print('Error: $e');
}

// After (0.3.x)
try {
  await whisper.transcribe(...);
} on ModelException catch (e) {
  print('Model error: ${e.message}');
} on AudioException catch (e) {
  print('Audio error: ${e.message}');
}
```

### Using Configuration Presets

```dart
// Before
final request = TranscribeRequest(audio: audioPath, threads: 4);

// After
final request = TranscriptionPreset.fast.toRequest(audioPath);
```

### Using Export Formats

```dart
// New in 0.3.x
final srt = response.toSRT();
final vtt = response.toVTT();
```

---

## Compatibility

| Version | Android | iOS | Flutter |
|---------|---------|-----|---------|
| 0.3.x | API 21+ | iOS 13+ | 3.0+ |
| 0.2.x | API 21+ | Partial | 3.0+ |
| 0.1.x | API 21+ | ❌ | 3.0+ |
