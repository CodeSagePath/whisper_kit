import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";

class AudioManager {
  static const List<Map<String, String>> _audioFiles = [
    {"name": "punjabi.wav", "size": "45KB"},
    {"name": "marathi.wav", "size": "35KB"},
    {"name": "english.wav", "size": "260KB"},
    {"name": "telugu.wav", "size": "52KB"},
    {"name": "french.wav", "size": "55KB"},
    {"name": "japanese.wav", "size": "58KB"},
  ];

  static List<Map<String, String>> get availableFiles => _audioFiles;

  static Future<String> prepareAudioFile(String fileName) async {
    try {
      final Directory documentDirectory =
          await getApplicationDocumentsDirectory();
      final File audioFile = File("${documentDirectory.path}/$fileName");

      if (audioFile.existsSync()) {
        if (kDebugMode) {
          debugPrint("Audio file already exists: ${audioFile.path}");
        }
        return audioFile.path;
      }

      if (kDebugMode) {
        debugPrint("Preparing audio file from assets: $fileName");
      }

      // Load from bundled assets and copy to documents directory
      final ByteData assetBytes = await rootBundle.load("assets/$fileName");
      await audioFile.writeAsBytes(assetBytes.buffer.asUint8List());

      if (kDebugMode) {
        debugPrint("Audio file prepared successfully: ${audioFile.path}");
      }

      return audioFile.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error preparing audio file $fileName: $e");
      }
      throw Exception("Failed to prepare audio file: $e");
    }
  }

  static Future<void> preloadAllAudioFiles() async {
    for (final audioFile in _audioFiles) {
      try {
        await prepareAudioFile(audioFile["name"]!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Failed to preload ${audioFile["name"]}: $e");
        }
      }
    }
  }
}
