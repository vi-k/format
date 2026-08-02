import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'model.dart';
import 'scenarios.dart';

const double _braceHotMeanLimit = 1.02;
const double _braceKeyLimit = 1.05;
const double _printfColdMeanLimit = 0.90;
const double _printfHotMeanLimit = 0.80;
const double _printfKeyLimit = 1.02;

const Map<String, Set<BenchmarkDialect>> _requiredRuntimeDialects = {
  'jit': {BenchmarkDialect.braces, BenchmarkDialect.printf},
  'aot': {BenchmarkDialect.braces, BenchmarkDialect.printf},
  'js': {BenchmarkDialect.printf},
};

/// The per-run brace decision. A failure becomes actionable only when the
/// same aggregate or key limit is also exceeded in `reproducedRatios`.
final class BraceGateResult {
  final double geometricMean;
  final double reproducedGeometricMean;
  final bool geometricMeanPassed;
  final bool keyScenariosPassed;
  final Set<String> reproducedKeyFailures;

  const BraceGateResult({
    required this.geometricMean,
    required this.reproducedGeometricMean,
    required this.geometricMeanPassed,
    required this.keyScenariosPassed,
    required this.reproducedKeyFailures,
  });

  bool get passed => geometricMeanPassed && keyScenariosPassed;
}

BraceGateResult evaluateBraceGates({
  required Map<String, double> ratios,
  required Set<String> hotScenarioIds,
  required Set<String> keyScenarioIds,
  required Map<String, double> reproducedRatios,
}) {
  final geometric = geometricMean(_valuesFor(ratios, hotScenarioIds));
  final reproducedGeometric = geometricMean(
    _valuesFor(reproducedRatios, hotScenarioIds),
  );
  final reproducedKeyFailures = <String>{
    for (final id in keyScenarioIds)
      if (_ratioFor(ratios, id) > _braceKeyLimit &&
          _ratioFor(reproducedRatios, id) > _braceKeyLimit)
        id,
  };
  return BraceGateResult(
    geometricMean: geometric,
    reproducedGeometricMean: reproducedGeometric,
    geometricMeanPassed:
        !(geometric > _braceHotMeanLimit &&
            reproducedGeometric > _braceHotMeanLimit),
    keyScenariosPassed: reproducedKeyFailures.isEmpty,
    reproducedKeyFailures: Set.unmodifiable(reproducedKeyFailures),
  );
}

bool evaluatePrintfMean(BenchmarkPhase phase, double value) => switch (phase) {
  BenchmarkPhase.cold => value <= _printfColdMeanLimit,
  BenchmarkPhase.hot => value <= _printfHotMeanLimit,
};

bool evaluatePrintfKeyScenarios(
  Map<String, double> ratios,
  Map<String, double> reproducedRatios,
) =>
    !ratios.keys.any(
      (id) =>
          _ratioFor(ratios, id) > _printfKeyLimit &&
          _ratioFor(reproducedRatios, id) > _printfKeyLimit,
    );

int medianNanoseconds(Iterable<int> measurements) {
  final values = measurements.toList()..sort();
  if (values.isEmpty) {
    throw ArgumentError.value(
      measurements,
      'measurements',
      'Must not be empty.',
    );
  }
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) ~/ 2;
}

double geometricMean(Iterable<double> ratios) {
  final values = ratios.toList(growable: false);
  if (values.isEmpty || values.any((value) => !value.isFinite || value <= 0)) {
    throw ArgumentError.value(ratios, 'ratios', 'Must be finite and positive.');
  }
  return math.exp(
    values.fold<double>(0, (sum, value) => sum + math.log(value)) /
        values.length,
  );
}

final class GateReport {
  final bool passed;
  final String sourceRevision;
  final int aotExecutableSizeBytes;
  final List<DialectGate> gates;
  final List<BenchmarkReport> reports;

