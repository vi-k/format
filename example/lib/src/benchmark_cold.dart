import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final _format3Cold = Format(textUnit: TextUnit.graphemeClusters);

/// Cold-path runners: every call formats through a template that has never
/// been seen before, so the template cache never hits and the parser stays
/// on the measured path. Only format 3.0 has a cache; the baselines' cold
/// numbers equal their hot numbers from the main matrix.
final class BenchmarkFormat3ColdFormat extends MyBenchmarkBase {
  var _counter = 0;

  BenchmarkFormat3ColdFormat() : super(name: 'format 3.0 → format (cold)');

  @override
  bool get isSprintf => false;

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = _format3Cold.formatWith(
        'v${_counter++}={:10d}',
        positional: values,
      );
    }
  }
}

final class BenchmarkFormat3ColdSprintf extends MyBenchmarkBase {
  var _counter = 0;

  BenchmarkFormat3ColdSprintf() : super(name: 'format 3.0 → sprintf (cold)');

  @override
  bool get isSprintf => true;

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = _format3Cold.vsprintf('v${_counter++}=%10d', values);
    }
  }
}
