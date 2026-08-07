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
        '{:#010_x}': '0x000_002a',
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

    test('prints exact decimal digits beyond 2^53 on every platform', () {
      // 2^60: exactly representable as a double, so the literal compiles on
      // dart2js too. JS String(n) would print the shortest-roundtrip form
      // 1152921504606847000; the exact digits are required instead.
      const big = 1152921504606846976;

      expect(format('{:d}', big), '1152921504606846976');
      expect(format('{}', big), '1152921504606846976');
      expect(format('{:x}', big), '1000000000000000');
      expect(sprintf('%d', big), '1152921504606846976');

      if (isJavaScript) {
        // 1e21 is an integral JavaScript number, so it dispatches as an
        // integer on the web. JS String(n) switches to exponential notation
        // at 1e21 ('1e+21'); exact digits are required instead.
        expect(format('{:d}', 1e21), '1000000000000000000000');
        expect(format('{:,d}', 1e21), '1,000,000,000,000,000,000,000');
        expect(sprintf('%d', 1e21), '1000000000000000000000');
      }
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
      final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

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

  test('integers past the exact double range keep every digit', () {
    // On the web these are doubles, so the digits have to come from
    // somewhere other than the platform's own number-to-string, which
    // switches to a shortest-roundtrip form here. Fixed-point conversion
    // covers most of the range and BigInt the rest; both must agree with
    // the value the double actually holds.
    const beyondExact = 9007199254740992; // 2^53
    expect(format('{}', beyondExact), '9007199254740992');
    expect(format('{:d}', beyondExact), '9007199254740992');
    expect(format('{}', -beyondExact), '-9007199254740992');
    expect(sprintf('%d', beyondExact), '9007199254740992');

    // Either side of the ceiling where fixed-point conversion gives up.
    // Only the web can hold these as integers at all; on the VM toInt()
    // saturates long before 1e21.
    if (isJavaScript) {
      for (final value in [999999999999999900000.0, 1e21, 1e22]) {
        expect(
          format('{:d}', value.toInt()),
          BigInt.from(value).toString(),
          reason: '$value',
        );
      }
    }

    // Grouping and width still see the same digits.
    expect(format('{:,d}', beyondExact), '9,007,199,254,740,992');
    expect(format('{:>20d}', beyondExact), '    9007199254740992');
  });
}
