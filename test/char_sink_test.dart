import 'dart:typed_data';

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  test('writeCodeUnits copies a prepared literal', () {
    final units = Uint16List.fromList('lit'.codeUnits);
    final sink =
        CharSink(1)
          ..writeCodeUnits(units)
          ..writeCodeUnits(units);
    expect(sink.toString(), 'litlit');
  });

  test('writes strings, chars and fill with growth', () {
    final sink =
        CharSink(1)
          ..writeString('ab')
          ..writeCharCode(0x2d)
          ..fill(0x30, 3)
          ..writeString('');
    expect(sink.length, 6);
    expect(sink.toString(), 'ab-000');
  });

  test('fill ignores non-positive counts', () {
    final sink =
        CharSink(4)
          ..fill(0x30, 0)
          ..fill(0x30, -2);
    expect(sink.toString(), isEmpty);
  });

  test('digitCount matches toString length across radixes', () {
    for (final value in [0, 1, 7, 9, 10, 99, 12345, -1, -12345]) {
      for (final radix in [2, 8, 10, 16]) {
        expect(
          CharSink.digitCount(value, radix),
          value.abs().toRadixString(radix).length,
          reason: '$value radix $radix',
        );
      }
    }
  });

  test('writeMagnitude writes |value| digits in place', () {
    final sink =
        CharSink(4)
          ..writeMagnitude(-48879, 16, uppercase: true)
          ..writeCharCode(0x7c)
          ..writeMagnitude(255, 16)
          ..writeMagnitude(0, 10);
    expect(sink.toString(), 'BEEF|ff0');
  });

  test('surrogate pairs survive as code units', () {
    final sink = CharSink(2)..writeString('a\u{1F600}b');
    expect(sink.toString(), 'a\u{1F600}b');
  });

  test('buffer reallocation handles growth past 16-unit minimum', () {
    final sink =
        CharSink(1)
          ..writeString('start')
          ..fill(0x30, 20)
          ..writeCharCode(0x2d)
          ..fill(0x31, 15);
    expect(sink.length, 41);
    expect(sink.toString(), 'start${'0' * 20}-${'1' * 15}');
  });
}
