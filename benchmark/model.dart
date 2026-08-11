import 'dart:collection';

enum BenchmarkDialect { braces, printf }

enum BenchmarkPhase { cold, hot }

/// Whether a second engine is a timing baseline, a correctness reference, or
/// unavailable because this Format 3 feature has no overlapping counterpart.
enum BenchmarkComparisonKind { performance, correctnessOnly, informational }

enum BenchmarkApiPath { topLevel, withValues, tearOff, configured }

enum BenchmarkReferenceKind { executable, golden }

sealed class BenchmarkOutcome {
  const BenchmarkOutcome();

  Map<String, Object?> toJson();

  static BenchmarkOutcome fromJson(Map<String, Object?> json) =>
      switch (json['kind']) {
        'text' => TextOutcome(json['value']! as String),
        'error' => ErrorOutcome(json['category']! as String),
        _ => throw ArgumentError.value(json, 'json', 'Unknown outcome kind.'),
      };
}

final class TextOutcome extends BenchmarkOutcome {
  final String value;

  const TextOutcome(this.value);

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'value': value};
}

final class ErrorOutcome extends BenchmarkOutcome {
  final String category;

  const ErrorOutcome(this.category);

  @override
  Map<String, Object?> toJson() => {'kind': 'error', 'category': category};
}

bool outcomesEqual(BenchmarkOutcome first, BenchmarkOutcome second) => switch ((
  first,
  second,
)) {
  (TextOutcome(:final value), TextOutcome(value: final other)) =>
    value == other,
  (ErrorOutcome(:final category), ErrorOutcome(category: final other)) =>
    category == other,
  _ => false,
};

/// One measured operation: the call itself, returning the text it produced.
///
/// Deliberately not an outcome. Wrapping every call in a try/catch and an
/// allocated [TextOutcome] is what the harness used to measure alongside the
/// call, and on the VM that shape cost up to 26% of a fast candidate against
/// 2% of a slow comparator — an overhead the printed ratio then carried. The
/// outcome is still built, but once per scenario, at validation, where its
/// cost buys the check that the two engines agree.
///
/// A scenario whose expected outcome is an [ErrorOutcome] throws instead of
/// returning, and the runner times it inside a catch: there the frame is not
/// overhead but the thing being measured.
typedef BenchmarkOperation = String Function(int iteration);

final class BenchmarkScenario {
  final String id;
  final BenchmarkDialect dialect;
  final BenchmarkPhase phase;
  final bool keyScenario;
  final BenchmarkOutcome expected;

  /// The template this scenario formats on a given iteration.
  ///
  /// A cold scenario has to answer with one nobody has parsed yet, so it
  /// builds the template from the iteration rather than cycling a prepared
  /// list: a round now runs for a duration, and a list long enough for one
  /// machine's count would be short on the next, quietly turning cold
  /// measurements into cache hits.
  final String Function(int iteration) templateFor;

  final BenchmarkOperation candidate;
  final BenchmarkOperation? baseline;
  final BenchmarkComparisonKind comparisonKind;
  final String? comparisonRationale;
  final BenchmarkApiPath apiPath;
  final int fieldCount;
  final BenchmarkReferenceKind referenceKind;
  final String? referenceLabel;

  BenchmarkScenario({
    required this.id,
    required this.dialect,
    required this.phase,
    required this.keyScenario,
    required this.expected,
    required this.templateFor,
    required this.candidate,
    this.baseline,
    this.comparisonKind = BenchmarkComparisonKind.performance,
    this.comparisonRationale,
    this.apiPath = BenchmarkApiPath.withValues,
    this.fieldCount = 1,
    this.referenceKind = BenchmarkReferenceKind.executable,
    this.referenceLabel,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Must not be empty.');
    if (fieldCount < 1) throw ArgumentError.value(fieldCount, 'fieldCount');
    // Sampled rather than counted: what separates the phases is whether a
    // later iteration brings work the engine has already done.
    final first = templateFor(0);
    final second = templateFor(1);
    if (first.isEmpty) {
      throw ArgumentError.value(first, 'templateFor', 'Must not be empty.');
    }
    if (phase == BenchmarkPhase.hot && first != second) {
      throw ArgumentError.value(
        templateFor,
        'templateFor',
        'Hot scenarios repeat one stable template.',
      );
    }
    if (phase == BenchmarkPhase.cold && first == second) {
      throw ArgumentError.value(
        templateFor,
        'templateFor',
        'Cold scenarios need a template no iteration has used before.',
      );
    }
    if (comparisonKind == BenchmarkComparisonKind.informational &&
        baseline != null) {
      throw ArgumentError.value(
        baseline,
        'baseline',
        'Informational scenarios cannot have a reference engine.',
      );
    }
    if (comparisonKind != BenchmarkComparisonKind.informational &&
        baseline == null) {
      throw ArgumentError.value(
        baseline,
        'baseline',
        'Comparable scenarios require a reference engine.',
      );
    }
    if (comparisonKind == BenchmarkComparisonKind.correctnessOnly &&
        (comparisonRationale == null || comparisonRationale!.isEmpty)) {
      throw ArgumentError.value(
        comparisonRationale,
        'comparisonRationale',
        'Reference-only comparisons explain why no ratio is measured.',
      );
    }
    if (referenceKind == BenchmarkReferenceKind.golden &&
        (referenceLabel == null || referenceLabel!.isEmpty)) {
      throw ArgumentError('Golden references require a stable label.');
    }
  }

  bool get comparable => baseline != null;

  bool get includeRatio =>
      comparisonKind == BenchmarkComparisonKind.performance;
}

final class BenchmarkSample {
  final String scenarioId;
  final String engine;
  final int elapsedNanoseconds;
  final int operations;
  final int round;

