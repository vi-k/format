import 'package:benchmark_harness/benchmark_harness.dart';

import 'scenarios.dart';

abstract base class GateBenchmarkBase extends BenchmarkBase {
  final GateBenchmarkScenario scenario;
  late String output;

  GateBenchmarkBase({required String name, required this.scenario})
    : super(name);

  String execute();

  void verifyOutput() {
    output = execute();
    if (output != scenario.expected) {
      throw StateError(
        '${scenario.name}: expected ${scenario.expected}, got $output',
      );
    }
  }

  double measureMicrosecondsPerCall() => measure() / 10;

  @override
  void run() {
    output = execute();
  }
}
