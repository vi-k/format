/// Choosing how long a measured round has to be for the clock underneath it.
///
/// A fixed operation count cannot serve every runtime. On the Dart VM the
/// clock advances in tens of nanoseconds, so twenty thousand short operations
/// span hundreds of ticks and the quantum disappears. Under dart2js it
/// advances in whole milliseconds: the same round resolves to one tick or
/// zero, and every figure the suite prints becomes a quotient of small
/// integers — 0 ns, 50 ns, 100 ns, and nothing in between. dart2wasm sits
/// with the VM.
///
/// So the count is calibrated against the clock actually running rather than
/// written down. The same reasoning, and the same shape, as
/// `benchmark/runner.dart` in the parent package.
library;

/// How many clock ticks a measured round should span, so the clock's own
/// quantum stays about a percent of the measurement.
const _targetTicks = 100;

/// A round this short measures the scheduler as much as the code, however
/// fine the clock is, so the target never falls below it.
const _floorNanoseconds = 10000000;

const _minimumOperations = 256;

/// A ceiling, in case a clock never advances and the search would not
/// otherwise terminate.
const _maximumOperations = 100000000;

/// The smallest interval this clock can report, in nanoseconds.
///
/// Measured rather than derived from `Stopwatch.frequency`, which names the
/// unit the clock counts in and not the step it actually advances by. Under
/// dart2js the two disagree by six orders of magnitude.
int clockStepNanoseconds() {
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

/// How long a measured round should last on this machine, in nanoseconds.
int targetRoundNanoseconds() {
  final resolved = clockStepNanoseconds() * _targetTicks;

  return resolved > _floorNanoseconds ? resolved : _floorNanoseconds;
}

/// An operation count whose round reaches [targetRoundNanoseconds].
///
/// [round] runs the work that many times; it is called repeatedly here, which
/// doubles as warm-up. Growth is held between doubling and eightfold so one
/// slow reading cannot pick an enormous count.
int calibratedOperations(void Function(int operations) round) {
  final target = targetRoundNanoseconds();
  var operations = _minimumOperations;
  while (operations < _maximumOperations) {
    // Each trial is timed twice and the shorter reading kept, which corrects
    // two errors that push the same way. Noise only ever adds time, so of two
    // readings of the same work the smaller is the honest one; and the second
    // runs on a warmer JIT than the first, which is the state every recorded
    // round will be in. Both make a single first reading an overestimate, and
    // an overestimated trial ends calibration early — leaving every recorded
    // round too short for the clock to resolve. The failure is quiet: the
    // numbers still look like numbers, only noisier. `benchmark/runner.dart`
    // hit exactly that and was corrected; this copy kept the defect, and it is
    // the one local A/B measurements are made with.
    var elapsed = 0;
    for (var probe = 0; probe < 2; probe++) {
      final stopwatch = Stopwatch()..start();
      round(operations);
      stopwatch.stop();
      final probed = stopwatch.elapsedTicks * 1000000000 ~/ stopwatch.frequency;
      if (probe == 0 || probed < elapsed) elapsed = probed;
    }
    if (elapsed >= target) return operations;
    // A clock too coarse to see this round says nothing about how much longer
    // it needs, so grow by the maximum step instead of dividing by zero.
    var next =
        elapsed <= 0
            ? operations * 8
            : (operations * (target / elapsed)).ceil();
    if (next < operations * 2) next = operations * 2;
    if (next > operations * 8) next = operations * 8;
    operations = next > _maximumOperations ? _maximumOperations : next;
  }

  return operations;
}
