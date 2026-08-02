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
no gate result; Task 3 owns gating. A smoke report has `smoke: true` and
`gateable: false`, so gates must reject it.

`comparisonKind` distinguishes frozen performance intersections
(`performance`) from `correctnessOnly` output references and `informational`
Format 3 features. Only `performance` scenarios have a ratio. `brace.locale.n`
uses an explicit `CNumberLocale` reference because Format 2 has no `n`
conversion. `brace.format_intl` checks a separate `IntlNumberLocale` adapter
instance; it is not a performance competitor. The frozen sprintf7 baseline has
no `%c`, `%u`, `%a`, or invalid-conversion detection counterpart, so those
scenarios are informational.
