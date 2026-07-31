import 'package:format/format.dart';
import 'package:test/test.dart';

final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is Map<String, Object?>;

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

void main() {
  test('public formatting functions have the 2.0 signatures', () {
    expect(format('{}', const ['value']), 'value');
    expect(formatNamed('{key}', const {'key': 'value'}), 'value');
  });

  test('public import exposes formatter extension types', () {
    final formatter = JsonFormatter();
    expect(formatter.specifier, 'json');
    expect(
      formatter.format(
        const {'answer': 42},
        const FormatOptions(),
      ),
      '{answer: 42}',
    );
  });
}
