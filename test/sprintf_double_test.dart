/// Floating conversions in the printf dialect, under the `compatible` profile —
/// including `%a`, which exists nowhere else in the package.
///
/// As in `double_format_test.dart`, `sprintf` is shadowed below with a
/// `compatible` instance: these are the digits the package produces itself, and
/// the reference is C rather than Dart.
///
/// Most of the decimal rules are shared with the brace path and are checked
/// here only where printf differs — repeated and conflicting flags, which the
/// brace grammar cannot even express, and the special values under zero
/// padding, where C pads with spaces because zeros around `inf` would be
/// nonsense.
///
/// `%a` is the reason the file is long. Hexadecimal floating notation prints
/// the binary64 value exactly, so every case is decidable and none of it is a
/// matter of taste: the leading digit is 1 for normals and 0 for subnormals,
/// the exponent is a power of two written in decimal, rounding at a given
/// precision is ties-to-even on hex digits, and both `p-1022` boundaries have a
/// canonical spelling. The precision sweep from 0 to 13 walks 0.1 through every
/// prefix of its mantissa — 13 being the point at which the value is exact — so
/// a rounding error at any single length is caught rather than averaged away.
///
/// The locale tests are here rather than with the brace ones because printf
/// reaches the localization through its own path: the same expanding-digit trap
/// (a locale whose digits are wider than ASCII, so padding has to be fitted
/// after localization) applies, and nothing else in the suite exercises it on
/// this side.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _PrintfNumberLocale implements NumberLocale {
  @override
  String get decimalSeparator => ',';

  @override
  String get exponentSeparator => '×10^';

  @override
  String get groupSeparator => '.';

  @override
  List<int> get grouping => const [3];

  @override
  bool get groupingEnabled => true;

  @override
  String get minusSign => '−';

  @override
  String get plusSign => '＋';

  @override
  String localizeDigits(String asciiDigits) => asciiDigits
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');
}

final class _ExpandingZeroLocale implements NumberLocale {
  @override
  String get decimalSeparator => '.';

  @override
  String get exponentSeparator => 'e';

  @override
  String get groupSeparator => ',';

  @override
  List<int> get grouping => const [3];

  @override
  bool get groupingEnabled => false;

  @override
  String get minusSign => '-';

  @override
  String get plusSign => '+';

  @override
  String localizeDigits(String asciiDigits) =>
      asciiDigits.replaceAll('0', '٠٠');
}

final _compatibleFormat = Format(doubleFormatMode: DoubleFormatMode.compatible);

String sprintf(String template, Object? value) =>
    _compatibleFormat.sprintf(template, value);

