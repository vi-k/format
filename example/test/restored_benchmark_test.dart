import 'package:example/benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('restored benchmark exposes Format 3, Format 2 and sprintf engines', () {
    final format3 = Format3Benchmark();
    final format2 = Format2Benchmark();
    final printf = SprintfBenchmark();

    format3.go('{:d}', [42]);
    format2.go('{:d}', [42]);
    printf.go('%d', [42]);

    expect(format3.output, '42');
    expect(format2.output, '42');
    expect(printf.output, '42');
  });

  test('restored matrix keeps separate brace and printf templates', () {
    final scenario = testData.first;

    expect(scenario.$1, '{}');
    expect(scenario.$2, '%d');
    expect(scenario.$3.first.$2, '0');
  });

  test('double modes benchmark prints results and timing for both modes', () {
    final lines = <String>[];

    runDoubleModesBenchmark(
      writeLine: lines.add,
      warmupOperations: 1,
      operations: 2,
      samples: 3,
    );

    final output = lines.join('\n');
    expect(output, contains('{:.0f}'));
    expect(output, contains('Dart SDK'));
    expect(output, contains('Compatible'));
    expect(output, contains(h2('3')));
    expect(output, contains(h2('2')));
    expect(output, contains('µs/op'));
    expect(output, contains('RESULTS DIFFER'));
  });

  test(
    'double modes benchmark treats differences inside threshold as equal',
    () {
      final lines = <String>[];

      runDoubleModesBenchmark(
        writeLine: lines.add,
        warmupOperations: 1,
        operations: 2,
        samples: 1,
        equivalenceThresholdPercent: 1e9,
      );

      final output = lines.join('\n');
      expect(output, contains('PERFORMANCE EQUAL'));
      expect(output, contains('<= 1000000000.0%'));
    },
  );

  test('double modes benchmark reports a winner outside threshold', () {
    final lines = <String>[];

    runDoubleModesBenchmark(
      writeLine: lines.add,
      warmupOperations: 1,
      operations: 2,
      samples: 3,
      equivalenceThresholdPercent: 0,
    );

    expect(lines.join('\n'), contains('FASTER:'));
  });

  for (final threshold in [-1.0, double.nan, double.infinity]) {
    test('double modes benchmark rejects threshold $threshold', () {
      expect(
        () => runDoubleModesBenchmark(equivalenceThresholdPercent: threshold),
        throwsArgumentError,
      );
    });
  }
}
