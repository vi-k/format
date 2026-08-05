import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final _format3Benchmark = Format(textUnit: TextUnit.graphemeClusters);

String _formatCurrent(String template, List<Object?> values) =>
    _format3Benchmark.vsprintf(template, values);

final class BenchmarkFormat3Sprintf extends MyBenchmarkBase {
  BenchmarkFormat3Sprintf() : super(name: 'format 3.0 → sprintf');

  @override
  bool get isSprintf => true;

  @override
  void run() {
    _formatCurrent(template, values); // 1
    _formatCurrent(template, values); // 2
    _formatCurrent(template, values); // 3
    _formatCurrent(template, values); // 4
    _formatCurrent(template, values); // 5
    _formatCurrent(template, values); // 6
    _formatCurrent(template, values); // 7
    _formatCurrent(template, values); // 8
    _formatCurrent(template, values); // 9
    output = _formatCurrent(template, values); // 10
  }
}
