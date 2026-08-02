# Frozen Format 2 benchmark baseline

This directory contains the benchmark-local, positional-formatting subset of
Format 2 from this repository's commit `86febb4`.

## Reproduction

The historical sources were inspected read-only with these commands:

```sh
rtk git show 86febb4:LICENSE
rtk git show 86febb4:lib/format.dart
rtk git show 86febb4:lib/src/processor.dart
rtk git show 86febb4:lib/src/formatter.dart
rtk git show 86febb4:lib/src/options.dart
rtk git show 86febb4:lib/src/format.dart
rtk git show 86febb4:lib/src/errors.dart
rtk git show 86febb4:lib/src/utils/utils.dart
```

`LICENSE` is an exact copy of the repository-root `LICENSE`.

## Scope and mechanical namespacing

`format2.dart` exposes only `legacyFormat(String, List<Object?>)`. The copied
implementation keeps the Format 2 positional parser and its string, character,
integer, and double built-ins used by the benchmark scenarios. Named arguments,
formatter registration, and the `n` formatter are omitted because they are not
reachable through that local API or selected scenarios.

To prevent benchmark code from creating package-level collisions, every copied
implementation declaration is private and prefixed `_Format2` (or
`_format2`). Those prefix changes and the conversion from historical source
files to `part` files are mechanical namespacing edits only; formatting logic
is otherwise retained from `86febb4` for the retained paths.

## Benchmark-only policy

This baseline is a reproducible performance comparator. It is not a public
package API, a production dependency, or a correctness oracle. Do not export
it from `lib/format.dart`.
