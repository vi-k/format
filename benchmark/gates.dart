import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'model.dart';
import 'scenarios.dart';

// The gate compares this build against a recorded measurement of an earlier
// build of this package, not against a fixed number.
//
// A single set of constants cannot serve every runtime: measured against the
// same frozen comparators, the candidate's ratios differ by an order of
// magnitude between the VM and dart2js, so any constant tight enough to mean
// something on the VM fires immediately on JavaScript. Ratios, on the other
// hand, are measured candidate-against-comparator in one process, which makes
// them portable across machines in a way absolute times are not — so a
// recorded ratio is a usable reference, and drift away from it is a
// regression regardless of runtime.
//
// The recorded numbers are a statement of fact, not of approval: where a
// runtime is known to be slow today, the baseline says so, and the gate then
// keeps it from getting worse.
//
// The tolerances have to cover the shared runner a nightly job lands on, and
// that is a wider spread than the two runs inside one job suggest. Requiring
// both runs to breach protects against noise within a job, but both runs
// share a machine, so it does nothing about the difference between the job
// that recorded the reference and the job that checks it. One such comparison
// measured a phase mean moving 14.3% with no change in the code — verified by
// an A/B of the same two revisions on one machine, where the same figure was
// 1%. Set from that single observation, so worth revisiting once a run of
// nightlies gives a real distribution.
//
// A regression worth failing a release over is large: the ones this package's
// review turned up ran from 3x to 8x. Tolerances that admit a quarter keep
// catching those while leaving the gate believable.
const double _meanTolerance = 1.25;
const double _scenarioTolerance = 1.60;
const double _keyScenarioTolerance = 1.35;

const Map<String, Set<BenchmarkDialect>> _requiredRuntimeDialects = {
  'jit': {BenchmarkDialect.braces, BenchmarkDialect.printf},
  'aot': {BenchmarkDialect.braces, BenchmarkDialect.printf},
  // Braces run under dart2js like any other dialect; leaving them out here
  // would hide the runtime where they cost the most.
  'js': {BenchmarkDialect.braces, BenchmarkDialect.printf},
};

/// The recorded per-scenario and per-phase ratios an evaluation compares
/// against, keyed `runtime/dialect` and, within that, by phase name and by
/// scenario id.
final class GateBaseline {
  final String sourceRevision;
  final String recordedAt;
  final Map<String, Map<String, double>> phaseMeans;
  final Map<String, Map<String, double>> scenarioRatios;

  const GateBaseline({
    required this.sourceRevision,
    required this.recordedAt,
    required this.phaseMeans,
    required this.scenarioRatios,
  });

  static String keyFor(String runtime, BenchmarkDialect dialect) =>
      '$runtime/${dialect.name}';

  factory GateBaseline.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported gate baseline schema.');
    }
    Map<String, Map<String, double>> read(String field) => {
      for (final entry in (json[field]! as Map).entries)
        entry.key as String: {
          for (final inner in (entry.value as Map).entries)
            inner.key as String: (inner.value as num).toDouble(),
        },
    };

    return GateBaseline(
      sourceRevision: json['sourceRevision']! as String,
      recordedAt: json['recordedAt']! as String,
      phaseMeans: read('phaseMeans'),
      scenarioRatios: read('scenarioRatios'),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'sourceRevision': sourceRevision,
    'recordedAt': recordedAt,
    'phaseMeans': phaseMeans,
    'scenarioRatios': scenarioRatios,
  };

  double phaseMean(String key, BenchmarkPhase phase) =>
      _require(phaseMeans[key]?[phase.name], '$key ${phase.name} mean');

  double scenarioRatio(String key, String scenarioId) =>
      _require(scenarioRatios[key]?[scenarioId], '$key $scenarioId');

  static double _require(double? value, String what) {
    if (value == null || !value.isFinite || value <= 0) {
      throw FormatException(
        'The gate baseline has no usable entry for $what. Re-record it '
        'after changing the benchmark matrix.',
      );
    }

    return value;
  }
}

