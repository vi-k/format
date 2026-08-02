import 'dart:convert';

import 'model.dart';
import 'scenarios.dart';
import 'src/parser_platform.dart' as platform;

const int _warmupRounds = 3;
const int _minimumRecordedRounds = 7;

final class BenchmarkRunOptions {
  final BenchmarkDialect? dialect;
  final BenchmarkPhase? phase;
  final String runtime;
  final int run;
  final int samples;
  final bool smoke;
  final String? output;

  const BenchmarkRunOptions({
    this.dialect,
    this.phase,
    this.runtime = 'jit',
    required this.run,
    this.samples = _minimumRecordedRounds,
    this.smoke = false,
    this.output,
  });
}

BenchmarkRunOptions parseRunnerOptions(List<String> arguments) {
  BenchmarkDialect? dialect;
  BenchmarkPhase? phase;
  var runtime = 'jit';
  var run = 1;
  var samples = _minimumRecordedRounds;
  var smoke = false;
  String? output;

  for (final argument in arguments) {
    if (argument == '--smoke') {
      smoke = true;
      continue;
    }
    final separator = argument.indexOf('=');
    if (!argument.startsWith('--') || separator < 3) {
      throw ArgumentError.value(
        argument,
        'arguments',
        'Expected --name=value.',
      );
    }
    final name = argument.substring(2, separator);
    final value = argument.substring(separator + 1);
    switch (name) {
      case 'dialect':
        dialect = _dialect(value);
      case 'phase':
        phase = _phase(value);
      case 'runtime':
        if (value.isEmpty) {
          throw ArgumentError.value(value, name, 'Must not be empty.');
        }
        runtime = value;
      case 'run':
        run = _positiveInt(name, value);
      case 'samples':
        samples = _positiveInt(name, value);
      case 'output':
        if (value.isEmpty) {
          throw ArgumentError.value(value, name, 'Must not be empty.');
        }
        output = value;
      default:
        throw ArgumentError.value(argument, 'arguments', 'Unknown option.');
    }
  }
  if (!smoke && samples < _minimumRecordedRounds) {
    throw ArgumentError.value(
      samples,
      'samples',
      'At least $_minimumRecordedRounds recorded rounds require --smoke.',
    );
  }
  return BenchmarkRunOptions(
    dialect: dialect,
    phase: phase,
    runtime: runtime,
    run: run,
    samples: samples,
    smoke: smoke,
    output: output,
  );
}

BenchmarkReport runBenchmark(
  BenchmarkRunOptions options, {
  Iterable<BenchmarkScenario>? scenarios,
}) {
  final selected = (scenarios ?? benchmarkScenarios)
      .where(
        (scenario) =>
            (options.dialect == null || scenario.dialect == options.dialect) &&
            (options.phase == null || scenario.phase == options.phase),
      )
      .toList(growable: false);
  if (selected.isEmpty) {
    throw ArgumentError('No scenarios match the selected dialect and phase.');
  }

  selected.forEach(_validateScenario);

  final rawSamples = <BenchmarkSample>[];
  final operations = options.smoke ? 1 : 100;
  for (var round = 0; round < _warmupRounds; round++) {
    for (final scenario in selected) {
      _measureRound(
        scenario,
        round,
        operations,
        record: false,
        sink: rawSamples,
      );
    }
  }
  for (var round = 0; round < options.samples; round++) {
    for (final scenario in selected) {
      _measureRound(
        scenario,
        round,
        operations,
        record: true,
        sink: rawSamples,
      );
    }
  }

  final results = selected.map((scenario) => _resultFor(scenario, rawSamples));
  return BenchmarkReport(
    runtime: options.runtime,
    run: options.run,
    versions: {
      ...platform.environmentInfo(),
      'format': '3.0.0',
      'format2Baseline': '86febb4',
      'sprintf7Baseline': '7.0.0/f1e74f2',
    },
    smoke: options.smoke,
    gateable: !options.smoke,
    warmupRounds: _warmupRounds,
    recordedRounds: options.samples,
    samples: rawSamples,
    scenarios: results,
  );
}

