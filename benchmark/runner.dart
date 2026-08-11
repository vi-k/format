import 'dart:convert';

import 'model.dart';
import 'scenarios.dart';
import 'src/parser_platform.dart' as platform;

const int _warmupRounds = 3;
const int _minimumRecordedRounds = 7;

/// How many clock ticks a measured round should span, so that the clock's
/// own quantum stays about a percent of the measurement.
///
/// A fixed operation count cannot serve both engines on both platforms. Under
/// dart2js the clock advances in whole milliseconds, so a round of ten
/// thousand operations resolved to a handful of ticks and every ratio became
/// a quotient of small integers — two runs of the same build disagreed by up
/// to 150% on a single scenario. Timing to a duration instead bounds that
/// quantum on any clock, and lets a fast candidate and a slow comparator each
/// run the count it needs.
const int _targetRoundTicks = 100;

/// A round this short measures the scheduler as much as the code, however
/// fine the clock is, so the target never falls below it.
const int _minimumRoundNanoseconds = 10000000;

/// The floor for a smoke run: a quick check, but still long enough to
/// register — a round that measures zero would make the ratio a division of
/// zero by zero.
const int _smokeRoundNanoseconds = 2000000;

/// The target for a measured round on this machine, for tests to assert
/// against without restating the arithmetic.
int benchmarkTargetRoundNanoseconds({bool smoke = false}) {
  final floor = smoke ? _smokeRoundNanoseconds : _minimumRoundNanoseconds;
  final resolved = _clockResolutionNanoseconds() * _targetRoundTicks;

  return resolved > floor ? resolved : floor;
}

/// Measures the smallest interval this clock can report.
///
/// The measurement stands in for `Stopwatch.frequency`, which names the unit
/// the clock counts in rather than the step it actually advances by. Here the
/// two happen to agree — a nanosecond frequency on the VM stepping by tens of
/// nanoseconds, a millisecond frequency under dart2js stepping by one — but
/// the target depends on the step, so the step is what gets measured.
int _clockResolutionNanoseconds() {
  final stopwatch = Stopwatch()..start();
  var smallest = 0;
  for (var probe = 0; probe < 5; probe++) {
    final start = stopwatch.elapsedTicks;
    var delta = 0;
    while (delta == 0) {
      delta = stopwatch.elapsedTicks - start;
    }
    if (smallest == 0 || delta < smallest) smallest = delta;
  }

  return smallest * 1000000000 ~/ stopwatch.frequency;
}

const int _minimumOperations = 64;

/// A ceiling on the calibrated count, in case a clock never advances and the
/// search would otherwise not terminate.
const int _maximumOperations = 100000000;

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
  final detectedRuntime = platform.detectedRuntime();
  if (options.runtime != detectedRuntime) {
    throw ArgumentError.value(
      options.runtime,
      'runtime',
      'Does not match detected runtime $detectedRuntime.',
    );
  }
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
  final operations = {
    for (final scenario in selected)
      scenario.id: _calibrateScenario(scenario, smoke: options.smoke),
  };
  for (var round = 0; round < _warmupRounds; round++) {
    for (final scenario in selected) {
      _measureRound(
        scenario,
        round,
        operations[scenario.id]!,
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
        operations[scenario.id]!,
        record: true,
        sink: rawSamples,
      );
    }
  }

  final results = selected.map(
    (scenario) => _resultFor(scenario, rawSamples, operations[scenario.id]!),
  );
  return BenchmarkReport(
    runtime: detectedRuntime,
    detectedRuntime: detectedRuntime,
    runtimeProvenance: platform.runtimeProvenance(),
    sourceRevision: platform.sourceRevision(),
    run: options.run,
    versions: {
      ...platform.environmentInfo(),
      'format': '3.0.0',
      'format20Baseline': '86febb4',
      // Exact pub pin (byte-identical to the previously vendored
      // upstream commit f1e74f2).
      'sprintf70Baseline': '7.0.0/pub',
    },
    executableSizeBytes:
        detectedRuntime == 'aot' ? platform.executableSizeBytes() : null,
    smoke: options.smoke,
    gateable: !options.smoke,
    warmupRounds: _warmupRounds,
    recordedRounds: options.samples,
    samples: rawSamples,
    scenarios: results,
  );
}

