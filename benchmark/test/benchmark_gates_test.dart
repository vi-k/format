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

    expect(restored.sourceRevision, baseline.sourceRevision);
    final reference = restored.references['test']!;
    expect(reference.recordedAt, '2026-01-01');
    final key = GateBaseline.keyFor('jit', BenchmarkDialect.braces);
    expect(reference.phaseMean(key, BenchmarkPhase.hot), closeTo(1.0, 1e-12));
    // A matrix that grew since the reference was taken must say so instead
    // of silently gating nothing.
    expect(
      () => reference.scenarioRatio(key, 'brace.invented.hot'),
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
    // Four runtimes times two dialects: a runtime that stopped being
    // required would shrink this silently.
    expect(result.toJson()['gates'], hasLength(8));
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

  // What the reports agreeing with *each other* never proved. The revision is
  // passed in from the shell, because a JavaScript runtime cannot ask git, so
  // three matching reports show only that one define reached three processes.
  // These are the two ways that define can be a lie: it names a commit the
  // checkout has moved off, or it names the right commit while the tree that
  // was measured differs from it.
  //
  // The rules are tested here rather than against a real repository, which is
  // the reason they were separated from running git at all: a test that had to
  // build a checkout would be slow, and it would test git.
  test('the checkout contradicts a report that misstates its revision', () {
    const revision = '0123456789abcdef0123456789abcdef01234567';
    const other = 'fedcba9876543210fedcba9876543210fedcba98';

    expect(
      checkoutObjection(
        revision: revision,
        head: revision,
        modifiedTrackedFiles: '',
      ),
      isNull,
    );
    // A status that ignored untracked files still ends in a newline, and a
    // reading that took that for a change would object to every clean tree.
    expect(
      checkoutObjection(
        revision: revision,
        head: revision,
        modifiedTrackedFiles: '\n',
      ),
      isNull,
    );
    expect(
      checkoutObjection(
        revision: revision,
        head: other,
        modifiedTrackedFiles: '',
      ),
      allOf(contains(revision), contains(other)),
    );
    expect(
      checkoutObjection(
        revision: revision,
        head: revision,
        modifiedTrackedFiles: ' M lib/src/engine.dart\n',
      ),
      allOf(contains('1 tracked file is'), contains('lib/src/engine.dart')),
    );
    expect(
      checkoutObjection(
        revision: revision,
        head: revision,
        modifiedTrackedFiles: ' M lib/src/engine.dart\n M benchmark/gates.dart',
      ),
      contains('2 tracked files are'),
    );
    // A moved HEAD is reported even when the tree is also dirty: it is the
    // more fundamental of the two, and naming both at once would read as one
    // compound problem rather than the first thing to fix.
    expect(
      checkoutObjection(
        revision: revision,
        head: other,
        modifiedTrackedFiles: ' M lib/src/engine.dart\n',
      ),
      contains('HEAD is $other'),
    );
  });

  // The gate's other half: the arithmetic can be perfect and still mean
  // nothing, because a ratio only describes the code when both sides of it ran
  // in the same place. Three consecutive nightly runs landed on an Intel Xeon
  // 8573C, an EPYC 7763 and an EPYC 9V74, and the two hardware changes were
  // reported as regressions — which is what these tests are about.
  //
  // A machine the reference does not describe therefore decides nothing rather
  // than failing: the hosted pool hands out a different processor most nights,
  // and a gate that went red for each of them would teach its reader to stop
  // looking.
  test('a matching CPU selects its own reference before provenance checks', () {
    // An Intel report must use its Intel record rather than be rejected against
    // the primary synthetic CPU merely because the map holds more than one.
    final baseline = GateBaseline.fromJson(
      _schema2Baseline(secondaryCpu: 'Intel Xeon test'),
    );

    final result = evaluateGateReports(
      _reportsForCpu('Intel Xeon test'),
      baseline,
    );

    expect(result.comparable, isTrue);
    expect(result.environmentDifferences, isEmpty);
  });

  test('an unknown CPU keeps diagnostic ratios without deciding the gate', () {
    // Falling back to the primary ratios keeps the report useful, but treating
    // an unrecorded processor as comparable would let different hardware pass
    // a regression verdict.
    final baseline = GateBaseline.fromJson(_schema2Baseline());

    final result = evaluateGateReports(
      _reportsForCpu('unrecorded CPU'),
      baseline,
    );

    expect(result.gates, hasLength(8));
    expect(result.comparable, isFalse);
    expect(result.decisive, isFalse);
    expect(result.environmentDifferences.single, contains('unrecorded CPU'));
  });

  test('schema 2 rejects an empty CPU reference map', () {
    // A baseline with no reference would make every unknown CPU silently
    // diagnostic, which looks like a working gate while deciding nothing.
    final malformed = _schema2Baseline()..['references'] = <String, Object?>{};

    expect(() => GateBaseline.fromJson(malformed), throwsFormatException);
  });

  test('a CPU reference does not expose mutable timing maps', () {
    final reference =
        recordGateBaseline(
          _completeReports(),
          '2026-01-01',
        ).references['test']!;
    final phaseMeans =
        reference.phaseMeans[GateBaseline.keyFor(
          'jit',
          BenchmarkDialect.braces,
        )]!;

    expect(
      () => phaseMeans[BenchmarkPhase.hot.name] = 2,
      throwsUnsupportedError,
    );
  });

  test('schema 2 rejects a missing primary and inconsistent CPU key', () {
    // The primary is the only permitted fallback, and each key is an exact CPU
    // identity. Accepting either malformed shape would make that policy lie.
    final missingPrimary = _schema2Baseline()..remove('primaryCpu');
    expect(() => GateBaseline.fromJson(missingPrimary), throwsFormatException);

    final mismatchedKey = _schema2Baseline();
    final references = Map<String, Object?>.from(
      mismatchedKey['references']! as Map,
    );
    final reference = references.remove('test')!;
    references['different CPU'] = reference;
    mismatchedKey['references'] = references;
    expect(() => GateBaseline.fromJson(mismatchedKey), throwsFormatException);
  });

  test('adding a CPU reference preserves the existing reference', () {
    final first = recordGateBaseline(_completeReports(), '2026-01-01');

    final added = addGateBaselineReference(
      first,
      _reportsForCpu('Intel Xeon test'),
      '2026-01-02',
    );

    expect(added.references.keys, unorderedEquals(['test', 'Intel Xeon test']));
    expect(added.references['test']!.recordedAt, '2026-01-01');
    expect(added.references['Intel Xeon test']!.recordedAt, '2026-01-02');
  });

  test('adding a CPU reference rejects an existing CPU', () {
    final baseline = recordGateBaseline(_completeReports(), '2026-01-01');

    expect(
      () =>
          addGateBaselineReference(baseline, _completeReports(), '2026-01-02'),
      throwsFormatException,
    );
  });

  test('adding a CPU reference rejects another source revision', () {
    final baseline = recordGateBaseline(_completeReports(), '2026-01-01');
    final reports = [
      for (final report in _reportsForCpu('Intel Xeon test'))
        _copyReport(
          report,
          sourceRevision: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
    ];

    expect(
      () => addGateBaselineReference(baseline, reports, '2026-01-02'),
      throwsFormatException,
    );
  });

  test(
    'the committed baseline names its primary CPU as a schema 2 reference',
    () {
      // This pins the data migration to the parser change: a committed
      // evaluator must always read the reference it is invoked with.
      final json = Map<String, Object?>.from(
        jsonDecode(
              File('benchmark/results/gate-baseline.json').readAsStringSync(),
            )
            as Map,
      );
      expect(json['schemaVersion'], 2);

      final references = Map<String, Object?>.from(json['references']! as Map);
      final primary = json['primaryCpu']! as String;
      final reference = Map<String, Object?>.from(references[primary]! as Map);
      final environment = Map<String, Object?>.from(
        reference['environment']! as Map,
      );

      expect(environment['cpu'], primary);
    },
  );

  test('a reference from another machine decides nothing', () {
    final baseline = _baseline();
    expect(
      evaluateGateReports(_completeReports(), baseline).comparable,
      isTrue,
    );

    for (final change in <(String, Map<String, String>)>[
      ('cpu', {'dartVersion': 'test', 'os': 'test', 'cpu': 'other'}),
      ('dart', {'dartVersion': 'other', 'os': 'test', 'cpu': 'test'}),
    ]) {
      final reports = [
        for (final report in _completeReports())
          if (report.runtime == 'js')
            report
          else
            _copyReport(report, versions: change.$2),
      ];
      final result = evaluateGateReports(reports, baseline);

      expect(result.comparable, isFalse, reason: change.$1);
      expect(result.decisive, isFalse, reason: change.$1);
      expect(result.environmentDifferences.single, startsWith(change.$1));
    }

    // Node comes from the JavaScript reports rather than the VM ones, so it
    // travels a different path into the comparison and is checked separately.
    final otherNode = [
      for (final report in _completeReports())
        if (report.runtime == 'js')
          _copyReport(
            report,
            runtimeProvenance: const {
              'detector': 'dart2js.compile-time-define',
              'dartCompilerVersion': '3.12.2',
              'nodeVersion': 'v24.9.0',
            },
          )
        else
          report,
    ];
    final node = evaluateGateReports(otherNode, baseline);
    expect(node.comparable, isFalse);
    expect(node.environmentDifferences.single, startsWith('node'));
  });

  // The operating system string is recorded and deliberately not compared: on
  // a hosted runner it carries a kernel build number that changes with every
  // image refresh without moving a timing, so gating on it would gate on image
  // releases. Stated as a test because it is a decision, not an oversight.
  test('a different operating system string is still comparable', () {
    final reports = [
      for (final report in _completeReports())
        if (report.runtime == 'js')
          report
        else
          _copyReport(
            report,
            versions: const {
              'dartVersion': 'test',
              'os': 'other kernel build',
              'cpu': 'test',
            },
          ),
    ];

    expect(evaluateGateReports(reports, _baseline()).comparable, isTrue);
  });

  // A machine change is not allowed to hide behind a passing verdict either:
  // the ratios are still evaluated and still reported, so the numbers can be
  // read as information. What changes is that they decide nothing.
  test('an incomparable run still reports its ratios', () {
    final regressed = _completeReports();
    const id = 'brace.double.fixed.compatible.hot';
    regressed[0] = _withPerformanceRatio(regressed[0], id, 1.6);
    regressed[1] = _withPerformanceRatio(regressed[1], id, 1.6);
    final baseline = _baseline();
    expect(evaluateGateReports(regressed, baseline).passed, isFalse);

    final elsewhere = [
      for (final report in regressed)
        if (report.runtime == 'js')
          report
        else
          _copyReport(
            report,
            versions: const {
              'dartVersion': 'test',
              'os': 'test',
              'cpu': 'other',
            },
          ),
    ];
    final result = evaluateGateReports(elsewhere, baseline);

    expect(result.passed, isFalse, reason: 'арифметика та же');
    expect(result.decisive, isFalse);
    // Four runtimes times two dialects: a runtime that stopped being
    // required would shrink this silently.
    expect(result.toJson()['gates'], hasLength(8));
  });

  // A CPU-keyed reference without its environment cannot name the CPU that
  // produced it, so it must be rejected while parsing rather than becoming a
  // reference that quietly decides nothing on every machine.
  test('a reference without an environment is refused, not assumed', () {
    expect(
      () => GateBaseline.fromJson(_schema2BaselineWithoutEnvironment()),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('environment'),
        ),
      ),
    );
  });

  // Which order the reports arrive in is the caller's business and must not
  // reach the verdict. It did: the environment took its Dart version from the
  // first report that was not `js`, and dart2wasm is compiled like the web —
  // it carries a bare compiler version where the VM carries an SDK banner. A
  // caller listing wasm first therefore compared one string against the other
  // and called a matching machine a different one.
  test('the order of the reports does not decide the environment', () {
    final reports = _reportsWithWebVersions();
    final baseline = recordGateBaseline(reports, '2026-01-01');

    expect(evaluateGateReports(reports, baseline).comparable, isTrue);

    final reordered = reports.reversed.toList(growable: false);
    final result = evaluateGateReports(reordered, baseline);

    expect(result.environmentDifferences, isEmpty);
    expect(result.comparable, isTrue);
  });

  // A report that omits a scenario of the current matrix is already refused.
  // The direction that was not is the one that happens in practice: the matrix
  // itself shrinks in `scenarios.dart`, so the reports are complete for the
  // code that produced them, and only the reference still remembers the
  // scenario. Adding one is a hard error — there is no recorded ratio to
  // compare against — while removing one used to narrow the gate in silence
  // and leave every remaining check passing.
  test('a reference that outlives its scenario is refused, not skipped', () {
    final json = _baseline().toJson();
    final references = Map<String, Object?>.from(json['references']! as Map);
    final reference = Map<String, Object?>.from(references['test']! as Map);
    final ratios = Map<String, Map<String, double>>.from(
      reference['scenarioRatios']! as Map,
    );
    ratios['jit/braces'] = {
      ...ratios['jit/braces']!,
      'brace.since.removed.hot': 1.0,
    };
    references['test'] = {...reference, 'scenarioRatios': ratios};
    json['references'] = references;

    expect(
      () =>
          evaluateGateReports(_completeReports(), GateBaseline.fromJson(json)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('brace.since.removed.hot'), contains('Re-record')),
        ),
      ),
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
            // The reports are built in memory and name an invented revision,
            // which the checkout would rightly object to. The refusal itself
            // is asserted in its own test below.
            '--allow-unverified-revision',
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
          '--allow-unverified-revision',
        ]);
        expect(record.exitCode, 0, reason: record.stderr.toString());

        final evaluate = await Process.run(Platform.resolvedExecutable, [
          'benchmark/gates.dart',
          '--reports=${paths.join(',')}',
          '--baseline=${recorded.path}',
          '--allow-unverified-revision',
        ]);
        expect(evaluate.exitCode, 0, reason: evaluate.stderr.toString());
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('gate command adds a CPU reference to its baseline', () async {
    final directory = await Directory.systemTemp.createTemp('format-add-');
    try {
      final baseline = File('${directory.path}/baseline.json');
      await baseline.writeAsString(jsonEncode(_baseline().toJson()));
      final paths = await _writeReports(
        directory,
        _reportsForCpu('Intel Xeon test'),
      );

      final result = await Process.run(Platform.resolvedExecutable, [
        'benchmark/gates.dart',
        '--reports=${paths.join(',')}',
        '--baseline=${baseline.path}',
        '--add-reference=2026-01-02',
        '--output=${baseline.path}',
        '--allow-unverified-revision',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final added = GateBaseline.fromJson(
        Map<String, Object?>.from(
          jsonDecode(await baseline.readAsString()) as Map,
        ),
      );
      expect(
        added.references.keys,
        unorderedEquals(['test', 'Intel Xeon test']),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('a duplicate gate-command add leaves its output unchanged', () async {
    final directory = await Directory.systemTemp.createTemp('format-add-');
    try {
      final baseline = File('${directory.path}/baseline.json');
      await baseline.writeAsString(jsonEncode(_baseline().toJson()));
      final paths = await _writeReports(
        directory,
        _reportsForCpu('Intel Xeon test'),
      );
      final arguments = [
        'benchmark/gates.dart',
        '--reports=${paths.join(',')}',
        '--baseline=${baseline.path}',
        '--add-reference=2026-01-02',
        '--output=${baseline.path}',
        '--allow-unverified-revision',
      ];

      final added = await Process.run(Platform.resolvedExecutable, arguments);
      expect(added.exitCode, 0, reason: added.stderr.toString());
      final beforeDuplicate = await baseline.readAsString();

      final duplicate = await Process.run(
        Platform.resolvedExecutable,
        arguments,
      );
      expect(duplicate.exitCode, 1, reason: duplicate.stderr.toString());
      expect(await baseline.readAsString(), beforeDuplicate);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  // The exit code is where "decides nothing" has to be visible to CI, and it
  // is the one piece the unit tests above cannot reach: a regressed set of
  // reports measured on another processor must leave the command green, while
  // the report it writes still says the ratios breached.
  test('gate command exits green when the machine does not match', () async {
    final directory = await Directory.systemTemp.createTemp('format-machine-');
    try {
      final regressed = _completeReports();
      const id = 'brace.double.fixed.compatible.hot';
      regressed[0] = _withPerformanceRatio(regressed[0], id, 1.6);
      regressed[1] = _withPerformanceRatio(regressed[1], id, 1.6);
      final elsewhere = [
        for (final report in regressed)
          if (report.runtime == 'js')
            report
          else
            _copyReport(
              report,
              versions: const {
                'dartVersion': 'test',
                'os': 'test',
                'cpu': 'a processor the reference never saw',
              },
            ),
      ];

      final baseline = File('${directory.path}/baseline.json');
      await baseline.writeAsString(jsonEncode(_baseline().toJson()));
      final paths = <String>[];
      for (var index = 0; index < elsewhere.length; index++) {
        final file = File('${directory.path}/report-$index.json');
        await file.writeAsString(jsonEncode(elsewhere[index].toJson()));
        paths.add(file.path);
      }
      final report = File('${directory.path}/gate.json');
      final result = await Process.run(Platform.resolvedExecutable, [
        'benchmark/gates.dart',
        '--reports=${paths.join(',')}',
        '--baseline=${baseline.path}',
        '--output=${report.path}',
        '--allow-unverified-revision',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stderr.toString(),
        contains('a processor the reference never saw'),
      );
      final decoded =
          jsonDecode(await report.readAsString()) as Map<String, Object?>;
      expect(decoded['comparable'], isFalse);
      expect(
        decoded['passed'],
        isFalse,
        reason: 'отчёт обязан сохранить арифметику, а не приукрасить её',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  // The escape hatch the two tests above lean on, checked from the other side.
  // Without it the same invented revision must stop the command — otherwise
  // those tests would be passing because the check never runs, and the flag
  // would be decoration.
  //
  // Recording is the mode asserted here. It is the one where an unverified
  // revision does lasting damage: the file it writes becomes the reference
  // every later run is compared against, and nothing downstream can tell that
  // it never was the commit it names.
  test('gate command refuses an unverified revision unless allowed', () async {
    final directory = await Directory.systemTemp.createTemp('format-unverif-');
    try {
      final reports = _completeReports();
      final paths = <String>[];
      for (var index = 0; index < reports.length; index++) {
        final file = File('${directory.path}/report-$index.json');
        await file.writeAsString(jsonEncode(reports[index].toJson()));
        paths.add(file.path);
      }
      final refused = await Process.run(Platform.resolvedExecutable, [
        'benchmark/gates.dart',
        '--reports=${paths.join(',')}',
        '--record=2026-01-01',
        '--output=${directory.path}/baseline.json',
      ]);

      expect(refused.exitCode, 1);
      expect(
        refused.stderr.toString(),
        allOf(
          contains(reports.first.sourceRevision),
          contains('--allow-unverified-revision'),
        ),
      );
      expect(
        File('${directory.path}/baseline.json').existsSync(),
        isFalse,
        reason: 'отказ обязан быть до записи, а не после',
      );
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
  // Both web backends, because they are two runtimes and not one: they reach
  // node the same way and compute differently, and the gate has to keep their
  // references apart.
  for (final runtime in ['js', 'wasm'])
    for (final run in [1, 2])
      _report(
        runtime: runtime,
        run: run,
        scenarios: benchmarkScenarios.map(_scenarioFor).toList(),
      ),
];

/// The same reports, with the two web runtimes describing themselves the way
/// they actually do: node reports the compiler version rather than the SDK
/// banner the VM prints, and its own view of the processor. Which is what
/// makes taking the environment from the wrong report visible at all.
List<BenchmarkReport> _reportsWithWebVersions() => [
  for (final report in _completeReports())
    if (report.runtime == 'js' || report.runtime == 'wasm')
      _copyReport(
        report,
        versions: const {
          'dartVersion': 'Dart 3.12.2',
          'os': 'linux 6.8 (x64); Node v24.8.0',
          'cpu': 'AMD EPYC 7763 as node sees it',
        },
      )
    else
      report,
];

List<BenchmarkReport> _reportsForCpu(String cpu) => [
  for (final report in _completeReports())
    _copyReport(
      report,
      versions: {'dartVersion': 'test', 'os': 'test', 'cpu': cpu},
    ),
];

Future<List<String>> _writeReports(
  Directory directory,
  Iterable<BenchmarkReport> reports,
) async {
  final paths = <String>[];
  for (final (index, report) in reports.indexed) {
    final file = File('${directory.path}/report-$index.json');
    await file.writeAsString(jsonEncode(report.toJson()));
    paths.add(file.path);
  }
  return paths;
}

Map<String, Object?> _schema2Baseline({String? secondaryCpu}) {
  final json = _baseline().toJson();
  final references = Map<String, Object?>.from(json['references']! as Map);
  if (secondaryCpu != null) {
    final reference = Map<String, Object?>.from(references['test']! as Map);
    final environment = Map<String, Object?>.from(
      reference['environment']! as Map,
    )..['cpu'] = secondaryCpu;
    references[secondaryCpu] = {...reference, 'environment': environment};
  }
  json['references'] = references;
  return json;
}

/// A reference recorded from the same synthetic reports the tests evaluate,
/// so an unchanged build sits exactly on its own recorded numbers.
GateBaseline _baseline() =>
    recordGateBaseline(_completeReports(), '2026-01-01');

Map<String, Object?> _schema2BaselineWithoutEnvironment() {
  final json = _schema2Baseline();
  final references = Map<String, Object?>.from(json['references']! as Map);
  final reference = Map<String, Object?>.from(references['test']! as Map)
    ..remove('environment');
  json['references'] = {...references, 'test': reference};
  return json;
}

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
    'wasm' => const {
      'detector': 'dart2wasm.compile-time-define',
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
  Map<String, String>? versions,
}) => BenchmarkReport(
  runtime: report.runtime,
  detectedRuntime: detectedRuntime ?? report.detectedRuntime,
  runtimeProvenance: runtimeProvenance ?? report.runtimeProvenance,
  sourceRevision: sourceRevision ?? report.sourceRevision,
  run: run ?? report.run,
  versions: versions ?? report.versions,
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
