import 'package:sprintf/sprintf.dart';

import 'my_benchmark_base.dart';

final class SprintfBenchmark extends MyBenchmarkBase {
  SprintfBenchmark() : super(name: 'sprintf::sprintf');

  @override
  bool get isSprintf => true;

  @override
  void run() {
    sprintf(template, values); // 1
    sprintf(template, values); // 2
    sprintf(template, values); // 3
    sprintf(template, values); // 4
    sprintf(template, values); // 5
    sprintf(template, values); // 6
    sprintf(template, values); // 7
    sprintf(template, values); // 8
    sprintf(template, values); // 9
    output = sprintf(template, values); // 10
  }
}
