import 'benchmark_base.dart';
import 'scenarios.dart';

final class GateFormatBenchmark extends GateBenchmarkBase {
  GateFormatBenchmark(GateBenchmarkScenario scenario)
    : super(name: 'format::format', scenario: scenario);

  @override
  String execute() {
    final namedValues = scenario.namedValues;
    final template = scenario.template == '{:,n}' ? '{:n}' : scenario.template;
    return namedValues == null
        ? gateBenchmarkFormat.formatWith(
          template,
          positional: scenario.positionalValues!,
        )
        : gateBenchmarkFormat.formatWith(template, named: namedValues);
  }
}