  const GateReport({
    required this.passed,
    required this.sourceRevision,
    required this.aotExecutableSizeBytes,
    required this.gates,
    required this.reports,
  });

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'passed': passed,
    'sourceRevision': sourceRevision,
    'aotExecutableSizeBytes': aotExecutableSizeBytes,
    'reports': reports.map(_reportSummary).toList(),
    'gates': gates.map((gate) => gate.toJson()).toList(),
  };
}

GateReport evaluateGateReports(Iterable<BenchmarkReport> input) {
  final reports = input.toList(growable: false);
  final byRuntime = <String, List<BenchmarkReport>>{};
  for (final report in reports) {
    _validateReport(report);
    (byRuntime[report.runtime] ??= []).add(report);
  }
  if (byRuntime.length != _requiredRuntimeDialects.length ||
      !byRuntime.keys.toSet().containsAll(_requiredRuntimeDialects.keys)) {
    throw const FormatException(
      'Reports must contain exactly JIT, AOT, and JavaScript runtime pairs.',
    );
  }

  final gates = <DialectGate>[];
  final sourceRevision = _sourceRevisionFor(reports);
  int? aotSize;
  for (final entry in _requiredRuntimeDialects.entries) {
    final pair = _validatePair(entry.key, byRuntime[entry.key]!, entry.value);
    if (entry.key == 'aot') {
      final sizes = pair.map((report) => report.executableSizeBytes).toSet();
      if (sizes.length != 1 || sizes.single == null) {
        throw const FormatException(
          'AOT reports must retain one matching executable size.',
        );
      }
      aotSize = sizes.single;
    }
    for (final dialect in entry.value) {
      gates.add(_evaluateDialect(entry.key, dialect, pair[0], pair[1]));
    }
  }
  return GateReport(
    passed: gates.every((gate) => gate.passed),
    sourceRevision: sourceRevision,
    aotExecutableSizeBytes: aotSize!,
    gates: List.unmodifiable(gates),
    reports: List.unmodifiable(reports),
  );
}

List<BenchmarkReport> _validatePair(
  String runtime,
  List<BenchmarkReport> reports,
  Set<BenchmarkDialect> expectedDialects,
) {
  if (reports.length != 2) {
    throw FormatException('$runtime requires exactly two reports.');
  }
  final byRun = {for (final report in reports) report.run: report};
  if (byRun.length != 2 || !byRun.keys.toSet().containsAll(const {1, 2})) {
    throw FormatException('$runtime reports must be independent runs 1 and 2.');
  }
  final first = byRun[1]!;
  final second = byRun[2]!;
  final firstDialects =
      first.scenarios.map((scenario) => scenario.dialect).toSet();
  final secondDialects =
      second.scenarios.map((scenario) => scenario.dialect).toSet();
  if (!_sameSet(firstDialects, expectedDialects) ||
      !_sameSet(secondDialects, expectedDialects)) {
    throw FormatException('$runtime reports have the wrong dialect coverage.');
  }
  if (first.recordedRounds != second.recordedRounds) {
    throw FormatException('$runtime reports have mismatched recorded rounds.');
  }
  if (!_sameStringMap(first.runtimeProvenance, second.runtimeProvenance)) {
    throw FormatException('$runtime reports have mismatched provenance.');
  }
  _validateScenarioMatrix(first, expectedDialects);
  _validateScenarioMatrix(second, expectedDialects);
  _validateMatchingScenarios(first, second);
  return [first, second];
}

