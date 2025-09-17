import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final class FormatBenchmark extends MyBenchmarkBase {
  FormatBenchmark() : super(name: 'format::format');

  @override
  bool get isSprintf => false;

  @override
  void run() {
    format(template, values); // 1
    format(template, values); // 2
    format(template, values); // 3
    format(template, values); // 4
    format(template, values); // 5
    format(template, values); // 6
    format(template, values); // 7
    format(template, values); // 8
    format(template, values); // 9
    output = format(template, values); // 10
  }
}