  const BenchmarkSample({
    required this.scenarioId,
    required this.engine,
    required this.elapsedNanoseconds,
    required this.operations,
    required this.round,
  });

  Map<String, Object?> toJson() => {
    'scenarioId': scenarioId,
    'engine': engine,
    'elapsedNanoseconds': elapsedNanoseconds,
    'operations': operations,
    'round': round,
  };

  factory BenchmarkSample.fromJson(Map<String, Object?> json) =>
      BenchmarkSample(
        scenarioId: json['scenarioId']! as String,
        engine: json['engine']! as String,
        elapsedNanoseconds: json['elapsedNanoseconds']! as int,
        operations: json['operations']! as int,
        round: json['round']! as int,
      );
}

final class BenchmarkScenarioResult {
  final String scenarioId;
  final BenchmarkDialect dialect;
  final BenchmarkPhase phase;
  final bool keyScenario;
  final BenchmarkComparisonKind comparisonKind;
  final String? comparisonRationale;
  final String? referenceLabel;
  final int? candidateMedianNanoseconds;
  final int? baselineMedianNanoseconds;

  /// How many operations each median covers.
  ///
  /// The two engines are timed for a comparable duration rather than for a
  /// fixed number of operations, so a slow comparator does not force the fast
  /// candidate into a round too short to measure. That makes the counts
  /// differ, and makes them necessary for reading a median: [ratio] is the
  /// quotient of the per-operation times, not of these medians.
  final int? candidateOperations;
  final int? baselineOperations;
  final double? ratio;

  const BenchmarkScenarioResult({
    required this.scenarioId,
    required this.dialect,
    required this.phase,
    required this.keyScenario,
    required this.comparisonKind,
    required this.comparisonRationale,
    required this.referenceLabel,
    required this.candidateMedianNanoseconds,
    required this.baselineMedianNanoseconds,
    required this.candidateOperations,
    required this.baselineOperations,
    required this.ratio,
  });

  /// The candidate's time for one operation, or null when it was not timed.
  double? get candidateNanosecondsPerOperation =>
      _perOperation(candidateMedianNanoseconds, candidateOperations);

  /// The comparator's time for one operation, or null when there is none.
  double? get baselineNanosecondsPerOperation =>
      _perOperation(baselineMedianNanoseconds, baselineOperations);

  static double? _perOperation(int? elapsed, int? operations) =>
      elapsed == null || operations == null || operations < 1
          ? null
          : elapsed / operations;

  Map<String, Object?> toJson() {
    if (comparisonKind != BenchmarkComparisonKind.performance &&
        ratio != null) {
      throw ArgumentError('Only performance scenarios may have ratios.');
    }
    return {
      'scenarioId': scenarioId,
      'dialect': dialect.name,
      'phase': phase.name,
      'keyScenario': keyScenario,
      'comparisonKind': comparisonKind.name,
      'comparisonRationale': comparisonRationale,
      'referenceLabel': referenceLabel,
      'candidateMedianNanoseconds': candidateMedianNanoseconds,
      'baselineMedianNanoseconds': baselineMedianNanoseconds,
      'candidateOperations': candidateOperations,
      'baselineOperations': baselineOperations,
      'ratio': ratio,
    };
  }

