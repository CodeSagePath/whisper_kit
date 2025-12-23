# WhisperKit GDPR Compliance Guide

This document provides guidance on using WhisperKit in compliance with the General Data Protection Regulation (GDPR) and other privacy regulations.

## Table of Contents

1. [Overview](#overview)
2. [Data Processing](#data-processing)
3. [Privacy by Design](#privacy-by-design)
4. [User Consent](#user-consent)
5. [Data Rights](#data-rights)
6. [Security Measures](#security-measures)
7. [Data Retention](#data-retention)
8. [Third-Party Considerations](#third-party-considerations)
9. [Implementation Checklist](#implementation-checklist)

---

## Overview

### What is WhisperKit?

WhisperKit is an **on-device** speech-to-text library. This means:

- ✅ Audio is processed locally on the user's device
- ✅ No audio data is sent to external servers
- ✅ Models run entirely offline
- ✅ No third-party API calls for transcription

### GDPR Relevance

Speech data is considered **biometric data** under GDPR Article 9, as voice patterns can identify individuals. However, WhisperKit's on-device processing significantly reduces data protection risks.

---

## Data Processing

### What Data is Processed?

| Data Type | Processed Locally | Sent Externally |
|-----------|------------------|-----------------|
| Audio recordings | ✅ Yes | ❌ No |
| Transcribed text | ✅ Yes | ❌ No (by default) |
| Voice patterns | ✅ Yes (transient) | ❌ No |
| Language detection | ✅ Yes | ❌ No |

### Data Flow

```
[Audio Recording] → [On-Device Processing] → [Transcribed Text]
                           ↓
                    [Deleted After Processing]
```

### Processing Locations

- **Model files**: Stored in app's local storage
- **Audio files**: Temporary, user-controlled
- **Transcription output**: App-controlled, not sent externally

---

## Privacy by Design

### Configuring Privacy Options

```dart
import 'package:whisper_kit/whisper_kit.dart';

// Configure privacy-focused processing
final privacyOptions = PrivacyOptions(
  deleteAudioAfterProcessing: true,
  disableTelemetry: true,
  localStorageOnly: true,
  encryptCachedResults: true,
);
```

### Privacy Options Explained

| Option | Description | GDPR Benefit |
|--------|-------------|--------------|
| `deleteAudioAfterProcessing` | Auto-delete source audio | Data minimization |
| `disableTelemetry` | No usage tracking | Purpose limitation |
| `localStorageOnly` | No cloud sync | Data localization |
| `encryptCachedResults` | Encrypt cached data | Data security |

### Disabling Telemetry

```dart
// Ensure no data collection
Telemetry.instance.setEnabled(false);
FeatureFlags.instance.disable(Feature.analytics);
```

---

## User Consent

### Obtaining Consent

Under GDPR, you must obtain explicit consent for:
- Recording audio (microphone permission)
- Processing voice data
- Storing transcriptions

### Consent Implementation

```dart
class ConsentManager {
  static const _consentKey = 'speech_processing_consent';
  
  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }
  
  static Future<void> setConsent(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, granted);
  }
}

// Before first use
if (!await ConsentManager.hasConsent()) {
  final granted = await showConsentDialog();
  if (!granted) {
    return; // Don't proceed without consent
  }
  await ConsentManager.setConsent(true);
}
```

### Consent Dialog Requirements

Your consent dialog should explain:
1. What data will be collected (audio)
2. How it will be processed (on-device transcription)
3. Why it's needed (app functionality)
4. User rights (withdraw consent, delete data)

### Example Consent Text

```
"This app uses speech recognition to transcribe your voice.

• Your audio is processed entirely on your device
• No audio is sent to external servers
• Transcriptions are stored locally
• You can delete all data at any time

Do you consent to voice processing?"
```

---

## Data Rights

### Right to Access

Users can request access to their data:

```dart
class DataAccessService {
  static Future<Map<String, dynamic>> exportUserData() async {
    final cache = TranscriptionCache();
    final transcriptions = await cache.getAll();
    
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'transcriptions': transcriptions.map((t) => t.toJson()).toList(),
    };
  }
}
```

### Right to Deletion

Users can request deletion of their data:

```dart
class DataDeletionService {
  static Future<void> deleteAllUserData() async {
    // Delete cached transcriptions
    final cache = TranscriptionCache();
    await cache.clear();
    
    // Delete temporary audio files
    await SecureCleanup.cleanTempAudioFiles('/path/to/temp');
    
    // Delete downloaded models (optional)
    await SecureCleanup.cleanDirectory(modelDirectory);
    
    // Clear preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

### Right to Rectification

Allow users to edit transcriptions:

```dart
class TranscriptionEditor {
  static Future<void> updateTranscription(
    String id,
    String correctedText,
  ) async {
    final db = TranscriptionDatabase();
    await db.update(id, {'text': correctedText});
  }
}
```

### Right to Portability

Export data in portable format:

```dart
// Export to JSON
final json = await DataAccessService.exportUserData();
final file = File('user_data_export.json');
await file.writeAsString(jsonEncode(json));

// Export transcriptions to common formats
for (final transcription in transcriptions) {
  await File('transcript_${transcription.id}.srt')
      .writeAsString(transcription.toSRT());
}
```

---

## Security Measures

### Secure Model Loading

```dart
// Verify models come from trusted sources
final loader = SecureModelLoader(
  options: SecureLoadingOptions(
    verifyBeforeLoad: true,
    trustedSources: TrustedSources.defaultSources
        .map((s) => s.urlPattern)
        .toList(),
  ),
);

final result = await loader.loadModel(modelPath);
if (!result.success) {
  throw SecurityException('Model verification failed');
}
```

### Secure Cleanup

```dart
// Securely delete audio after processing
await SecureCleanup.secureDelete(audioPath);

// Regular cleanup of temporary files
await SecureCleanup.cleanTempAudioFiles(
  tempDirectory,
  olderThan: Duration(hours: 1),
);
```

### Encryption at Rest

```dart
// Encrypt cached transcriptions
final cache = TranscriptionCache(
  directory: cacheDir,
  encryptionKey: userEncryptionKey,  // User-derived key
);
```

---

## Data Retention

### Retention Policies

Configure automatic data expiration:

```dart
final cache = TranscriptionCache(
  expiration: Duration(days: 30),  // Auto-expire after 30 days
  maxEntries: 100,                  // Limit stored items
);

// Regularly cleanup expired entries
await cache.cleanup();
```

### Recommended Retention Periods

| Data Type | Recommended Retention | Justification |
|-----------|----------------------|---------------|
| Audio recordings | Delete immediately | Not needed after processing |
| Transcriptions | 30-90 days | User convenience |
| Cache | 7 days | Performance optimization |
| Logs | 14 days | Debugging only |

### Automatic Deletion

```dart
// Schedule regular cleanup
class CleanupService {
  static Future<void> performCleanup() async {
    // Delete old transcriptions
    final cache = TranscriptionCache();
    await cache.cleanup();
    
    // Delete orphaned audio files
    await SecureCleanup.cleanTempAudioFiles(
      tempDirectory,
      olderThan: Duration(hours: 24),
    );
  }
}
```

---

## Third-Party Considerations

### WhisperKit Components

| Component | Source | Data Sharing |
|-----------|--------|--------------|
| whisper.cpp | Open source | None |
| Whisper models | Hugging Face | Download only |
| Flutter plugin | Open source | None |

### Model Downloads

Models are downloaded from trusted sources:
- Hugging Face (huggingface.co)
- GitHub releases

No telemetry or user data is sent during downloads.

### If You Add Cloud Features

If you extend WhisperKit with cloud features:

```dart
// Example: Cloud backup (requires additional consent)
if (userConsentForCloudBackup) {
  // Ensure proper data protection
  final encrypted = encryptTranscription(transcription);
  await uploadToSecureCloud(encrypted);
}
```

---

## Implementation Checklist

### Before Launch

- [ ] **Privacy Policy**: Document voice data processing
- [ ] **Consent Flow**: Implement explicit consent before recording
- [ ] **Data Access**: Provide way to export user data
- [ ] **Data Deletion**: Implement complete data deletion
- [ ] **Retention Policy**: Configure automatic data expiration
- [ ] **Secure Storage**: Encrypt sensitive cached data
- [ ] **Minimal Data**: Delete audio after processing
- [ ] **Telemetry**: Disable or make opt-in

### Privacy Settings UI

```dart
class PrivacySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Privacy',
      children: [
        SwitchSetting(
          title: 'Auto-delete recordings',
          value: privacyOptions.deleteAudioAfterProcessing,
          onChanged: (v) => updatePrivacyOption('deleteAudio', v),
        ),
        SwitchSetting(
          title: 'Usage analytics',
          value: !privacyOptions.disableTelemetry,
          onChanged: (v) => updatePrivacyOption('telemetry', v),
        ),
        ActionSetting(
          title: 'Export my data',
          onPressed: () => exportUserData(),
        ),
        ActionSetting(
          title: 'Delete all my data',
          isDestructive: true,
          onPressed: () => confirmAndDeleteData(),
        ),
      ],
    );
  }
}
```

### Documentation Requirements

For GDPR compliance, document:

1. **Purpose**: Why you process voice data
2. **Legal Basis**: Consent or legitimate interest
3. **Processing**: On-device, no external transmission
4. **Retention**: How long data is kept
5. **Rights**: How users exercise their rights
6. **Security**: Measures to protect data

---

## Summary

### GDPR Compliance Benefits of WhisperKit

1. **On-Device Processing**: No data leaves the device
2. **No Third-Party Sharing**: Audio stays local
3. **User Control**: Easy data deletion
4. **Transparency**: Open-source, auditable

### Key Compliance Actions

1. Get explicit consent before recording
2. Process audio on-device only
3. Delete audio after processing
4. Provide data export/deletion
5. Document your privacy practices

### Legal Disclaimer

This guide provides technical guidance for implementing GDPR-compliant applications using WhisperKit. It is not legal advice. Consult with a legal professional for specific compliance requirements in your jurisdiction.

---

## Resources

- [GDPR Official Text](https://gdpr.eu/)
- [Article 29 Working Party Guidelines](https://ec.europa.eu/newsroom/article29/items/612053)
- [ICO Guide to AI and Data Protection](https://ico.org.uk/for-organisations/guide-to-data-protection/key-dp-themes/guidance-on-ai-and-data-protection/)
