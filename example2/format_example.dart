import 'package:format/format.dart';

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
  print(format('{} {}', const ['hello', 'world']));
  print(
    formatNamed(
      '{name}: {value}',
      const {'name': 'answer', 'value': 42},
    ),
  );

  Format.registerFormatter(JsonFormatter());
  print(format('{:json}', const [<String, Object?>{'answer': 42}]));
  Format.unregisterFormatter('json');
}
