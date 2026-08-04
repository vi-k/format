# format benchmarks

This package contains runnable, ANSI-colored examples and performance checks
for `format`.

Run the restored original user benchmark (quick mode, ~35 s):

```console
dart run bin/benchmark.dart
```

Precise measurements with the benchmark_harness defaults (~4 min):

```console
dart run bin/benchmark.dart --full
```

Compare Format 3 against the frozen Format 2 baseline:

```console
dart run bin/format2_gate_benchmark.dart
```

Compare the Dart SDK and Python/C++-compatible decimal `double` profiles:

```console
dart run bin/double_modes_benchmark.dart
```

The double-mode report shows the template, input value, formatted result, and
median time for both profiles. Different results are highlighted so rounding
and notation changes are visible alongside performance. Timing differences up
to 5% are reported as equal by default. Library callers may change that limit
with the `equivalenceThresholdPercent` argument to `runDoubleModesBenchmark`.

VS Code launch configurations are available for every benchmark. Use
**Benchmark: all** to run the complete set.
