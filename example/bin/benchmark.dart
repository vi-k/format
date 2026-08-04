import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:example/benchmark.dart';

void main(List<String> arguments) {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    () => runComparisonBenchmark(args: arguments),
  );
}
