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

  test('float modes benchmark prints results and timing for both modes', () {
    final lines = <String>[];

    runFloatModesBenchmark(
      writeLine: lines.add,
      warmupOperations: 1,
      operations: 2,
      samples: 3,
    );

    final output = lines.join('\n');
    expect(output, contains('{:.0f}'));
    expect(output, contains('Dart SDK'));
    expect(output, contains('Compatible'));
    expect(output, contains('Result: 3'));
    expect(output, contains('Result: 2'));
    expect(output, contains('µs/op'));
    expect(output, contains('RESULTS DIFFER'));
  });
}
