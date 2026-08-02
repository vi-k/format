import 'package:sprintf7_baseline/sprintf.dart' as sprintf7;

import 'my_benchmark_base.dart';

final class SprintfBenchmark extends MyBenchmarkBase {
  SprintfBenchmark() : super(name: 'sprintf::sprintf');

  @override
  bool get isSprintf => true;

  @override
  void run() {
    sprintf7.sprintf(template, values); // 1
    sprintf7.sprintf(template, values); // 2
    sprintf7.sprintf(template, values); // 3
    sprintf7.sprintf(template, values); // 4
    sprintf7.sprintf(template, values); // 5
    sprintf7.sprintf(template, values); // 6
    sprintf7.sprintf(template, values); // 7
    sprintf7.sprintf(template, values); // 8
    sprintf7.sprintf(template, values); // 9
    output = sprintf7.sprintf(template, values); // 10
  }
}
