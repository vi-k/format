import 'package:format/format.dart';

final class BenchmarkScenario {
  final String name;
  final String template;
  final List<Object?>? positionalValues;
  final Map<String, Object?>? namedValues;
  final String expected;
  final int? placeholderCount;

  const BenchmarkScenario.positional({
    required this.name,
    required this.template,
    required List<Object?> values,
    required this.expected,
    this.placeholderCount,
  }) : positionalValues = values,
       namedValues = null;

  const BenchmarkScenario.named({
    required this.name,
    required this.template,
    required Map<String, Object?> values,
    required this.expected,
  }) : positionalValues = null,
       namedValues = values,
       placeholderCount = null;

  Object get values => positionalValues ?? namedValues!;
}

final class BenchmarkValue {
  final String value;

  const BenchmarkValue(this.value);

  @override
  String toString() => value;
}

final class BenchmarkValueFormatter extends Formatter<BenchmarkValue> {
  const BenchmarkValueFormatter();

  @override
  String get specifier => 'benchmarkValue';

  @override
  bool canFormat(Object? value) => value is BenchmarkValue;

  @override
  String format(BenchmarkValue value, FormatOptions options) => value.value;
}

final benchmarkFormat = Format(formatters: const [BenchmarkValueFormatter()]);

final List<BenchmarkScenario> benchmarkScenarios = [
  const BenchmarkScenario.positional(
    name: 'int',
    template: '{:d}',
    values: [123456],
    expected: '123456',
  ),
  const BenchmarkScenario.positional(
    name: 'double',
    template: '{:.2f}',
    values: [123.456],
    expected: '123.46',
  ),
  const BenchmarkScenario.positional(
    name: 'string',
    template: '{:s}',
    values: ['hello'],
    expected: 'hello',
  ),
  const BenchmarkScenario.positional(
    name: 'unicode',
    template: '{:👨‍👩‍👦‍👧^5s}',
    values: ['x'],
    expected: '👨‍👩‍👦‍👧👨‍👩‍👦‍👧x👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
  ),
  const BenchmarkScenario.named(
    name: 'named',
    template: '{name}:{value:d}',
    values: {'name': 'answer', 'value': 42},
    expected: 'answer:42',
  ),
  const BenchmarkScenario.positional(
    name: 'locale n',
    template: '{:,n}',
    values: [123456],
    expected: '123,456',
  ),
  const BenchmarkScenario.positional(
    name: 'custom formatter',
    template: '{}',
    values: [BenchmarkValue('custom')],
    expected: 'custom',
  ),
  for (final count in [1, 5, 10, 50]) _placeholderScenario(count),
];

BenchmarkScenario _placeholderScenario(int count) {
  final values = List<Object?>.generate(count, (index) => index);
  return BenchmarkScenario.positional(
    name: '$count placeholder',
    template: List.filled(count, '{}').join('|'),
    values: values,
    expected: List.generate(count, (index) => '$index').join('|'),
    placeholderCount: count,
  );
}
