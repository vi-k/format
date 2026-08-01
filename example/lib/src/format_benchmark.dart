import 'my_benchmark_base.dart';
import 'tests/tests.dart';

final class FormatBenchmark extends MyBenchmarkBase {
  FormatBenchmark(BenchmarkScenario scenario)
    : super(name: 'format::format', scenario: scenario);

  @override
  String execute() {
    final namedValues = scenario.namedValues;
    return namedValues == null
        ? benchmarkFormat.formatWith(
          scenario.template,
          positional: scenario.positionalValues!,
        )
        : benchmarkFormat.formatWith(scenario.template, named: namedValues);
  }
}
