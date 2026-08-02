# Frozen `sprintf` 7.0.0 benchmark baseline

This directory vendors package `sprintf` version 7.0.0 from the official
upstream repository:

- Upstream: <https://github.com/Naddiseo/dart-sprintf>
- Commit: `f1e74f2f4c339d983f9d011b4ba1df4ec8b8857c`
- Tag: `7.0.0`
- License: BSD-2-Clause; the upstream `LICENSE` is preserved verbatim.

The tag, upstream `master`, and requested short commit `f1e74f2` were verified
to resolve to the full commit above before copying. All files under `lib/` and
`LICENSE` are byte-for-byte copies from that commit.

## Dart 3 compatibility

No Dart source edits were required. The nested `analysis_options.yaml` only
turns off this host package's strict analysis modes for the frozen Dart 2-era
source; it does not change runtime behavior. No upstream formatting, naming,
or lint cleanup was applied.

## Benchmark-only policy

This baseline is a reproducible performance competitor only. It is not a
correctness oracle, must not define expected behavior, and must never be
exported by `lib/format.dart` or another production library.
