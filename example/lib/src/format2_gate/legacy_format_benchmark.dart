import '../legacy_format_baseline.dart';
import 'benchmark_base.dart';
import 'scenarios.dart';

final class GateLegacyFormatBenchmark extends GateBenchmarkBase {
  GateLegacyFormatBenchmark(GateBenchmarkScenario scenario)
    : super(name: 'legacyFormat', scenario: scenario);

  @override
  String execute() => legacyFormat(scenario.template, scenario.values);
}
