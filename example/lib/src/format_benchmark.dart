import 'package:format/format.dart';

import 'my_benchmark_base.dart';
import 'tests/tests.dart';

final class FormatBenchmark extends MyBenchmarkBase {
  FormatBenchmark(BenchmarkScenario scenario)
      : super(name: 'format::format', scenario: scenario);

  @override
  String execute() {
    final namedValues = scenario.namedValues;
    return namedValues == null
        ? format(scenario.template, scenario.positionalValues!)
        : formatNamed(scenario.template, namedValues);
  }
}
