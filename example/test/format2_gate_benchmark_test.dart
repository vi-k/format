import 'package:example/format2_gate_benchmark.dart';
import 'package:intl/intl.dart';
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

  test(
    'gate locale n keeps its template and produces the shared locale output',
    () {
      final previousLocale = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previousLocale);
      Intl.defaultLocale = 'en_US';

      final scenario = gateBenchmarkScenarios.singleWhere(
        (value) => value.name == 'locale n',
      );

      expect(
        [
          GateFormatBenchmark(scenario).execute(),
          GateLegacyFormatBenchmark(scenario).execute(),
        ],
        ['123,456', '123,456'],
      );
      expect(scenario.template, '{:,n}');
    },
  );
}
