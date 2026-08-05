import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final _format3Benchmark = Format(textUnit: TextUnit.graphemeClusters);

String _formatCurrent(String template, List<Object?> values) =>
    _format3Benchmark.formatWith(template, positional: values);

final class BenchmarkFormat30Format extends MyBenchmarkBase {
  BenchmarkFormat30Format() : super(name: 'format 3.0 → format');

  @override
  bool get isSprintf => false;

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
