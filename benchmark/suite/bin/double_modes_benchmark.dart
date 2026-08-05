import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:format_benchmarks/benchmark.dart';

void main() {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    runDoubleModesBenchmark,
  );
}
