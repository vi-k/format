# Format 3 benchmark reports

`benchmark/runner.dart` is a correctness-first harness. Before it starts a
stopwatch, it evaluates the Format 3 candidate and its frozen comparator (or
explicit output reference) once and requires both to match the hand-authored
expected outcome.

Run a gate-eligible JIT measurement with at least seven recorded rounds:

```sh
rtk dart run benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
```

The shortened command is for local diagnosis only and must say `--smoke`:

```sh
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/brace-smoke.json
```

Every report has `schemaVersion`, `runtime`, `run`, `versions`, raw `samples`,
per-scenario medians, and candidate/baseline ratios. Reports deliberately have
no gate result; `benchmark/gates.dart` owns gating. A smoke report has
`smoke: true` and `gateable: false`, so gates reject it.

Run the six full reports (two JIT, two AOT, and two printf-only JavaScript)
before merging them. The `--runtime` value is checked against runtime-detected
provenance: JIT and AOT use `dart.vm.product`; JavaScript uses a dart2js
compile-time Dart-version define. These commands use the installed Dart 3.12.2
and required Node 24.8.0 binary package.

```sh
rtk dart run benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
rtk dart run benchmark/runner.dart --runtime=jit --run=2 --output=/private/tmp/format3-jit-2.json

rtk dart compile exe benchmark/runner.dart -o /private/tmp/format3-benchmark-aot
rtk /private/tmp/format3-benchmark-aot --runtime=aot --run=1 --output=/private/tmp/format3-aot-1.json
rtk /private/tmp/format3-benchmark-aot --runtime=aot --run=2 --output=/private/tmp/format3-aot-2.json

rtk dart compile js -O4 -Dformat.benchmark.dartCompilerVersion=3.12.2 benchmark/runner.dart -o /private/tmp/format3-benchmark.js
rtk npx -y node-bin-darwin-arm64@24.8.0 /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json
rtk npx -y node-bin-darwin-arm64@24.8.0 /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=2 --output=/private/tmp/format3-js-2.json
```

Merge the reports after all six commands finish:

```sh
rtk dart run benchmark/gates.dart --reports=/private/tmp/format3-jit-1.json,/private/tmp/format3-jit-2.json,/private/tmp/format3-aot-1.json,/private/tmp/format3-aot-2.json,/private/tmp/format3-js-1.json,/private/tmp/format3-js-2.json --output=/private/tmp/format3-gates.json
```

The merge rejects smoke/non-gateable reports, fewer than seven or mismatched
rounds, missing runtime/dialect/run pairs, missing or mismatched detected
runtime provenance, omitted matrix scenarios, invalid ratios, and missing raw
samples. Its JSON retains each report's environment,
absolute median times and ratios, two-run reproduction evidence, geometric
means, and AOT executable size. A threshold fails only when the same violation
reproduces in both runs.

`comparisonKind` distinguishes frozen performance intersections
(`performance`) from `correctnessOnly` output references and `informational`
Format 3 features. Only `performance` scenarios have a ratio. `brace.locale.n`
uses an explicit `CNumberLocale` reference because Format 2 has no `n`
conversion. `brace.format_intl` checks a separate `IntlNumberLocale` adapter
instance; it is not a performance competitor. The frozen sprintf7 baseline has
no `%c`, `%u`, `%a`, or invalid-conversion detection counterpart, so those
scenarios are informational.
