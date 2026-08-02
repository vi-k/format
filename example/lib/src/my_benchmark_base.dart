import 'package:benchmark_harness/benchmark_harness.dart';

abstract base class MyBenchmarkBase extends BenchmarkBase {
  late String template;
  late List<Object?> values;
  late String output;

  MyBenchmarkBase({required String name}) : super(name);

  bool get isSprintf;

  double go(String template, List<Object?> values) {
    this.template = template;
    this.values = values;

    return measure() / 100;
  }
}
