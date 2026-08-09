/// The performance gate's own logic, tested as ordinary code.
///
/// The gate decides whether a change may land, from benchmark reports produced
/// on CI. That makes it a piece of software with two ways to fail, and both are
/// expensive: passing a real regression, or failing an innocent change often
/// enough that people learn to override it. Neither can be discovered by
/// running it — a green gate looks the same whether it is working or asleep.
///
/// So none of these tests measure anything. They build reports in memory, feed
/// them to the same functions the gate uses, and assert the decision: the
/// tolerance arithmetic, the rule that a scenario must breach in *both* runs
/// before it counts, and the provenance checks that make a report admissible at
/// all — right runtime, right Node version, one source revision across every
/// report, no smoke runs, no shortened ones.
///
/// The provenance half is the larger one, and deliberately so. A wrong number
/// compared correctly is worse than no gate: reports from two different builds,
/// or from a JIT run mislabelled as AOT, produce ratios that mean nothing while
/// looking exactly like ratios that mean something.
///
/// The last two tests run the command end to end in a temporary directory, on a
/// build that did not change and one that regressed, so the wiring between the
/// pieces above is checked as well as the pieces.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../gates.dart';
import '../model.dart';
import '../scenarios.dart';

void main() {
  // The arithmetic itself, at three tolerance levels — the tighter a scenario's
  // classification, the less it may drift. The last expectation states the
  // ordering as a property rather than as three separate numbers, so a
  // reshuffle of the constants cannot invert it.
  test('limits are the recorded reference times a tolerance', () {
    // A key scenario is held to a tighter tolerance than an ordinary one,
    // and an aggregate to the tightest of the three.
    expect(gateLimitFor(0.20, keyScenario: false), closeTo(0.32, 1e-12));
    expect(gateLimitFor(0.20, keyScenario: true), closeTo(0.27, 1e-12));
    expect(gateMeanLimitFor(0.20), closeTo(0.25, 1e-12));
    expect(
      gateLimitFor(0.20, keyScenario: true),
      lessThan(gateLimitFor(0.20, keyScenario: false)),
    );
  });

  // Two runs are taken per configuration precisely so that a single noisy one
  // cannot fail the build: a breach counts only when both runs breach. This is
  // the rule that keeps the gate credible enough to be obeyed.
  test('a limit is breached only when both runs breach it', () {
    expect(clearsGate(0.10, 0.10, 0.20), isTrue);
    expect(
      clearsGate(0.20, 0.20, 0.20),
      isTrue,
      reason: 'exactly at the limit',
    );
    expect(clearsGate(0.21, 0.10, 0.20), isTrue, reason: 'one run only');
    expect(clearsGate(0.10, 0.21, 0.20), isTrue, reason: 'the other run only');
    expect(clearsGate(0.21, 0.21, 0.20), isFalse);
  });

  // The baseline is a file that outlives the process that wrote it, so it has
  // to survive a write-and-read cycle unchanged — and a file missing a scenario
  // must be rejected rather than treated as "nothing to compare", which would
  // silently exempt whatever was dropped.
  test('a recorded baseline survives a round trip and rejects gaps', () {
    final baseline = recordGateBaseline(_completeReports(), '2026-01-01');
    final restored = GateBaseline.fromJson(
      // `from`, not `of`: a decoded map is Map<dynamic, dynamic>.
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(baseline.toJson())) as Map,
      ),
    );

    expect(restored.recordedAt, '2026-01-01');
    expect(restored.sourceRevision, baseline.sourceRevision);
    final key = GateBaseline.keyFor('jit', BenchmarkDialect.braces);
    expect(restored.phaseMean(key, BenchmarkPhase.hot), closeTo(1.0, 1e-12));
    // A matrix that grew since the reference was taken must say so instead
    // of silently gating nothing.
    expect(
      () => restored.scenarioRatio(key, 'brace.invented.hot'),
      throwsFormatException,
    );
  });

  // The two summary statistics, pinned because the choice is not arbitrary: the
  // median is taken over sorted integer nanoseconds (no floating drift, no
  // dependence on sample order), and the aggregate is a geometric mean, since
  // the values being combined are ratios.
  test('median uses sorted integer nanoseconds and mean is geometric', () {
    expect(medianNanoseconds(const [10, 1, 3]), 3);
    expect(medianNanoseconds(const [10, 1, 3, 9]), 6);
    expect(geometricMean(const [0.5, 2]), closeTo(1, 1e-12));
  });

  // The happy path, stated as a requirement: exactly two runs, complete, and
  // agreeing on their provenance. Everything below is a way of falling short of
  // this.
  test('merged gates accept exactly two complete reproducible runs', () {
    final result = evaluateGateReports(_completeReports(), _baseline());

    expect(result.passed, isTrue);
    expect(result.toJson()['aotExecutableSizeBytes'], 123456);
    expect(result.toJson()['gates'], hasLength(6));
  });

  // A report that does not say what it ran on, or two reports that disagree,
  // cannot be compared: the ratio would be between different machines. Rejected
  // rather than merged.
  test('gates reject absent or mismatched runtime provenance', () {
    final mismatched = _completeReports();
    final jit = mismatched.indexWhere((report) => report.runtime == 'jit');
    mismatched[jit] = _copyReport(mismatched[jit], detectedRuntime: 'aot');
    expect(
      () => evaluateGateReports(mismatched, _baseline()),
      throwsFormatException,
    );

    final missingCompiler = _completeReports();
    final js = missingCompiler.indexWhere((report) => report.runtime == 'js');
    missingCompiler[js] = _copyReport(
      missingCompiler[js],
      runtimeProvenance: const {
        'detector': 'dart2js.compile-time-define',
        'dartCompilerVersion': 'unavailable',
      },
    );
    expect(
      () => evaluateGateReports(missingCompiler, _baseline()),
      throwsFormatException,
    );
  });

  // The two provenance facts that decide whether numbers are comparable at all:
  // a pinned Node version — JavaScript performance moves between releases, so
  // an upgrade invalidates the baseline rather than beating it — and a single
  // source revision across every report, which is what stops two different
  // builds from being compared to each other.
  test('gates require Node 24.8.0 and one canonical source revision', () {
    final wrongNode = _completeReports();
    final js = wrongNode.indexWhere((report) => report.runtime == 'js');
    wrongNode[js] = _copyReport(
      wrongNode[js],
      runtimeProvenance: const {
        'detector': 'dart2js.compile-time-define',
        'dartCompilerVersion': '3.12.2',
        'nodeVersion': 'v26.5.0',
      },
    );
    expect(
      () => evaluateGateReports(wrongNode, _baseline()),
      throwsFormatException,
    );

    final mismatchedCompiler = _completeReports();
    final secondJs = mismatchedCompiler.lastIndexWhere(
      (report) => report.runtime == 'js',
    );
    mismatchedCompiler[secondJs] = _copyReport(
      mismatchedCompiler[secondJs],
      runtimeProvenance: const {
        'detector': 'dart2js.compile-time-define',
        'dartCompilerVersion': '3.12.3',
        'nodeVersion': 'v24.8.0',
      },
    );
    expect(
      () => evaluateGateReports(mismatchedCompiler, _baseline()),
      throwsFormatException,
    );

    final missing = _completeReports();
    missing[0] = _copyReport(missing[0], sourceRevision: '');
    expect(
      () => evaluateGateReports(missing, _baseline()),
      throwsFormatException,
    );

    final malformed = _completeReports();
    malformed[0] = _copyReport(malformed[0], sourceRevision: 'not-a-sha');
    expect(
      () => evaluateGateReports(malformed, _baseline()),
      throwsFormatException,
    );

    final mismatched = _completeReports();
    mismatched[0] = _copyReport(
      mismatched[0],
      sourceRevision: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(
      () => evaluateGateReports(mismatched, _baseline()),
      throwsFormatException,
    );
  });

  // The four ways a report can be well-formed and still inadmissible: it was a
  // smoke run, it declared itself non-gateable, it was cut short, or it does
  // not match its partner. Each is silently plausible — the numbers look like
  // numbers — which is why each is refused explicitly.
  test(
    'merged gates reject smoke, non-gateable, short, and mismatched runs',
    () {
      final smoke = _completeReports();
      smoke[0] = _copyReport(smoke[0], smoke: true, gateable: false);
      expect(
        () => evaluateGateReports(smoke, _baseline()),
        throwsFormatException,
      );

      final nonGateable = _completeReports();
      nonGateable[0] = _copyReport(nonGateable[0], gateable: false);
      expect(
        () => evaluateGateReports(nonGateable, _baseline()),
        throwsFormatException,
      );

      final short = _completeReports();
      expect(
        () => short[0] = _copyReport(short[0], recordedRounds: 6),
        throwsArgumentError,
      );

      final mismatchedDialect = _completeReports();
      mismatchedDialect[1] = _report(
        runtime: 'jit',
        run: 2,
        scenarios: [
          _scenarioFor(
            benchmarkScenarios.firstWhere(
              (scenario) => scenario.id == 'brace.double.general.hot',
            ),
          ),
        ],
      );
      expect(
        () => evaluateGateReports(mismatchedDialect, _baseline()),
        throwsFormatException,
      );

      final duplicateRun = _completeReports();
      duplicateRun[1] = _copyReport(duplicateRun[1], run: 1);
      expect(
        () => evaluateGateReports(duplicateRun, _baseline()),
        throwsFormatException,
      );
    },
  );

  // A ratio only means something for a scenario the matrix declares as a
  // performance measurement. One arriving for anything else is a sign the
  // reports and the matrix have drifted apart, and is refused rather than
  // averaged in.
  test('merged gates reject ratios outside performance scenarios', () {
    final reports = _completeReports();
    final altered = reports[0].toJson();
    final scenarios = List<Object?>.of(altered['scenarios']! as List<Object?>);
    final first =
        Map<String, Object?>.of(scenarios.first! as Map<String, Object?>)
          ..['comparisonKind'] = 'informational'
          ..['ratio'] = 1.0;
    scenarios[0] = first;
    altered['scenarios'] = scenarios;
    expect(() {
      reports[0] = BenchmarkReport.fromJson(altered);
      evaluateGateReports(reports, _baseline());
    }, throwsArgumentError);
  });

  // The gate end to end, in both directions — the only test here that proves
  // the pieces are wired together, and the only one that would catch a gate
  // that evaluates correctly and then ignores its own verdict.
  test(
    'gate command passes an unchanged build and fails a regressed one',
    () async {
      final directory = await Directory.systemTemp.createTemp('format-gates-');
      try {
        final baseline = File('${directory.path}/baseline.json');
        await baseline.writeAsString(jsonEncode(_baseline().toJson()));

        Future<ProcessResult> runGates(List<BenchmarkReport> reports) async {
          final paths = <String>[];
          for (var index = 0; index < reports.length; index++) {
            final file = File('${directory.path}/report-$index.json');
            await file.writeAsString(jsonEncode(reports[index].toJson()));
            paths.add(file.path);
          }

          return Process.run(Platform.resolvedExecutable, [
            'benchmark/gates.dart',
            '--reports=${paths.join(',')}',
            '--baseline=${baseline.path}',
          ]);
        }

        // Without this control, a gate that fails for an unrelated reason —
        // a missing argument, say — would still look like it was working.
        final unchanged = await runGates(_completeReports());
        expect(unchanged.exitCode, 0, reason: unchanged.stderr.toString());

        final regressed = _completeReports();
        const id = 'brace.double.fixed.compatible.hot';
        regressed[0] = _withPerformanceRatio(regressed[0], id, 1.6);
        regressed[1] = _withPerformanceRatio(regressed[1], id, 1.6);
        final result = await runGates(regressed);
        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(result.stdout, contains(id));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  // Recording and evaluating are the same tool in two modes, and they have to
  // agree about the file format: a baseline written by one and unreadable by
  // the other would only surface on the next release.
  test(
    'gate command records a baseline it can then evaluate against',
    () async {
      final directory = await Directory.systemTemp.createTemp('format-record-');
      try {
        final reports = _completeReports();
        final paths = <String>[];
        for (var index = 0; index < reports.length; index++) {
          final file = File('${directory.path}/report-$index.json');
          await file.writeAsString(jsonEncode(reports[index].toJson()));
          paths.add(file.path);
        }
        final recorded = File('${directory.path}/baseline.json');
        final record = await Process.run(Platform.resolvedExecutable, [
          'benchmark/gates.dart',
          '--reports=${paths.join(',')}',
          '--record=2026-01-01',
          '--output=${recorded.path}',
        ]);
        expect(record.exitCode, 0, reason: record.stderr.toString());

        final evaluate = await Process.run(Platform.resolvedExecutable, [
          'benchmark/gates.dart',
          '--reports=${paths.join(',')}',
          '--baseline=${recorded.path}',
        ]);
        expect(evaluate.exitCode, 0, reason: evaluate.stderr.toString());
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

List<BenchmarkReport> _completeReports() => [
  for (final runtime in ['jit', 'aot'])
    for (final run in [1, 2])
      _report(
        runtime: runtime,
        run: run,
        executableSizeBytes: runtime == 'aot' ? 123456 : null,
        scenarios: benchmarkScenarios.map(_scenarioFor).toList(),
      ),
  for (final run in [1, 2])
    _report(
      runtime: 'js',
      run: run,
      scenarios: benchmarkScenarios.map(_scenarioFor).toList(),
    ),
];

/// A reference recorded from the same synthetic reports the tests evaluate,
/// so an unchanged build sits exactly on its own recorded numbers.
GateBaseline _baseline() =>
    recordGateBaseline(_completeReports(), '2026-01-01');

BenchmarkScenarioResult _scenarioFor(BenchmarkScenario scenario) {
  final candidate = switch ((scenario.dialect, scenario.phase)) {
    (BenchmarkDialect.printf, BenchmarkPhase.cold) => 90,
    (BenchmarkDialect.printf, BenchmarkPhase.hot) => 80,
    _ => 100,
  };
  return BenchmarkScenarioResult(
    scenarioId: scenario.id,
    dialect: scenario.dialect,
    phase: scenario.phase,
    keyScenario: scenario.keyScenario,
    comparisonKind: scenario.comparisonKind,
    comparisonRationale: scenario.comparisonRationale,
    referenceLabel: scenario.referenceLabel,
    candidateMedianNanoseconds: candidate,
    baselineMedianNanoseconds: scenario.includeRatio ? 200 : null,
    // Deliberately unequal: the engines are timed to a duration, so a report
    // whose counts happened to match would not exercise the normalization.
    // Per operation the comparator still costs 0.1 ns, so the ratios the
    // other tests reason about are unchanged.
    candidateOperations: 1000,
    baselineOperations: scenario.includeRatio ? 2000 : null,
    ratio: scenario.includeRatio ? candidate / 100 : null,
  );
}

BenchmarkReport _report({
  required String runtime,
  required int run,
  required List<BenchmarkScenarioResult> scenarios,
  int? executableSizeBytes,
}) => BenchmarkReport(
  runtime: runtime,
  detectedRuntime: runtime,
  runtimeProvenance: switch (runtime) {
    'jit' => const {'detector': 'dart.vm.product', 'value': 'false'},
    'aot' => const {'detector': 'dart.vm.product', 'value': 'true'},
    'js' => const {
      'detector': 'dart2js.compile-time-define',
      'dartCompilerVersion': '3.12.2',
      'nodeVersion': 'v24.8.0',
    },
    _ => const {},
  },
  sourceRevision: '0123456789abcdef0123456789abcdef01234567',
  run: run,
  versions: const {'dartVersion': 'test', 'os': 'test', 'cpu': 'test'},
  smoke: false,
  gateable: true,
  warmupRounds: 3,
  recordedRounds: 7,
  executableSizeBytes: executableSizeBytes,
  samples: [
    for (final scenario in scenarios)
      for (final engine in [
        'candidate',
        if (scenario.comparisonKind == BenchmarkComparisonKind.performance)
          'baseline',
      ])
        for (var round = 0; round < 7; round++)
          BenchmarkSample(
            scenarioId: scenario.scenarioId,
            engine: engine,
            elapsedNanoseconds:
                engine == 'candidate'
                    ? scenario.candidateMedianNanoseconds!
                    : scenario.baselineMedianNanoseconds!,
            operations:
                engine == 'candidate'
                    ? scenario.candidateOperations!
                    : scenario.baselineOperations!,
            round: round,
          ),
  ],
  scenarios: scenarios,
);

BenchmarkReport _copyReport(
  BenchmarkReport report, {
  bool? smoke,
  bool? gateable,
  int? recordedRounds,
  int? run,
  String? detectedRuntime,
  Map<String, String>? runtimeProvenance,
  String? sourceRevision,
}) => BenchmarkReport(
  runtime: report.runtime,
  detectedRuntime: detectedRuntime ?? report.detectedRuntime,
  runtimeProvenance: runtimeProvenance ?? report.runtimeProvenance,
  sourceRevision: sourceRevision ?? report.sourceRevision,
  run: run ?? report.run,
  versions: report.versions,
  smoke: smoke ?? report.smoke,
  gateable: gateable ?? report.gateable,
  warmupRounds: report.warmupRounds,
  recordedRounds: recordedRounds ?? report.recordedRounds,
  executableSizeBytes: report.executableSizeBytes,
  samples: report.samples,
  scenarios: report.scenarios,
);

BenchmarkReport _withPerformanceRatio(
  BenchmarkReport report,
  String scenarioId,
  double ratio,
) {
  final json = report.toJson();
  final candidate = (ratio * 100).round();
  final scenarios = List<Object?>.of(json['scenarios']! as List<Object?>);
  final scenarioIndex = scenarios.indexWhere(
    (scenario) =>
        (scenario! as Map<String, Object?>)['scenarioId'] == scenarioId,
  );
  final scenario =
      Map<String, Object?>.of(scenarios[scenarioIndex]! as Map<String, Object?>)
        ..['candidateMedianNanoseconds'] = candidate
        ..['baselineMedianNanoseconds'] = 200
        ..['candidateOperations'] = 1000
        ..['baselineOperations'] = 2000
        ..['ratio'] = candidate / 100;
  scenarios[scenarioIndex] = scenario;
  final samples =
      (json['samples']! as List<Object?>)
          .map(
            (sample) =>
                Map<String, Object?>.of(sample! as Map<String, Object?>),
          )
          .toList();
  for (final sample in samples) {
    if (sample['scenarioId'] == scenarioId && sample['engine'] == 'candidate') {
      sample['elapsedNanoseconds'] = candidate;
    }
  }
  json
    ..['scenarios'] = scenarios
    ..['samples'] = samples;
  return BenchmarkReport.fromJson(json);
}
