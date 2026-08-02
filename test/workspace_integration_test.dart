import 'package:format/format.dart';
// The workspace boundary test intentionally imports the sibling public API.
// ignore: depend_on_referenced_packages
import 'package:format_intl/format_intl.dart';
import 'package:test/test.dart';

void main() {
  test('workspace public imports configure both formatting dialects', () {
    final engine = Format(numberLocale: IntlNumberLocale('uk_UA'));

    expect(engine.format('{:n}', 1234), '1\u00A0234');
    expect(engine.sprintf('%.1f', 1234.5), '1234,5');
  });
}
