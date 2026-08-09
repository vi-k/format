/// The IR-versus-legacy A/B benchmark, tested as a program rather than as a
/// measurement.
///
/// This benchmark is the project's sharpest instrument for detecting a
/// performance regression in the IR: it runs both paths on the same scenarios
/// and reports which won. Its own failure mode is that it stops covering
/// something and keeps reporting confidently — a scenario dropped from the
/// matrix, or a comparison that silently disagreed on output.
///
/// So the test runs it with tiny sample counts and reads its output: every
/// scenario label is present, including the fallback controls, no comparison
/// reported differing results, and the verdict count matches the scenario
/// count. Timings are deliberately not asserted — they are what the tool
/// measures, not what it promises.
library;

import 'package:format_benchmarks/benchmark.dart';
import 'package:test/test.dart';

void main() {
  // Presence, agreement and completeness in one pass: the labels prove the
  // matrix still covers each op family and its fallback controls, `RESULTS
  // DIFFER` proves the two paths agreed everywhere, and the verdict count
  // proves every scenario actually ran rather than being skipped.
  test('template IR benchmark reports every scenario without diffs', () {
    final lines = <String>[];
    runTemplateIrBenchmark(
      writeLine: lines.add,
      warmupOperations: 10,
      operations: 50,
      samples: 3,
    );
    final output = lines.join('\n');
    expect(output, contains('{:10d}'));
    expect(output, contains('%0*d'));
    expect(output, contains('{:.2f}'));
    // The compatible-mode double scenario carries the mode in its label.
    expect(output, contains('compatible'));
    // Grouping keeps doubles on the legacy tail: the new fallback control.
    expect(output, contains('{:,.2f}'));
    // Zero padding fitted to the grouped width stays on the legacy tail too.
    expect(output, contains('{:010,d}'));
    expect(output, isNot(contains('RESULTS DIFFER')));
    final verdicts = lines.where(
      (line) =>
          line.contains('IR FASTER') ||
          line.contains('LEGACY FASTER') ||
          line.contains('PERFORMANCE EQUAL'),
    );
    expect(verdicts.length, 16);
  });

  // A benchmark run with nonsensical options would produce numbers rather than
  // an error, and nothing downstream could tell the difference.
  test('template IR benchmark validates its options', () {
    expect(() => runTemplateIrBenchmark(operations: 0), throwsArgumentError);
  });
}