void _validateReport(BenchmarkReport report) {
  if (report.smoke || !report.gateable) {
    throw FormatException(
      '${report.runtime} run ${report.run} is not gateable.',
    );
  }
  if (report.recordedRounds < 7) {
    throw FormatException(
      '${report.runtime} run ${report.run} has too few rounds.',
    );
  }
  if (!_requiredRuntimeDialects.containsKey(report.runtime)) {
    throw FormatException('Unknown benchmark runtime: ${report.runtime}.');
  }
  if (report.detectedRuntime != report.runtime) {
    throw FormatException(
      '${report.runtime} run ${report.run} has mismatched runtime provenance.',
    );
  }
  switch (report.runtime) {
    case 'jit':
      _requireProvenance(report, 'dart.vm.product', 'false');
    case 'aot':
      _requireProvenance(report, 'dart.vm.product', 'true');
    case 'js':
      if (report.runtimeProvenance['detector'] !=
          'dart2js.compile-time-define') {
        throw FormatException('js run ${report.run} lacks dart2js provenance.');
      }
      final compiler = report.runtimeProvenance['dartCompilerVersion'];
      if (compiler == null ||
          !RegExp(
            r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$',
          ).hasMatch(compiler)) {
        throw FormatException(
          'js run ${report.run} lacks a concrete Dart compiler version.',
        );
      }
      if (report.runtimeProvenance['nodeVersion'] != 'v24.8.0') {
        throw FormatException(
          'js run ${report.run} requires Node v24.8.0 provenance.',
        );
      }
  }
  final ids = <String>{};
  for (final scenario in report.scenarios) {
    if (!ids.add(scenario.scenarioId)) {
      throw FormatException('Duplicate scenario: ${scenario.scenarioId}.');
    }
    if (scenario.comparisonKind != BenchmarkComparisonKind.performance) {
      if (scenario.ratio != null) {
        throw ArgumentError('Only performance scenarios may have ratios.');
      }
      continue;
    }
    final candidate = scenario.candidateMedianNanoseconds;
    final baseline = scenario.baselineMedianNanoseconds;
    final ratio = scenario.ratio;
    if (candidate == null ||
        candidate <= 0 ||
        baseline == null ||
        baseline <= 0 ||
        ratio == null ||
        !ratio.isFinite ||
        ratio <= 0) {
      throw FormatException(
        '${scenario.scenarioId} has an invalid performance ratio.',
      );
    }
    final observedRatio = candidate / baseline;
    if ((ratio - observedRatio).abs() > 1e-12) {
      throw FormatException(
        '${scenario.scenarioId} ratio does not match absolute times.',
      );
    }
    _validateSamples(report, scenario);
  }
}

String _sourceRevisionFor(List<BenchmarkReport> reports) {
  final revisions = reports.map((report) => report.sourceRevision).toSet();
  if (revisions.length != 1 ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(revisions.single)) {
    throw const FormatException(
      'Gateable reports require one canonical full source revision.',
    );
  }
  return revisions.single;
}

void _requireProvenance(BenchmarkReport report, String detector, String value) {
  if (report.runtimeProvenance['detector'] != detector ||
      report.runtimeProvenance['value'] != value) {
    throw FormatException(
      '${report.runtime} run ${report.run} has invalid runtime provenance.',
    );
  }
}

bool _sameStringMap(Map<String, String> first, Map<String, String> second) =>
    first.length == second.length &&
    first.entries.every((entry) => second[entry.key] == entry.value);

void _validateSamples(
  BenchmarkReport report,
  BenchmarkScenarioResult scenario,
) {
  for (final engine in const ['candidate', 'baseline']) {
    final samples = report.samples
        .where(
          (sample) =>
              sample.scenarioId == scenario.scenarioId &&
              sample.engine == engine,
        )
        .toList(growable: false);
    if (samples.length != report.recordedRounds ||
        samples.any(
          (sample) => sample.operations < 1 || sample.elapsedNanoseconds < 1,
        ) ||
        samples.map((sample) => sample.round).toSet().length !=
            report.recordedRounds ||
        !samples
            .map((sample) => sample.round)
            .toSet()
            .containsAll(
              List.generate(report.recordedRounds, (round) => round),
            )) {
      throw FormatException(
        '${scenario.scenarioId} lacks ${report.recordedRounds} interleaved '
        '$engine samples.',
      );
    }
    final median = medianNanoseconds(
      samples.map((sample) => sample.elapsedNanoseconds),
    );
    final reported =
        engine == 'candidate'
            ? scenario.candidateMedianNanoseconds
            : scenario.baselineMedianNanoseconds;
    if (median != reported) {
      throw FormatException(
        '${scenario.scenarioId} $engine median differs from raw samples.',
      );
    }
  }
}

