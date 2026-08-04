import 'dart:math';

import 'package:format/format.dart';

import 'benchmark_format2_format.dart';
import 'benchmark_format3_format.dart';
import 'benchmark_format3_sprintf.dart';
import 'benchmark_sprintf7.dart';
import 'double_modes_benchmark.dart' show BenchmarkLineWriter;
import 'my_benchmark_base.dart';
import 'tests/tests.dart';
import 'utils/output.dart';

/// Parses benchmark CLI arguments: no flags select the quick mode, `--full`
/// selects the precise benchmark_harness defaults.
BenchmarkDurations parseBenchmarkArgs(List<String> args) => switch (args) {
  [] => BenchmarkDurations.quick,
  ['--full'] => BenchmarkDurations.full,
  _ => throw FormatException(
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
    BenchmarkSprintf7(),
    BenchmarkFormat2Format(),
    BenchmarkFormat3Format(),
    BenchmarkFormat3Sprintf(),
  ];
  for (final benchmark in benchmarks) {
    benchmark.durations = resolved;
  }

  final stopwatch = Stopwatch()..start();
  for (final template in testData) {
    final formatTemplate = template.$1;
    final sprintfTemplate = template.$2;

    emit('');
    emit(h1('----------------------------------------'));
    emit('Format template: ${h1(formatTemplate)}');
    emit('Sprintf template: ${h1(sprintfTemplate)}');

    for (final test in template.$3) {
      final values = test.$1;
      final result = test.$2;

      emit('');
      emit('Values: ${h2(values.join(', '))}');

      for (final benchmark in benchmarks) {
        try {
          final score = benchmark.go(
            benchmark.isSprintf ? sprintfTemplate : formatTemplate,
            values,
          );

          String message;
          if (benchmark.output == result) {
            message = ok('OK');
          } else {
            final difference = _diff(result, benchmark.output);
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
    }
  }

  emit('');
  emit(h1('----------------------------------------'));
  final mode =
      identical(resolved, BenchmarkDurations.full) ? 'full' : 'quick';
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