void main() {
  // The decimal rules, stated against the current C++ specification of printf:
  // ties to even on the binary value, six default digits for `%e`, `%g`
  // choosing notation from the rounded exponent and stripping trailing zeros
  // unless `#` keeps them, an underflowing value printing as zeros rather than
  // vanishing, and carry moving the exponent (`9.999` at two digits becomes
  // `1.00e+01`).
  test('matches C++23 decimal float rules', () {
    expect(sprintf('%.0f', 2.5), '2');
    expect(sprintf('%.0f', 3.5), '4');
    expect(sprintf('%e', 1.0), '1.000000e+00');
    expect(sprintf('%.0g', 12.0), '1e+01');
    expect(sprintf('%#.4g', 12.0), '12.00');
    expect(sprintf('%f', 1e-10), '0.000000');
    expect(sprintf('%.2e', 9.999), '1.00e+01');
  });

  // Case follows the conversion letter, for digits and for the special values
  // alike; `#` keeps a point with nothing after it; negative zero keeps its
  // sign; and a precision of 50 shows the exact binary value, which is what
  // separates a real decimal conversion from one that stops at what a `double`
  // can round-trip.
  test('supports case precision extremes and negative zero', () {
    expect(sprintf('%E', 1.0), '1.000000E+00');
    expect(sprintf('%F', double.infinity), 'INF');
    expect(sprintf('%G', double.nan), 'NAN');
    expect(sprintf('%f', -0.0), '-0.000000');
    expect(sprintf('%#.0f', 1.0), '1.');
    expect(sprintf('%#.0e', 1.0), '1.e+00');
    expect(
      sprintf('%.50f', 1e-6),
      '0.00000099999999999999995474811182588625868561393872',
    );
  });

  // `%f` never switches to exponential, however large the value: the largest
  // finite double is 309 digits, and all of them are printed. This is where a
  // `toStringAsFixed` shortcut gives up — the SDK refuses this precision — so
  // the digits have to come from the package's own conversion.
  test('keeps finite fixed conversion out of exponent notation', () {
    expect(
      sprintf('%.0f', 1.7976931348623157e308),
      '179769313486231570814527423731704356798070567525844996598917476803'
      '157260780028538760589558632766878171540458953514382464234321326889'
      '464182768467546703537516986049910576551282076245490090389328944075'
      '868508455133942304583236903222948165808559332123348274797826204144'
      '723168738177180919299881250404026184124858368',
    );
  });

  // printf lets flags repeat and conflict, which the brace grammar cannot even
  // express. Repetition is idempotent, `-` beats `0`, and `+` beats the space
  // flag — so the parser has to accumulate flags rather than take the last one,
  // and the layout has to resolve them by rule rather than by order.
  test('applies repeated flags width and precedence', () {
    expect(sprintf('%+++08.2f', 12.5), '+0012.50');
    expect(sprintf('%--08.2f', 12.5), '12.50   ');
    expect(sprintf('% 08.2f', 12.5), ' 0012.50');
  });

  // Zero padding is suppressed for the special values: `%08f` of infinity is
  // spaces and `inf`, not `0000+inf`. This is the one place printf and the
  // brace dialect deliberately disagree — `{:010f}` of infinity *does* pad with
  // zeros, following Python — and both are pinned so neither drifts toward the
  // other.
  test('uses spaces for zero-padded special values', () {
    expect(sprintf('%+08f', double.infinity), '    +inf');
    expect(sprintf('%+08f', double.nan), '    +nan');
    expect(sprintf('%08f', double.negativeInfinity), '    -inf');
  });

  // printf has no `n`, so a locale applies to the ordinary conversions — but
  // only to the symbols and digits, never to grouping: this locale enables
  // grouping and `%+.2f` still prints `1234` ungrouped, because a printf
  // template that did not ask for separators must not get them. Everything else
  // is localized, including the exponent separator and the sign inside the
  // exponent, and zero padding is fitted around the localized text.
  test('localizes symbols and digits without implicit grouping', () {
    final localized = Format(
      numberLocale: _PrintfNumberLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );

    expect(localized.sprintf('%+.2f', 1234.5), '＋١٢٣٤,٥٠');
    expect(localized.sprintf('%+.1e', 12.0), '＋١,٢×10^＋٠١');
    expect(localized.sprintf('%+010.2f', 12.5), '＋٠٠٠٠١٢,٥٠');
    expect(localized.sprintf('%+15.1e', 12.0), '    ＋١,٢×10^＋٠١');
    expect(localized.sprintf('%+015.1e', 12.0), '＋٠٠٠٠١,٢×10^＋٠١');
  });

  // A locale whose digits are *wider* than the ASCII ones — each `0` becomes
  // two characters. Padding computed before localization would overshoot the
  // requested width, so the fit has to happen after: the result is exactly ten
  // characters, with the expansion accounted for.
  test('fits zero padding after expanding localized digits', () {
    final localized = Format(
      numberLocale: _ExpandingZeroLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );

    expect(localized.sprintf('%010.2f', 12.5), '٠٠٠٠12.5٠٠');
  });

  // A string is never coerced to a number. The integer case is the platform
  // divergence again, in the other direction from `%d`: on the web `1` is a
  // `double` and `%f` accepts it, on the VM it is an `int` and `%f` does not.
  // Both answers are asserted rather than one being chosen.
  test('floating printf conversions require double', () {
    expect(
      () => sprintf('%f', '1.0'),
      throwsA(
        isA<UnsupportedFormatValueException>()
            .having((error) => error.context.template, 'template', '%f')
            .having((error) => error.context.specifier, 'specifier', 'f')
            .having((error) => error.context.conversion, 'conversion', 'f')
            .having((error) => error.context.argumentIndex, 'argument', 0),
      ),
    );

    if (identical(1, 1.0)) {
      expect(sprintf('%f', 1), '1.000000');
    } else {
      expect(
        () => sprintf('%f', 1),
        throwsA(isA<UnsupportedFormatValueException>()),
      );
    }
  });

  // `%a` in its ordinary shape: a hexadecimal mantissa, a binary exponent
  // written in decimal, case following the conversion letter for the digits,
  // the `0x` prefix and the `p`. Zero is spelled `0x0p+0` with no fractional
  // part, and negative zero keeps its sign — the notation is exact, so it must
  // represent that distinction too.
  test('formats hexadecimal doubles', () {
    expect(sprintf('%a', 1.5), '0x1.8p+0');
    expect(sprintf('%A', 1.5), '0X1.8P+0');
    expect(sprintf('%#.0a', 1.0), '0x1.p+0');
    expect(sprintf('%.1a', 1.96875), '0x2.0p+0');
    expect(sprintf('%a', 0.0), '0x0p+0');
    expect(sprintf('%a', -0.0), '-0x0p+0');
  });

  // The boundaries of the format, where the leading digit stops being 1.
  // Subnormals have no implicit leading bit, so the smallest one is
  // `0x0.0000000000001p-1022` — a leading zero and a fixed exponent, the glibc
  // spelling — while the smallest normal at the same exponent is `0x1p-1022`.
  // The largest finite value shows the mantissa saturated. The last pair pins
  // that a precision beyond the value's 13 hex digits pads with zeros rather
  // than inventing digits.
  test('formats hexadecimal binary64 boundaries canonically', () {
    expect(sprintf('%a', 5e-324), '0x0.0000000000001p-1022');
    expect(sprintf('%a', 2.2250738585072014e-308), '0x1p-1022');
    expect(sprintf('%a', 1.7976931348623157e308), '0x1.fffffffffffffp+1023');
    expect(sprintf('%.13a', 0.1), '0x1.999999999999ap-4');
    expect(sprintf('%.14a', 0.1), '0x1.999999999999a0p-4');
  });

  // Rounding hex digits, where a tie is exact rather than approximate: 1.5 at
  // precision 0 is exactly halfway between `0x1p+0` and `0x2p+0`, and ties to
  // even gives 2. The `1.03125`/`1.09375` pair does the same one digit in, and
  // the last two show rounding at the extremes — where carry would overflow the
  // exponent, and where a subnormal rounds away to zero while keeping the fixed
  // `p-1022`.
  test('rounds hexadecimal precision ties to even', () {
    expect(sprintf('%.0a', 1.5), '0x2p+0');
    expect(sprintf('%.1a', 1.03125), '0x1.0p+0');
    expect(sprintf('%.1a', 1.09375), '0x1.2p+0');
    expect(sprintf('%.0a', 1.7976931348623157e308), '0x2p+1023');
    expect(sprintf('%.0a', 5e-324), '0x0p-1022');
  });

  // The sweep: 0.1 at every precision from 0 to 13, which is where its mantissa
  // becomes exact. The expected values are a written-out table rather than a
  // computation, so the test cannot share a bug with the code — and because the
  // mantissa is `1.999…a`, every single length rounds differently from a naive
  // truncation. A rounding error at one precision is caught rather than hidden
  // among the others.
  test('formats every exact hexadecimal precision from 0 through 13', () {
    const expected = [
      '0x2p-4',
      '0x1.ap-4',
      '0x1.9ap-4',
      '0x1.99ap-4',
      '0x1.999ap-4',
      '0x1.9999ap-4',
      '0x1.99999ap-4',
      '0x1.999999ap-4',
      '0x1.9999999ap-4',
      '0x1.99999999ap-4',
      '0x1.999999999ap-4',
      '0x1.9999999999ap-4',
      '0x1.99999999999ap-4',
      '0x1.999999999999ap-4',
    ];
    for (var precision = 0; precision <= 13; precision++) {
      expect(
        sprintf('%.${precision}a', 0.1),
        expected[precision],
        reason: 'precision $precision',
      );
    }
  });

  // `%a` under the ordinary layout: zero padding goes between the `0x` prefix
  // and the mantissa — not before the prefix, which would produce a number that
  // no longer reads as hexadecimal — and the special values follow the same
  // space-padding rule as the decimal conversions.
  test('applies hexadecimal signs width and special policy', () {
    expect(sprintf('%+020.3a', 1.5), '+0x0000000001.800p+0');
    expect(sprintf('%-20.3a', 1.5), '0x1.800p+0          ');
    expect(sprintf('%+08a', double.infinity), '    +inf');
    expect(sprintf('%08A', double.negativeInfinity), '    -INF');
  });
}
