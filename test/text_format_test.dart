import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  test('uses Unicode scalars by default and graphemes when configured', () {
    expect(format('{:.1s}', 'e\u0301'), 'e');

    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    expect(graphemes.format('{:.1s}', 'e\u0301'), 'e\u0301');
  });

  test('aligns text using selected Unicode text units', () {
    expect(format('{:4s}', 'é'), 'é   ');
    expect(format('{:>4s}', 'é'), '   é');
    expect(format('{:^4s}', 'é'), ' é  ');
    expect(format('{:*^4s}', 'é'), '*é**');
    expect(format('{:>4s}', 'a👩‍🔬'), 'a👩‍🔬');
  });

  test('uses grapheme fill only in grapheme mode', () {
    final graphemes = Format(textUnit: TextUnit.graphemeClusters);

    expect(
      () => format('{:👩‍🔬>3s}', 'x'),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(graphemes.format('{:👩‍🔬>3s}', 'x'), '👩‍🔬👩‍🔬x');
  });

  test('rejects escaped braces as literal text fill', () {
    expect(
      () => format('{:{{<5s}', 'x'),
      throwsA(isA<InvalidFormatException>()),
    );
  });

  test('accepts precision zero for text', () {
    expect(format('{:.0s}', 'text'), '');
  });

  test('formats converted null text with the requested precision', () {
    expect(format('{!s:.2s}', null), 'nu');
  });

  for (final template in [
    '{:+s}',
    '{:#.4s}',
    '{:04s}',
    '{:.1c}',
    '{:|4s}',
    '{:ab>4s}',
    '{:4.1>}',
  ]) {
    test('rejects invalid text spec $template', () {
      expect(
        () => format(template, 'x'),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }

  test('formats Unicode scalar values with c', () {
    expect(format('{:c}', 0), '\u0000');
    expect(format('{:c}', 0x10ffff), String.fromCharCode(0x10ffff));
    expect(format('{:c}', BigInt.from(65)), 'A');
    expect(format('{:4c}', 65), '   A');
    expect(format('{:<4c}', 65), 'A   ');
  });

  for (final template in [
    '{:+c}',
    '{:zc}',
    '{:#c}',
    '{:04c}',
    '{:,c}',
    '{:.1c}',
    '{:=4c}',
  ]) {
    test('rejects unsupported c option $template', () {
      expect(
        () => format(template, 65),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }

  for (final value in [
    -1,
    0x110000,
    0xd800,
    BigInt.from(-1),
    BigInt.from(0x110000),
    const <int>[65],
  ]) {
    test('rejects unsupported c value $value with a typed error', () {
      expect(
        () => format('{:c}', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', '{:c}')
              .having((error) => error.context.fragment, 'fragment', '{:c}')
              .having((error) => error.context.specifier, 'specifier', 'c'),
        ),
      );
    });
  }
}