void _validateScenario(BenchmarkScenario scenario) {
  final candidate = scenario.candidate(0);
  if (!outcomesEqual(candidate, scenario.expected)) {
    throw StateError(
      '${scenario.id}: candidate produced ${candidate.toJson()}, '
      'expected ${scenario.expected.toJson()}.',
    );
  }
  final baseline = scenario.baseline;
  if (baseline == null) return;
  final reference = baseline(0);
  if (!outcomesEqual(reference, scenario.expected)) {
    throw StateError(
      '${scenario.id}: reference produced ${reference.toJson()}, '
      'expected ${scenario.expected.toJson()}.',
    );
  }
}

void _measureRound(
  BenchmarkScenario scenario,
  int round,
  int operations, {
  required bool record,
  required List<BenchmarkSample> sink,
}) {
  final candidateFirst = round.isEven;
  if (candidateFirst) {
    _measure(
      'candidate',
      scenario.candidate,
      scenario,
      round,
      operations,
      record,
      sink,
    );
    final baseline = scenario.baseline;
    if (baseline != null && scenario.includeRatio) {
      _measure('baseline', baseline, scenario, round, operations, record, sink);
    }
  } else {
    final baseline = scenario.baseline;
    if (baseline != null && scenario.includeRatio) {
      _measure('baseline', baseline, scenario, round, operations, record, sink);
    }
    _measure(
      'candidate',
      scenario.candidate,
      scenario,
      round,
      operations,
      record,
      sink,
    );
  }
}

void _measure(
  String engine,
  BenchmarkOperation operation,
  BenchmarkScenario scenario,
  int round,
  int operations,
  bool record,
  List<BenchmarkSample> sink,
) {
  final stopwatch = Stopwatch()..start();
  for (var operationIndex = 0; operationIndex < operations; operationIndex++) {
    operation(round * operations + operationIndex);
  }
  stopwatch.stop();
  if (!record) return;
  sink.add(
    BenchmarkSample(
      scenarioId: scenario.id,
      engine: engine,
      elapsedNanoseconds:
          stopwatch.elapsedTicks * 1000000000 ~/ stopwatch.frequency,
      operations: operations,
      round: round,
    ),
  );
}

BenchmarkScenarioResult _resultFor(
  BenchmarkScenario scenario,
  List<BenchmarkSample> samples,
) {
  final candidate = _median(samples, scenario.id, 'candidate');
  final baseline =
      !scenario.includeRatio || scenario.baseline == null
          ? null
          : _median(samples, scenario.id, 'baseline');
  final ratio = scenario.includeRatio ? candidate / baseline! : null;
  return BenchmarkScenarioResult(
    scenarioId: scenario.id,
    dialect: scenario.dialect,
    phase: scenario.phase,
    keyScenario: scenario.keyScenario,
    comparisonKind: scenario.comparisonKind,
    comparisonRationale: scenario.comparisonRationale,
    candidateMedianNanoseconds: candidate,
    baselineMedianNanoseconds:
        scenario.comparisonKind == BenchmarkComparisonKind.performance
            ? baseline
            : null,
    ratio: ratio,
  );
}

int _median(List<BenchmarkSample> samples, String scenarioId, String engine) {
  final values =
      samples
          .where(
            (sample) =>
                sample.scenarioId == scenarioId && sample.engine == engine,
          )
          .map((sample) => sample.elapsedNanoseconds)
          .toList()
        ..sort();
  if (values.isEmpty) throw StateError('No $engine samples for $scenarioId.');
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) ~/ 2;
}

BenchmarkDialect _dialect(String value) => switch (value) {
  'braces' => BenchmarkDialect.braces,
  'printf' => BenchmarkDialect.printf,
  _ =>
    throw ArgumentError.value(value, 'dialect', 'Expected braces or printf.'),
};

BenchmarkPhase _phase(String value) => switch (value) {
  'cold' => BenchmarkPhase.cold,
  'hot' => BenchmarkPhase.hot,
  _ => throw ArgumentError.value(value, 'phase', 'Expected cold or hot.'),
};

int _positiveInt(String name, String value) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    throw ArgumentError.value(value, name, 'Expected a positive integer.');
  }
  return parsed;
}

void main(List<String> arguments) {
  final options = parseRunnerOptions(platform.effectiveArguments(arguments));
  final report = runBenchmark(options);
  final output = const JsonEncoder.withIndent('  ').convert(report.toJson());
  if (options.output == null) {
    print(output);
  } else {
    platform.writeTextFile(options.output!, '$output\n');
  }
}
