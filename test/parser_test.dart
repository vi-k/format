import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  test('formats positional and named values', () {
    expect(format('{} {1}', ['a', 'b']), 'a b');
    expect(formatNamed('{name}', const {'name': 'Ada'}), 'Ada');
  });

  test('escapes both braces', () {
    expect(format('{{0}}->{0}', [9]), '{0}->9');
    expect(format('left }} right', const []), 'left } right');
  });

  for (final template in [
    '{:{}}',
    '{:.{}}',
    '{:{width}}',
    '{:.{precision}f}',
  ]) {
    test('rejects dynamic option in $template', () {
      expect(
        () => format(template, [1, 4]),
        throwsA(isA<InvalidFormatException>()),
      );
    });
  }

  test('rejects overflowing literal options with a typed error', () {
    const overflow = '9999999999999999999999999999999999999999';

    for (final template in ['{:${overflow}d}', '{:.${overflow}f}']) {
      expect(
        () => format(template, const [1]),
        throwsA(isA<InvalidFormatException>()),
      );
    }
  });
}
