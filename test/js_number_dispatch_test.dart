import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  const isJavaScript = identical(1, 1.0);

  group('integral number dispatch', () {
    test('preserves VM types and canonicalizes JavaScript numbers', () {
      const integer = 42;
      const integralDouble = 42.0;

      expect(format('{}', integer), '42');
      expect(format('{}', integralDouble), isJavaScript ? '42' : '42.0');

      const integerFormats = <String, String>{
        '{:d}': '42',
        '{:b}': '101010',
        '{:o}': '52',
        '{:x}': '2a',
        '{:X}': '2A',
        '{:c}': '*',
        '{:#010_x}': '0x0000_002a',
      };
      for (final MapEntry(:key, :value) in integerFormats.entries) {
        expect(format(key, integer), value, reason: key);
        if (isJavaScript) {
          expect(format(key, integralDouble), value, reason: key);
        }
      }
      if (!isJavaScript) {
        expect(
          () => format('{:d}', integralDouble),
          throwsA(isA<InvalidSpecifierException>()),
        );
        expect(
          () => format('{:#010_x}', integralDouble),
          throwsA(isA<InvalidSpecifierException>()),
        );
      }

      expect(format('{:f}', integer), '42.000000');
      expect(format('{:f}', integralDouble), '42.000000');
      expect(format('{:d}', BigInt.from(42)), '42');
      expect(format('{:f}', BigInt.from(42)), '42.000000');
    });

    test('canonicalizes representation recursively only on JavaScript', () {
      const integer = 42;
      const integralDouble = 42.0;

      expect(format('{!r}', integer), '42');
      expect(format('{!a}', integralDouble), isJavaScript ? '42' : '42.0');
      expect(format('{!r}', BigInt.from(42)), '42');
      expect(
        format('{!r}', [integer, integralDouble]),
        isJavaScript ? '[42, 42]' : '[42, 42.0]',
      );
    });

    test('keeps distinguishable JavaScript doubles on floating paths', () {
      final compatible = Format(
        doubleFormatMode: DoubleFormatMode.compatible,
      );

      expect(format('{}', double.infinity), 'Infinity');
      expect(format('{:f}', double.infinity), 'Infinity');
      expect(format('{!r}', double.negativeInfinity), '-Infinity');
      expect(compatible.format('{}', double.infinity), 'inf');
      expect(compatible.format('{:f}', double.infinity), 'inf');
      expect(compatible.format('{!r}', double.negativeInfinity), '-inf');
      expect(format('{}', -0.0), isJavaScript ? '-0' : '-0.0');
      expect(format('{:f}', -0.0), '-0.000000');
      expect(format('{!r}', -0.0), '-0.0');
      expect(compatible.format('{}', -0.0), '-0.0');
      expect(compatible.format('{!r}', -0.0), '-0.0');
    });
  });
}
