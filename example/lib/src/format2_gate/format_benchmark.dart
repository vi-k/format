import 'benchmark_base.dart';
import 'scenarios.dart';

final class GateFormatBenchmark extends GateBenchmarkBase {
  GateFormatBenchmark(GateBenchmarkScenario scenario)
    : super(name: 'format::format', scenario: scenario);

  @override
  String execute() {
    final namedValues = scenario.namedValues;
    return namedValues == null
        ? gateBenchmarkFormat.formatWith(
          scenario.template,
          positional: scenario.positionalValues!,
        )
        : gateBenchmarkFormat.formatWith(scenario.template, named: namedValues);
  }
}
