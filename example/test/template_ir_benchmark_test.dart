import 'package:example/benchmark.dart';
import 'package:test/test.dart';

void main() {
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
    expect(output, isNot(contains('RESULTS DIFFER')));
    final verdicts =
        lines.where(
          (line) =>
              line.contains('IR FASTER') ||
              line.contains('LEGACY FASTER') ||
              line.contains('PERFORMANCE EQUAL'),
        );
    expect(verdicts.length, 10);
  });

  test('template IR benchmark validates its options', () {
    expect(
      () => runTemplateIrBenchmark(operations: 0),
      throwsArgumentError,
    );
  });
}
