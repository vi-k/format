import 'dart:math';

import 'package:format/format.dart';

import 'utils/clock.dart';
import 'utils/output.dart';

typedef BenchmarkLineWriter = void Function(String line);

final _dartFormat = Format();
final _compatibleFormat = Format(doubleFormatMode: DoubleFormatMode.compatible);

var _benchmarkChecksum = 0;

void runDoubleModesBenchmark({
  BenchmarkLineWriter? writeLine,
  int warmupOperations = 1000,
  // Null means "ask the clock". A fixed ten thousand spans a comfortable
  // stretch of the VM's clock and exactly one tick of the millisecond one
  // dart2js has, where it turns every reading into a multiple of 0.1 µs.
  // Callers that want a short, deterministic run still pass a count.
  int? operations,
  int samples = 7,
  double equivalenceThresholdPercent = 5.0,
}) {
  if (warmupOperations < 0 ||
      (operations != null && operations <= 0) ||
      samples <= 0) {
    throw ArgumentError('Benchmark operation counts must be positive.');
  }
  if (!equivalenceThresholdPercent.isFinite ||
      equivalenceThresholdPercent < 0) {
    throw ArgumentError.value(
      equivalenceThresholdPercent,
      'equivalenceThresholdPercent',
      'must be finite and non-negative',
    );
  }
  final emit = writeLine ?? print;
  for (final scenario in _doubleModeScenarios) {
    final dartResult = scenario.run(_dartFormat);
    final compatibleResult = scenario.run(_compatibleFormat);
    final measurements = _measureModes(
      scenario,
      dartResult,
      compatibleResult,
      warmupOperations,
      operations,
      samples,
    );

    emit('');
    emit(h1('----------------------------------------'));
    emit('${scenario.dialect} template: ${h1(scenario.template)}');
    emit(h2('Value: ${scenario.value}'));
    emit('');
    emit(
      '${accent('Dart SDK')}:   '
      '${h2(dartResult)}  '
      '${measurements.dartMicros.toStringAsFixed(3)} µs/op',
    );
    emit(
      '${accent('Compatible')}: '
      '${h2(compatibleResult)}  '
      '${measurements.compatibleMicros.toStringAsFixed(3)} µs/op',
    );
    if (dartResult != compatibleResult) {
      emit(accentWarning('RESULTS DIFFER'));
    }
    final dartFaster = measurements.dartMicros <= measurements.compatibleMicros;
    final fastest = dartFaster ? 'Dart SDK' : 'Compatible';
    final slowest =
        dartFaster ? measurements.compatibleMicros : measurements.dartMicros;
    final fastestTime =
        dartFaster ? measurements.dartMicros : measurements.compatibleMicros;
    final difference =
        fastestTime == 0 ? 0.0 : (slowest / fastestTime - 1) * 100;
    if (difference <= equivalenceThresholdPercent) {
      emit(
        ok(
          'PERFORMANCE EQUAL: difference '
          '${difference.toStringAsFixed(1)}% <= '
          '${equivalenceThresholdPercent.toStringAsFixed(1)}%',
        ),
      );
    } else {
      emit(ok('$fastest FASTER: ${difference.toStringAsFixed(1)}%'));
    }
  }
}

({double dartMicros, double compatibleMicros}) _measureModes(
  _DoubleModeScenario scenario,
  String dartResult,
  String compatibleResult,
  int warmupOperations,
  int? requestedOperations,
  int samples,
) {
  final operations =
      requestedOperations ??
      calibratedOperations(
        (count) => _measure(() => scenario.run(_dartFormat), dartResult, count),
      );
  _measure(
    () => scenario.run(_dartFormat),
    dartResult,
    max(1, warmupOperations),
  );
  _measure(
    () => scenario.run(_compatibleFormat),
    compatibleResult,
    max(1, warmupOperations),
  );
  final dartSamples = <double>[];
  final compatibleSamples = <double>[];
  for (var sample = 0; sample < samples; sample++) {
    if (sample.isEven) {
      dartSamples.add(
        _measure(() => scenario.run(_dartFormat), dartResult, operations),
      );
      compatibleSamples.add(
        _measure(
          () => scenario.run(_compatibleFormat),
          compatibleResult,
          operations,
        ),
      );
    } else {
      compatibleSamples.add(
        _measure(
          () => scenario.run(_compatibleFormat),
          compatibleResult,
          operations,
        ),
      );
      dartSamples.add(
        _measure(() => scenario.run(_dartFormat), dartResult, operations),
      );
    }
  }
  return (
    dartMicros: _median(dartSamples),
    compatibleMicros: _median(compatibleSamples),
  );
}

double _measure(String Function() operation, String expected, int operations) {
  String? result;
  var checksum = 0;
  final stopwatch = Stopwatch()..start();
  for (var index = 0; index < operations; index++) {
    result = operation();
    checksum = (checksum + result.length + index) & 0x3fffffff;
  }
  stopwatch.stop();
  if (result != expected) {
    throw StateError('Timed formatting result changed: $result != $expected');
  }
  _benchmarkChecksum = (_benchmarkChecksum + checksum) & 0x3fffffff;
  return stopwatch.elapsedTicks * 1000000 / stopwatch.frequency / operations;
}

double _median(List<double> values) {
  values.sort();
  return values[values.length ~/ 2];
}

final class _DoubleModeScenario {
  final String dialect;
  final String template;
  final double value;
  final String Function(Format engine) run;

  const _DoubleModeScenario({
    required this.dialect,
    required this.template,
    required this.value,
    required this.run,
  });
}

_DoubleModeScenario _brace(String template, double value) =>
    _DoubleModeScenario(
      dialect: 'Format',
      template: template,
      value: value,
      run: (engine) => engine.format(template, value),
    );

_DoubleModeScenario _printf(String template, double value) =>
    _DoubleModeScenario(
      dialect: 'Sprintf',
      template: template,
      value: value,
      run: (engine) => engine.sprintf(template, value),
    );

final _doubleModeScenarios = <_DoubleModeScenario>[
  _brace('{:.2f}', 0.1),
  _brace('{:.2f}', 12345678901234.568),
  _brace('{:.0f}', 2.5),
  _brace('{:e}', 1.0),
  _brace('{:.3g}', 1.0),
  _brace('{:f}', double.nan),
  _brace('{:f}', double.infinity),
  _printf('%.2f', 0.1),
  _printf('%.2f', 12345678901234.568),
  _printf('%.0f', 2.5),
  _printf('%e', 1.0),
  _printf('%.3g', 1.0),
  _printf('%f', double.nan),
  _printf('%f', double.infinity),
];
