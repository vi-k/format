import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:test/test.dart';

void main() {
  test('IntlNumberLocale implements the core contract', () {
    final NumberLocale locale = IntlNumberLocale('en_US');
    expect(locale.decimalSeparator, '.');
  });
}
