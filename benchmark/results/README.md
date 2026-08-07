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
git rev-parse HEAD
```

Run a gate-eligible JIT measurement with at least seven recorded rounds:

```sh
dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
```

The shortened command is for local diagnosis only and must say `--smoke`:

```sh
dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/brace-smoke.json
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
node --version
```

```sh
dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json
dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --run=2 --output=/private/tmp/format3-jit-2.json

dart compile exe -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart -o /private/tmp/format3-benchmark-aot
/private/tmp/format3-benchmark-aot --runtime=aot --run=1 --output=/private/tmp/format3-aot-1.json
/private/tmp/format3-benchmark-aot --runtime=aot --run=2 --output=/private/tmp/format3-aot-2.json

dart compile js -O4 -Dformat.benchmark.dartCompilerVersion=3.12.2 -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart -o /private/tmp/format3-benchmark.js
node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json
node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=2 --output=/private/tmp/format3-js-2.json
```

On macOS only, if the system `node` is not pinned, the Darwin ARM64 package can
be used as a local workaround after verifying its version; do not substitute
this package for the cross-platform commands above:

```sh
npx -y node-bin-darwin-arm64@24.8.0 --version
npx -y node-bin-darwin-arm64@24.8.0 /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json
```

Both JavaScript commands cover the whole matrix; `--dialect=printf` is for
local diagnosis only. Braces compile and run under dart2js like any other
dialect, and they are the runtime's most expensive scenarios, so the gate
requires them.

Merge the reports after all six commands finish, passing the recorded
reference:

```sh
dart run benchmark/gates.dart --reports=/private/tmp/format3-jit-1.json,/private/tmp/format3-jit-2.json,/private/tmp/format3-aot-1.json,/private/tmp/format3-aot-2.json,/private/tmp/format3-js-1.json,/private/tmp/format3-js-2.json --baseline=benchmark/results/gate-baseline.json --output=/private/tmp/format3-gates.json
```

## The recorded reference

`benchmark/results/gate-baseline.json` holds the ratios an earlier build
measured, per runtime, dialect, phase, and scenario. The gate asks whether
this build drifted away from them, not whether it clears a fixed number.

The reason is that one set of constants cannot serve three runtimes. Against
the same frozen comparators, the candidate's ratios differ by an order of
magnitude between the VM and dart2js, so a limit tight enough to mean
anything on the VM fires immediately on JavaScript. A ratio, unlike an
absolute time, is measured candidate-against-comparator inside one process,
which is what makes a recorded one portable enough to compare against.

Tolerances live in `gates.dart`, not in the file: 1.15 on a phase geometric
mean, 1.25 on a key scenario, 1.40 on any other scenario. A limit fails only
when both runs breach it.

**The recorded numbers state what is, not what is acceptable.** Where a
runtime is slow today the reference says so, and the gate's job is then to
keep it from getting worse.

Re-record after an intentional performance change, and after adding or
renaming a scenario — a reference with no entry for a scenario is a hard
error rather than a silently skipped check:

```sh
dart run benchmark/gates.dart --reports=<the same six paths> --record=$(date +%F) --output=benchmark/results/gate-baseline.json
```

Record and evaluate on comparable machines. A reference taken on one CPU and
evaluated on another can drift by more than the tolerances allow; when the
gate runs in CI, re-record it from a CI run rather than from a laptop.

Each round is timed to a duration rather than to a fixed operation count, so
the two engines run different counts and a ratio is read per operation. The
target is `max(10 ms, 100 clock ticks)`, measured per machine: under dart2js
the clock advances in whole milliseconds, which is why a JavaScript run takes
minutes where a VM run takes seconds.

One consequence to keep in mind when reading a cold number: a longer round
means far more operations over the same 200 templates, so the cold phase now
sits even closer to the hot path than it did. Until the cold scenarios draw a
fresh template per operation, treat their ratios as hot ones.

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
