import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:test/test.dart';

void main() {
  test('workspace public imports configure both formatting dialects', () {
    final engine = Format(numberLocale: IntlNumberLocale('uk_UA'));

    expect(engine.format('{:n}', 1234), isNot('1,234'));
    expect(engine.sprintf('%.1f', 1.5), '1,5');
  });
}
