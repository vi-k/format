/// The benchmark matrix and the runner that measures it.
///
/// The matrix is a list of scenarios, and its completeness is a claim: that the
/// gate watches the paths worth watching. Nothing enforces that claim at
/// runtime — a scenario deleted in a refactor leaves a gate that still passes,
/// on a smaller set of measurements, and says nothing about what it stopped
/// looking at. So the required dimensions are listed here by id, and the
/// scenarios that carry extra weight (the key comparisons, the two double
/// profiles, cold versus hot inputs) are pinned individually.
///
/// The runner is the other half, and its failure modes are worse than the
/// matrix's, because they produce numbers rather than nothing. A measurement
/// taken over too few rounds, or on an input that was already warm when it
/// claimed to be cold, or under a runtime it labels wrongly, is not a smaller
/// measurement — it is a different one, indistinguishable from the real thing
/// in the report. Every one of those is refused explicitly here.
///
/// A measurement is also only meaningful if the engines being compared produced
/// the same string, so the runner checks the output before it records a timing,
/// and comparisons that cannot be made at all (a locale reference, a conversion
/// one comparator lacks) are marked as informational rather than turned into a
/// ratio.
///
/// The last two tests compile and run the harness under dart2js and AOT in
/// temporary directories: the provenance the reports carry has to be detected,
/// not declared, and a JIT run mislabelled as AOT would poison the baseline.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../model.dart';
import '../runner.dart';
import '../scenarios.dart';

const _testSourceRevision = '0123456789abcdef0123456789abcdef01234567';

void main() {
  // The coverage claim as a list of ids. A scenario removed silently narrows
  // the gate without failing it, so removal has to be an explicit edit here.
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

  // Key scenarios are held to a tighter tolerance and compared against the
  // frozen 2.0 baseline. Which ones carry that weight is a decision, not an
  // attribute, so it is pinned rather than inferred.
  test('large decimal integer is a key Format 2 comparison', () {
    final scenario = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.int.large_decimal.hot',
    );

    expect(scenario.keyScenario, isTrue);
    expect(scenario.comparisonKind, BenchmarkComparisonKind.performance);
    expect(scenario.templateFor(0), '{:d}');
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

  // The double-side key comparison, on the profile whose digits the package
  // produces itself — the most expensive path in the package and the one worth
  // the tighter tolerance.
  test('large compatible fixed double is a key Format 2 comparison', () {
    final scenario = benchmarkScenarios.singleWhere(
      (value) => value.id == 'brace.double.fixed_large.compatible.hot',
    );

    expect(scenario.keyScenario, isTrue);
    expect(scenario.comparisonKind, BenchmarkComparisonKind.performance);
    expect(scenario.templateFor(0), '{:.2f}');
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

  // The two double profiles are separate measurements even for the same value,
  // because they run different code: merging them would average a delegation to
  // the SDK with the package's own conversion and hide a regression in either.
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

  // A cold scenario measures parsing, which only happens once per template —
  // so its inputs must still be unparsed when measurement begins, and a hot
  // scenario's must be stable across rounds. Get this wrong and a cold
  // measurement quietly becomes a warm one, several times faster and meaningless.
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
        // What makes a scenario cold is that no iteration repeats an
        // earlier template, however many iterations a round turns out to
        // need — a prepared list of any fixed length cannot promise that.
        final seen = <String>{};
        for (var iteration = 0; iteration < 1000; iteration++) {
          expect(
            seen.add(scenario.templateFor(iteration)),
            isTrue,
            reason: '${scenario.id} repeated a template at $iteration',
          );
        }
      }
      for (final scenario in hot) {
        expect(scenario.templateFor(0), scenario.templateFor(1));
        expect(scenario.templateFor(0), scenario.templateFor(999));
      }
    },
  );

  // Too few rounds does not produce a rougher number, it produces a different
  // one — dominated by warm-up. A shortened run is refused rather than recorded
  // with a caveat nobody reads.
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

  // Smoke runs exist to check the harness works, not to measure. They are
  // marked non-gateable at the source, so the gate refuses them by construction
  // rather than by convention — and the raw samples are kept, since a rejected
  // report is still worth reading.
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

  // A batch too small measures the clock and the loop rather than the work. The
  // minimum is a property of a gateable scenario, checked here so that adding a
  // fast scenario cannot quietly introduce a noisy one.
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
      // Each engine runs the count its own speed requires, so the counts
      // differ; what has to hold is that every recorded round is long enough
      // for the clock to resolve it.
      for (final sample in report.samples) {
        expect(
          sample.elapsedNanoseconds,
          greaterThanOrEqualTo(benchmarkTargetRoundNanoseconds() ~/ 2),
          reason: '${sample.engine} round ${sample.round}',
        );
      }
      final counts = report.samples.map((sample) => sample.operations).toSet();
      expect(counts, hasLength(2), reason: 'one calibrated count per engine');
    },
  );

  // Provenance is detected, never taken on the caller's word: a report claiming
  // a runtime it is not running on would be compared against the wrong
  // baseline, which is the failure that looks most like a real regression.
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

  // Some scenarios exist to show a number, not to compare one — there is no
  // comparable implementation on the other side. They are marked so no ratio is
  // computed, because a ratio against nothing is still a ratio in a report.
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

  // The reference output for the locale scenario is a committed constant rather
  // than something this package produces, so the comparison cannot silently
  // become the package agreeing with itself.
  test('format_intl uses a pinned golden reference rather than Format', () {
    final scenario = benchmarkScenarios.singleWhere(
      (scenario) => scenario.id == 'brace.format_intl.hot',
    );
    expect(scenario.referenceKind, BenchmarkReferenceKind.golden);
    expect(scenario.referenceLabel, 'golden-intl:kk_KZ:1234');
    final outcome = scenario.baseline!(0);
    expect((outcome as TextOutcome).value, '1\u00a0234');
  });

  // Where the comparator has no equivalent conversion there is nothing to
  // compare, and the scenario stays informational — measuring it against
  // something it does not implement would produce a flattering number that
  // means nothing.
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

  // Some scenarios measure a calling convention rather than a template, so the
  // shape of the call is part of the scenario's definition and has to be
  // recorded with it.
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

  // Coverage stated structurally rather than by id: whatever the matrix is
  // called, it must contain scenarios with several fields, with non-ASCII text,
  // and with cold inputs. This survives a renaming that the id list above would
  // not.
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
      expect(byId['brace.text.scalars.hot']!.templateFor(0), '{:.1s}');
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

  // The report refuses to describe itself inconsistently: gateable and smoke at
  // once, gateable with too few rounds. The invariants live in the type rather
  // than in the code that fills it, so no producer can bypass them.
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

  // A timing is only meaningful if the two sides produced the same string.
  // Checking that first turns "one engine is much faster" into "one engine is
  // wrong", which is the more useful failure.
  test('runner checks a comparable output before recording timing', () {
    final scenario = BenchmarkScenario(
      id: 'test.mismatch.hot',
      dialect: BenchmarkDialect.braces,
      phase: BenchmarkPhase.hot,
      keyScenario: false,
      expected: const TextOutcome('candidate'),
      templateFor: (_) => 'ignored',
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

  // The harness compiled under dart2js and run for real: a scenario that fails
  // must arrive as the same typed outcome it has on the VM, or the web reports
  // would differ from the VM ones for reasons that have nothing to do with
  // speed.
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

  // The same for AOT, plus the refusal that matters most: an AOT run must not
  // be able to present itself as a JIT one. The two have different baselines,
  // and a mislabelled report is compared against numbers from another
  // compiler.
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
