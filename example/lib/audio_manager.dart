import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";

class AudioManager {
  static const String _audioHost = "https://github.com/thewh1teagle/whisper_flutter/raw/master/example/assets";

  static const List<Map<String, String>> _audioFiles = [
    {"name": "punjabi.wav", "size": "565KB"},
    {"name": "marathi.wav", "size": "436KB"},
    {"name": "english.wav", "size": "8.3MB"},
    {"name": "telugu.wav", "size": "655KB"},
    {"name": "french.wav", "size": "694KB"},
    {"name": "japanese.wav", "size": "726KB"},
  ];

  static List<Map<String, String>> get availableFiles => _audioFiles;

  static Future<String> downloadAudioFile(String fileName) async {
    try {
      final Directory documentDirectory = await getApplicationDocumentsDirectory();
      final File audioFile = File("${documentDirectory.path}/$fileName");

      if (audioFile.existsSync()) {
        if (kDebugMode) {
          debugPrint("Audio file already exists: ${audioFile.path}");
        }
        return audioFile.path;
      }

      if (kDebugMode) {
        debugPrint("Downloading audio file: $fileName");
      }

      final response = await http.get(
        Uri.parse("$_audioHost/$fileName"),
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        await audioFile.writeAsBytes(response.bodyBytes);

        if (kDebugMode) {
          debugPrint("Audio file downloaded successfully: ${audioFile.path}");
        }

        return audioFile.path;
      } else {
        throw Exception("Failed to download audio file: HTTP ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error downloading audio file $fileName: $e");
      }
      throw Exception("Failed to download audio file: $e");
    }
  }

  static Future<void> preloadAllAudioFiles() async {
    for (final audioFile in _audioFiles) {
      try {
        await downloadAudioFile(audioFile["name"]!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Failed to preload ${audioFile["name"]}: $e");
        }
      }
    }
  }
}