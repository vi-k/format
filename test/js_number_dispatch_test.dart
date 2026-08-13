/// What the two platforms disagree about, written down and checked on both.
///
/// On the VM [int] and [double] are distinct types. Under dart2js they are the
/// same type: `42.0 is int` is true, `identical(1, 1.0)` is true, and there is
/// no way to ask which one the programmer meant. That difference reaches the
/// surface of this package — `format('{}', 42.0)` is `'42.0'` on the VM and
/// `'42'` on the web, and `%d` accepts an integral double on one and rejects it
/// on the other — so it cannot be hidden, only made explicit.
///
/// This file is where it is made explicit. Every test asserts *both* answers,
/// keyed off `isJavaScript`, so neither platform's behaviour can drift
/// unnoticed and a reader can see the divergence rather than discover it. The
/// same cases are listed in the divergence registry the documentation is
/// generated from.
///
/// The second theme is the web's number-to-string, which is not usable here.
/// JavaScript prints the shortest form that round-trips (`1152921504606847000`
/// for 2^60) and switches to exponential at 1e21 — neither of which is what an
/// integer conversion promises. The tests pin exact digits across the range
/// where the platform's own conversion would give something else.
///
/// The third is the option-size ceiling, which used to be a divergence and no
/// longer is: a digit run too long to be an [int] rounds under dart2js instead
/// of failing to parse, so a template rejected on the VM was once accepted in a
/// browser. Both platforms now refuse at the same point, with the same type.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  const isJavaScript = identical(1, 1.0);

  group('integral number dispatch', () {
    // The other direction of the same divergence, and the one that used to
    // arrive as an exception. A specification with no type but a precision is
    // a floating specification — an integer conversion cannot carry one at
    // all — yet on the web the value reaching it is an `int` whenever it came
    // out whole, and the integer validator rejected the precision outright.
    // So `format('{:.3}', someDouble)` formatted on the VM and threw in the
    // browser, depending on whether the arithmetic happened to land on a whole
    // number: a defect that depends on data and never reproduces where the
    // author develops.
    //
    // Since dart2js cannot tell `2` from `2.0`, one divergence from CPython is
    // unavoidable here, and the milder one is taken: the web formats where
    // CPython raises, rather than raising where CPython formats. The VM keeps
    // CPython's answer exactly.
    test(
      'a precision without a type formats an integral double everywhere',
      () {
        const integer = 7;
        const integralDouble = 2.0;

        for (final template in ['{:.3}', '{:10.3}', '{:,.3}']) {
          expect(
            format(template, 2.5).trim(),
            '2.50',
            reason: '$template on a fractional double',
          );
          expect(
            format(template, integralDouble).trim(),
            '2.00',
            reason: '$template on a whole double',
          );
        }

        // `z` and a fraction separator are the other two options no integer
        // specification accepts, so they take the same route.
        expect(format('{:.2n}', integralDouble), '2.0');
        expect(format('{:z}', integralDouble), isJavaScript ? '2' : '2.0');

        // A value the author meant as an integer: indistinguishable from the
        // whole double on the web, so the two answers cannot both be CPython's.
        if (isJavaScript) {
          expect(format('{:.3}', integer), '7.00');
        } else {
          expect(
            () => format('{:.3}', integer),
            throwsA(isA<InvalidSpecifierException>()),
          );
        }
      },
    );

    // The core divergence, across every integer conversion. On the web an
    // integral double *is* an integer, so all seven conversions accept it and
    // give the same answer as the `int`; on the VM the same value is rejected.
    // The floating conversions are the control: they accept both types
    // everywhere, so the divergence is specific to integer dispatch and not a
    // general looseness about number types.
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

    // Above 2^53 the web's own number-to-string stops being exact, so the
    // digits have to come from somewhere else. The value and the notes in the
    // body say which traps are being avoided; what matters is that both
    // platforms print the same exact digits, through both dialects, in both
    // decimal and hexadecimal.
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

    // Only decimal needs a detour above 2^53. Every other radix this package
    // supports is a power of two, and a binary double converts into one
    // exactly — so the platform's own conversion already spells the value and
    // going through BigInt bought nothing. Under dart2js it cost a great deal:
    // 4070 ns for an octal and 11550 for a binary against 150 and 380 without
    // it.
    //
    // BigInt is the oracle here rather than the implementation: it carries the
    // double's exact value, so it says what the digits must be. The values
    // have low bits set on purpose — 2^60 above would agree under any rounding
    // whatsoever, and prove nothing about the ones that would not.
    test('power-of-two radices spell exact digits beyond 2^53', () {
      const values = [
        9007199254740994, // 2^53 + 2, the first step past the safe range
        1152921504606847232, // 2^60 + 256, one step at that magnitude
        4611686018427387904, // 2^62
      ];

      for (final value in values) {
        final exact = BigInt.from(value);
        expect(
          format('{:x}', value),
          exact.toRadixString(16),
          reason: '$value',
        );
        expect(
          format('{:X}', value),
          exact.toRadixString(16).toUpperCase(),
          reason: '$value',
        );
        expect(format('{:o}', value), exact.toRadixString(8), reason: '$value');
        expect(format('{:b}', value), exact.toRadixString(2), reason: '$value');
        expect(sprintf('%x', value), exact.toRadixString(16), reason: '$value');
        expect(
          format('{:x}', -value),
          '-${exact.toRadixString(16)}',
          reason: 'negative $value',
        );
      }
    });

    // The divergence follows the value into a container: a list of `[42, 42.0]`
    // represents as `[42, 42]` on the web and `[42, 42.0]` on the VM. Whichever
    // rule the top level uses, the nested elements have to use the same one —
    // a representation that canonicalized only at the outer level would be
    // inconsistent with itself.
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

    // The values that are doubles on both platforms — infinities and negative
    // zero — must not be dragged into the divergence. Their spelling depends on
    // the configured profile, not on the backend, so every line here is the
    // same on the VM and the web except the one that goes through empty
    // formatting, where negative zero is integral and canonicalizes on the web
    // like any other integral double.
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

  // The range where the digits stop being free. Two conversion strategies meet
  // here — fixed-point up to a ceiling, `BigInt` beyond it — and the seam is
  // crossed from both sides on the web, comparing against `BigInt` rather than
  // a literal so the expectation is derived from the value the double actually
  // holds. Grouping and width are checked at the end to pin that the layout
  // sees the same digits the conversion produced.
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

  // The assumptions the dispatch is built on, asserted directly rather than
  // inferred from behaviour. If a backend ever answered differently, the tests
  // above would fail in confusing ways; these two fail with a clear reason.
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

  // The ceiling, from both dialects and both sources — a literal too long to be
  // an `int` and one merely past the limit. One test per template so a
  // regression names the shape it came back on. The last test is the other
  // half of the contract: the ceiling value itself still works, so the limit is
  // a limit and not an off-by-one.
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

  group('the field index ceiling', () {
    // The ceiling is checked as a BigInt, which is exact everywhere, so both
    // platforms accept and refuse at the same value — the property that
    // matters, and the one worth pinning. What differs is only how the
    // rejection names the index: above 2^53-1 the web has no int that can
    // hold it, so `key` comes back rounded.
    test('accepts and refuses at the same value on both platforms', () {
      expect(
        () => formatWith('{9223372036854775807}'),
        throwsA(isA<MissingFormatArgumentException>()),
      );
      expect(
        () => formatWith('{9223372036854775808}'),
        throwsA(isA<InvalidFormatException>()),
      );
    });

    // No argument can ever be fetched by such an index — no list is that
    // long — so the rounding reaches the message and nothing else. The exact
    // digits stay available in the fragment, which is why `key` is left as it
    // is rather than changing type with magnitude.
    //
    // Both values are compared as text: `9223372036854775807` cannot appear
    // as a literal in this file at all, because dart2js refuses an int
    // literal it cannot represent exactly — the same platform limit the test
    // is about.
    test('names the index exactly on the VM and roundly on the web', () {
      try {
        formatWith('{9223372036854775807}');
        fail('expected a missing argument');
      } on MissingFormatArgumentException catch (error) {
        expect(
          error.key.toString(),
          isJavaScript ? '9223372036854776000' : '9223372036854775807',
        );
        expect(error.context.fragment, '{9223372036854775807}');
      }
    });
  });
}
