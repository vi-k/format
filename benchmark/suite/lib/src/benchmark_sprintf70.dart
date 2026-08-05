import 'package:sprintf/sprintf.dart' as sprintf70;

import 'my_benchmark_base.dart';

final class BenchmarkSprintf70 extends MyBenchmarkBase {
  BenchmarkSprintf70() : super(name: 'sprintf 7.0 → sprintf');

  @override
  bool get isSprintf => true;

  @override
  bool get isSprintf70 => true;

  @override
  void run() {
    sprintf70.sprintf(template, values); // 1
    sprintf70.sprintf(template, values); // 2
    sprintf70.sprintf(template, values); // 3
    sprintf70.sprintf(template, values); // 4
    sprintf70.sprintf(template, values); // 5
    sprintf70.sprintf(template, values); // 6
    sprintf70.sprintf(template, values); // 7
    sprintf70.sprintf(template, values); // 8
    sprintf70.sprintf(template, values); // 9
    output = sprintf70.sprintf(template, values); // 10
  }
}
