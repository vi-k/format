import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:example/benchmark.dart';

void main() {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    runDoubleModesBenchmark,
  );
}
