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

  group('platform integer predicates', () {
    test('states what the engine assumes about int on this platform', () {
      // The double dispatch reads `value is int` and then rules out a
      // negative zero, which only matters where an int is a double. The
      // assumption is written down here so it is checked rather than
      // believed: if a backend ever stops answering this way, the branch
      // that guards it is dead code and this test says so.
      expect(identical(1, 1.0), isJavaScript);
      expect(1.0 is int, isJavaScript);
      expect(-0.0 is int, isJavaScript);
      expect(1.5 is int, isFalse);
      expect(double.nan is int, isFalse);
      expect(double.infinity is int, isFalse);
    });

    test('keeps a negative zero out of the integer presentations', () {
      // This is what the predicate above buys. Under dart2js a plain zero
      // is an integer and formats as one, while a negative zero — the same
      // type, by that platform's rules — must not: an integer presentation
      // has no way to spell it, so it is refused there exactly as it is on
      // the VM, where it was never an integer to begin with.
      if (isJavaScript) expect(format('{:d}', 0.0), '0');
      // Not 'n': it is a floating presentation too, and spells the sign.
      for (final type in ['d', 'b', 'o', 'x', 'X']) {
        expect(
          () => format('{:$type}', -0.0),
          throwsA(isA<InvalidSpecifierException>()),
          reason: type,
        );
      }
      // The sign survives everywhere it can be spelled.
      expect(format('{:f}', -0.0), '-0.000000');
      // `n` carries no floating marker of its own, so it canonicalizes on
      // the web the way an empty conversion does.
      expect(format('{:n}', -0.0), isJavaScript ? '-0' : '-0.0');
      expect(format('{!r}', -0.0), '-0.0');
      expect(sprintf('%s', -0.0), '-0.0');
      // Empty formatting canonicalizes an integral double on the web, and
      // a negative zero is integral, so the two platforms differ by the
      // fraction — the same rule the README states for 42.0.
      expect(format('{}', -0.0), isJavaScript ? '-0' : '-0.0');
      expect(format('{}', 0.0), isJavaScript ? '0' : '0.0');
    });
  });

  group('option sizes past the safety ceiling', () {
    // A digit run too long to be an int rounds under dart2js instead of
    // failing to parse, so these used to be rejected on the VM and accepted
    // in the browser. Both platforms now refuse them the same way, at the
    // same point, with the same type.
    for (final template in [
      '{:.99999999999999999999s}',
      '{:.100001s}',
      '{:99999999999999999999d}',
      '{:100001d}',
    ]) {
      test(template, () {
        expect(
          () => format(template, template.contains('d') ? 1 : 'abc'),
          throwsA(isA<InvalidSpecifierException>()),
          reason: template,
        );
      });
    }

    for (final entry in [
      (template: '%99999999999999999999d', value: 1, role: 'width'),
      (template: '%100001d', value: 1, role: 'width'),
      (template: '%.99999999999999999999s', value: 'x', role: 'precision'),
      (template: '%.100001s', value: 'x', role: 'precision'),
    ]) {
      test(entry.template, () {
        expect(
          () => sprintf(entry.template, entry.value),
          throwsA(
            isA<InvalidSpecifierException>().having(
              (error) => error.context.specifier,
              'specifier',
              entry.role,
            ),
          ),
        );
      });
    }

    test('the ceiling itself still formats', () {
      expect(format('{:.100000s}', 'abc'), 'abc');
      expect(sprintf('%.100000s', 'abc'), 'abc');
      expect(format('{:100000d}', 1).length, 100000);
    });
  });
}
