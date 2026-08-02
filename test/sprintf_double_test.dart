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

void main() {
  test('matches C++23 decimal float rules', () {
    expect(sprintf('%.0f', 2.5), '2');
    expect(sprintf('%.0f', 3.5), '4');
    expect(sprintf('%e', 1.0), '1.000000e+00');
    expect(sprintf('%.0g', 12.0), '1e+01');
    expect(sprintf('%#.4g', 12.0), '12.00');
    expect(sprintf('%f', 1e-10), '0.000000');
    expect(sprintf('%.2e', 9.999), '1.00e+01');
  });

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

  test('applies repeated flags width and precedence', () {
    expect(sprintf('%+++08.2f', 12.5), '+0012.50');
    expect(sprintf('%--08.2f', 12.5), '12.50   ');
    expect(sprintf('% 08.2f', 12.5), ' 0012.50');
  });

  test('uses spaces for zero-padded special values', () {
    expect(sprintf('%+08f', double.infinity), '    +inf');
    expect(sprintf('%+08f', double.nan), '    +nan');
    expect(sprintf('%08f', double.negativeInfinity), '    -inf');
  });

  test('localizes symbols and digits without implicit grouping', () {
    final localized = Format(numberLocale: _PrintfNumberLocale());

    expect(localized.sprintf('%+.2f', 1234.5), '＋١٢٣٤,٥٠');
    expect(localized.sprintf('%+.1e', 12.0), '＋١,٢×10^＋٠١');
    expect(localized.sprintf('%+010.2f', 12.5), '＋٠٠٠٠١٢,٥٠');
    expect(localized.sprintf('%+15.1e', 12.0), '    ＋١,٢×10^＋٠١');
    expect(localized.sprintf('%+015.1e', 12.0), '＋٠٠٠٠١,٢×10^＋٠١');
  });

  test('fits zero padding after expanding localized digits', () {
    final localized = Format(numberLocale: _ExpandingZeroLocale());

    expect(localized.sprintf('%010.2f', 12.5), '٠٠٠٠12.5٠٠');
  });

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
}
