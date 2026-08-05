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

  test('default double uses Python shortest policy', () {
    expect(format('{}', 1.23456789), '1.23456789');
    expect(format('{}', 1.0), '1.0');
    expect(format('{}', -0.0), '-0.0');
    expect(format('{}', 0.0001), '0.0001');
    expect(format('{}', 0.00001), '1e-05');
    expect(format('{}', 999999999999999.0), '999999999999999.0');
    expect(format('{}', 1e16), '1e+16');
  });

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

  test('applies Python empty-type options to shortest digits', () {
    expect(format('{:#}', 1e-5), '1.e-05');
    expect(format('{:08,}', 1e-5), '0,001e-05');
    expect(format('{:.2}', 1.234), '1.2');
    expect(format('{:.2}', 1.0), '1.0');
    expect(format('{:.1}', 0.0), '0e+00');
    expect(format('{:.2}', 12.0), '1.2e+01');
    expect(format('{:.3}', 12.0), '12.0');
  });

  test('normalizes negative zero only after rounding', () {
    expect(format('{:f}', -0.0), '-0.000000');
    expect(format('{:z.3f}', -0.0001), '0.000');
    expect(format('{:z.3e}', -0.0001), '-1.000e-04');
    expect(format('{:z.3g}', -0.0001), '-0.0001');
    expect(format('{:+z.0f}', -0.1), '+0');
  });

  test('formats percent from the binary value and preserves its suffix', () {
    expect(format('{:%}', 2.5), '250.000000%');
    expect(format('{:.2%}', 0.01255), '1.26%');
    expect(format('{:.16%}', 0.1), '10.0000000000000000%');
    expect(format('{:#.0%}', 0.125), '12.%');
    expect(format('{:.1%}', -0.0), '-0.0%');
    expect(format('{:z.1%}', -0.0001), '0.0%');
    expect(format('{:%}', 1.7976931348623157e308), 'inf%');
  });

  test('applies grouping after rounding to integer and fractional digits', () {
    expect(format('{:,.2f}', 1234567.125), '1,234,567.12');
    expect(format('{:_.9_f}', 1234567.123456789), '1_234_567.123_456_789');
    expect(format('{:.9,f}', 1234567.123456789), '1234567.123,456,789');
    expect(format('{:014,.2f}', 1234.5), '000,001,234.50');
    expect(format('{:.9_e}', 1234567.123456789), '1.234_567_123e+06');
  });

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

  test('formats nan and infinity with Python sign and case policies', () {
    expect(format('{}', double.nan), 'nan');
    expect(format('{:+f}', double.nan), '+nan');
    expect(format('{: F}', double.nan), ' NAN');
    expect(format('{:E}', double.infinity), 'INF');
    expect(format('{:+G}', double.infinity), '+INF');
    expect(format('{:%}', double.negativeInfinity), '-inf%');
  });

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

  test('formats double n through every locale callback', () {
    final localized = Format(
      numberLocale: _LocalizedNumberLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(localized.format('{:n}', 1234567.5), '١,٢٣٤٥٧×10^＋٠٦');
    expect(localized.format('{:+n}', 1e20), '＋١×10^＋٢٠');
    expect(localized.format('{:012n}', -1234.5), '−٠٠.٠١.٢٣٤,٥');
  });

  test('passes only non-empty ASCII digit runs to locale localization', () {
    final configured = Format(
      numberLocale: _NonEmptyDigitsLocale(),
      doubleFormatMode: DoubleFormatMode.compatible,
    );
    expect(configured.format('{:n}', 1e20), '1e+20');
  });

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

  for (final template in ['{:,n}', '{:_n}', '{:.2d}', '{:.2x}']) {
    test('rejects incompatible double options $template', () {
      expect(
        () => format(template, 1.5),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }
}
