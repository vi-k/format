import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:test/test.dart';

void main() {
  test('one configured Format localizes both dialects', () {
    final engine = Format(numberLocale: IntlNumberLocale('kk_KZ'));
    final formatKk = engine.format;
    final sprintfKk = engine.sprintf;

    expect(formatKk('{:n}', 1234), '1\u00A0234');
    expect(sprintfKk('%.1f', 1234.5), '1234,5');
  });

  test('one locale supports Dart and compatible double profiles', () {
    final locale = IntlNumberLocale('kk_KZ');
    final dartFormat = Format(numberLocale: locale);
    final compatibleFormat = Format(
      numberLocale: locale,
      doubleFormatMode: DoubleFormatMode.compatible,
    );

    expect(dartFormat.format('{:.3n}', 1.0), '1,00');
    expect(compatibleFormat.format('{:.3n}', 1.0), '1');
    expect(dartFormat.format('{:n}', double.infinity), 'Infinity');
    expect(compatibleFormat.format('{:n}', double.infinity), 'inf');
  });

  test('fromDefault snapshots the current locale', () {
    final previousDefaultLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousDefaultLocale);
    Intl.defaultLocale = 'en_US';
    final locale = IntlNumberLocale.fromDefault();
    Intl.defaultLocale = 'kk_KZ';

    expect(locale.decimalSeparator, '.');
  });
}
