/// Double layout under the `compatible` profile — the package's own digits,
/// matching C and Python rather than the Dart SDK.
///
/// The whole file shadows `format` with a `compatible` instance (below the
/// locale classes), because that is the profile whose digits the package
/// produces itself and therefore the only one whose correctness is ours to
/// prove. The `dartSdk` profile delegates to the SDK and is covered in
/// `dart_double_format_test.dart`.
///
/// What is being pinned is a decimal conversion of a binary value, so the
/// expectations are long and exact on purpose. A double is a rational with a
/// power-of-two denominator, and printing it at high precision must show that
/// exact value — `{:.50f}` of 1.23456789 is not the digits anyone typed, and
/// `{:.0f}` of the largest finite double is 309 digits, all of them determined.
/// Anything shorter would let a `toStringAsFixed` shortcut pass while quietly
/// rounding.
///
/// Rounding is ties-to-even, on the binary value and not on its decimal
/// spelling: 2.675 is really 2.67499…, so `{:.2f}` is `2.67`. Cases that look
/// like off-by-one errors are the point of the test rather than a mistake in
/// it.
///
/// The rest is layout over those digits — exponent thresholds and carry, the
/// alternate form, grouping on both sides of the point, sign and zero padding,
/// negative zero (normalized after rounding, never before), the special values,
/// and `n`, which hands the separators, the digits and the exponent marker to a
/// caller-supplied locale.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _LocalizedNumberLocale implements NumberLocale {
  @override
  String get decimalSeparator => ',';

  @override
  String get exponentSeparator => '×10^';

  @override
  String get groupSeparator => '.';

  @override
  List<int> get grouping => const [3, 2];

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

final class _ThrowingDoubleLocale implements NumberLocale {
  @override
  String get decimalSeparator => throw StateError('decimal failed');

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
  String localizeDigits(String asciiDigits) => asciiDigits;
}

final class _NonEmptyDigitsLocale implements NumberLocale {
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
  String localizeDigits(String asciiDigits) {
    if (asciiDigits.isEmpty) throw StateError('empty digit run');
    return asciiDigits;
  }
}

final _compatibleFormat = Format(doubleFormatMode: DoubleFormatMode.compatible);

String format(String template, Object? value) =>
    _compatibleFormat.format(template, value);

