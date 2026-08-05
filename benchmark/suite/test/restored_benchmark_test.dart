import 'package:format_benchmarks/benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('restored benchmark exposes Format 3, Format 2 and sprintf engines', () {
    final format3 = BenchmarkFormat3Format();
    final format2 = BenchmarkFormat2Format();
    final printf = BenchmarkSprintf7();

    format3.go('{:d}', [42]);
    format2.go('{:d}', [42]);
    printf.go('%d', [42]);

    expect(format3.output, '42');
    expect(format2.output, '42');
    expect(printf.output, '42');
  });

  test('comparison matrix covers common builtin scenarios', () {
    expect(benchmarkScenarios, hasLength(28));

    final braces = benchmarkScenarios.map((s) => s.brace).toList();
    expect(braces, contains('{:b}'));
    expect(braces, contains('{:,d}'));
    expect(braces, contains('{:010,d}'));
    expect(braces, contains('{:é^10s}'));
    expect(braces, contains('{:d} ' * 10));
    expect(braces, isNot(contains('{:10d} ' * 10)));

    final binary = benchmarkScenarios.singleWhere((s) => s.brace == '{:b}');
    expect(binary.sprintf, isNull);

    // Zero padding fitted to the grouped width: the regression scenario for
    // the fitRegroupedZeroPadding fix; format 2.0 agrees on the output.
    final groupedZero = benchmarkScenarios.singleWhere(
      (s) => s.brace == '{:010,d}',
    );
    expect(groupedZero.sprintf, isNull);
    expect(groupedZero.skipLegacy, isFalse);
    expect(groupedZero.cases.single.$1, [1234]);
    expect(groupedZero.cases.single.$2, '00,001,234');

    final first = benchmarkScenarios.first;
    expect(first.brace, '{}');
    expect(first.sprintf, '%d');
    expect(first.cases.first.$2, '0');

    final char = benchmarkScenarios.singleWhere((s) => s.brace == '{:c}');
    expect(char.sprintf, '%c');
    expect(char.skipSprintf7, isTrue);

    final scientific = benchmarkScenarios.singleWhere((s) => s.brace == '{:e}');
    expect(scientific.sprintf, '%e');
    expect(scientific.skipSprintf7, isTrue);
    expect(scientific.skipLegacy, isTrue);

    final integer = benchmarkScenarios.singleWhere((s) => s.brace == '{:d}');
    expect(integer.cases.last.$1, [-9223372036854775808]);
    expect(integer.cases.last.$2, '-9223372036854775808');
  });

  test('comparison matrix keeps the 50-placeholder scaling scenario', () {
    final wide = benchmarkScenarios.singleWhere(
      (s) => s.brace == List.filled(50, '{}').join('|'),
    );

    expect(wide.sprintf, List.filled(50, '%d').join('|'));
    expect(wide.skipLegacy, isFalse);
    expect(wide.skipSprintf7, isFalse);
    expect(wide.cases, hasLength(1));
    expect(wide.cases.single.$1, List<Object?>.generate(50, (index) => index));
    expect(
      wide.cases.single.$2,
      List.generate(50, (index) => '$index').join('|'),
    );
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

  test('benchmark durations default to quick and switch to full', () {
    expect(BenchmarkDurations.quick.warmupMillis, 45);
    expect(BenchmarkDurations.quick.measureMillis, 165);
    expect(BenchmarkDurations.full.warmupMillis, 100);
    expect(BenchmarkDurations.full.measureMillis, 2000);

    final benchmark = BenchmarkFormat3Format();
    expect(benchmark.durations, BenchmarkDurations.quick);
    benchmark.durations = BenchmarkDurations.full;
    expect(benchmark.durations, BenchmarkDurations.full);
  });

  test('benchmark arguments select measurement durations', () {
    expect(parseBenchmarkArgs([]), BenchmarkDurations.quick);
    expect(parseBenchmarkArgs(['--full']), BenchmarkDurations.full);
    expect(() => parseBenchmarkArgs(['--fast']), throwsFormatException);
    expect(() => parseBenchmarkArgs(['--full', 'x']), throwsFormatException);
  });

  test('comparison benchmark skips unsupported runners and shows only the '
      'known sprintf7 error', () {
    final lines = <String>[];

    runComparisonBenchmark(
      writeLine: lines.add,
      durations: const BenchmarkDurations(warmupMillis: 1, measureMillis: 1),
    );

    final output = lines.join('\n');
    expect(output, contains('{:b}'));
    expect(output, contains(List.filled(50, '{}').join('|')));
    expect(output, contains(': —'));
    expect(output, contains('OK'));
    expect(output, contains('Mode: quick'));
    expect(output, contains('Total:'));

    final errors = lines.where((line) => line.contains('ERROR')).toList();
    expect(errors, hasLength(1));
    final plain = errors.single.replaceAll(RegExp('\x1B\\[[0-9;]*m'), '');
    expect(plain, contains('sprintf 7.0'));
    expect(plain, contains('--9223372036854775808'));

    expect(output, contains('Cold: unique template per call'));
    expect(output, contains('(cold)'));
  });
}
