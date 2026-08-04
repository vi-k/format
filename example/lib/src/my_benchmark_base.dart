import 'package:benchmark_harness/benchmark_harness.dart';

final class BenchmarkDurations {
  final int warmupMillis;
  final int measureMillis;

  const BenchmarkDurations({
    required this.warmupMillis,
    required this.measureMillis,
  });

  static const quick =
      BenchmarkDurations(warmupMillis: 50, measureMillis: 180);
  static const full =
      BenchmarkDurations(warmupMillis: 100, measureMillis: 2000);
}

abstract base class MyBenchmarkBase extends BenchmarkBase {
  late String template;
  late List<Object?> values;
  late String output;
  BenchmarkDurations durations = BenchmarkDurations.quick;

  MyBenchmarkBase({required String name}) : super(name);

  bool get isSprintf;

  bool get isLegacy => false;

  @override
  double measure() {
    setup();
    BenchmarkBase.measureFor(warmup, durations.warmupMillis);
    final result = BenchmarkBase.measureFor(
      exercise,
      durations.measureMillis,
    );
    teardown();
    return result;
  }

  double go(String template, List<Object?> values) {
    this.template = template;
    this.values = values;

    return measure() / 100;
  }
}
