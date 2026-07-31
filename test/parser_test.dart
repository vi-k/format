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
}
