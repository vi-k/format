import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final class Format2Benchmark extends MyBenchmarkBase {
  Format2Benchmark() : super(name: 'format::format2');

  @override
  bool get isSprintf => false;

  @override
  void run() {
    format2(template, values); // 1
    format2(template, values); // 2
    format2(template, values); // 3
    format2(template, values); // 4
    format2(template, values); // 5
    format2(template, values); // 6
    format2(template, values); // 7
    format2(template, values); // 8
    format2(template, values); // 9
    output = format2(template, values); // 10
  }
}
