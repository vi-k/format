import 'dart:math';

import 'package:format/format.dart';
// The legacy-path seams (debugFormatBraceWithoutIr/debugFormatPrintfWithoutIr)
// are deliberately not part of the public API; this A/B benchmark is one of
// the few callers allowed to reach across the package boundary for them.
// ignore: implementation_imports
import 'package:format/src/engine.dart' as engine;

import 'double_modes_benchmark.dart' show BenchmarkLineWriter;
import 'utils/output.dart';

// Grapheme-cluster engine: used only by the fallback-control scenario that
// exercises a multi-code-unit fill, which stays on the legacy path even
// after the IR hot ops land.
final _graphemes = Format(textUnit: TextUnit.graphemeClusters);

var _benchmarkChecksum = 0;

final class _IrScenario {
  final String label; // printed template label
  final String kind; // 'hot' | 'fallback-control'
  final String Function() ir;
  final String Function() legacy;

  const _IrScenario({
    required this.label,
    required this.kind,
    required this.ir,
    required this.legacy,
  });
}

final _scenarios = <_IrScenario>[
  // Both sides below call the list-taking entry points (formatWith/vsprintf
  // vs. the debugFormat*WithoutIr seams) with pre-built const argument
  // lists. The convenience varargs entry points (format()/sprintf()) funnel
  // through _collectOptionalValues(), which allocates an extra list per
  // call; that marshalling cost is real but avoidable here, and it is
  // orthogonal to what this benchmark measures (IR compiled-op dispatch vs.
  // the legacy string-walking path) — so both sides use the same
  // zero-extra-allocation calling convention.
  // --- hot: brace static integer ops ---
  _IrScenario(
    label: '{:10d}',
    kind: 'hot',
    ir: () => formatWith('{:10d}', positional: const [12345]),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:10d}',
      defaultFormat,
      positional: const [12345],
    ),
  ),
  _IrScenario(
    label: '{:x}',
    kind: 'hot',
    ir: () => formatWith('{:x}', positional: const [255]),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:x}',
      defaultFormat,
      positional: const [255],
    ),
  ),
  // --- hot: brace static text ops ---
  _IrScenario(
    label: '{:s}',
    kind: 'hot',
    ir: () => formatWith('{:s}', positional: const ['hello world']),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:s}',
      defaultFormat,
      positional: const ['hello world'],
    ),
  ),
  _IrScenario(
    label: '{:<10s}',
    kind: 'hot',
    ir: () => formatWith('{:<10s}', positional: const ['hello']),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:<10s}',
      defaultFormat,
      positional: const ['hello'],
    ),
  ),
  // --- hot: brace dynamic-value op (empty spec) ---
  _IrScenario(
    label: '{}',
    kind: 'hot',
    ir: () => formatWith('{}', positional: const ['hello']),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{}',
      defaultFormat,
      positional: const ['hello'],
    ),
  ),
  // --- hot: printf static string op ---
  _IrScenario(
    label: '%s',
    kind: 'hot',
    ir: () => vsprintf('%s', const ['hello world']),
    legacy: () => engine.debugFormatPrintfWithoutIr(
      '%s',
      defaultFormat,
      const ['hello world'],
    ),
  ),
  // --- hot: printf static integer op ---
  _IrScenario(
    label: '%10d',
    kind: 'hot',
    ir: () => vsprintf('%10d', const [12345]),
    legacy: () => engine.debugFormatPrintfWithoutIr(
      '%10d',
      defaultFormat,
      const [12345],
    ),
  ),
  // --- hot: printf integer op with dynamic width (still hot for printf) ---
  _IrScenario(
    label: '%0*d',
    kind: 'hot',
    ir: () => vsprintf('%0*d', const [7, 42]),
    legacy: () => engine.debugFormatPrintfWithoutIr(
      '%0*d',
      defaultFormat,
      const [7, 42],
    ),
  ),
  // --- fallback-control: doubles never compile hot ---
  _IrScenario(
    label: '{:.2f}',
    kind: 'fallback-control',
    ir: () => formatWith('{:.2f}', positional: const [3.14159]),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:.2f}',
      defaultFormat,
      positional: const [3.14159],
    ),
  ),
  // --- fallback-control: multi-code-unit fill on a grapheme-cluster engine.
  // The fill is 'e' + combining U+0301, written as an explicit escape so it
  // stays two code units regardless of source normalization; a precomposed
  // 'é' is one code unit and would compile hot instead.
  _IrScenario(
    label: '{:e\u0301^10s}',
    kind: 'fallback-control',
    ir: () => _graphemes.formatWith(
      '{:e\u0301^10s}',
      positional: const ['abc'],
    ),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:e\u0301^10s}',
      _graphemes,
      positional: const ['abc'],
    ),
  ),
];

void runTemplateIrBenchmark({
  BenchmarkLineWriter? writeLine,
  int warmupOperations = 1000,
  int operations = 10000,
  int samples = 7,
  double equivalenceThresholdPercent = 5.0,
}) {
  if (warmupOperations < 0 || operations <= 0 || samples <= 0) {
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
  for (final scenario in _scenarios) {
    final irResult = scenario.ir();
    final legacyResult = scenario.legacy();
    final measurements = _measureScenario(
      scenario,
      irResult,
      legacyResult,
      warmupOperations,
      operations,
      samples,
    );

    emit('');
    emit(h1('----------------------------------------'));
    emit('${scenario.kind} template: ${h1(scenario.label)}');
    emit('');
    emit(
      '${accent('IR')}:     '
      '${h2('"$irResult"')}  '
      '${measurements.irMicros.toStringAsFixed(3)} µs/op',
    );
    emit(
      '${accent('Legacy')}: '
      '${h2('"$legacyResult"')}  '
      '${measurements.legacyMicros.toStringAsFixed(3)} µs/op',
    );
    if (irResult != legacyResult) {
      emit(accentWarning('RESULTS DIFFER'));
    }
    final irFaster = measurements.irMicros <= measurements.legacyMicros;
    final fastest = irFaster ? 'IR' : 'LEGACY';
    final slowest = irFaster ? measurements.legacyMicros : measurements.irMicros;
    final fastestTime =
        irFaster ? measurements.irMicros : measurements.legacyMicros;
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

({double irMicros, double legacyMicros}) _measureScenario(
  _IrScenario scenario,
  String irResult,
  String legacyResult,
  int warmupOperations,
  int operations,
  int samples,
) {
  _measure(scenario.ir, irResult, max(1, warmupOperations));
  _measure(scenario.legacy, legacyResult, max(1, warmupOperations));
  final irSamples = <double>[];
  final legacySamples = <double>[];
  for (var sample = 0; sample < samples; sample++) {
    if (sample.isEven) {
      irSamples.add(_measure(scenario.ir, irResult, operations));
      legacySamples.add(_measure(scenario.legacy, legacyResult, operations));
    } else {
      legacySamples.add(_measure(scenario.legacy, legacyResult, operations));
      irSamples.add(_measure(scenario.ir, irResult, operations));
    }
  }
  return (
    irMicros: _median(irSamples),
    legacyMicros: _median(legacySamples),
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
