import 'package:format/format.dart';

final class GateBenchmarkScenario {
  final String name;
  final String template;
  final List<Object?>? positionalValues;
  final Map<String, Object?>? namedValues;
  final String expected;
  final int? placeholderCount;

  const GateBenchmarkScenario.positional({
    required this.name,
    required this.template,
    required List<Object?> values,
    required this.expected,
    this.placeholderCount,
  }) : positionalValues = values,
       namedValues = null;

  const GateBenchmarkScenario.named({
    required this.name,
    required this.template,
    required Map<String, Object?> values,
    required this.expected,
  }) : positionalValues = null,
       namedValues = values,
       placeholderCount = null;

  Object get values => positionalValues ?? namedValues!;
}

final class GateBenchmarkValue {
  final String value;

  const GateBenchmarkValue(this.value);

  @override
  String toString() => value;
}

final class GateBenchmarkValueFormatter extends Formatter<GateBenchmarkValue> {
  const GateBenchmarkValueFormatter();

  @override
  String get specifier => 'benchmarkValue';

  @override
  bool canFormat(Object? value) => value is GateBenchmarkValue;

  @override
  String format(GateBenchmarkValue value, FormatOptions options) => value.value;
}

final gateBenchmarkFormat = Format(
  textUnit: TextUnit.graphemeClusters,
  formatters: const [GateBenchmarkValueFormatter()],
);

final List<GateBenchmarkScenario> gateBenchmarkScenarios = [
  const GateBenchmarkScenario.positional(
    name: 'int',
    template: '{:d}',
    values: [123456],
    expected: '123456',
  ),
  const GateBenchmarkScenario.positional(
    name: 'double',
    template: '{:.2f}',
    values: [123.456],
    expected: '123.46',
  ),
  const GateBenchmarkScenario.positional(
    name: 'string',
    template: '{:s}',
    values: ['hello'],
    expected: 'hello',
  ),
  const GateBenchmarkScenario.positional(
    name: 'unicode',
    template: '{:👨‍👩‍👦‍👧^5s}',
    values: ['x'],
    expected: '👨‍👩‍👦‍👧👨‍👩‍👦‍👧x👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
  ),
  const GateBenchmarkScenario.named(
    name: 'named',
    template: '{name}:{value:d}',
    values: {'name': 'answer', 'value': 42},
    expected: 'answer:42',
  ),
  const GateBenchmarkScenario.positional(
    name: 'locale n',
    template: '{:,d}',
    values: [123456],
    expected: '123,456',
  ),
  const GateBenchmarkScenario.positional(
    name: 'custom formatter',
    template: '{}',
    values: [GateBenchmarkValue('custom')],
    expected: 'custom',
  ),
  for (final count in [1, 5, 10, 50]) _placeholderScenario(count),
];

GateBenchmarkScenario _placeholderScenario(int count) {
  final values = List<Object?>.generate(count, (index) => index);
  return GateBenchmarkScenario.positional(
    name: '$count placeholder',
    template: List.filled(count, '{}').join('|'),
    values: values,
    expected: List.generate(count, (index) => '$index').join('|'),
    placeholderCount: count,
  );
}
