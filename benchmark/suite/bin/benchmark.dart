import 'dart:io';

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:format_benchmarks/benchmark.dart';

void main(List<String> arguments) {
  final BenchmarkDurations durations;
  try {
    durations = parseBenchmarkArgs(arguments);
  } on FormatException catch (exception) {
    print(exception.message);
    exitCode = 64;
    return;
  }

  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    () => runComparisonBenchmark(durations: durations),
  );
}
