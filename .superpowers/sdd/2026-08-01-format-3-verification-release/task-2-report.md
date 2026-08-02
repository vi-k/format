# Task 2 report — Format 3 scenario harness

## RED evidence

`rtk dart test test/benchmark_scenarios_test.dart` initially failed to load the
three intentionally absent harness libraries (`benchmark/model.dart`,
`benchmark/scenarios.dart`, and `benchmark/runner.dart`). The initial test
also named the observable contracts: required matrix IDs, 200 pre-created cold
templates, smoke-only shortened samples, non-gateable smoke JSON, output
comparison before timing, and round-trip report JSON.

During integration, the real printf smoke run failed for `%c`, then `%u`.
Inspection of frozen sprintf7's formatter registry established that it has
neither conversion. Focused regression coverage was added first and observed
RED for each; both are now explicit informational scenarios. `%a/%A` and
invalid-conversion detection are likewise informational because sprintf7 has
no counterpart.

## Implementation

- Immutable scenario/sample/report value objects with JSON codecs, runtime/run
  metadata, versions, raw samples, medians, ratios, and no gate result.
- Complete brace/printf matrix covering literal/parser/API paths, field counts,
  text units, numeric variants, dynamic printf options, Unicode, locale,
  errors, and Format 3 extensions.
- Frozen Format2 and sprintf7 are performance comparators only where their
  output contract overlaps Format 3. Candidate/reference output is checked
  once before any stopwatch starts.
- Cold templates are generated and retained before timing (200 unique valid
  strings); hot scenarios keep one stable template. Each round alternates
  candidate→baseline and baseline→candidate, after three warmups and with a
  default of seven recorded rounds.
- `comparisonKind` serializes `performance`, `correctnessOnly`, or
  `informational`. C `n` uses an explicit C-locale output reference, while
  format_intl uses a separate IntlNumberLocale adapter/reference. Both are
  verified before timing but emit no ratio and cannot be gated as performance.
- `--samples=1` requires `--smoke`; smoke reports are visibly marked
  `smoke: true`, `gateable: false`.

## Verification

- RED: focused test missing-harness failure, then regression RED for frozen
  sprintf7 `%c` and `%u` classification.
- GREEN: `rtk dart test test/benchmark_scenarios_test.dart` — 7 passing tests.
- Smoke CLI: brace hot, brace cold, printf hot, and printf cold all completed
  with `--samples=1 --smoke`; the requested brace hot report was written to
  `/private/tmp/brace-smoke.json`.
- `rtk dart analyze` exited 0. It retains six pre-existing frozen Format2 info
  diagnostics plus four non-error harness style infos (three JSON factory
  suggestions and explicit CNumberLocale's redundant-default suggestion).
- `rtk dart test` — 284 passing tests.
- `rtk git diff --check` — clean.

## Files

- `benchmark/model.dart`
- `benchmark/scenarios.dart`
- `benchmark/runner.dart`
- `benchmark/results/README.md`
- `test/benchmark_scenarios_test.dart`

The required SDD task report is an intentional sixth created file, outside the
Task 2 deliverable list; no plan or ledger file was modified. Existing
`.vscode` changes remain unstaged and untouched.

## Self-review and concerns

The performance subset uses only verified frozen intersections. Reference-only
and informational scenarios are serialized distinctly, preventing Task 3 from
accidentally interpreting them as ratios. The harness reports elapsed values
from `Stopwatch` ticks converted to nanoseconds; these are measurement values,
not gate results. Task 3 still needs to reject `smoke: true` and
`gateable: false` reports when it implements gates.
