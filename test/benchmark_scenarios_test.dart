import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../benchmark/model.dart';
import '../benchmark/runner.dart';
import '../benchmark/scenarios.dart';

const _testSourceRevision = '0123456789abcdef0123456789abcdef01234567';

void main() {
  test('benchmark matrix covers every required dimension', () {
    final ids = benchmarkScenarios.map((scenario) => scenario.id).toSet();
    for (final required in [
      'brace.literal.cold',
      'brace.int.large_decimal.hot',
      'brace.double.fixed.dart.hot',
      'brace.double.fixed.compatible.hot',
      'brace.double.fixed_large.dart.hot',
      'brace.double.fixed_large.compatible.hot',
      'brace.mixed_named.hot.10',
      'brace.graphemes.hot',
      'brace.nested_precision.hot',
      'printf.literal.cold',
      'printf.dynamic.hot.10',
      'printf.hex_float.hot',
      'printf.invalid.hot',
    ]) {
      expect(ids, contains(required));
    }
  });

  test('large decimal integer is a key Format 2 comparison', () {
    final scenario = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.int.large_decimal.hot',
    );

    expect(scenario.keyScenario, isTrue);
    expect(scenario.comparisonKind, BenchmarkComparisonKind.performance);
    expect(scenario.templates, const ['{:d}']);
    expect(
      scenario.expected,
      isA<TextOutcome>().having(
        (outcome) => outcome.value,
        'value',
        '9007199254740991',
      ),
    );
    expect(outcomesEqual(scenario.candidate(0), scenario.expected), isTrue);
    expect(outcomesEqual(scenario.baseline!(0), scenario.expected), isTrue);
  });

  test('large compatible fixed double is a key Format 2 comparison', () {
    final scenario = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.double.fixed_large.compatible.hot',
    );

    expect(scenario.keyScenario, isTrue);
    expect(scenario.comparisonKind, BenchmarkComparisonKind.performance);
    expect(scenario.templates, const ['{:.2f}']);
    expect(
      scenario.expected,
      isA<TextOutcome>().having(
        (outcome) => outcome.value,
        'value',
        '12345678901234.57',
      ),
    );
    expect(outcomesEqual(scenario.candidate(0), scenario.expected), isTrue);
    expect(outcomesEqual(scenario.baseline!(0), scenario.expected), isTrue);
  });

  test('Dart and compatible half ties remain separate scenarios', () {
    final dart = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.double.half_tie.dart.hot',
    );
    final compatible = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.double.half_tie.compatible.hot',
    );

    expect(
      dart.expected,
      isA<TextOutcome>().having((value) => value.value, 'value', '3'),
    );
    expect(
      compatible.expected,
      isA<TextOutcome>().having((value) => value.value, 'value', '2'),
    );
    expect(outcomesEqual(dart.candidate(0), dart.expected), isTrue);
    expect(outcomesEqual(compatible.candidate(0), compatible.expected), isTrue);
  });

  test(
    'scenarios retain cold inputs before measurement and hot inputs stable',
    () {
      final cold =
          benchmarkScenarios
              .where((scenario) => scenario.phase == BenchmarkPhase.cold)
              .toList();
      final hot =
          benchmarkScenarios
              .where((scenario) => scenario.phase == BenchmarkPhase.hot)
              .toList();

      expect(cold, isNotEmpty);
      expect(hot, isNotEmpty);
      for (final scenario in cold) {
        expect(scenario.templates, hasLength(greaterThanOrEqualTo(200)));
        expect(
          scenario.templates.toSet(),
          hasLength(scenario.templates.length),
        );
      }
      for (final scenario in hot) {
        expect(scenario.templates, hasLength(1));
      }
    },
  );

  test('runner rejects a shortened non-smoke measurement', () {
    expect(
      () => parseRunnerOptions(const [
        '--dialect=braces',
        '--phase=hot',
        '--run=1',
        '--samples=1',
      ]),
      throwsArgumentError,
    );

    final smoke = parseRunnerOptions(const [
      '--dialect=braces',
      '--phase=hot',
      '--run=1',
      '--samples=1',
      '--smoke',
    ]);
    expect(smoke.smoke, isTrue);
    expect(smoke.samples, 1);
  });

  test('runner marks smoke reports non-gateable and preserves raw samples', () {
    final report = runBenchmark(
      const BenchmarkRunOptions(
        dialect: BenchmarkDialect.braces,
        phase: BenchmarkPhase.hot,
        run: 1,
        samples: 1,
        smoke: true,
      ),
    );

    expect(report.smoke, isTrue);
    expect(report.gateable, isFalse);
    expect(report.warmupRounds, 3);
    expect(report.samples, isNotEmpty);
    expect(report.toJson(), isNot(contains('gateResult')));
    expect(BenchmarkReport.fromJson(report.toJson()).toJson(), report.toJson());
  });

  test(
    'gateable JIT measurements use batches large enough to suppress noise',
    () {
      final scenario = benchmarkScenarios.singleWhere(
        (value) => value.id == 'brace.double.fixed.compatible.hot',
      );
      final report = runBenchmark(
        const BenchmarkRunOptions(
          dialect: BenchmarkDialect.braces,
          phase: BenchmarkPhase.hot,
          run: 1,
        ),
        scenarios: [scenario],
      );

      expect(report.gateable, isTrue);
      expect(report.samples.map((sample) => sample.operations).toSet(), const {
        1000,
      });
    },
  );

  test('runner records detected JIT provenance and rejects a false label', () {
    const options = BenchmarkRunOptions(
      dialect: BenchmarkDialect.braces,
      phase: BenchmarkPhase.hot,
      run: 1,
      samples: 1,
      smoke: true,
    );
    final report = runBenchmark(options);

    expect(report.runtime, 'jit');
    expect(report.detectedRuntime, 'jit');
    expect(report.runtimeProvenance['detector'], 'dart.vm.product');
    expect(report.runtimeProvenance['value'], 'false');
    expect(
      () => runBenchmark(
        const BenchmarkRunOptions(
          dialect: BenchmarkDialect.braces,
          phase: BenchmarkPhase.hot,
          runtime: 'aot',
          run: 1,
          samples: 1,
          smoke: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('reference-only locale comparisons never produce a ratio', () {
    final references = benchmarkScenarios.where(
      (scenario) =>
          scenario.comparisonKind == BenchmarkComparisonKind.correctnessOnly,
    );
    expect(
      references.map((scenario) => scenario.id),
      containsAll(['brace.locale.n.hot', 'brace.format_intl.hot']),
    );

    final report = runBenchmark(
      const BenchmarkRunOptions(
        dialect: BenchmarkDialect.braces,
        phase: BenchmarkPhase.hot,
        run: 1,
        samples: 1,
        smoke: true,
      ),
      scenarios: references.toList(),
    );
    expect(
      report.scenarios.every((scenario) => scenario.ratio == null),
      isTrue,
    );
    expect(
      report.scenarios.every(
        (scenario) =>
            scenario.comparisonKind == BenchmarkComparisonKind.correctnessOnly,
      ),
      isTrue,
    );
  });

  test('format_intl uses a pinned golden reference rather than Format', () {
    final scenario = benchmarkScenarios.singleWhere(
      (scenario) => scenario.id == 'brace.format_intl.hot',
    );
    expect(scenario.referenceKind, BenchmarkReferenceKind.golden);
    expect(scenario.referenceLabel, 'golden-intl:uk_UA:1234');
    final outcome = scenario.baseline!(0);
    expect((outcome as TextOutcome).value, '1\u00a0234');
  });

  test('non-overlapping sprintf7 conversions stay informational', () {
    final byId = {
      for (final scenario in benchmarkScenarios) scenario.id: scenario,
    };
    for (final id in [
      'printf.character.hot',
      'printf.unsigned.hot',
      'printf.hex_float.hot',
    ]) {
      expect(
        byId[id]!.comparisonKind,
        BenchmarkComparisonKind.informational,
        reason: '$id has no sprintf7 conversion counterpart.',
      );
    }
  });

  test('matrix records the API call shape behind API-path scenarios', () {
    final byId = {
      for (final scenario in benchmarkScenarios) scenario.id: scenario,
    };
    expect(byId['brace.top_level.hot']!.apiPath, BenchmarkApiPath.topLevel);
    expect(byId['brace.with.hot']!.apiPath, BenchmarkApiPath.withValues);
    expect(byId['brace.tear_off.hot']!.apiPath, BenchmarkApiPath.tearOff);
    expect(byId['printf.sprintf.hot']!.apiPath, BenchmarkApiPath.topLevel);
    expect(byId['printf.vsprintf.hot']!.apiPath, BenchmarkApiPath.withValues);
    expect(byId['printf.tear_off.hot']!.apiPath, BenchmarkApiPath.tearOff);
  });

  test(
    'matrix structurally covers multi-field, Unicode, and cold dimensions',
    () {
      final byId = {
        for (final scenario in benchmarkScenarios) scenario.id: scenario,
      };
      expect(byId['brace.mixed_named.hot.10']!.fieldCount, 10);
      expect(
        (byId['brace.double.default.hot']!.expected as TextOutcome).value,
        '1.23456789',
      );
      expect(
        (byId['brace.text.scalars.hot']!.expected as TextOutcome).value,
        'e',
      );
      expect(byId['brace.text.scalars.hot']!.templates.single, '{:.1s}');
      expect(
        (byId['brace.graphemes.hot']!.expected as TextOutcome).value,
        'e\u0301',
      );
      for (final id in [
        'printf.exponential.hot',
        'printf.uppercase_exponential.hot',
        'printf.general.hot',
        'printf.uppercase_general.hot',
        'printf.uppercase_fixed.hot',
        'printf.conversions.cold',
        'printf.dynamic.cold',
        'brace.parser_heavy.cold',
        'brace.fields.10.cold',
      ]) {
        expect(byId[id], isNotNull, reason: id);
      }
      expect(byId['printf.dynamic.cold']!.keyScenario, isTrue);
    },
  );

  test('report rejects gateable smoke, short gateable rounds, and '
      'forbidden ratios', () {
    final valid =
        runBenchmark(
          const BenchmarkRunOptions(
            dialect: BenchmarkDialect.braces,
            phase: BenchmarkPhase.hot,
            run: 1,
            samples: 1,
            smoke: true,
          ),
        ).toJson();
    final gateableSmoke = Map<String, Object?>.from(valid)..['gateable'] = true;
    expect(() => BenchmarkReport.fromJson(gateableSmoke), throwsArgumentError);
    final shortGateable =
        Map<String, Object?>.from(valid)
          ..['smoke'] = false
          ..['gateable'] = true;
    expect(() => BenchmarkReport.fromJson(shortGateable), throwsArgumentError);
    final results = List<Object?>.from(valid['scenarios']! as List<Object?>);
    final nonPerformance =
        Map<String, Object?>.from(results.first! as Map<String, Object?>)
          ..['comparisonKind'] = 'informational'
          ..['ratio'] = 1.0;
    results[0] = nonPerformance;
    final forbiddenRatio = Map<String, Object?>.from(valid)
      ..['scenarios'] = results;
    expect(() => BenchmarkReport.fromJson(forbiddenRatio), throwsArgumentError);
  });

  test('runner checks a comparable output before recording timing', () {
    final scenario = BenchmarkScenario(
      id: 'test.mismatch.hot',
      dialect: BenchmarkDialect.braces,
      phase: BenchmarkPhase.hot,
      keyScenario: false,
      expected: const TextOutcome('candidate'),
      templates: const ['ignored'],
      candidate: (_) => const TextOutcome('candidate'),
      baseline: (_) => const TextOutcome('baseline'),
    );

    expect(
      () => runBenchmark(
        const BenchmarkRunOptions(
          dialect: BenchmarkDialect.braces,
          phase: BenchmarkPhase.hot,
          run: 1,
          samples: 1,
          smoke: true,
        ),
        scenarios: [scenario],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'compiled JavaScript runner preserves typed error outcomes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'format-js-runner-',
      );
      final output = '${directory.path}/runner.js';
      try {
        final compile = await Process.run(Platform.resolvedExecutable, [
          'compile',
          'js',
          'benchmark/runner.dart',
          '-Dformat.benchmark.dartCompilerVersion=3.12.2',
          '-Dformat.benchmark.sourceRevision=$_testSourceRevision',
          '-O4',
          '-o',
          output,
        ]);
        expect(compile.exitCode, 0, reason: compile.stderr.toString());

        final mismatch = await Process.run('node', [
          output,
          '--runtime=jit',
          '--dialect=printf',
          '--run=1',
          '--samples=1',
          '--smoke',
        ]);
        expect(mismatch.exitCode, isNonZero);

        final run = await Process.run('node', [
          output,
          '--runtime=js',
          '--dialect=printf',
          '--run=1',
          '--samples=1',
          '--smoke',
          '--output=${directory.path}/report.json',
        ]);
        expect(run.exitCode, 0, reason: run.stderr.toString());
        final report = BenchmarkReport.fromJson(
          jsonDecode(await File('${directory.path}/report.json').readAsString())
              as Map<String, Object?>,
        );
        expect(report.runtime, 'js');
        expect(report.detectedRuntime, 'js');
        expect(
          report.runtimeProvenance['detector'],
          'dart2js.compile-time-define',
        );
        expect(report.runtimeProvenance['dartCompilerVersion'], '3.12.2');
        expect(report.sourceRevision, _testSourceRevision);
        expect(
          report.scenarios
              .where(
                (scenario) =>
                    scenario.comparisonKind ==
                    BenchmarkComparisonKind.performance,
              )
              .map((scenario) => scenario.ratio),
          everyElement(
            isA<double>().having((ratio) => ratio.isFinite, 'finite', isTrue),
          ),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout.factor(4),
  );

  test(
    'compiled AOT runner rejects JIT label and records AOT provenance',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'format-aot-runner-',
      );
      final output = '${directory.path}/runner';
      try {
        final compile = await Process.run(Platform.resolvedExecutable, [
          'compile',
          'exe',
          'benchmark/runner.dart',
          '-Dformat.benchmark.sourceRevision=$_testSourceRevision',
          '-o',
          output,
        ]);
        expect(compile.exitCode, 0, reason: compile.stderr.toString());

        final mismatch = await Process.run(output, [
          '--runtime=jit',
          '--dialect=braces',
          '--run=1',
          '--samples=1',
          '--smoke',
        ]);
        expect(mismatch.exitCode, isNonZero);

        final run = await Process.run(output, [
          '--runtime=aot',
          '--dialect=braces',
          '--run=1',
          '--samples=1',
          '--smoke',
          '--output=${directory.path}/report.json',
        ]);
        expect(run.exitCode, 0, reason: run.stderr.toString());
        final report = BenchmarkReport.fromJson(
          jsonDecode(await File('${directory.path}/report.json').readAsString())
              as Map<String, Object?>,
        );
        expect(report.runtime, 'aot');
        expect(report.detectedRuntime, 'aot');
        expect(report.runtimeProvenance, const {
          'detector': 'dart.vm.product',
          'value': 'true',
        });
        expect(report.executableSizeBytes, greaterThan(0));
        expect(report.sourceRevision, _testSourceRevision);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
