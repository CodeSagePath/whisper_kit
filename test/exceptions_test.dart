import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_kit/src/exceptions.dart';

void main() {
  test('typed exceptions include context in toString()', () {
    final e = ModelException.notFound('ggml-base.bin');
    expect(e.toString(), contains('ModelException:'));
    expect(e.toString(), contains('ggml-base.bin'));
  });
}

