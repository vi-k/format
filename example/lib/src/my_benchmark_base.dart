import 'package:benchmark_harness/benchmark_harness.dart';

import 'tests/tests.dart';

abstract base class MyBenchmarkBase extends BenchmarkBase {
  final BenchmarkScenario scenario;
  late String output;

  MyBenchmarkBase({required String name, required this.scenario}) : super(name);

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
