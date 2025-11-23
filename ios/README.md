# Whisper Kit iOS Implementation

This document describes the iOS implementation of the Whisper Kit plugin for Flutter.

## Architecture Overview

The iOS implementation consists of several key components:

### Core Components

1. **WhisperKitPlugin.swift** - Main plugin class that handles Flutter method channel communication
2. **AudioRecorder.swift** - Audio capture and processing using AVAudioEngine
3. **PermissionManager.swift** - Permission handling for microphone and storage access
4. **ModelManager.swift** - Model download, validation, and management
5. **C++ Integration** - Native whisper.cpp integration for audio processing

### Features Implemented

#### ✅ Audio Recording and Processing
- Real-time audio capture using AVAudioEngine
- Automatic format conversion to 16kHz mono PCM (required by Whisper)
- Audio level monitoring and analysis
- Temporary file management
- Base64 audio data encoding for Flutter integration

#### ✅ Permission Management
- Microphone permission requests and status checks
- Documents/storage permission handling
- Comprehensive permission status reporting
- Settings integration for easy permission management

#### ✅ Model Management
- Model download from Hugging Face repositories
- Progress tracking during downloads
- Model validation and integrity checking
- Storage space management
- Model cleanup for corrupted files

#### ✅ Whisper.cpp Integration
- Direct C++ integration using FFI
- JSON-based request/response system
- Support for all Whisper model sizes (tiny, base, small, medium, large)
- Real-time transcription capabilities

## API Methods

### Audio Methods

#### `startAudioCapture`
Starts capturing audio from the microphone.

**Parameters:**
- `shouldSave` (bool): Whether to save audio to a temporary file

**Returns:**
```json
{
  "isRecording": true,
  "audioURL": "file:///path/to/audio.wav"
}
```

#### `stopAudioCapture`
Stops audio capture and returns captured data.

**Returns:**
```json
{
  "isRecording": false,
  "audioURL": "file:///path/to/audio.wav",
  "audioDataLength": 12345
}
```

#### `getAudioData`
Returns currently captured audio data as base64.

**Returns:**
```json
{
  "audioData": "base64-encoded-audio-data",
  "length": 12345,
  "audioLevel": 0.75
}
```

#### `saveAudioData`
Saves captured audio data to documents directory.

**Parameters:**
- `fileName` (string, optional): Custom filename

**Returns:**
```json
{
  "savedURL": "file:///path/to/saved/audio.wav",
  "fileName": "audio_123456.wav"
}
```

### Permission Methods

#### `requestMicrophonePermission`
Requests microphone access.

**Returns:**
```json
{
  "status": "Authorized",
  "granted": true
}
```

#### `checkMicrophonePermission`
Checks current microphone permission status.

**Returns:**
```json
{
  "status": "Authorized",
  "granted": true,
  "shouldShowRationale": false
}
```

#### `requestDocumentsPermission`
Requests documents storage access.

**Returns:**
```json
{
  "status": "Authorized",
  "granted": true
}
```

#### `checkAllPermissions`
Checks all required permissions.

**Returns:**
```json
{
  "microphone": {
    "status": "Authorized",
    "granted": true
  },
  "documents": {
    "status": "Authorized",
    "granted": true
  }
}
```

#### `openAppSettings`
Opens the app settings page.

### Model Management Methods

#### `downloadModel`
Downloads a Whisper model.

**Parameters:**
- `modelName` (string): Model name (tiny, base, small, medium, large-v3)

**Returns:**
```json
{
  "success": true,
  "modelPath": "/path/to/model.bin",
  "modelName": "tiny"
}
```

#### `deleteModel`
Deletes a downloaded model.

**Parameters:**
- `modelName` (string): Model name to delete

**Returns:**
```json
{
  "success": true,
  "modelName": "tiny",
  "message": "Model deleted successfully"
}
```

#### `getAvailableModels`
Returns list of available models.

**Returns:**
```json
[
  {
    "name": "tiny",
    "displayName": "Tiny (75MB)",
    "sizeBytes": 78643200,
    "sizeDescription": "75 MB",
    "downloadURL": "https://huggingface.co/..."
  }
]
```

#### `getDownloadedModels`
Returns list of downloaded models with validation status.

**Returns:**
```json
[
  {
    "name": "tiny",
    "displayName": "Tiny (75MB)",
    "sizeBytes": 78643200,
    "sizeDescription": "75 MB",
    "actualSizeBytes": 78643200,
    "isValid": true
  }
]
```

