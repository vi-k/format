# Restore the user-owned example benchmark

## Context

Commit `adabb6d` replaced the existing `example/bin/benchmark.dart`, removed
its `SprintfBenchmark` and `Format2Benchmark` adapters, and replaced its test
matrix with a release-oriented Legacy/Current gate. The original source is
recoverable from commit
`d865cd21056754a2815b23a74f48799756f5ebb9`.

The replacement benchmark is also currently broken. Its Unicode fill scenario
uses a family emoji as one grapheme, while its immutable `Format` instance uses
the default `TextUnit.unicodeScalars`. The scenario therefore throws
`InvalidSpecifierException`; the same template succeeds with
`TextUnit.graphemeClusters`.

## Goal

Restore the original benchmark experience and scenario matrix without
restoring the obsolete Format 2 implementation to the package's public API.
Preserve the newer gate benchmark under a distinct, descriptive entrypoint so
that it no longer replaces user-owned code.

## Considered approaches

### 1. Restore the old production API verbatim

Restore `format2()` to `lib/format.dart`, restore the external `sprintf`
dependency, and check out the historical example files unchanged.

This gives the closest textual restoration but reintroduces an obsolete public
API solely for a benchmark. It also couples release code to historical
implementations. This approach is rejected.

### 2. Keep the replacement as `benchmark.dart`

Add the historical benchmark under a second filename and fix only the Unicode
scenario in the replacement.

This preserves current paths but does not restore ownership or the established
meaning of `example/bin/benchmark.dart`. This approach is rejected.

### 3. Restore the original entrypoint with benchmark-local adapters

Restore the historical driver, scenario matrix, output helpers, and three
engine layout. Adapt only the engine boundaries:

- current Format uses Format 3's immutable `Format`/`formatWith` API;
- Format 2 uses a benchmark-local frozen implementation;
- sprintf uses the frozen sprintf 7 benchmark implementation;
- the newer Legacy/Current gate moves to a separately named entrypoint.

This is the selected approach. It restores the user's benchmark while keeping
legacy code out of production and public exports.

## Architecture and file boundaries

`example/bin/benchmark.dart` again owns the historical, human-readable driver:
it iterates the restored brace/printf test matrix, invokes three benchmark
engines, checks each output, and prints timing plus colored diffs.

The historical support classes are restored under `example/lib/src/`:

- `format_benchmark.dart` targets the current Format 3 API;
- `format2_benchmark.dart` targets a benchmark-local Format 2 adapter;
- `sprintf_benchmark.dart` targets the frozen sprintf 7 adapter;
- `my_benchmark_base.dart`, `tests/tests.dart`, and `utils/output.dart` retain
  their original roles.

No legacy implementation is exported from `lib/format.dart`. Existing frozen
sources are imported only by example/benchmark code. If a direct relative
import would make package analysis unreliable, a thin adapter is placed inside
`example/lib/src/baselines/`; it contains no new formatting behavior and records
the exact frozen source provenance.

The replacement Legacy/Current gate is preserved as
`example/bin/format2_gate_benchmark.dart` with isolated support files under
`example/lib/src/format2_gate/`. Its Unicode scenario constructs its `Format`
with `TextUnit.graphemeClusters`, matching the scenario's expected semantics.

The release-grade cross-runtime harness remains `benchmark/runner.dart`; it is
not moved or renamed by this restoration.

## Data flow

The restored driver selects the brace or printf template for each engine,
passes the same values, verifies the exact expected string before accepting a
timing, and prints a localized diff on mismatch. Historical Format 2 and
sprintf execute only through their benchmark-local adapters.

The separate gate entrypoint keeps its current Legacy/Current scenarios and
threshold output. It does not share mutable registration state with the
restored benchmark.

## Error handling

Each restored engine remains isolated by the driver's per-engine exception
handling, so one unsupported case is printed as an error without hiding other
engine results. Output mismatches remain visible as colored expected/actual
diffs.

The gate entrypoint continues to fail fast when a scenario's output differs,
because its timings are meaningful only after exact output verification.

## Testing and acceptance

Implementation follows RED/GREEN TDD.

Automated tests must prove:

1. the restored benchmark exposes all three engines;
2. representative integer and multi-placeholder scenarios produce identical
   expected output across their applicable engines;
3. the original driver retains separate brace and printf templates;
4. the gate benchmark's family-emoji fill succeeds under grapheme-cluster
   semantics;
5. neither historical baseline is imported or exported by production code.

Verification commands run from `example/` include focused tests, `dart analyze`,
and smoke execution of both entrypoints. The repository-wide Dart test suite is
then run once. Existing `.vscode` changes are never staged or modified.

## Non-goals

- Restoring `format2()` to the public Format 3 API.
- Replacing the release harness in `benchmark/runner.dart`.
- Changing performance thresholds or the frozen baseline behavior.
- Rewriting the historical benchmark's presentation or scenario intent.
