import 'dart:math';

import 'package:format/format.dart';

import 'benchmark_cold.dart';
import 'benchmark_format16_format.dart';
import 'benchmark_format30_format.dart';
import 'benchmark_format30_sprintf.dart';
import 'benchmark_sprintf70.dart';
import 'double_modes_benchmark.dart' show BenchmarkLineWriter;
import 'my_benchmark_base.dart';
import 'tests/tests.dart';
import 'utils/output.dart';

/// Parses benchmark CLI arguments: no flags select the quick mode, `--full`
/// selects the precise benchmark_harness defaults.
BenchmarkDurations parseBenchmarkArgs(List<String> args) => switch (args) {
  [] => BenchmarkDurations.quick,
  ['--full'] => BenchmarkDurations.full,
  _ =>
    throw FormatException(
      'Unknown arguments: ${args.join(' ')}. '
      'Usage: benchmark.dart [--full]',
    ),
};

void runComparisonBenchmark({
  List<String> args = const [],
  BenchmarkLineWriter? writeLine,
  BenchmarkDurations? durations,
}) {
  final resolved = durations ?? parseBenchmarkArgs(args);
  final emit = writeLine ?? print;
  final benchmarks = [
    BenchmarkFormat16Format(),
    BenchmarkFormat30Format(),
    BenchmarkFormat30Sprintf(),
    BenchmarkSprintf70(),
  ];
  for (final benchmark in benchmarks) {
    benchmark.durations = resolved;
  }

  // Only format 3.0 caches parsed templates, so only format 3.0 has two
  // numbers to report. A comparator parses on every call by construction, and
  // its single figure already is a first parse — measuring it twice would
  // print the same number under two headings.
  final coldBenchmarks = [
    BenchmarkFormat30ColdFormat(),
    BenchmarkFormat30ColdSprintf(),
  ];
  for (final benchmark in coldBenchmarks) {
    benchmark.durations = resolved;
  }

  emit('');
  emit('A time is per call. A "no cache" row is the same call with the');
  emit('template cache switched off, so it parses every time — which is what');
  emit('a comparator does anyway, having no cache of its own.');

  final stopwatch = Stopwatch()..start();
  for (final scenario in benchmarkScenarios) {
    emit('');
    emit(h1('----------------------------------------'));
    emit('Format template: ${h1(scenario.brace ?? '—')}');
    emit('Sprintf template: ${h1(scenario.sprintf ?? '—')}');

    for (final (values, expected) in scenario.cases) {
      emit('');
      emit('Values: ${h2(values.join(', '))}');

      for (final benchmark in benchmarks) {
        final template =
            benchmark.isSprintf ? scenario.sprintf : scenario.brace;
        final skipped =
            template == null ||
            (benchmark.isSprintf70 && scenario.skipSprintf70) ||
            (benchmark.isFormat16 && scenario.skipFormat16);
        if (skipped) {
          emit('${accent(benchmark.name)}: —');
          continue;
        }
        try {
          final score = benchmark.go(template, values);

          String message;
          if (benchmark.output == expected) {
            message = ok('OK');
          } else {
            final difference = _diff(expected, benchmark.output);
            message =
                '${accentError('ERROR')}'
                '\n  expected: ${difference.$1}'
                '\n  actual:   ${difference.$2}';
          }
          emit(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (errorValue) {
          emit(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(errorValue.toString())}',
          );
        }
      }

      for (final benchmark in coldBenchmarks) {
        final template =
            benchmark.isSprintf ? scenario.sprintf : scenario.brace;
        if (template == null) continue;
        try {
          final score = benchmark.go(template, values);
          final message =
              benchmark.output == expected ? ok('OK') : accentError('ERROR');
          emit(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (errorValue) {
          emit(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(errorValue.toString())}',
          );
        }
      }
    }
  }

  emit('');
  emit(h1('----------------------------------------'));
  final mode = identical(resolved, BenchmarkDurations.full) ? 'full' : 'quick';
  final seconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
  emit('Mode: $mode. Total: $seconds s');
}

(String, String) _diff(String expected, String actual) {
  final minLength = min(expected.length, actual.length);
  final maxLength = max(expected.length, actual.length);
  final expectedReturn = expected.padRight(maxLength);

  var end = 0;
  while (end < minLength && expected[end] == actual[end]) {
    end++;
  }

  final absent =
      actual.length >= expected.length
          ? ''
          : '•' * (expected.length - actual.length);

  final rest = actual.substring(end);
  return (
    expectedReturn,
    '${actual.substring(0, end)}'
        '${error(rest)}'
        '${error(absent)}',
  );
}