  factory BenchmarkScenarioResult.fromJson(Map<String, Object?> json) =>
      BenchmarkScenarioResult(
        scenarioId: json['scenarioId']! as String,
        dialect: BenchmarkDialect.values.byName(json['dialect']! as String),
        phase: BenchmarkPhase.values.byName(json['phase']! as String),
        keyScenario: json['keyScenario']! as bool,
        comparisonKind: BenchmarkComparisonKind.values.byName(
          json['comparisonKind']! as String,
        ),
        comparisonRationale: json['comparisonRationale'] as String?,
        referenceLabel: json['referenceLabel'] as String?,
        candidateMedianNanoseconds: json['candidateMedianNanoseconds'] as int?,
        baselineMedianNanoseconds: json['baselineMedianNanoseconds'] as int?,
        candidateOperations: json['candidateOperations'] as int?,
        baselineOperations: json['baselineOperations'] as int?,
        ratio: (json['ratio'] as num?)?.toDouble(),
      ).._validate();

  void _validate() {
    if (comparisonKind != BenchmarkComparisonKind.performance &&
        ratio != null) {
      throw ArgumentError('Only performance scenarios may have ratios.');
    }
    if (candidateMedianNanoseconds != null && candidateOperations == null) {
      throw ArgumentError('A median without its operation count is unusable.');
    }
    if (baselineMedianNanoseconds != null && baselineOperations == null) {
      throw ArgumentError('A median without its operation count is unusable.');
    }
  }
}

final class BenchmarkReport {
  final String runtime;
  final String detectedRuntime;
  final Map<String, String> runtimeProvenance;
  final String sourceRevision;
  final int run;
  final Map<String, String> versions;
  final int? executableSizeBytes;
  final bool smoke;
  final bool gateable;
  final int warmupRounds;
  final int recordedRounds;
  final List<BenchmarkSample> samples;
  final List<BenchmarkScenarioResult> scenarios;

  BenchmarkReport({
    required this.runtime,
    required this.detectedRuntime,
    required Map<String, String> runtimeProvenance,
    required this.sourceRevision,
    required this.run,
    required Map<String, String> versions,
    this.executableSizeBytes,
    required this.smoke,
    required this.gateable,
    required this.warmupRounds,
    required this.recordedRounds,
    required Iterable<BenchmarkSample> samples,
    required Iterable<BenchmarkScenarioResult> scenarios,
  }) : runtimeProvenance = UnmodifiableMapView(Map.of(runtimeProvenance)),
       versions = UnmodifiableMapView(Map.of(versions)),
       samples = List.unmodifiable(samples),
       scenarios = List.unmodifiable(scenarios) {
    if (smoke && gateable) {
      throw ArgumentError('Smoke reports are not gateable.');
    }
    if (gateable && recordedRounds < 7) {
      throw ArgumentError('Gateable reports require seven rounds.');
    }
    if (executableSizeBytes != null && executableSizeBytes! < 1) {
      throw ArgumentError.value(
        executableSizeBytes,
        'executableSizeBytes',
        'Must be positive when present.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'runtime': runtime,
    'detectedRuntime': detectedRuntime,
    'runtimeProvenance': runtimeProvenance,
    'sourceRevision': sourceRevision,
    'run': run,
    'versions': versions,
    'executableSizeBytes': executableSizeBytes,
    'smoke': smoke,
    'gateable': gateable,
    'warmupRounds': warmupRounds,
    'recordedRounds': recordedRounds,
    'samples': samples.map((sample) => sample.toJson()).toList(),
    'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
  };

  factory BenchmarkReport.fromJson(Map<String, Object?> json) =>
      BenchmarkReport(
        runtime: json['runtime']! as String,
        detectedRuntime: json['detectedRuntime']! as String,
        runtimeProvenance: (json['runtimeProvenance']! as Map<Object?, Object?>)
            .map((key, value) => MapEntry(key! as String, value! as String)),
        sourceRevision: json['sourceRevision']! as String,
        run: json['run']! as int,
        versions: (json['versions']! as Map<Object?, Object?>).map(
          (key, value) => MapEntry(key! as String, value! as String),
        ),
        executableSizeBytes: json['executableSizeBytes'] as int?,
        smoke: json['smoke']! as bool,
        gateable: json['gateable']! as bool,
        warmupRounds: json['warmupRounds']! as int,
        recordedRounds: json['recordedRounds']! as int,
        samples: (json['samples']! as List<Object?>).map(
          (sample) => BenchmarkSample.fromJson(sample! as Map<String, Object?>),
        ),
        scenarios: (json['scenarios']! as List<Object?>).map(
          (scenario) => BenchmarkScenarioResult.fromJson(
            scenario! as Map<String, Object?>,
          ),
        ),
      );
}
