import 'dart:math';

import 'package:format/format.dart';

import 'double_modes_benchmark.dart' show BenchmarkLineWriter;
import 'formatter_benchmark.dart';
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
  // One list, warm and no-cache together: each measurement sets the cache
  // mode it needs, so the order here is presentation, not a dependency.
  // Only format 3.0 keeps parsed templates, so only format 3.0 has a second
  // number — a comparator parses on every call anyway, and printing its
  // figure twice would say the same thing under two headings.
  final benchmarks = [
    for (final engine in benchmarkEngines) ...[
      FormatterBenchmark(engine),
      if (engine.hasTemplateCache) FormatterBenchmark(engine, cached: false),
    ],
  ];
  for (final benchmark in benchmarks) {
    benchmark.durations = resolved;
  }

  emit('');
  emit('A time is per call. A "no cache" row is the same call with the');
  emit('template cache switched off, so it parses every time — which is what');
  emit('a comparator does anyway, having no cache of its own.');
  emit('');
  emit('Each row is scaled against format 1.6 on the same values: x2.00');
  emit('means twice as fast as it, x0.50 half as fast. A row says OK instead');
  emit('when format 1.6 has no figure to scale against.');

  final stopwatch = Stopwatch()..start();
  for (final scenario in benchmarkScenarios) {
    emit('');
    emit(h1('----------------------------------------'));
    emit('Format template: ${h1(scenario.brace ?? '—')}');
    emit('Sprintf template: ${h1(scenario.sprintf ?? '—')}');

    for (final (values, expected) in scenario.cases) {
      emit('');
      emit('Values: ${h2(values.join(', '))}');

      // The whole row is measured before any of it is printed: the scale is
      // format 1.6's time on these values, and it is not the first engine in
      // the list. Printing as each one finishes would mean printing a
      // factor before knowing what to divide by.
      final rows = <_Row>[];
      for (final benchmark in benchmarks) {
        final template =
            benchmark.isSprintf ? scenario.sprintf : scenario.brace;
        final skipped =
            template == null ||
            (benchmark.isSprintf70 && scenario.skipSprintf70) ||
            (benchmark.isFormat16 && scenario.skipFormat16);
        if (skipped) {
          rows.add(_Row(name: benchmark.name));
          continue;
        }
        try {
          final score = benchmark.go(template, values);
          final correct = benchmark.output == expected;
          final difference = correct ? null : _diff(expected, benchmark.output);
          rows.add(
            _Row(
              name: benchmark.name,
              score: score,
              isReference: benchmark.isFormat16,
              failure:
                  difference == null
                      ? null
                      : '${accentError('ERROR')}'
                          '\n  expected: ${difference.$1}'
                          '\n  actual:   ${difference.$2}',
            ),
          );
        } on Object catch (errorValue) {
          rows.add(
            _Row(
              name: benchmark.name,
              failure:
                  '${accentError('ERROR')}\n${error(errorValue.toString())}',
            ),
          );
        }
      }

      // A wrong result is no scale for a right one, so a reference that
      // failed leaves the row unscaled rather than silently mis-scaled.
      final reference =
          rows
              .where((row) => row.isReference && row.failure == null)
              .map((row) => row.score)
              .firstOrNull;
      for (final row in rows) {
        emit(row.render(reference));
      }
    }
  }

  emit('');
  emit(h1('----------------------------------------'));
  final mode = identical(resolved, BenchmarkDurations.full) ? 'full' : 'quick';
  final seconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
  emit('Mode: $mode. Total: $seconds s');
}

/// One measured engine on one set of values, held until the whole row is
/// known and the scale can be applied.
final class _Row {
  final String name;

  /// Null when the engine was skipped for this scenario, or threw.
  final double? score;

  /// The rendered ERROR block, or null when the output was expected.
  final String? failure;

  /// Whether this is the row every other one is scaled against.
  final bool isReference;

  const _Row({
    required this.name,
    this.score,
    this.failure,
    this.isReference = false,
  });

  String render(double? reference) {
    final time = score;
    if (time == null) {
      return failure == null
          ? '${accent(name)}: —'
          : '${accent(name)}: <- $failure';
    }

    return '${accent(name)}:'
        ' ${format('{:.3f}', time)} µs'
        ' <- ${failure ?? _scale(time, reference)}';
  }

  String _scale(double time, double? reference) {
    if (isReference) return faintAccent('reference');
    // Nothing to scale against, so the row falls back to saying what it
    // still knows: the output was the expected one.
    if (reference == null || time <= 0) return ok('OK');
    final factor = reference / time;
    final text = 'x${format('{:.2f}', factor)}';

    return factor >= 1 ? ok(text) : warning(text);
  }
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
