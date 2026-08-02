import 'package:test/test.dart';

import '../benchmark/model.dart';
import '../benchmark/runner.dart';
import '../benchmark/scenarios.dart';

void main() {
  test('benchmark matrix covers every required dimension', () {
    final ids = benchmarkScenarios.map((scenario) => scenario.id).toSet();
    for (final required in [
      'brace.literal.cold',
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

  test(
    'report rejects gateable smoke, short gateable rounds, and forbidden ratios',
    () {
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
      final gateableSmoke = Map<String, Object?>.from(valid)
        ..['gateable'] = true;
      expect(
        () => BenchmarkReport.fromJson(gateableSmoke),
        throwsArgumentError,
      );
      final shortGateable =
          Map<String, Object?>.from(valid)
            ..['smoke'] = false
            ..['gateable'] = true;
      expect(
        () => BenchmarkReport.fromJson(shortGateable),
        throwsArgumentError,
      );
      final results = List<Object?>.from(valid['scenarios']! as List<Object?>);
      final nonPerformance =
          Map<String, Object?>.from(results.first! as Map<String, Object?>)
            ..['comparisonKind'] = 'informational'
            ..['ratio'] = 1.0;
      results[0] = nonPerformance;
      final forbiddenRatio = Map<String, Object?>.from(valid)
        ..['scenarios'] = results;
      expect(
        () => BenchmarkReport.fromJson(forbiddenRatio),
        throwsArgumentError,
      );
    },
  );

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
}
