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
    final stopwatch = Stopwatch()..start();
    round(operations);
    stopwatch.stop();
    final elapsed = stopwatch.elapsedTicks * 1000000000 ~/ stopwatch.frequency;
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
