# JavaScript integral number canonicalization

Status: DONE

Base: `8878558` (`docs: define JavaScript number semantics`), on top of
`7018cd8`.

## Changes

- Added a VM/Node regression suite for empty formatting, every integer
  presentation (`d`, `b`, `o`, `x`, `X`, `c`), grouped alternate hex,
  explicit floating presentation, `!r`, `!a`, recursive container
  representation, and BigInt separation.
- Centralized the internal integer-value predicate. A finite dart2js number
  that passes `is int` is canonicalized as an integer, while distinguishable
  floating values such as infinities and negative zero remain on floating
  paths.
- Moved integer/BigInt dispatch before double dispatch in normal formatting
  and moved guarded integer representation before double representation.
  Explicit `f`, `e`, `g`, and `%` types still enter binary64 formatting.
- Added the sorted `dart-js-integral-number-canonicalization` divergence,
  raised the reviewed schema count from 9 to 10, and documented the stable
  `#javascript-number-semantics` README anchor.

## RED evidence

The first Node run, before production changes, failed both new behavioral
tests:

```sh
rtk dart test -p node test/js_number_dispatch_test.dart
```

- empty formatting returned `42.0` instead of `42`;
- `!a` and recursive container representation returned `42.0` instead of
  canonical integer spelling.

Adding the tenth divergence before updating its count guard also produced the
expected 9-vs-10 failure:

```sh
rtk dart test -p vm test/python_compatibility_test.dart
```

The self-review found a second dart2js classification edge. Its focused test
failed before the predicate refinement because infinity reached
`BigInt.from()` through the raw `is int` branch:

```sh
rtk dart test -p node test/js_number_dispatch_test.dart
```

## GREEN and verification evidence

```sh
rtk dart test -p node test/js_number_dispatch_test.dart
rtk dart test -p vm test/js_number_dispatch_test.dart test/integer_format_test.dart test/double_format_test.dart test/conversion_test.dart
rtk dart test -p vm
rtk dart analyze
rtk dart format --output=none --set-exit-if-changed lib test
rtk git diff --check
```

The standalone build smoke also compiled with dart2js and executed under
Node, checking canonical empty/integer/container output, explicit `f`, and
BigInt:

```sh
rtk dart compile js tool/js_number_smoke.dart -O2 -o /private/tmp/format-js-number-smoke.js
rtk node /private/tmp/format-js-number-smoke.js
```

The temporary smoke source was removed after the successful run. No fixture
generator or generated fixture was changed; the intentional-divergence file
is maintained separately.

## Dispatch audit and self-review

No material findings remain.

- Explicit floating specifiers are selected inside the canonical integer
  branch before integer formatting, for int, integral JavaScript double, and
  BigInt inputs.
- BigInt remains a distinct representation case and retains the binary64
  overflow guard when explicitly converted for floating formatting.
- The double-first conversion switch inside `formatBraceDouble` is not a
  value-kind dispatcher: it runs only after floating formatting has already
  been selected. Its overflow guard now uses the shared integer predicate so
  JavaScript infinities are not mistaken for converted integers.
- The remaining `is double`/`is num` occurrences under `lib` do not precede a
  competing integer value-kind branch.

## Commit

`fix: canonicalize integral JavaScript numbers`

## Concerns

The repository's general double-format tests encode VM expectations for
integral doubles and are therefore intentionally not a full Node suite. The
dedicated platform-aware Node suite is the normative JavaScript regression
entry point. No public API or static-type preservation was added.
