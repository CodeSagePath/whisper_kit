import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_kit/bean/request_bean.dart';

void main() {
  test('TranscribeRequestDto.toRequestString includes @type and keys', () {
    final dto = TranscribeRequestDto.fromTranscribeRequest(
      TranscribeRequest(audio: '/tmp/audio.wav'),
      '/tmp/ggml-base.bin',
    );

    final map = json.decode(dto.toRequestString()) as Map<String, dynamic>;

    expect(map['@type'], 'getTextFromWavFile');
    expect(map['audio'], '/tmp/audio.wav');
    expect(map['model'], '/tmp/ggml-base.bin');
    expect(map['language'], 'auto');
    expect(map['threads'], 6);
    expect(map['is_translate'], false);
    expect(map['is_verbose'], false);
    expect(map['is_no_timestamps'], false);
    expect(map['is_special_tokens'], false);
    expect(map['n_processors'], 1);
    expect(map['split_on_word'], false);
    expect(map['no_fallback'], false);
    expect(map['diarize'], false);
    expect(map['speed_up'], false);
  });
}