void _validateScenario(BenchmarkScenario scenario) {
  final candidate = captureOutcome(scenario.candidate, 0);
  if (!outcomesEqual(candidate, scenario.expected)) {
    throw StateError(
      '${scenario.id}: candidate produced ${candidate.toJson()}, '
      'expected ${scenario.expected.toJson()}.',
    );
  }
  final baseline = scenario.baseline;
  if (baseline == null) return;
  final reference = captureOutcome(baseline, 0);
  if (!outcomesEqual(reference, scenario.expected)) {
    throw StateError(
      '${scenario.id}: reference produced ${reference.toJson()}, '
      'expected ${scenario.expected.toJson()}.',
    );
  }
}

/// The calibrated operation count for each engine of one scenario.
final class _ScenarioOperations {
  final int candidate;
  final int? baseline;

  const _ScenarioOperations(this.candidate, this.baseline);
}

_ScenarioOperations _calibrateScenario(
  BenchmarkScenario scenario, {
  required bool smoke,
}) {
  final baseline = scenario.includeRatio ? scenario.baseline : null;
  final target = benchmarkTargetRoundNanoseconds(smoke: smoke);

  return _ScenarioOperations(
    _calibrate(scenario, scenario.candidate, target),
    baseline == null ? null : _calibrate(scenario, baseline, target),
  );
}

/// Finds an operation count whose round reaches [target] nanoseconds.
///
/// The estimate is extrapolated from the trial that fell short, but a single
/// trial is noisy, so growth is held between doubling and eightfold: that
/// converges in a few trials without letting one slow reading pick an
/// enormous count. Calibration doubles as extra warm-up.
///
/// Each trial is timed twice and the shorter reading is kept, which corrects
/// two errors that push the same way. Noise only ever adds time, so of two
/// readings of the same work the smaller is the honest one; and the second
/// reading runs on a warmer JIT than the first, which is the state every
/// recorded round will actually be in. Both make a single first reading an
/// overestimate, and an overestimated trial ends calibration early — leaving
/// every recorded round too short for the clock to resolve. That failure is
/// quiet: the numbers still look like numbers, only noisier. A shared runner
/// produced exactly it, landing a round at half the length it was calibrated
/// for.
int _calibrate(
  BenchmarkScenario scenario,
  BenchmarkOperation operation,
  int target,
) {
  final throwing = scenario.expected is ErrorOutcome;
  var operations = _minimumOperations;
  while (true) {
    var elapsed = 0;
    for (var probe = 0; probe < 2; probe++) {
      final round = _timeRound(operation, 0, operations, throwing: throwing);
      // Calibration rounds are rounds: an operation that stops doing its work
      // is caught here, before it has been extrapolated into an operation
      // count that then looks merely fast.
      _verifyChecksum(scenario, operations, round.checksum);
      final probed = round.elapsedNanoseconds;
      if (probe == 0 || probed < elapsed) elapsed = probed;
    }
    if (elapsed >= target || operations >= _maximumOperations) {
      return operations;
    }
    // A clock too coarse to see this round says nothing about how much
    // longer it needs, so grow by the maximum step instead of dividing by
    // zero.
    var next =
        elapsed <= 0
            ? operations * 8
            : (operations * (target / elapsed)).ceil();
    if (next < operations * 2) next = operations * 2;
    if (next > operations * 8) next = operations * 8;
    operations = next > _maximumOperations ? _maximumOperations : next;
  }
}

