import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:test/test.dart';

void main() {
  test('reads separators, signs, exponent and grouping from intl data', () {
    final NumberLocale locale = IntlNumberLocale('en_US');
    expect(locale.decimalSeparator, '.');
    expect(locale.groupSeparator, ',');
    expect(locale.plusSign, '+');
    expect(locale.minusSign, '-');
    expect(locale.exponentSeparator, 'E');
    expect(locale.grouping, [3]);
    expect(locale.groupingEnabled, isTrue);
  });

  test('localizes contiguous decimal digits', () {
    final locale = IntlNumberLocale('ar_EG');
    expect(locale.localizeDigits('120'), isNot('120'));
  });

  test('reads Indian grouping from intl data', () {
    final locale = IntlNumberLocale('hi');
    expect(locale.grouping, [3, 2]);
    expect(locale.groupingEnabled, isTrue);
  });

  test('wraps invalid locales in a configuration error', () {
    expect(
      () => IntlNumberLocale('invalid_locale'),
      throwsA(
        isA<FormatConfigurationException>().having(
          (error) => error.reason,
          'reason',
          contains('invalid_locale'),
        ),
      ),
    );
  });
}
