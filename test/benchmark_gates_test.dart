import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../benchmark/gates.dart';
import '../benchmark/model.dart';
import '../benchmark/scenarios.dart';

void main() {
  test('brace gates accept exact mean and key boundaries', () {
    final result = evaluateBraceGates(
      ratios: const {'hot': 1.02, 'cold-key': 1.05},
      hotScenarioIds: const {'hot'},
      keyScenarioIds: const {'cold-key'},
      reproducedRatios: const {'hot': 1.02, 'cold-key': 1.05},
    );

    expect(result.geometricMeanPassed, isTrue);
    expect(result.keyScenariosPassed, isTrue);
    expect(result.passed, isTrue);
  });

  test('brace failures require the same threshold violation in both runs', () {
    final unreproduced = evaluateBraceGates(
      ratios: const {'hot': 1.0201, 'key': 1.0501},
      hotScenarioIds: const {'hot'},
      keyScenarioIds: const {'key'},
      reproducedRatios: const {'hot': 1.0, 'key': 1.0},
    );
    final reproduced = evaluateBraceGates(
      ratios: const {'hot': 1.0201, 'key': 1.0501},
      hotScenarioIds: const {'hot'},
      keyScenarioIds: const {'key'},
      reproducedRatios: const {'hot': 1.0201, 'key': 1.0501},
    );

    expect(unreproduced.passed, isTrue);
    expect(reproduced.geometricMeanPassed, isFalse);
    expect(reproduced.keyScenariosPassed, isFalse);
    expect(reproduced.passed, isFalse);
  });

  test('printf gates distinguish exact cold and hot mean boundaries', () {
    expect(evaluatePrintfMean(BenchmarkPhase.cold, 0.90), isTrue);
    expect(evaluatePrintfMean(BenchmarkPhase.cold, 0.9001), isFalse);
    expect(evaluatePrintfMean(BenchmarkPhase.hot, 0.80), isTrue);
    expect(evaluatePrintfMean(BenchmarkPhase.hot, 0.8001), isFalse);
  });

  test('printf key boundary requires reproduction in both runs', () {
    expect(
      evaluatePrintfKeyScenarios(const {'key': 1.02}, const {'key': 1.02}),
      isTrue,
    );
    expect(
      evaluatePrintfKeyScenarios(const {'key': 1.0201}, const {'key': 1.02}),
      isTrue,
    );
    expect(
      evaluatePrintfKeyScenarios(const {'key': 1.0201}, const {'key': 1.0201}),
      isFalse,
    );
  });

  test('median uses sorted integer nanoseconds and mean is geometric', () {
    expect(medianNanoseconds(const [10, 1, 3]), 3);
    expect(medianNanoseconds(const [10, 1, 3, 9]), 6);
    expect(geometricMean(const [0.5, 2]), closeTo(1, 1e-12));
  });

  test('merged gates accept exactly two complete reproducible runs', () {
    final result = evaluateGateReports(_completeReports());

    expect(result.passed, isTrue);
    expect(result.toJson()['aotExecutableSizeBytes'], 123456);
    expect(result.toJson()['gates'], hasLength(5));
  });

  test('gates reject absent or mismatched runtime provenance', () {
    final mismatched = _completeReports();
    final jit = mismatched.indexWhere((report) => report.runtime == 'jit');
    mismatched[jit] = _copyReport(mismatched[jit], detectedRuntime: 'aot');
    expect(() => evaluateGateReports(mismatched), throwsFormatException);

    final missingCompiler = _completeReports();
    final js = missingCompiler.indexWhere((report) => report.runtime == 'js');
    missingCompiler[js] = _copyReport(
      missingCompiler[js],
      runtimeProvenance: const {
        'detector': 'dart2js.compile-time-define',
        'dartCompilerVersion': 'unavailable',
      },
    );
    expect(() => evaluateGateReports(missingCompiler), throwsFormatException);
  });

  test(
    'merged gates reject smoke, non-gateable, short, and mismatched runs',
    () {
      final smoke = _completeReports();
      smoke[0] = _copyReport(smoke[0], smoke: true, gateable: false);
      expect(() => evaluateGateReports(smoke), throwsFormatException);

      final nonGateable = _completeReports();
      nonGateable[0] = _copyReport(nonGateable[0], gateable: false);
      expect(() => evaluateGateReports(nonGateable), throwsFormatException);

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
        () => evaluateGateReports(mismatchedDialect),
        throwsFormatException,
      );

      final duplicateRun = _completeReports();
      duplicateRun[1] = _copyReport(duplicateRun[1], run: 1);
      expect(() => evaluateGateReports(duplicateRun), throwsFormatException);
    },
  );

  test('merged gates reject ratios outside performance scenarios', () {
    final reports = _completeReports();
    final altered = reports[0].toJson();
    final scenarios = List<Object?>.from(
      altered['scenarios']! as List<Object?>,
    );
    final first =
        Map<String, Object?>.from(scenarios.first! as Map<String, Object?>)
          ..['comparisonKind'] = 'informational'
          ..['ratio'] = 1.0;
    scenarios[0] = first;
    altered['scenarios'] = scenarios;
    expect(() {
      reports[0] = BenchmarkReport.fromJson(altered);
      evaluateGateReports(reports);
    }, throwsArgumentError);
  });

  test('gate command exits one when a reproduced threshold fails', () async {
    final reports = _completeReports();
    reports[0] = _withPerformanceRatio(
      reports[0],
      'brace.double.fixed.hot',
      1.06,
    );
    reports[1] = _withPerformanceRatio(
      reports[1],
      'brace.double.fixed.hot',
      1.06,
    );
    final directory = await Directory.systemTemp.createTemp('format-gates-');
    try {
      final paths = <String>[];
      for (var index = 0; index < reports.length; index++) {
        final file = File('${directory.path}/report-$index.json');
        await file.writeAsString(jsonEncode(reports[index].toJson()));
        paths.add(file.path);
      }
      final result = await Process.run(Platform.resolvedExecutable, [
        'benchmark/gates.dart',
        '--reports=${paths.join(',')}',
      ]);
      expect(result.exitCode, 1, reason: result.stderr.toString());
    } finally {
      await directory.delete(recursive: true);
    }
  });
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
      scenarios:
          benchmarkScenarios
              .where((scenario) => scenario.dialect == BenchmarkDialect.printf)
              .map(_scenarioFor)
              .toList(),
    ),
];

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
    baselineMedianNanoseconds: scenario.includeRatio ? 100 : null,
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
    },
    _ => const {},
  },
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
            operations: 1,
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
}) => BenchmarkReport(
  runtime: report.runtime,
  detectedRuntime: detectedRuntime ?? report.detectedRuntime,
  runtimeProvenance: runtimeProvenance ?? report.runtimeProvenance,
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
  final scenarios = List<Object?>.from(json['scenarios']! as List<Object?>);
  final scenarioIndex = scenarios.indexWhere(
    (scenario) =>
        (scenario! as Map<String, Object?>)['scenarioId'] == scenarioId,
  );
  final scenario =
      Map<String, Object?>.from(
          scenarios[scenarioIndex]! as Map<String, Object?>,
        )
        ..['candidateMedianNanoseconds'] = candidate
        ..['baselineMedianNanoseconds'] = 100
        ..['ratio'] = candidate / 100;
  scenarios[scenarioIndex] = scenario;
  final samples =
      (json['samples']! as List<Object?>)
          .map(
            (sample) =>
                Map<String, Object?>.from(sample! as Map<String, Object?>),
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