#### `isModelDownloaded`
Checks if a specific model is downloaded and valid.

**Parameters:**
- `modelName` (string): Model name to check

**Returns:**
```json
{
  "isDownloaded": true,
  "isValid": true,
  "modelPath": "/path/to/model.bin"
}
```

#### `getStorageInfo`
Returns storage information.

**Returns:**
```json
{
  "totalModelsSize": 157286400,
  "totalModelsSizeMB": 150,
  "availableSpace": 10737418240,
  "availableSpaceMB": 10240,
  "modelsDirectory": "/path/to/models"
}
```

### Processing Methods

#### `processAudioFile`
Processes an audio file using a Whisper model.

**Parameters:**
- `audioPath` (string): Path to audio file
- `modelPath` (string): Path to model file
- `options` (object, optional): Processing options

**Returns:**
```json
{
  "@type": "transcribe",
  "result": [
    [
      {
        "transcript": "Hello, world!",
        "timestamps": [0.0, 2.0]
      }
    ]
  ]
}
```

## Configuration

### Permissions

Add these keys to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for speech-to-text transcription using Whisper.</string>

<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to the documents folder to store Whisper models for offline speech recognition.</string>
```

### iOS Deployment Target

- **Minimum iOS Version**: iOS 12.0+
- **Recommended iOS Version**: iOS 14.0+ for best performance

## Performance Considerations

### Model Selection

- **Tiny (75MB)**: Fastest processing, lower accuracy
- **Base (142MB)**: Good balance of speed and accuracy
- **Small (466MB)**: Better accuracy, slower processing
- **Medium (1.5GB)**: High accuracy, requires more memory
- **Large-v3 (3.1GB)**: Best accuracy, requires significant memory and processing time

### Memory Management

- Large models may cause memory pressure on older devices
- Consider device capabilities when selecting model sizes
- Monitor memory usage during transcription

### Battery Optimization

- Audio processing is CPU intensive
- Consider implementing background processing limits
- Provide user feedback for long-running operations

## Testing

### Unit Tests

Run unit tests using:
```bash
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Manual Testing

1. **Audio Recording**: Test microphone access and audio capture
2. **Permission Flow**: Test permission requests and denial scenarios
3. **Model Download**: Test model download on various network conditions
4. **Transcription**: Test with different audio qualities and languages
5. **Error Handling**: Test edge cases and error scenarios

### Device Testing

Test on a variety of iOS devices:
- iPhone (different screen sizes)
- iPad (regular and mini)
- Different iOS versions (12.0+)
- Different performance capabilities

## Troubleshooting

### Common Issues

1. **Microphone Permission Denied**
   - Guide user to Settings app
   - Check permission status before attempting recording

2. **Model Download Fails**
   - Check network connectivity
   - Verify available storage space
   - Validate downloaded model integrity

3. **Audio Quality Issues**
   - Ensure proper microphone access
   - Check audio format conversion
   - Verify sample rate and channel configuration

4. **Memory Issues**
   - Recommend smaller models for older devices
   - Implement memory monitoring
   - Provide fallback options

### Debug Logging

Enable debug logging by setting log level in your app:
```swift
// In your AppDelegate or app initialization
import os.log

// Set global log level
let logger = Logger(subsystem: "com.whisper_kit", category: "App")
logger.log("Whisper Kit initialized")
```

## Future Enhancements

### Planned Features

- [ ] Real-time streaming transcription
- [ ] Voice activity detection (VAD)
- [ ] Multi-language support
- [ ] Background audio processing
- [ ] Custom model loading
- [ ] Audio format conversion utilities
- [ ] Performance profiling tools

### Performance Optimizations

- [ ] Core ML model support
- [ ] Metal shader acceleration
- [ ] Audio compression for storage
- [ ] Intelligent model caching
- [ ] Background processing optimizations

## Contributing

When contributing to the iOS implementation:

1. Follow Swift coding conventions
2. Add comprehensive unit tests
3. Update documentation
4. Test on multiple iOS devices
5. Verify memory and performance impact
6. Update API documentation if methods change

## Support

For iOS-specific issues:
1. Check device compatibility
2. Verify iOS version requirements
3. Review permission configurations
4. Test with different audio sources
5. Monitor memory usage during operation