import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:test/test.dart';

void main() {
  test('one configured Format localizes both dialects', () {
    final engine = Format(numberLocale: IntlNumberLocale('uk_UA'));
    final formatUk = engine.format;
    final sprintfUk = engine.sprintf;

    expect(formatUk('{:n}', 1234), contains('1'));
    expect(formatUk('{:n}', 1234), isNot('1,234'));
    expect(sprintfUk('%.1f', 1.5), '1,5');
  });

  test('fromDefault snapshots the current locale', () {
    final previousDefaultLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousDefaultLocale);
    Intl.defaultLocale = 'en_US';
    final locale = IntlNumberLocale.fromDefault();
    Intl.defaultLocale = 'uk_UA';

    expect(locale.decimalSeparator, '.');
  });
}