/// The tolerated ratio for one recorded reference value.
double gateLimitFor(double baselineRatio, {required bool keyScenario}) =>
    baselineRatio * (keyScenario ? _keyScenarioTolerance : _scenarioTolerance);

/// The tolerated ratio for a recorded phase geometric mean.
double gateMeanLimitFor(double baselineMean) => baselineMean * _meanTolerance;

/// Whether a measurement clears its recorded reference.
///
/// A single run never decides: a limit counts as breached only when both
/// independent runs breach it, which is what keeps a noisy sample from
/// failing a release on its own.
bool clearsGate(double run1, double run2, double limit) =>
    !(run1 > limit && run2 > limit);

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

GateReport evaluateGateReports(
  Iterable<BenchmarkReport> input,
  GateBaseline baseline,
) {
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
      gates.add(
        _evaluateDialect(entry.key, dialect, pair[0], pair[1], baseline),
      );
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
    final candidate = scenario.candidateNanosecondsPerOperation;
    final baseline = scenario.baselineNanosecondsPerOperation;
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
    // Per operation: the engines are timed to a duration, so their operation
    // counts differ and the medians alone do not reconstruct the ratio.
    final observedRatio = candidate / baseline;
    if ((ratio - observedRatio).abs() > 1e-9 * ratio) {
      throw FormatException(
        '${scenario.scenarioId} ratio does not match its measured times.',
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
    // The ratio is read per operation, so a count that disagrees with the
    // samples it claims to describe would silently rescale the comparison.
    final operations =
        engine == 'candidate'
            ? scenario.candidateOperations
            : scenario.baselineOperations;
    if (samples.any((sample) => sample.operations != operations)) {
      throw FormatException(
        '${scenario.scenarioId} $engine operations differ from raw samples.',
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
  GateBaseline baseline,
) {
  final one = _performanceById(first, dialect);
  final two = _performanceById(second, dialect);
  if (one.isEmpty) {
    throw FormatException(
      '$runtime ${dialect.name} has no performance scenarios.',
    );
  }

  return _evaluateDialectAgainst(runtime, dialect, one, two, baseline);
}

DialectGate _evaluateDialectAgainst(
  String runtime,
  BenchmarkDialect dialect,
  Map<String, BenchmarkScenarioResult> first,
  Map<String, BenchmarkScenarioResult> second,
  GateBaseline baseline,
) {
  final key = GateBaseline.keyFor(runtime, dialect);
  final failures = <GateFailure>[];
  final metrics = <String, Object?>{
    'meanTolerance': _meanTolerance,
    'scenarioTolerance': _scenarioTolerance,
    'keyScenarioTolerance': _keyScenarioTolerance,
  };

  for (final phase in BenchmarkPhase.values) {
    final ids = {
      for (final entry in first.entries)
        if (entry.value.phase == phase) entry.key,
    };
    if (ids.isEmpty) continue;
    final run1 = geometricMean(_valuesFor(_ratios(first), ids));
    final run2 = geometricMean(_valuesFor(_ratios(second), ids));
    final recorded = baseline.phaseMean(key, phase);
    final limit = gateMeanLimitFor(recorded);
    metrics['${phase.name}GeometricMean'] = {
      'baseline': recorded,
      'threshold': limit,
      'run1': run1,
      'run2': run2,
    };
    if (!clearsGate(run1, run2, limit)) {
      failures.add(
        GateFailure(
          kind: 'geometricMean',
          phase: phase,
          threshold: limit,
          run1: run1,
          run2: run2,
        ),
      );
    }
  }

  for (final id in first.keys.toList()..sort()) {
    final scenario = first[id]!;
    final limit = gateLimitFor(
      baseline.scenarioRatio(key, id),
      keyScenario: scenario.keyScenario,
    );
    final run1 = scenario.ratio!;
    final run2 = second[id]!.ratio!;
    if (!clearsGate(run1, run2, limit)) {
      failures.add(
        GateFailure(
          kind: scenario.keyScenario ? 'keyScenario' : 'scenario',
          scenarioId: id,
          phase: scenario.phase,
          threshold: limit,
          run1: run1,
          run2: run2,
        ),
      );
    }
  }

  return DialectGate(
    runtime: runtime,
    dialect: dialect,
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

/// Derives a reference from a full, validated set of reports.
///
/// Each recorded value is the geometric mean of the two independent runs, so
/// a single noisy run cannot set the reference on its own.
GateBaseline recordGateBaseline(
  Iterable<BenchmarkReport> input,
  String recordedAt,
) {
  final reports = input.toList(growable: false);
  final byRuntime = <String, List<BenchmarkReport>>{};
  for (final report in reports) {
    _validateReport(report);
    (byRuntime[report.runtime] ??= []).add(report);
  }
  final phaseMeans = <String, Map<String, double>>{};
  final scenarioRatios = <String, Map<String, double>>{};
  for (final entry in _requiredRuntimeDialects.entries) {
    final pair = _validatePair(
      entry.key,
      byRuntime[entry.key] ?? const [],
      entry.value,
    );
    for (final dialect in entry.value) {
      final key = GateBaseline.keyFor(entry.key, dialect);
      final first = _performanceById(pair[0], dialect);
      final second = _performanceById(pair[1], dialect);
      scenarioRatios[key] = {
        for (final id in first.keys.toList()..sort())
          id: geometricMean([first[id]!.ratio!, second[id]!.ratio!]),
      };
      phaseMeans[key] = {
        for (final phase in BenchmarkPhase.values)
          if (first.values.any((scenario) => scenario.phase == phase))
            phase.name: geometricMean([
              geometricMean(
                _valuesFor(_ratios(first), {
                  for (final e in first.entries)
                    if (e.value.phase == phase) e.key,
                }),
              ),
              geometricMean(
                _valuesFor(_ratios(second), {
                  for (final e in second.entries)
                    if (e.value.phase == phase) e.key,
                }),
              ),
            ]),
      };
    }
  }

  return GateBaseline(
    sourceRevision: _sourceRevisionFor(reports),
    recordedAt: recordedAt,
    phaseMeans: phaseMeans,
    scenarioRatios: scenarioRatios,
  );
}

/// What the checkout disagrees with the reports about, or null when it does
/// not disagree.
///
/// The revision a report carries is supplied from outside — the JavaScript
/// runtime cannot ask git, so the shell that starts a measurement passes the
/// same `-D` define to all three runtimes. Checking that the reports agree
/// with each other, which is what the gate already did, therefore proves only
/// that one define reached three processes. It says nothing about whether that
/// define was the source those processes actually ran.
///
/// [modifiedTrackedFiles] must come from a status that ignores untracked
/// files. A measurement writes its reports, its AOT executable and its
/// compiled JavaScript into the working directory, so "no untracked files"
/// is never true by the time the gate runs — and demanding it would make this
/// check fail always, which is the same as not having it.
///
/// Separate from running git so the rules can be tested without a repository.
String? checkoutObjection({
  required String revision,
  required String head,
  required String modifiedTrackedFiles,
}) {
  if (head != revision) {
    return 'Reports name source revision $revision, but HEAD is $head. '
        'The measurement did not run on the source it claims.';
  }
  final modified =
      modifiedTrackedFiles
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
  if (modified.isNotEmpty) {
    return 'HEAD is $revision, but ${modified.length} tracked '
        '${modified.length == 1 ? 'file is' : 'files are'} modified: '
        '${modified.join('; ')}. The measured source is not that revision.';
  }

  return null;
}

/// [checkoutObjection] against the checkout this process runs in, or null when
/// there is no checkout to ask.
///
/// An unpacked archive is not a repository and a gate that refused to run
/// there would be worse than one that cannot verify; the caller says out loud
/// which of the two happened.
String? _checkoutObjection(String revision) {
  final head = _git(['rev-parse', 'HEAD']);
  final status = _git(['status', '--porcelain', '--untracked-files=no']);
  if (head == null || status == null) return null;

  return checkoutObjection(
    revision: revision,
    head: head.trim(),
    modifiedTrackedFiles: status,
  );
}

String? _git(List<String> arguments) {
  final ProcessResult result;
  try {
    result = Process.runSync('git', arguments);
  } on ProcessException {
    return null;
  }

  return result.exitCode == 0 ? result.stdout as String : null;
}

void main(List<String> arguments) {
  try {
    final reports = _parseReports(arguments);
    final output = _outputPath(arguments);
    final record = _recordArgument(arguments);
    _verifyRevision(reports, arguments);
    final Map<String, Object?> json;
    var passed = true;
    if (record != null) {
      json = recordGateBaseline(reports, record).toJson();
    } else {
      final result = evaluateGateReports(
        reports,
        _loadBaseline(_baselineArgument(arguments)),
      );
      json = result.toJson();
      passed = result.passed;
    }
    final encoded = '${const JsonEncoder.withIndent('  ').convert(json)}\n';
    if (output == null) {
      stdout.write(encoded);
    } else {
      File(output).writeAsStringSync(encoded);
    }
    if (!passed) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

/// Refuses to evaluate or record reports whose revision the checkout
/// contradicts.
///
/// Recording is the case that matters most: a reference recorded from a dirty
/// tree becomes the number every later run is measured against, and nothing
/// downstream can tell that it was never the revision it names.
void _verifyRevision(List<BenchmarkReport> reports, List<String> arguments) {
  if (arguments.contains(_allowUnverifiedRevision)) return;
  final revisions = reports.map((report) => report.sourceRevision).toSet();
  if (revisions.length != 1) return; // the evaluator reports this properly
  final objection = _checkoutObjection(revisions.single);
  if (objection == null) return;

  throw FormatException(
    '$objection Commit or stash first and measure again, or pass '
    '$_allowUnverifiedRevision to evaluate reports recorded elsewhere.',
  );
}

const _allowUnverifiedRevision = '--allow-unverified-revision';

GateBaseline _loadBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FormatException(
      'No recorded reference at $path. Record one with --record=YYYY-MM-DD '
      'from a full set of reports; see benchmark/results/README.md.',
    );
  }

  return GateBaseline.fromJson(
    // `from`, not `of`: jsonDecode yields Map<dynamic, dynamic>, so this is a
    // real conversion rather than a copy of an already-typed map.
    Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map),
  );
}

List<BenchmarkReport> _parseReports(List<String> arguments) {
  final paths = _reportsArgument(arguments);
  return [
    for (final path in paths)
      BenchmarkReport.fromJson(
        // `from` for the same reason as above: the decoded map is untyped.
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
  final output = _optional(arguments, '--output=');
  if (output.length > 1) {
    throw const FormatException('--output may be supplied once with a path.');
  }
  const recognized = [
    '--reports=',
    '--output=',
    '--baseline=',
    '--record=',
    _allowUnverifiedRevision,
  ];
  if (!arguments.every((argument) => recognized.any(argument.startsWith))) {
    throw const FormatException('Unknown gates argument.');
  }

  return output.isEmpty ? null : output.single;
}

String _baselineArgument(List<String> arguments) {
  final value = _optional(arguments, '--baseline=');
  if (value.length != 1) {
    throw const FormatException(
      'Expected one --baseline=PATH argument, or --record=DATE to write one.',
    );
  }

  return value.single;
}

/// The `--record=DATE` value, or null when the run evaluates instead.
///
/// The date is supplied rather than read from the clock so that recording is
/// reproducible and the recorded file says when the measurement was taken.
String? _recordArgument(List<String> arguments) {
  final value = _optional(arguments, '--record=');
  if (value.length > 1) {
    throw const FormatException('--record may be supplied once with a date.');
  }
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.single)) {
    throw const FormatException('--record expects an ISO YYYY-MM-DD date.');
  }

  return value.single;
}

List<String> _optional(List<String> arguments, String prefix) {
  final values = arguments
      .where((argument) => argument.startsWith(prefix))
      .map((argument) => argument.substring(prefix.length))
      .toList(growable: false);
  if (values.any((value) => value.isEmpty)) {
    throw FormatException('$prefix requires a value.');
  }

  return values;
}