/// One round, timed, with a checksum of everything it produced.
///
/// Nothing else in the round is observable. A compiler entitled to notice
/// that would be entitled to delete the call, and the report would keep
/// printing plausible numbers for an empty loop — so the round consumes what
/// each call returned and [_verifyChecksum] holds the total against what the
/// scenario's expected outcome implies. No elision happens today on any of
/// the three runtimes; that is luck, and this is the contract.
///
/// [throwing] belongs to scenarios whose expected outcome is an error. There
/// the frame is not overhead but the measurement, and the count of throws is
/// the checksum.
({int elapsedNanoseconds, int checksum}) _timeRound(
  BenchmarkOperation operation,
  int seed,
  int operations, {
  required bool throwing,
}) {
  var checksum = 0;
  final stopwatch = Stopwatch()..start();
  if (throwing) {
    for (var index = 0; index < operations; index++) {
      try {
        operation(seed + index);
      } on Object {
        checksum++;
      }
    }
  } else {
    for (var index = 0; index < operations; index++) {
      checksum += operation(seed + index).length;
    }
  }
  stopwatch.stop();

  return (
    elapsedNanoseconds:
        stopwatch.elapsedTicks * 1000000000 ~/ stopwatch.frequency,
    checksum: checksum,
  );
}

/// Refuses a round whose output does not add up to what the scenario promised.
///
/// A hot scenario writes the same text every time, so its total is exact. A
/// cold one suffixes the iteration, and the suffix only grows, so its total
/// has a floor rather than a value. An error scenario throws once per
/// operation and counts the throws.
void _verifyChecksum(BenchmarkScenario scenario, int operations, int checksum) {
  final expected = switch (scenario.expected) {
    TextOutcome(:final value) => operations * value.length,
    ErrorOutcome() => operations,
  };
  final exact = scenario.phase == BenchmarkPhase.hot;
  if (exact ? checksum == expected : checksum >= expected) return;

  throw StateError(
    '${scenario.id}: a round of $operations operations produced a checksum '
    'of $checksum, expected ${exact ? '' : 'at least '}$expected. The work '
    'was elided, or the operation stopped producing what the scenario says '
    'it produces.',
  );
}

void _measureRound(
  BenchmarkScenario scenario,
  int round,
  _ScenarioOperations operations, {
  required bool record,
  required List<BenchmarkSample> sink,
}) {
  void measureCandidate() => _measure(
    'candidate',
    scenario.candidate,
    scenario,
    round,
    operations.candidate,
    record,
    sink,
  );
  void measureBaseline() {
    final baseline = scenario.baseline;
    if (baseline == null || operations.baseline == null) return;
    _measure(
      'baseline',
      baseline,
      scenario,
      round,
      operations.baseline!,
      record,
      sink,
    );
  }

  // Alternating by round keeps a drift in machine state from landing on one
  // engine only.
  if (round.isEven) {
    measureCandidate();
    measureBaseline();
  } else {
    measureBaseline();
    measureCandidate();
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
  final result = _timeRound(
    operation,
    round * operations,
    operations,
    throwing: scenario.expected is ErrorOutcome,
  );
  // Checked on every round, warm-up included: a round that measured nothing
  // is worth catching where it happened, not after it has been averaged in.
  _verifyChecksum(scenario, operations, result.checksum);
  if (!record) return;
  sink.add(
    BenchmarkSample(
      scenarioId: scenario.id,
      engine: engine,
      elapsedNanoseconds: result.elapsedNanoseconds,
      operations: operations,
      round: round,
    ),
  );
}

BenchmarkScenarioResult _resultFor(
  BenchmarkScenario scenario,
  List<BenchmarkSample> samples,
  _ScenarioOperations operations,
) {
  final candidate = _median(samples, scenario.id, 'candidate');
  final baseline =
      !scenario.includeRatio || scenario.baseline == null
          ? null
          : _median(samples, scenario.id, 'baseline');
  // Per operation, because the two engines were timed to a duration rather
  // than to a shared count.
  final ratio =
      scenario.includeRatio
          ? (candidate / operations.candidate) /
              (baseline! / operations.baseline!)
          : null;
  final performance =
      scenario.comparisonKind == BenchmarkComparisonKind.performance;

  return BenchmarkScenarioResult(
    scenarioId: scenario.id,
    dialect: scenario.dialect,
    phase: scenario.phase,
    keyScenario: scenario.keyScenario,
    comparisonKind: scenario.comparisonKind,
    comparisonRationale: scenario.comparisonRationale,
    referenceLabel: scenario.referenceLabel,
    candidateMedianNanoseconds: candidate,
    baselineMedianNanoseconds: performance ? baseline : null,
    candidateOperations: operations.candidate,
    baselineOperations: performance ? operations.baseline : null,
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
