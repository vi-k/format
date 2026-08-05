// The frozen pub release competes in the matrix exactly as published;
// see benchmark/baselines/format16/README.md for provenance and policy.
import 'package:format16_baseline/format16.dart' as format16;

import 'my_benchmark_base.dart';

final class BenchmarkFormat16Format extends MyBenchmarkBase {
  BenchmarkFormat16Format() : super(name: 'format 1.6 → format');

  @override
  bool get isSprintf => false;

  @override
  bool get isFormat16 => true;

  @override
  void run() {
    format16.format(template, values); // 1
    format16.format(template, values); // 2
    format16.format(template, values); // 3
    format16.format(template, values); // 4
    format16.format(template, values); // 5
    format16.format(template, values); // 6
    format16.format(template, values); // 7
    format16.format(template, values); // 8
    format16.format(template, values); // 9
    output = format16.format(template, values); // 10
  }
}
