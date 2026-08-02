import 'package:example/format2_gate_benchmark.dart';
import 'package:test/test.dart';

void main() {
  test(
    'gate unicode scenario treats the family emoji as one fill grapheme',
    () {
      final scenario = gateBenchmarkScenarios.singleWhere(
        (value) => value.name == 'unicode',
      );
      final benchmark = GateFormatBenchmark(scenario);

      expect(benchmark.execute(), scenario.expected);
    },
  );

  test('gate locale scenario executes without an invalid specifier', () {
    final scenario = gateBenchmarkScenarios.singleWhere(
      (value) => value.name == 'locale n',
    );
    final benchmark = GateFormatBenchmark(scenario);

    expect(benchmark.execute(), scenario.expected);
  });
}
