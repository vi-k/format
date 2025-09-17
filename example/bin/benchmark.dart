import 'dart:math';

import 'package:ansi_escape_codes/ansi_escape_codes.dart';
import 'package:example/benchmark.dart';
import 'package:format/format.dart';

void main(List<String> arguments) {
  runZonedAnsiPrinter(
    defaultState: const SgrPlainState(foreground: defaultFg),
    run,
  );
}

// s - String
//     Iterable<int> (fromCharCodes)
// c - int (fromCharCode)
// d - int
//     BigInt
//     String "12345678901234567890.23"
void run() {
  final list = [1, 'a', null, 2.0];
  print(list.whereType<double>());

  final v = 1e+21;
  print(v.toString());
  print(v.toStringAsFixed(2));
  print(format2('{:.4f}', [v]));

  final v2 = 10.000000000000001 * pow(10.0, 20);
  print(v2.toString());
  print(v2.toStringAsFixed(2));
  print(v2.toStringAsExponential());
  print(format2('{:.4f}', [v2]));
  // return;

  final benchmarks = [
    SprintfBenchmark(),
    FormatBenchmark(),
    Format2Benchmark(),
  ];

  for (final template in testData.skip(0)) {
    final formatTemplate = template.$1;
    final sprintfTemplate = template.$2;

    print('');
    print(h1('----------------------------------------'));
    print('Format template: ${h1(formatTemplate)}');
    print('Sprintf template: ${h1(sprintfTemplate)}');

    for (var test in template.$3) {
      final values = test.$1;
      final result = test.$2;

      print('');
      print('Values: ${h2(values.join(', '))}');
      // print('');

      for (var benchmark in benchmarks) {
        try {
          final score = benchmark.go(
            benchmark.isSprintf ? sprintfTemplate : formatTemplate,
            values,
          );

          String message;
          if (benchmark.output == result) {
            message = ok('OK');
          } else {
            final d = diff(result, benchmark.output);
            message =
                '${accentError('ERROR')}'
                '\n  expected: ${d.$1}'
                '\n  actual:   ${d.$2}';
          }
          print(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (e) {
          print(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(e.toString())}',
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