void _validateScenarioMatrix(
  BenchmarkReport report,
  Set<BenchmarkDialect> dialects,
) {
  final expected = benchmarkScenarios
      .where((scenario) => dialects.contains(scenario.dialect))
      .toList(growable: false);
  final actual = {
    for (final scenario in report.scenarios) scenario.scenarioId: scenario,
  };
  if (actual.length != expected.length ||
      !actual.keys.toSet().containsAll(
        expected.map((scenario) => scenario.id),
      )) {
    throw FormatException(
      '${report.runtime} run ${report.run} omits benchmark scenarios.',
    );
  }
  for (final scenario in expected) {
    final result = actual[scenario.id]!;
    if (result.dialect != scenario.dialect ||
        result.phase != scenario.phase ||
        result.keyScenario != scenario.keyScenario ||
        result.comparisonKind != scenario.comparisonKind) {
      throw FormatException(
        '${scenario.id} metadata differs from the benchmark matrix.',
      );
    }
  }
}

void _validateMatchingScenarios(BenchmarkReport first, BenchmarkReport second) {
  final firstById = {
    for (final scenario in first.scenarios) scenario.scenarioId: scenario,
  };
  final secondById = {
    for (final scenario in second.scenarios) scenario.scenarioId: scenario,
  };
  if (!_sameSet(firstById.keys.toSet(), secondById.keys.toSet())) {
    throw FormatException(
      '${first.runtime} runs do not cover matching scenarios.',
    );
  }
  for (final id in firstById.keys) {
    final one = firstById[id]!;
    final two = secondById[id]!;
    if (one.dialect != two.dialect ||
        one.phase != two.phase ||
        one.keyScenario != two.keyScenario ||
        one.comparisonKind != two.comparisonKind) {
      throw FormatException('$id differs between run 1 and run 2.');
    }
  }
}

DialectGate _evaluateDialect(
  String runtime,
  BenchmarkDialect dialect,
  BenchmarkReport first,
  BenchmarkReport second,
) {
  final one = _performanceById(first, dialect);
  final two = _performanceById(second, dialect);
  if (one.isEmpty) {
    throw FormatException(
      '$runtime ${dialect.name} has no performance scenarios.',
    );
  }
  return switch (dialect) {
    BenchmarkDialect.braces => _evaluateBraces(runtime, one, two),
    BenchmarkDialect.printf => _evaluatePrintf(runtime, one, two),
  };
}

DialectGate _evaluateBraces(
  String runtime,
  Map<String, BenchmarkScenarioResult> first,
  Map<String, BenchmarkScenarioResult> second,
) {
  final hot = {
    for (final entry in first.entries)
      if (entry.value.phase == BenchmarkPhase.hot) entry.key,
  };
  final keys = {
    for (final entry in first.entries)
      if (entry.value.keyScenario) entry.key,
  };
  final result = evaluateBraceGates(
    ratios: _ratios(first),
    hotScenarioIds: hot,
    keyScenarioIds: keys,
    reproducedRatios: _ratios(second),
  );
  final failures = <GateFailure>[];
  if (!result.geometricMeanPassed) {
    failures.add(
      GateFailure(
        kind: 'geometricMean',
        phase: BenchmarkPhase.hot,
        threshold: _braceHotMeanLimit,
        run1: result.geometricMean,
        run2: result.reproducedGeometricMean,
      ),
    );
  }
  for (final id in result.reproducedKeyFailures) {
    failures.add(
      GateFailure(
        kind: 'keyScenario',
        scenarioId: id,
        phase: first[id]!.phase,
        threshold: _braceKeyLimit,
        run1: first[id]!.ratio!,
        run2: second[id]!.ratio!,
      ),
    );
  }
  return DialectGate(
    runtime: runtime,
    dialect: BenchmarkDialect.braces,
    passed: result.passed,
    metrics: {
      'hotGeometricMean': {
        'threshold': _braceHotMeanLimit,
        'run1': result.geometricMean,
        'run2': result.reproducedGeometricMean,
      },
      'keyScenarioLimit': _braceKeyLimit,
    },
    scenarios: _scenarioEvidence(first, second),
    failures: failures,
  );
}

