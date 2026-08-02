# Format 3 benchmark reports

`benchmark/runner.dart` is a correctness-first harness. Before it starts a
stopwatch, it evaluates the Format 3 candidate and its frozen comparator (or
explicit output reference) once and requires both to match the hand-authored
expected outcome.

All gateable reports must carry the full, lowercase, 40-character revision of
the source they measured. Obtain it once from a clean committed checkout, then
replace `<40hex>` in every compile or run command below with that
exact value:

```sh
rtk git rev-parse HEAD
```

Run a gate-eligible JIT measurement with at least seven recorded rounds:

```sh
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
```

The shortened command is for local diagnosis only and must say `--smoke`:

```sh
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/brace-smoke.json
```

Every report has `schemaVersion`, `runtime`, `run`, `versions`,
`sourceRevision`, raw `samples`, per-scenario medians, and candidate/baseline
ratios. Reports deliberately have no gate result; `benchmark/gates.dart` owns
gating. A smoke report has `smoke: true` and `gateable: false`, may omit a
source revision, and is rejected by gates.

Run the six full reports (two JIT, two AOT, and two printf-only JavaScript)
before merging them. The `--runtime` value is checked against runtime-detected
provenance: JIT and AOT use `dart.vm.product`; JavaScript records both a
dart2js compile-time Dart-version define and the Node runtime version.

Gateable JavaScript reports require `node --version` to print exactly
`v24.8.0`. Pin that version on `PATH` (for example with CI's Node setup) and
verify it before running the JavaScript commands:

```sh
rtk node --version
```

```sh
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=2 --output=/private/tmp/format3-jit-2.json

rtk dart compile exe -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart -o /private/tmp/format3-benchmark-aot
rtk /private/tmp/format3-benchmark-aot --runtime=aot --run=1 --output=/private/tmp/format3-aot-1.json
rtk /private/tmp/format3-benchmark-aot --runtime=aot --run=2 --output=/private/tmp/format3-aot-2.json

rtk dart compile js -O4 -Dformat.benchmark.dartCompilerVersion=3.12.2 -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart -o /private/tmp/format3-benchmark.js
rtk node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json
rtk node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=2 --output=/private/tmp/format3-js-2.json
```

On macOS only, if the system `node` is not pinned, the Darwin ARM64 package can
be used as a local workaround after verifying its version; do not substitute
this package for the cross-platform commands above:

```sh
rtk npx -y node-bin-darwin-arm64@24.8.0 --version
rtk npx -y node-bin-darwin-arm64@24.8.0 /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json
```

Merge the reports after all six commands finish:

```sh
rtk dart run benchmark/gates.dart --reports=/private/tmp/format3-jit-1.json,/private/tmp/format3-jit-2.json,/private/tmp/format3-aot-1.json,/private/tmp/format3-aot-2.json,/private/tmp/format3-js-1.json,/private/tmp/format3-js-2.json --output=/private/tmp/format3-gates.json
```

The merge rejects smoke/non-gateable reports, fewer than seven or mismatched
rounds, missing runtime/dialect/run pairs, missing or mismatched detected
runtime provenance, omitted matrix scenarios, invalid ratios, missing raw
samples, and absent or inconsistent source, Node, or Dart provenance. Its JSON
retains each report's environment, absolute median times and ratios, two-run
reproduction evidence, geometric means, and AOT executable size. A threshold
fails only when the same violation reproduces in both runs.

`comparisonKind` distinguishes frozen performance intersections
(`performance`) from `correctnessOnly` output references and `informational`
Format 3 features. Only `performance` scenarios have a ratio. `brace.locale.n`
uses an explicit `CNumberLocale` reference because Format 2 has no `n`
conversion. `brace.format_intl` checks a separate `IntlNumberLocale` adapter
instance; it is not a performance competitor. The frozen sprintf7 baseline has
no `%c`, `%u`, `%a`, or invalid-conversion detection counterpart, so those
scenarios are informational.
