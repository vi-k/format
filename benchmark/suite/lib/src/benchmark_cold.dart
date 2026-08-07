import 'package:format/format.dart';
import 'package:format16_baseline/format16.dart' as format16;
import 'package:sprintf/sprintf.dart' as sprintf70;

import 'my_benchmark_base.dart';

final _format3Cold = Format(textUnit: TextUnit.graphemeClusters);

/// Makes a template no engine has parsed before.
///
/// The marker is literal text in both mini-languages, so every runner is
/// handed the same string and pays the same cost for building it. It also
/// lands in the output, which is what lets a runner check itself.
String coldTemplate(String template, int counter) => '$template [$counter]';

String coldExpected(String expected, int counter) => '$expected [$counter]';

/// Cold-path runners: every call formats a template that has never been seen
/// before, so the template cache never hits and parsing stays on the measured
/// path.
///
/// The comparators have no cache, so their cold numbers should match their hot
/// ones. They run here anyway rather than being described that way in a
/// comment: this is the phase where the difference between parsing a template
/// and looking one up decides the result, so it is worth showing side by side
/// instead of asking the reader to hold two sections in their head.
abstract base class ColdBenchmark extends MyBenchmarkBase {
  var _counter = 0;

  /// The output a call should produce, before the unique marker.
  late String expected;

  /// Set when a call disagreed with [expected]; the matrix reports it the
  /// same way it reports a wrong answer in the hot phase.
  var mismatched = false;

  ColdBenchmark({required super.name});

  /// Formats [template] once, with this runner's engine.
  String formatOnce(String template);

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      final counter = _counter++;
      output = formatOnce(coldTemplate(template, counter));
      if (output != coldExpected(expected, counter)) mismatched = true;
    }
  }

  double goCold(String template, List<Object?> values, String expected) {
    this.expected = expected;
    // Per measurement, not per runner: a wrong answer in one case must not
    // paint every case after it.
    mismatched = false;

    return go(template, values);
  }
}

final class BenchmarkFormat30ColdFormat extends ColdBenchmark {
  BenchmarkFormat30ColdFormat() : super(name: 'format 3.0 → format (cold)');

  @override
  bool get isSprintf => false;

  @override
  String formatOnce(String template) =>
      _format3Cold.formatWith(template, positional: values);
}

final class BenchmarkFormat30ColdSprintf extends ColdBenchmark {
  BenchmarkFormat30ColdSprintf() : super(name: 'format 3.0 → sprintf (cold)');

  @override
  bool get isSprintf => true;

  @override
  String formatOnce(String template) => _format3Cold.vsprintf(template, values);
}

final class BenchmarkFormat16ColdFormat extends ColdBenchmark {
  BenchmarkFormat16ColdFormat() : super(name: 'format 1.6 → format (cold)');

  @override
  bool get isSprintf => false;

  @override
  bool get isFormat16 => true;

  @override
  String formatOnce(String template) => format16.format(template, values);
}

final class BenchmarkSprintf70Cold extends ColdBenchmark {
  BenchmarkSprintf70Cold() : super(name: 'sprintf 7.0 (cold)');

  @override
  bool get isSprintf => true;

  @override
  bool get isSprintf70 => true;

  @override
  String formatOnce(String template) => sprintf70.sprintf(template, values);
}