DialectGate _evaluatePrintf(
  String runtime,
  Map<String, BenchmarkScenarioResult> first,
  Map<String, BenchmarkScenarioResult> second,
) {
  final failures = <GateFailure>[];
  final metrics = <String, Object?>{'keyScenarioLimit': _printfKeyLimit};
  for (final phase in BenchmarkPhase.values) {
    final ids = {
      for (final entry in first.entries)
        if (entry.value.phase == phase) entry.key,
    };
    final firstMean = geometricMean(_valuesFor(_ratios(first), ids));
    final secondMean = geometricMean(_valuesFor(_ratios(second), ids));
    final passed =
        evaluatePrintfMean(phase, firstMean) ||
        evaluatePrintfMean(phase, secondMean);
    metrics['${phase.name}GeometricMean'] = {
      'threshold':
          phase == BenchmarkPhase.cold
              ? _printfColdMeanLimit
              : _printfHotMeanLimit,
      'run1': firstMean,
      'run2': secondMean,
    };
    if (!passed) {
      failures.add(
        GateFailure(
          kind: 'geometricMean',
          phase: phase,
          threshold:
              phase == BenchmarkPhase.cold
                  ? _printfColdMeanLimit
                  : _printfHotMeanLimit,
          run1: firstMean,
          run2: secondMean,
        ),
      );
    }
  }
  final keys = {
    for (final entry in first.entries)
      if (entry.value.keyScenario) entry.key,
  };
  if (!evaluatePrintfKeyScenarios(
    _ratios(first, keys),
    _ratios(second, keys),
  )) {
    for (final id in keys) {
      if (first[id]!.ratio! > _printfKeyLimit &&
          second[id]!.ratio! > _printfKeyLimit) {
        failures.add(
          GateFailure(
            kind: 'keyScenario',
            scenarioId: id,
            phase: first[id]!.phase,
            threshold: _printfKeyLimit,
            run1: first[id]!.ratio!,
            run2: second[id]!.ratio!,
          ),
        );
      }
    }
  }
  return DialectGate(
    runtime: runtime,
    dialect: BenchmarkDialect.printf,
    passed: failures.isEmpty,
    metrics: metrics,
    scenarios: _scenarioEvidence(first, second),
    failures: failures,
  );
}

Map<String, BenchmarkScenarioResult> _performanceById(
  BenchmarkReport report,
  BenchmarkDialect dialect,
) => {
  for (final scenario in report.scenarios)
    if (scenario.dialect == dialect &&
        scenario.comparisonKind == BenchmarkComparisonKind.performance)
      scenario.scenarioId: scenario,
};

Map<String, double> _ratios(
  Map<String, BenchmarkScenarioResult> scenarios, [
  Set<String>? only,
]) => {
  for (final entry in scenarios.entries)
    if (only == null || only.contains(entry.key)) entry.key: entry.value.ratio!,
};

List<Map<String, Object?>> _scenarioEvidence(
  Map<String, BenchmarkScenarioResult> first,
  Map<String, BenchmarkScenarioResult> second,
) => [
  for (final id in (first.keys.toList()..sort()))
    {
      'scenarioId': id,
      'phase': first[id]!.phase.name,
      'keyScenario': first[id]!.keyScenario,
      'candidateMedianNanoseconds': [
        first[id]!.candidateMedianNanoseconds,
        second[id]!.candidateMedianNanoseconds,
      ],
      'baselineMedianNanoseconds': [
        first[id]!.baselineMedianNanoseconds,
        second[id]!.baselineMedianNanoseconds,
      ],
      'ratios': [first[id]!.ratio, second[id]!.ratio],
    },
];

List<double> _valuesFor(Map<String, double> ratios, Set<String> ids) => [
  for (final id in ids) _ratioFor(ratios, id),
];

