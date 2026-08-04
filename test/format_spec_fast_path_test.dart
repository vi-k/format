import 'package:format/format.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/src/engine.dart' as engine;

void main() {
  test('recognizes single ASCII built-in format specifications', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('d'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('%'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('é'), isFalse);
  });

  test('recognizes fixed double precision without Unicode tokenization', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.0f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.20F'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.f'), isFalse);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2g'), isFalse);
  });

  test(
    'recognizes ASCII flag and width specifications and matches the general '
    'parser',
    () {
      const sources = [
        '10d',
        '010d',
        '+10d',
        '-10d',
        ' 10d',
        '#x',
        '#o',
        '+#010X',
        'z10d',
        '0d',
        '00d',
        '07',
        '10',
        '100000x',
        '+d',
        '10s',
        '10%',
      ];
      for (final source in sources) {
        expect(
          engine.debugSimpleBuiltinFormatSpecMatchesGeneralParser(source),
          isTrue,
          reason: source,
        );
      }
    },
  );

  test('leaves Unicode, custom and uncommon specifications to the general '
      'parser', () {
    const sources = [
      '10q', // custom format name
      '1<5d', // fill and align
      '<5d', // align
      '8.2f', // width with precision
      '10,d', // grouping
      '1234567d', // width beyond the fast path digit limit
      'é<5d', // Unicode fill
      '#é', // Unicode after a flag
      '10д', // Unicode in place of a type
    ];
    for (final source in sources) {
      expect(
        engine.debugUsesSimpleBuiltinFormatSpec(source),
        isFalse,
        reason: source,
      );
    }
  });

  test('formats fast path specifications like the general parser', () {
    expect(format('{:10d}', 1), '         1');
    expect(format('{:10d}', -1), '        -1');
    expect(format('{:010d}', 42), '0000000042');
    expect(format('{:010d}', -42), '-000000042');
    expect(format('{:+10d}', 42), '       +42');
    expect(format('{: d}', 42), ' 42');
    expect(format('{:#x}', 255), '0xff');
    expect(format('{:#X}', 255), '0XFF');
    expect(format('{:#o}', 8), '0o10');
    expect(format('{:10}', 'ab'), 'ab        ');
    expect(format('{:10}', 42), '        42');
  });
}
