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

typedef BenchmarkOperation = BenchmarkOutcome Function(int iteration);

final class BenchmarkScenario {
  final String id;
  final BenchmarkDialect dialect;
  final BenchmarkPhase phase;
  final bool keyScenario;
  final BenchmarkOutcome expected;
  final List<String> templates;
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
    required Iterable<String> templates,
    required this.candidate,
    this.baseline,
    this.comparisonKind = BenchmarkComparisonKind.performance,
    this.comparisonRationale,
    this.apiPath = BenchmarkApiPath.withValues,
    this.fieldCount = 1,
    this.referenceKind = BenchmarkReferenceKind.executable,
    this.referenceLabel,
  }) : templates = List.unmodifiable(templates) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Must not be empty.');
    if (fieldCount < 1) throw ArgumentError.value(fieldCount, 'fieldCount');
    if (this.templates.isEmpty) {
      throw ArgumentError.value(templates, 'templates', 'Must not be empty.');
    }
    if (phase == BenchmarkPhase.hot && this.templates.length != 1) {
      throw ArgumentError.value(
        templates,
        'templates',
        'Hot scenarios use exactly one stable template.',
      );
    }
    if (phase == BenchmarkPhase.cold && this.templates.length < 200) {
      throw ArgumentError.value(
        templates,
        'templates',
        'Cold scenarios pre-create at least 200 templates.',
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

  static BenchmarkSample fromJson(Map<String, Object?> json) => BenchmarkSample(
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
    required this.ratio,
  });

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
      'ratio': ratio,
    };
  }

  static BenchmarkScenarioResult fromJson(Map<String, Object?> json) =>
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
        ratio: (json['ratio'] as num?)?.toDouble(),
      ).._validate();

  void _validate() {
    if (comparisonKind != BenchmarkComparisonKind.performance &&
        ratio != null) {
      throw ArgumentError('Only performance scenarios may have ratios.');
    }
  }
}

final class BenchmarkReport {
  final String runtime;
  final int run;
  final Map<String, String> versions;
  final bool smoke;
  final bool gateable;
  final int warmupRounds;
  final int recordedRounds;
  final List<BenchmarkSample> samples;
  final List<BenchmarkScenarioResult> scenarios;

  BenchmarkReport({
    required this.runtime,
    required this.run,
    required Map<String, String> versions,
    required this.smoke,
    required this.gateable,
    required this.warmupRounds,
    required this.recordedRounds,
    required Iterable<BenchmarkSample> samples,
    required Iterable<BenchmarkScenarioResult> scenarios,
  }) : versions = UnmodifiableMapView(Map.of(versions)),
       samples = List.unmodifiable(samples),
       scenarios = List.unmodifiable(scenarios) {
    if (smoke && gateable)
      throw ArgumentError('Smoke reports are not gateable.');
    if (gateable && recordedRounds < 7)
      throw ArgumentError('Gateable reports require seven rounds.');
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'runtime': runtime,
    'run': run,
    'versions': versions,
    'smoke': smoke,
    'gateable': gateable,
    'warmupRounds': warmupRounds,
    'recordedRounds': recordedRounds,
    'samples': samples.map((sample) => sample.toJson()).toList(),
    'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
  };

  static BenchmarkReport fromJson(Map<String, Object?> json) => BenchmarkReport(
    runtime: json['runtime']! as String,
    run: json['run']! as int,
    versions: (json['versions']! as Map<Object?, Object?>).map(
      (key, value) => MapEntry(key! as String, value! as String),
    ),
    smoke: json['smoke']! as bool,
    gateable: json['gateable']! as bool,
    warmupRounds: json['warmupRounds']! as int,
    recordedRounds: json['recordedRounds']! as int,
    samples: (json['samples']! as List<Object?>).map(
      (sample) => BenchmarkSample.fromJson(sample! as Map<String, Object?>),
    ),
    scenarios: (json['scenarios']! as List<Object?>).map(
      (scenario) =>
          BenchmarkScenarioResult.fromJson(scenario! as Map<String, Object?>),
    ),
  );
}
