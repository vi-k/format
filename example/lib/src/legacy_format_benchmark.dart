import 'legacy_format_baseline.dart';
import 'my_benchmark_base.dart';
import 'tests/tests.dart';

final class LegacyFormatBenchmark extends MyBenchmarkBase {
  LegacyFormatBenchmark(BenchmarkScenario scenario)
    : super(name: 'legacyFormat', scenario: scenario);

  @override
  String execute() => legacyFormat(scenario.template, scenario.values);
}
