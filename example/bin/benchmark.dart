import 'dart:math';

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:example/benchmark.dart';
import 'package:format/format.dart';

void main(List<String> arguments) {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    _run,
  );
}

void _run() {
  final benchmarks = [
    SprintfBenchmark(),
    FormatBenchmark(),
    Format2Benchmark(),
  ];

  for (final template in testData) {
    final formatTemplate = template.$1;
    final sprintfTemplate = template.$2;

    print('');
    print(h1('----------------------------------------'));
    print('Format template: ${h1(formatTemplate)}');
    print('Sprintf template: ${h1(sprintfTemplate)}');

    for (final test in template.$3) {
      final values = test.$1;
      final result = test.$2;

      print('');
      print('Values: ${h2(values.join(', '))}');

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
            final difference = diff(result, benchmark.output);
            message =
                '${accentError('ERROR')}'
                '\n  expected: ${difference.$1}'
                '\n  actual:   ${difference.$2}';
          }
          print(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (errorValue) {
          print(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(errorValue.toString())}',
          );
        }
      }
    }
  }
}

(String, String) diff(String expected, String actual) {
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