double _ratioFor(Map<String, double> ratios, String id) {
  final value = ratios[id];
  if (value == null || !value.isFinite || value <= 0) {
    throw FormatException('Missing or invalid ratio for $id.');
  }
  return value;
}

bool _sameSet<T>(Set<T> first, Set<T> second) =>
    first.length == second.length && first.containsAll(second);

Map<String, Object?> _reportSummary(BenchmarkReport report) => {
  'runtime': report.runtime,
  'detectedRuntime': report.detectedRuntime,
  'runtimeProvenance': report.runtimeProvenance,
  'sourceRevision': report.sourceRevision,
  'run': report.run,
  'versions': report.versions,
  'smoke': report.smoke,
  'gateable': report.gateable,
  'warmupRounds': report.warmupRounds,
  'recordedRounds': report.recordedRounds,
  'executableSizeBytes': report.executableSizeBytes,
};

final class DialectGate {
  final String runtime;
  final BenchmarkDialect dialect;
  final bool passed;
  final Map<String, Object?> metrics;
  final List<Map<String, Object?>> scenarios;
  final List<GateFailure> failures;

  const DialectGate({
    required this.runtime,
    required this.dialect,
    required this.passed,
    required this.metrics,
    required this.scenarios,
    required this.failures,
  });

  Map<String, Object?> toJson() => {
    'runtime': runtime,
    'dialect': dialect.name,
    'passed': passed,
    'metrics': metrics,
    'scenarios': scenarios,
    'failures': failures.map((failure) => failure.toJson()).toList(),
  };
}

final class GateFailure {
  final String kind;
  final String? scenarioId;
  final BenchmarkPhase? phase;
  final double threshold;
  final double run1;
  final double run2;

  const GateFailure({
    required this.kind,
    this.scenarioId,
    this.phase,
    required this.threshold,
    required this.run1,
    required this.run2,
  });

  Map<String, Object?> toJson() => {
    'kind': kind,
    'scenarioId': scenarioId,
    'phase': phase?.name,
    'threshold': threshold,
    'run1': run1,
    'run2': run2,
    'reproduced': true,
  };
}

void main(List<String> arguments) {
  try {
    final reports = _parseReports(arguments);
    final result = evaluateGateReports(reports);
    final output = _outputPath(arguments);
    final encoded =
        '${const JsonEncoder.withIndent('  ').convert(result.toJson())}\n';
    if (output == null) {
      stdout.write(encoded);
    } else {
      File(output).writeAsStringSync(encoded);
    }
    if (!result.passed) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

List<BenchmarkReport> _parseReports(List<String> arguments) {
  final paths = _reportsArgument(arguments);
  return [
    for (final path in paths)
      BenchmarkReport.fromJson(
        Map<String, Object?>.from(
          jsonDecode(File(path).readAsStringSync()) as Map,
        ),
      ),
  ];
}

List<String> _reportsArgument(List<String> arguments) {
  final value = arguments
      .where((argument) => argument.startsWith('--reports='))
      .map((argument) => argument.substring('--reports='.length))
      .toList(growable: false);
  if (value.length != 1 || value.single.isEmpty) {
    throw const FormatException('Expected one --reports=PATH,PATH argument.');
  }
  final paths = value.single.split(',');
  if (paths.any((path) => path.isEmpty)) {
    throw const FormatException('Report paths must not be empty.');
  }
  return paths;
}

String? _outputPath(List<String> arguments) {
  final output = arguments
      .where((argument) => argument.startsWith('--output='))
      .map((argument) => argument.substring('--output='.length))
      .toList(growable: false);
  if (output.length > 1 || output.any((value) => value.isEmpty)) {
    throw const FormatException('--output may be supplied once with a path.');
  }
  final recognized = arguments.every(
    (argument) =>
        argument.startsWith('--reports=') || argument.startsWith('--output='),
  );
  if (!recognized) throw const FormatException('Unknown gates argument.');
  return output.isEmpty ? null : output.single;
}