void main() {
  // Ties to even, and what a "tie" actually is. 2.5 and −2.5 are exact, so both
  // round to 2; 1.25 is exact and rounds down while 1.35 is not exact and
  // rounds up. 2.675 looks like a tie and is not one — its binary value is
  // below the midpoint, so `2.67` is correct and `2.68` would be the bug. The
  // last case shows the value the earlier ones are decided from.
  test('rounds exact binary64 rationals with ties to even', () {
    expect(format('{:.0f}', 2.5), '2');
    expect(format('{:.0f}', -2.5), '-2');
    expect(format('{:.1f}', 1.25), '1.2');
    expect(format('{:.1f}', 1.35), '1.4');
    expect(format('{:.2f}', 2.675), '2.67');
    expect(
      format('{:.50f}', 1.23456789),
      '1.23456788999999989009381806681631132960319519042969',
    );
  });

  // `f` has a fast path for ordinary precisions and an exact one for the rest,
  // and they must agree everywhere. The pairs cross the boundary in both
  // directions — 2.5/3.5 and 1.25/1.75 for the tie rule, .20/.21 for the
  // precision where the SDK stops being able to help — and the extremes pin
  // that neither path gives up: the smallest subnormal rounds to `0.00` without
  // underflowing, and the largest finite double prints all 309 integer digits.
  // Negative zero keeps its sign.
  test('preserves fixed-format boundaries across fast and exact paths', () {
    expect(format('{:.0f}', 2.5), '2');
    expect(format('{:.0f}', 3.5), '4');
    expect(format('{:.1f}', 1.25), '1.2');
    expect(format('{:.1f}', 1.75), '1.8');
    expect(format('{:.2f}', 0.0), '0.00');
    expect(format('{:.2f}', -0.0), '-0.00');
    expect(format('{:.2f}', 5e-324), '0.00');
    expect(format('{:.20f}', 0.1), '0.10000000000000000555');
    expect(format('{:.21f}', 0.1), '0.100000000000000005551');
    expect(
      format('{:.0f}', 1.7976931348623157e308),
      '179769313486231570814527423731704356798070567525844996598917476803'
      '157260780028538760589558632766878171540458953514382464234321326889'
      '464182768467546703537516986049910576551282076245490090389328944075'
      '868508455133942304583236903222948165808559332123348274797826204144'
      '723168738177180919299881250404026184124858368',
    );
  });

  // `g` chooses between fixed and exponential notation by the exponent *after*
  // rounding, which is where carry makes the decision unstable: 999.5 at three
  // significant digits becomes 1000, whose exponent is one higher, so the
  // answer is `1e+03` and not `1.00e+03`. Same at 999999.5, and the mirror case
  // at 0.00009999995, where carry moves the value back into fixed range. The
  // exponent is always at least two digits, as in C.
  test('matches exponent spelling, general thresholds and carry', () {
    expect(format('{:g}', 1e-6), '1e-06');
    expect(format('{:.0g}', 12.0), '1e+01');
    expect(format('{:e}', 1.0), '1.000000e+00');
    expect(format('{:.3g}', 999.5), '1e+03');
    expect(format('{:.6g}', 999999.5), '1e+06');
    expect(format('{:.5g}', 0.00009999995), '0.0001');
    expect(format('{:.3e}', 9.9995), '9.999e+00');
    expect(format('{:.1E}', 999.0), '1.0E+03');
  });

  // A bare `{}` prints the shortest digits that read back as the same double,
  // and then chooses notation by Python's thresholds rather than Dart's: fixed
  // down to 1e-4 and up to 1e16, exponential outside. `1.0` keeps its `.0` so
  // the result still looks like a double, and negative zero keeps its sign. The
  // two pairs at the boundaries are where an off-by-one threshold shows.
  test('default double uses Python shortest policy', () {
    expect(format('{}', 1.23456789), '1.23456789');
    expect(format('{}', 1.0), '1.0');
    expect(format('{}', -0.0), '-0.0');
    expect(format('{}', 0.0001), '0.0001');
    expect(format('{}', 0.00001), '1e-05');
    expect(format('{}', 999999999999999.0), '999999999999999.0');
    expect(format('{}', 1e16), '1e+16');
  });

  // The three values where binary64 stops behaving uniformly: the smallest
  // subnormal, the smallest normal, and the largest finite. Subnormals have
  // fewer significant bits, so `5e-324` is shortest-round-trip while its exact
  // expansion begins `4.940656…` — both spellings are correct and each belongs
  // to its own conversion.
  test('formats subnormal, minimum normal and maximum finite values', () {
    expect(format('{:.0g}', 5e-324), '5e-324');
    expect(format('{:e}', 5e-324), '4.940656e-324');
    expect(format('{:g}', 2.2250738585072014e-308), '2.22507e-308');
    expect(format('{:g}', 1.7976931348623157e308), '1.79769e+308');
    expect(
      format('{:.0f}', 1.7976931348623157e308),
      '179769313486231570814527423731704356798070567525844996598917476803'
      '157260780028538760589558632766878171540458953514382464234321326889'
      '464182768467546703537516986049910576551282076245490090389328944075'
      '868508455133942304583236903222948165808559332123348274797826204144'
      '723168738177180919299881250404026184124858368',
    );
  });

  // `#` keeps the decimal point even with nothing after it, in every notation —
  // and for `g` it also keeps the trailing zeros `g` would otherwise strip. The
  // precisions climb past what any SDK conversion offers: 20 and 50 digits show
  // the exact binary value, and `{:.1000f}` pins that a precision far beyond
  // the value's significance produces zeros rather than garbage or a refusal.
  test('supports alternate form and precision 0, 1, 20 and 50', () {
    expect(format('{:#.0f}', 1.0), '1.');
    expect(format('{:#.0e}', 1.0), '1.e+00');
    expect(format('{:#.5g}', 12.0), '12.000');
    expect(format('{:.20f}', 1e-6), '0.00000100000000000000');
    expect(
      format('{:.50f}', 1e-6),
      '0.00000099999999999999995474811182588625868561393872',
    );
    expect(format('{:.20e}', 0.1), '1.00000000000000005551e-01');
    expect(
      format('{:.50G}', 5e-324),
      '4.9406564584124654417656879286822137236505980261432E-324',
    );
    expect(format('{:#.6g}', 1e-5), '1.00000e-05');
    expect(format('{:.1000f}', 1.0), '1.${'0' * 1000}');
  });

  // With no conversion letter the digits are the shortest ones, but the options
  // still apply — and precision here counts *significant* digits, like `g` and
  // unlike `f`. That is why `{:.2}` of 1.234 is `1.2` while `{:.2}` of 12.0 is
  // `1.2e+01`: two significant digits cannot express 12 in fixed notation. The
  // grouping case also shows padding fitted to the grouped length, as with
  // integers.
  test('applies Python empty-type options to shortest digits', () {
    expect(format('{:#}', 1e-5), '1.e-05');
    expect(format('{:08,}', 1e-5), '0,001e-05');
    expect(format('{:.2}', 1.234), '1.2');
    expect(format('{:.2}', 1.0), '1.0');
    expect(format('{:.1}', 0.0), '0e+00');
    expect(format('{:.2}', 12.0), '1.2e+01');
    expect(format('{:.3}', 12.0), '12.0');
  });

  // `z` asks for "no negative zero in the output", which is a statement about
  // the *printed* value, not the input: −0.0001 at three fixed digits rounds to
  // zero and loses its sign, while the same value in exponential or general
  // notation still has digits and keeps it. Normalizing the input first would
  // make all three agree — and would be wrong for two of them.
  test('normalizes negative zero only after rounding', () {
    expect(format('{:f}', -0.0), '-0.000000');
    expect(format('{:z.3f}', -0.0001), '0.000');
    expect(format('{:z.3e}', -0.0001), '-1.000e-04');
    expect(format('{:z.3g}', -0.0001), '-0.0001');
    expect(format('{:+z.0f}', -0.1), '+0');
  });

  // `%` scales by 100 and appends the sign, and the scaling happens on the
  // binary value rather than by shifting the decimal point of a rendered
  // string — `{:.16%}` of 0.1 is `10.0000000000000000%`, not the digits of 0.1
  // moved over. The suffix survives everything: the alternate form, negative
  // zero, `z`, and overflow to infinity when the scaled value leaves the range.
  test('formats percent from the binary value and preserves its suffix', () {
    expect(format('{:%}', 2.5), '250.000000%');
    expect(format('{:.2%}', 0.01255), '1.26%');
    expect(format('{:.16%}', 0.1), '10.0000000000000000%');
    expect(format('{:#.0%}', 0.125), '12.%');
    expect(format('{:.1%}', -0.0), '-0.0%');
    expect(format('{:z.1%}', -0.0001), '0.0%');
    expect(format('{:%}', 1.7976931348623157e308), 'inf%');
  });

  // Grouping applies to whichever side of the point the separator was written
  // on — before the precision it groups the integer digits, after it the
  // fractional ones — and it happens after rounding, so it groups the digits
  // that will actually be printed. The zero-padding case is the double version
  // of the fitted-width arithmetic, and the last line pins that a fractional
  // group survives exponential notation without the exponent being grouped.
  test('applies grouping after rounding to integer and fractional digits', () {
    expect(format('{:,.2f}', 1234567.125), '1,234,567.12');
    expect(format('{:_.9_f}', 1234567.123456789), '1_234_567.123_456_789');
    expect(format('{:.9,f}', 1234567.123456789), '1234567.123,456,789');
    expect(format('{:014,.2f}', 1234.5), '000,001,234.50');
    expect(format('{:.9_e}', 1234567.123456789), '1.234_567_123e+06');
  });

  // Zero padding puts the sign first and the zeros after it — and applies to
  // the special values too, where there are no digits to pad: `{:010f}` of
  // infinity is seven zeros and `inf`, which reads oddly but is what C does.
  // The last case pins that the fill is counted in text units for doubles as
  // well.
  test('applies signs, TextUnit-aware width and special zero padding', () {
    expect(format('{:+010.2f}', 12.5), '+000012.50');
    expect(format('{: 010.2f}', 12.5), ' 000012.50');
    expect(format('{:010f}', double.infinity), '0000000inf');
    expect(format('{:010F}', double.negativeInfinity), '-000000INF');

    final graphemes = Format(
      textUnit: TextUnit.graphemeClusters,
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(graphemes.format('{:👩‍🔬>4.0f}', 42.0), '👩‍🔬👩‍🔬42');
  });

  // The special values take a sign flag like any number — `+nan` — and their
  // case follows the conversion letter rather than the value, so `F`, `E` and
  // `G` all uppercase them while `f`, `e` and `g` do not. `%` keeps its suffix.
  test('formats nan and infinity with Python sign and case policies', () {
    expect(format('{}', double.nan), 'nan');
    expect(format('{:+f}', double.nan), '+nan');
    expect(format('{: F}', double.nan), ' NAN');
    expect(format('{:E}', double.infinity), 'INF');
    expect(format('{:+G}', double.infinity), '+INF');
    expect(format('{:%}', double.negativeInfinity), '-inf%');
  });

  // A floating conversion accepts integers by converting them to binary64
  // first, with the precision loss that implies: `9007199254740993` is not
  // representable and prints as the even neighbour. That is the honest answer,
  // and it is why the conversion is explicit rather than exact. A `BigInt` too
  // large to become a finite double is rejected instead of becoming infinity,
  // and a boolean is not a number here either.
  test('converts int and BigInt through binary64 for floating types', () {
    expect(format('{:.1f}', 2), '2.0');
    expect(format('{:.1e}', BigInt.from(12)), '1.2e+01');
    expect(
      format('{:.0f}', BigInt.parse('9007199254740993')),
      '9007199254740992',
    );
    expect(
      () => format('{:f}', BigInt.one << 20000),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
    expect(
      () => format('{:f}', true),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  // Every locale callback a double can reach, in one place: the group
  // separator and its irregular sizes, the decimal separator, the digits, both
  // signs, and — unique to doubles — the exponent separator, which is a whole
  // string here (`×10^`) rather than a letter, with its own sign localized
  // after it. The padded case does all of that at once over a fitted width.
  test('formats double n through every locale callback', () {
    final localized = Format(
      numberLocale: _LocalizedNumberLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(localized.format('{:n}', 1234567.5), '١,٢٣٤٥٧×10^＋٠٦');
    expect(localized.format('{:+n}', 1e20), '＋١×10^＋٢٠');
    expect(localized.format('{:012n}', -1234.5), '−٠٠.٠١.٢٣٤,٥');
  });

  // A contract on what the engine hands the locale: runs of ASCII digits, and
  // never an empty one. `1e+20` has three separate runs with punctuation
  // between them, so a naive splitter produces empty pieces — this locale
  // throws on one, which turns a silent contract into a failing test.
  test('passes only non-empty ASCII digit runs to locale localization', () {
    final configured = Format(
      numberLocale: _NonEmptyDigitsLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(configured.format('{:n}', 1e20), '1e+20');
  });

  // The same extension-failure contract as on the integer side, through a
  // different callback: the double path reaches `decimalSeparator`, which the
  // integer path never touches.
  test('wraps double locale failures with format context', () {
    final configured = Format(
      numberLocale: _ThrowingDoubleLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(
      () => configured.format('{:n}', 1.5),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.error, 'original error', isA<StateError>())
            .having((error) => error.context.specifier, 'specifier', 'n'),
      ),
    );
  });

  // Two rules, from both directions. `n` takes its grouping from the locale, so
  // an explicit separator contradicts it; and a precision belongs to floating
  // conversions only, so `{:.2d}` on a double is still rejected — the value
  // being a double does not make an integer conversion accept one.
  for (final template in ['{:,n}', '{:_n}', '{:.2d}', '{:.2x}']) {
    test('rejects incompatible double options $template', () {
      expect(
        () => format(template, 1.5),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }
}
