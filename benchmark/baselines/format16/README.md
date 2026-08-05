# format 1.6.0 baseline

The last published `format` release, used only as a benchmark
competitor. The package name collides with this repository's own
`format`, so it cannot be a regular pub dependency of the suite: one
resolution cannot hold two versions of the same package. Instead this
thin wrapper package (`format16_baseline`) exposes the pub sources
under a non-colliding name.

The implementation file `lib/src/format_base.dart` is **not
committed** — pub is the source of truth (it verifies the archive hash
on download). Materialize it once per clone:

```console
dart run benchmark/baselines/format16/fetch.dart
```

Provenance:

- Source: <https://pub.dev/packages/format/versions/1.6.0>
- Archive SHA-256 (verified by pub on download):
  `b6a2d9bdacd35d9161cdad37a2ab2f8fdcdaf1d37ca1dc84bbda8d46d7924875`
- `lib/src/format_base.dart` is the archive's file of the same path —
  the whole implementation; upstream's `lib/format.dart` is a bare
  export of it, mirrored here as `lib/format16.dart`.

Policy: benchmark-only. Do not edit, format, or "fix" the materialized
code — the point is measuring against the release exactly as
published. Known 1.6.0 behavior differences from format 3.0 are
handled by per-scenario `skipFormat16` flags in the benchmark suite,
with the reason recorded next to each flag.
