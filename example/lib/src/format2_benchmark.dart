import 'legacy_format_baseline.dart';
import 'my_benchmark_base.dart';

final class Format2Benchmark extends MyBenchmarkBase {
  Format2Benchmark() : super(name: 'format::format2');

  @override
  bool get isSprintf => false;

  @override
  void run() {
    legacyFormat(template, values); // 1
    legacyFormat(template, values); // 2
    legacyFormat(template, values); // 3
    legacyFormat(template, values); // 4
    legacyFormat(template, values); // 5
    legacyFormat(template, values); // 6
    legacyFormat(template, values); // 7
    legacyFormat(template, values); // 8
    legacyFormat(template, values); // 9
    output = legacyFormat(template, values); // 10
  }
}
