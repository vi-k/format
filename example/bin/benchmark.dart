import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:example/benchmark.dart';
import 'package:intl/intl.dart';

const _measurementCount = 3;
const _multiPlaceholderLimit = 1.02;

void main() {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    _run,
  );
}

void _run() {
  Intl.defaultLocale = 'en_US';
  registerBenchmarkFormatter();

  var gatePassed = true;
  final placeholderResults = <int, double>{};

  print('Format 2.0 benchmark ($_measurementCount measurements per engine)');
  for (final scenario in benchmarkScenarios) {
    final legacySamples = <double>[];
    final currentSamples = <double>[];

    for (var measurement = 0;
        measurement < _measurementCount;
        measurement++) {
      final legacy = LegacyFormatBenchmark(scenario)..verifyOutput();
      final current = FormatBenchmark(scenario)..verifyOutput();
      legacySamples.add(legacy.measureMicrosecondsPerCall());
      currentSamples.add(current.measureMicrosecondsPerCall());
    }

    final legacyMedian = _median(legacySamples);
    final currentMedian = _median(currentSamples);
    final ratio = currentMedian / legacyMedian;
    final sampleRatios = [
      for (var index = 0; index < _measurementCount; index++)
        currentSamples[index] / legacySamples[index],
    ];

    final count = scenario.placeholderCount;
    if (count != null) {
      placeholderResults[count] = ratio;
      if (count >= 5 &&
          sampleRatios.any((value) => value > _multiPlaceholderLimit)) {
        gatePassed = false;
      }
    }

    print(
      '${scenario.name.padRight(18)} '
      'old=${legacyMedian.toStringAsFixed(3)} µs '
      'new=${currentMedian.toStringAsFixed(3)} µs '
      'new/old=${ratio.toStringAsFixed(3)} '
      'runs=${sampleRatios.map((value) => value.toStringAsFixed(3)).join(',')}',
    );
  }

  print('Placeholder summary:');
  for (final entry in placeholderResults.entries) {
    print('${entry.key.toString().padLeft(2)}: ${entry.value.toStringAsFixed(3)}');
  }
  print('Multi-placeholder gate: ${gatePassed ? 'PASS' : 'FAIL'}');
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}
