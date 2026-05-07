import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_kit/src/method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getAudioData decodes base64 bytes', () async {
    const channel = MethodChannel('whisper_kit');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAudioData') {
        return {'audioData': base64Encode([1, 2, 3])};
      }
      return null;
    });

    final bytes = await WhisperKitMethodChannel().getAudioData();
    expect(bytes, [1, 2, 3]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

