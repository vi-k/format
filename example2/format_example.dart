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
  print(format('{} {}', 'hello', 'world'));
  print(
    formatWith('{name}: {value}', named: const {'name': 'answer', 'value': 42}),
  );

  final jsonFormat = Format(formatters: [JsonFormatter()]);
  print(
    jsonFormat.formatWith(
      '{}',
      positional: const [
        <String, Object?>{'answer': 42},
      ],
    ),
  );
}
