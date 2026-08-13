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

"Clean committed checkout" is checked rather than trusted. Before evaluating
or recording anything, `gates.dart` compares the revision the reports carry
with `git rev-parse HEAD` and refuses when they differ or when a tracked file
is modified — the define is supplied from the shell, because a JavaScript
runtime cannot ask git, so three reports agreeing with each other proves only
that one define reached three processes. Untracked files are ignored, since a
measurement leaves its reports, its AOT executable and its compiled JavaScript
in the working directory.

Pass `--allow-unverified-revision` to evaluate reports recorded elsewhere —
on another machine, or before a commit that has since landed. Recording a
baseline accepts the same flag and is the place to think twice: the file it
writes becomes the reference every later run is compared against.

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

Run the eight full reports — two each on JIT, AOT, dart2js and dart2wasm —
before merging them. Both dialects are required on every runtime. The
`--runtime` value is checked against runtime-detected provenance: JIT and AOT
use `dart.vm.product`; the two web runtimes record a compile-time Dart-version
define and the Node runtime version, and are told apart by what the target
actually computes with, not by the label the command passed.

The Node version is not a fixed number any more. The gate compares the Node a
run used with the Node its reference was recorded on: a mismatch makes the run
undecidable rather than failed, which is also why upgrading Node without
re-recording is visible instead of silent.

```sh
revision="$(git rev-parse HEAD)"
define="-Dformat.benchmark.sourceRevision=$revision"
compiler="$(dart --version 2>&1 | sed -E 's/.*version: ([^ ]+).*/\1/')"

for run in 1 2; do
  dart run "$define" benchmark/runner.dart --runtime=jit --run="$run" --output="jit-$run.json"
done

dart compile exe "$define" benchmark/runner.dart -o benchmark-aot
for run in 1 2; do
  ./benchmark-aot --runtime=aot --run="$run" --output="aot-$run.json"
done

dart compile js -O4 "-Dformat.benchmark.dartCompilerVersion=$compiler" "$define" benchmark/runner.dart -o benchmark.js
for run in 1 2; do
  node benchmark.js --runtime=js --run="$run" --output="js-$run.json"
done

dart compile wasm -O2 "-Dformat.benchmark.dartCompilerVersion=$compiler" "$define" benchmark/runner.dart -o benchmark.wasm
for run in 1 2; do
  node benchmark/wasm_host.mjs benchmark.wasm --runtime=wasm --run="$run" --output="wasm-$run.json"
done
```

`-O4` for dart2js is not a detail: above `-O2` it drops the implicit type
checks it otherwise emits on every write into a typed list, which is worth
24–37% on cold parsing — measuring `-O2` would be measuring a build nobody
ships. The wasm host script is committed rather than generated, because a
harness that writes itself is one more thing that can differ between a laptop
and CI.

`--dialect=` narrows a run to one mini-language and is for local diagnosis
only: a gateable report carries the whole matrix, and braces are the most
expensive scenarios dart2js has.

Merge the reports after all eight commands finish, passing the recorded
reference:

```sh
dart run benchmark/gates.dart --reports=jit-1.json,jit-2.json,aot-1.json,aot-2.json,js-1.json,js-2.json,wasm-1.json,wasm-2.json --baseline=benchmark/results/gate-baseline.json --output=gate-report.json
```

The easier route is the workflow: `gh workflow run ci.yaml --ref main` runs
exactly the commands above on CI hardware, and `gh run download <id> -n
performance-gate` brings back the eight reports along with the gate's own
verdict.

## The recorded reference

`benchmark/results/gate-baseline.json` holds the ratios an earlier build
measured, per runtime, dialect, phase, and scenario. The gate asks whether
this build drifted away from them, not whether it clears a fixed number.

The reason is that one set of constants cannot serve four runtimes. Against
the same frozen comparators, the candidate's ratios differ by an order of
magnitude between the VM and dart2js, so a limit tight enough to mean
anything on the VM fires immediately on JavaScript. A ratio, unlike an
absolute time, is measured candidate-against-comparator inside one process,
which is what makes a recorded one portable enough to compare against.

Tolerances live in `gates.dart`, not in the file: 1.25 on a phase geometric
mean, 1.35 on a key scenario, 1.60 on any other scenario. A limit fails only
when both runs breach it — which guards against noise inside a job, but not
against the difference between the job that recorded the reference and the
job that checks it, since both runs share one machine. One measured pair of
jobs moved a phase mean by 14.3% with no change in the code, so the
tolerances have to cover that.

**The recorded numbers state what is, not what is acceptable.** Where a
runtime is slow today the reference says so, and the gate's job is then to
keep it from getting worse.

Re-record **immediately** after adding, renaming or removing a scenario: a
reference missing an entry the reports carry is a hard error, and so is a
reference carrying an entry the reports no longer have. Both directions are
errors rather than silently skipped checks, because either one changes how
much of the matrix is being checked.

After an intentional speed-up there is no hurry. The reference is one-sided —
a faster build never fails against it, it just stops being measured against
anything tight — so a stale one is safe and merely less useful. Re-record in
batches, when a run lands on the same processor model the reference was taken
on.

```sh
dart run benchmark/gates.dart --reports=<the same eight paths> --record=$(date +%F) --output=benchmark/results/gate-baseline.json
```

Record and evaluate on comparable machines. The committed reference is
recorded on CI hardware, because that is where the nightly gate runs; the
same reports evaluated on a laptop drifted by up to 16.2% on a phase mean,
against a 15% tolerance. Treat a local gate run as indicative and the CI one
as authoritative, and re-record from a CI run — dispatch the workflow, then
take the reports from its artifact.

"Comparable" is now recorded rather than assumed. A reference carries the
processor, the operating system, the Dart version and the Node version it was
measured on, and a run whose processor, Dart or Node differs decides nothing:
the report says `"comparable": false`, lists what moved, and the command
still exits zero. The ratios are computed and kept, so they can be read as
information — they are simply not a verdict about the code.

That is not a hypothetical. Three consecutive nightly runs landed on an Intel
Xeon 8573C, an EPYC 7763 and an EPYC 9V74, because a hosted pool hands out
what it has; the two hardware changes were reported as failures. A gate that
goes red for the pool teaches its reader to ignore it.

The operating system string is recorded and deliberately not compared: on a
hosted runner it carries a kernel build number that changes with every image
refresh without moving a timing.

A reference with no environment at all is refused outright, with the command
to re-record it. That is the loud choice of two: a gate that quietly decides
nothing, run after run, reads exactly like a gate that works.

Which machine the pool hands out is worth knowing before dispatching. Measured
across four dispatches on a fixed revision: two AMD models differ by at most
1.13 with the tolerance at 1.25, so they are interchangeable in practice,
while an Intel Xeon reaches 1.36 on `js/braces/cold` alone. The committed
reference is therefore recorded on the model that comes up most often, and a
night that lands elsewhere is expected to decide nothing.

Each round is timed to a duration rather than to a fixed operation count, so
the two engines run different counts and a ratio is read per operation. The
target is `max(10 ms, 100 clock ticks)`, measured per machine: under dart2js
the clock advances in whole milliseconds, which is why a JavaScript run takes
minutes where a VM run takes seconds.

A cold scenario draws a fresh template per operation — the iteration number is
suffixed to it, which costs both engines the same and so leaves the ratio
alone — so a cold ratio is a parsing ratio and reads as one. It is also the
phase most sensitive to the template cache, since a workload that never
repeats a template is precisely what the cache stops serving.

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
