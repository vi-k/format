import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final _format3Cold = Format(textUnit: TextUnit.graphemeClusters);

/// Runners that format with the template cache switched off, so every call
/// parses the template again.
///
/// This is the same work a template never seen before would cost, without
/// having to invent one: building a unique template per call would add the
/// cost of building it to the measurement, and would make the expected output
/// differ from the one the warm rows check against.
///
/// Only this package caches parsed templates, so only this package has a
/// second number worth printing: a comparator parses on every call by
/// construction, and the figure it already reports is a first parse.
abstract base class ColdBenchmark extends MyBenchmarkBase {
  ColdBenchmark({required super.name});

  /// Formats [template] once, with this runner's engine.
  String formatOnce();

  @override
  void setup() {
    // Zero discards what is already cached and stops anything being kept, so
    // the first call is as cold as every call after it. Restored in
    // [teardown] — the capacity is global, and the warm runners need theirs.
    templateCacheCapacity = 0;
  }

  @override
  void teardown() {
    templateCacheCapacity = 512;
  }

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = formatOnce();
    }
  }
}

final class BenchmarkFormat30ColdFormat extends ColdBenchmark {
  BenchmarkFormat30ColdFormat() : super(name: 'format 3.0 → format (no cache)');

  @override
  bool get isSprintf => false;

  @override
  String formatOnce() => _format3Cold.formatWith(template, positional: values);
}

final class BenchmarkFormat30ColdSprintf extends ColdBenchmark {
  BenchmarkFormat30ColdSprintf()
    : super(name: 'format 3.0 → sprintf (no cache)');

  @override
  bool get isSprintf => true;

  @override
  String formatOnce() => _format3Cold.vsprintf(template, values);
}
