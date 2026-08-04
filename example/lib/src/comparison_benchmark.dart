import 'my_benchmark_base.dart';

/// Parses benchmark CLI arguments: no flags select the quick mode, `--full`
/// selects the precise benchmark_harness defaults.
BenchmarkDurations parseBenchmarkArgs(List<String> args) => switch (args) {
  [] => BenchmarkDurations.quick,
  ['--full'] => BenchmarkDurations.full,
  _ => throw FormatException(
    'Unknown arguments: ${args.join(' ')}. '
    'Usage: benchmark.dart [--full]',
  ),
};
