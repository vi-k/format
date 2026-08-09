/// The comparison matrix — the tool that prints how this package measures up
/// against [format] 1.6 and [sprintf] — tested for the things a benchmark run
/// cannot tell you about itself.
///
/// A benchmark is a program that always produces plausible output. If a
/// comparator silently stopped being measured, or a scenario disappeared, or
/// the engines were compared on values one of them formats differently, the
/// table would still print and still look authoritative. These tests read the
/// output and the matrix instead of trusting them: the engines are present and
/// produce the expected strings, the scenario count and the scaling case are
/// pinned, and a comparator that cannot run a scenario is shown as skipped
/// rather than omitted.
///
/// The measurement machinery gets the same treatment. Cache mode is per
/// measurement and must be restored afterwards, so one row cannot change what
/// the next one measures. Durations default to quick and switch on request, and
/// an invalid threshold is refused rather than quietly accepted.
///
/// Nothing here asserts a timing. The output format is asserted, because it is
/// what a reader interprets, and it has changed several times.
library;

import 'package:format/format.dart';
import 'package:format_benchmarks/benchmark.dart';
import 'package:test/test.dart';

void main() {
  // All three engines are reachable by name and produce the same string for
  // the same value — the precondition for comparing their timings at all.
  test('restored benchmark exposes Format 3, Format 1.6 and sprintf '
      'engines', () {
    BenchmarkEngine named(String name) =>
        benchmarkEngines.singleWhere((engine) => engine.name == name);
    final format3 = FormatterBenchmark(named('format 3.0 → format'));
    final format16 = FormatterBenchmark(named('format 1.6 → format'));
    final printf = FormatterBenchmark(named('sprintf 7.0 → sprintf'));

    format3.go('{:d}', [42]);
    format16.go('{:d}', [42]);
    printf.go('%d', [42]);

    expect(format3.output, '42');
    expect(format16.output, '42');
    expect(printf.output, '42');
  });

  // The scenario count and contents, pinned so that a scenario cannot vanish in
  // a refactor and leave a smaller table that looks complete.
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
    // the fitRegroupedZeroPadding fix; pub format 1.6 agrees on the output.
    final groupedZero = benchmarkScenarios.singleWhere(
      (s) => s.brace == '{:010,d}',
    );
    expect(groupedZero.sprintf, isNull);
    expect(groupedZero.skipFormat16, isFalse);
    expect(groupedZero.cases.single.$1, [1234]);
    expect(groupedZero.cases.single.$2, '00,001,234');

    final first = benchmarkScenarios.first;
    expect(first.brace, '{}');
    expect(first.sprintf, '%d');
    expect(first.cases.first.$2, '0');

    final char = benchmarkScenarios.singleWhere((s) => s.brace == '{:c}');
    expect(char.sprintf, '%c');
    expect(char.skipSprintf70, isTrue);

    final scientific = benchmarkScenarios.singleWhere((s) => s.brace == '{:e}');
    expect(scientific.sprintf, '%e');
    expect(scientific.skipSprintf70, isTrue);
    expect(scientific.skipFormat16, isTrue);

    final integer = benchmarkScenarios.singleWhere((s) => s.brace == '{:d}');
    expect(integer.cases.last.$1, [-9223372036854775808]);
    expect(integer.cases.last.$2, '-9223372036854775808');
  });

  // The one scenario that measures how the engines scale with template size
  // rather than with value type. It is the easiest to drop and the hardest to
  // notice missing.
  test('comparison matrix keeps the 50-placeholder scaling scenario', () {
    final wide = benchmarkScenarios.singleWhere(
      (s) => s.brace == List.filled(50, '{}').join('|'),
    );

    expect(wide.sprintf, List.filled(50, '%d').join('|'));
    expect(wide.skipFormat16, isFalse);
    expect(wide.skipSprintf70, isFalse);
    expect(wide.cases, hasLength(1));
    expect(wide.cases.single.$1, List<Object?>.generate(50, (index) => index));
    expect(
      wide.cases.single.$2,
      List.generate(50, (index) => '$index').join('|'),
    );
  });

  // The double-mode comparison prints both profiles, with their results as well
  // as their timings — the results are what tells a reader the two are being
  // compared on the same value and not on two different answers.
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

  // A difference smaller than the threshold is noise, and reporting a winner
  // from noise is how a benchmark becomes misleading. Inside the threshold the
  // verdict is "equal".
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

  // And the other side of the same rule: a real difference is reported rather
  // than absorbed.
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
    // A threshold outside the sensible range would make every run either always
    // equal or never equal, silently. It is refused.
    test('double modes benchmark rejects threshold $threshold', () {
      expect(
        () => runDoubleModesBenchmark(equivalenceThresholdPercent: threshold),
        throwsArgumentError,
      );
    });
  }

  // The default is the quick mode, because a default that took minutes would be
  // run less often; the precise mode is opt-in.
  test('benchmark durations default to quick and switch to full', () {
    expect(BenchmarkDurations.quick.warmupMillis, 45);
    expect(BenchmarkDurations.quick.measureMillis, 165);
    expect(BenchmarkDurations.full.warmupMillis, 100);
    expect(BenchmarkDurations.full.measureMillis, 2000);

    final benchmark = FormatterBenchmark(benchmarkEngines.first);
    expect(benchmark.durations, BenchmarkDurations.quick);
    benchmark.durations = BenchmarkDurations.full;
    expect(benchmark.durations, BenchmarkDurations.full);
  });

  // The command-line surface of that choice, including the refusal of anything
  // it does not recognize — a mistyped flag must not silently produce quick
  // numbers labelled as full ones.
  test('benchmark arguments select measurement durations', () {
    expect(parseBenchmarkArgs([]), BenchmarkDurations.quick);
    expect(parseBenchmarkArgs(['--full']), BenchmarkDurations.full);
    expect(() => parseBenchmarkArgs(['--fast']), throwsFormatException);
    expect(() => parseBenchmarkArgs(['--full', 'x']), throwsFormatException);
  });

  // A comparator that cannot express a scenario is printed as skipped, not left
  // out: an absent row reads as "not measured yet", while a skipped one says
  // the comparison does not exist. This test also pins the row format itself —
  // the scale, the reference row, and what a row without a reference looks
  // like.
  test('comparison benchmark skips unsupported runners and shows only the '
      'known sprintf7 error', () {
    final lines = <String>[];

    runComparisonBenchmark(
      writeLine: lines.add,
      durations: const BenchmarkDurations(warmupMillis: 1, measureMillis: 1),
    );

    final output = lines.join('\n');
    final plainOutput = output.replaceAll(RegExp('\x1B\\[[0-9;]*m'), '');
    expect(output, contains('{:b}'));
    expect(output, contains(List.filled(50, '{}').join('|')));
    expect(output, contains(': —'));
    expect(output, contains('Mode: quick'));
    expect(output, contains('Total:'));

    // Every row is scaled against format 1.6, which shows as the trivial
    // row rather than as a word of its own.
    expect(plainOutput, contains('<- 1.00 (×1.00)'));
    expect(plainOutput, matches(RegExp(r'<- \d+\.\d+ \(×\d+\.\d\d\)')));
    // A scenario format 1.6 does not run leaves nothing to scale against,
    // so those rows end at their own time.
    expect(plainOutput, matches(RegExp(r'µs$', multiLine: true)));

    final errors = lines.where((line) => line.contains('ERROR')).toList();
    expect(errors, hasLength(1));
    final plain = errors.single.replaceAll(RegExp('\x1B\\[[0-9;]*m'), '');
    expect(plain, contains('sprintf 7.0'));
    expect(plain, contains('--9223372036854775808'));

    expect(output, contains('no cache'));
    expect(output, contains('(no cache)'));
  });

  // Cache mode is global state, and the table measures both warm and no-cache
  // rows in one run. Each measurement therefore sets what it needs and restores
  // what it found — otherwise the rows would depend on the order they are
  // printed in, which is presentation rather than intent.
  test('a measurement sets its own cache mode and restores what it found', () {
    // The point of one class for both modes: the matrix may run them in any
    // order, so neither may depend on what ran before it, nor leave a trace
    // for what runs after.
    const durations = BenchmarkDurations(warmupMillis: 1, measureMillis: 1);
    final engine = benchmarkEngines.singleWhere(
      (engine) => engine.name == 'format 3.0 → format',
    );
    final warm = FormatterBenchmark(engine)..durations = durations;
    final cold = FormatterBenchmark(engine, cached: false)
      ..durations = durations;

    templateCacheCapacity = 64;
    for (final order in [
      [cold, warm],
      [warm, cold],
    ]) {
      for (final benchmark in order) {
        benchmark.go('{:10d}', [12345]);
        expect(benchmark.output, '     12345', reason: benchmark.name);
        expect(
          templateCacheCapacity,
          64,
          reason: '${benchmark.name} did not put the capacity back',
        );
      }
    }

    clearTemplateCache();
    cold.go('{:10d}', [12345]);
    expect(
      templateCacheSize,
      0,
      reason: 'a no-cache measurement must leave nothing cached',
    );
    warm.go('{:10d}', [12345]);
    expect(
      templateCacheSize,
      greaterThan(0),
      reason: 'a warm measurement must have had a cache to use',
    );
    templateCacheCapacity = 512;
  });
}
