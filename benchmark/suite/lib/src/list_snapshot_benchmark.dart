/// Compares the ways of taking a defensive snapshot of an argument list.
///
/// The engine snapshots the collections handed to `Format.vsprintf` and
/// `Format.formatWith`, because formatting calls `toString` on their contents
/// and one of those can reach back and mutate the very list being formatted.
/// The snapshot is therefore not optional — but which snapshot is, and the
/// difference turned out to dominate the cost of a short call: `%d` with one
/// argument spent about a third of its time inside `List.unmodifiable`.
///
/// The strategies differ in what they promise. `List.unmodifiable` returns a
/// list that also refuses writes; `List.of(growable: false)` returns a plain
/// fixed-length copy; `List.of` returns a growable one. The engine never
/// writes to the snapshot, so the write barrier buys it nothing — which is
/// what this benchmark is here to show, and to keep showing if the SDK's
/// relative costs ever move.
///
/// Measured as the minimum over rounds rather than the mean: on a loaded
/// machine a mean inflates by a factor the fastest round does not.
library;

import 'utils/clock.dart';
import 'utils/output.dart';

typedef _Strategy = ({String name, List<Object?> Function(List<Object?>) take});

const _sizes = [0, 1, 2, 3, 5, 10, 50];
const _rounds = 40;
const _warmupOperations = 20000;

final _strategies = <_Strategy>[
  (name: 'no copy (floor)', take: (values) => values),
  (
    name: 'List.of(growable: false)',
    take: (values) => List<Object?>.of(values, growable: false),
  ),
  (name: 'List.of', take: List<Object?>.of),
  (name: '[...values]', take: (values) => <Object?>[...values]),
  (name: 'List.unmodifiable', take: List<Object?>.unmodifiable),
];

/// Prevents the copy from being optimized away.
///
/// Without a use of the result, nothing in the loop is observable and the
/// compiler is free to delete the allocation being measured — the benchmark
/// would then report the cost of an empty loop and look like a discovery.
///
/// Summed rather than xor-ed: xor-ing a constant length an even number of
/// times cancels to zero, which both weakens the guard and prints a total
/// that proves nothing.
int _checksum = 0;

double _measureNanos(
  List<Object?> Function(List<Object?>) take,
  List<Object?> values,
) {
  void round(int operations) {
    for (var operation = 0; operation < operations; operation++) {
      final snapshot = take(values);
      _checksum += snapshot.length;
    }
  }

  // Calibrated rather than fixed: a copy of a short list costs a few
  // nanoseconds, so the count that spans a comfortable stretch of the VM's
  // clock spans a single tick of the one dart2js has, and every row printed
  // there collapses onto multiples of 50 ns.
  final operations = calibratedOperations(round);
  var best = double.infinity;
  for (var index = 0; index < _rounds; index++) {
    final watch = Stopwatch()..start();
    round(operations);
    watch.stop();
    final nanos =
        watch.elapsedTicks * 1000000000 / watch.frequency / operations;
    if (nanos < best) best = nanos;
  }

  return best;
}

/// Runs the comparison and prints one row per list length.
void runListSnapshotBenchmark() {
  print(h1('Argument-list snapshot strategies'));
  print(
    faintAccent(
      'Minimum of $_rounds rounds, ns per snapshot; the operations per round '
      'are calibrated to the clock this runtime has. The engine never writes '
      'to the snapshot, so a write barrier is cost without benefit.',
    ),
  );
  print('');

  const nameWidth = 26;
  final header = StringBuffer('length'.padLeft(6));
  for (final strategy in _strategies) {
    header.write(strategy.name.padLeft(nameWidth));
  }
  print(h2(header.toString()));

  for (final size in _sizes) {
    final values = List<Object?>.generate(size, (index) => index);
    // Warm up every strategy on this length before timing any of them, so the
    // first column does not pay for the JIT the others then benefit from.
    for (final strategy in _strategies) {
      for (var operation = 0; operation < _warmupOperations; operation++) {
        _checksum += strategy.take(values).length;
      }
    }

    final timings = [
      for (final strategy in _strategies) _measureNanos(strategy.take, values),
    ];
    // The floor is not a candidate: it copies nothing, and is printed only to
    // show what the row is measured against.
    final fastest = timings.skip(1).reduce((a, b) => a < b ? a : b);

    final row = StringBuffer(size.toString().padLeft(6));
    for (var index = 0; index < timings.length; index++) {
      final cell = '${timings[index].toStringAsFixed(1)} ns'.padLeft(nameWidth);
      row.write(
        index == 0
            ? faintAccent(cell)
            : timings[index] == fastest
            ? accentOk(cell)
            : cell,
      );
    }
    print(row.toString());
  }

  print('');
  print(faintAccent('checksum $_checksum'));
}
