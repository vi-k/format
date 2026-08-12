# CHANGELOG

## 3.0.0

Upgrading from the published 1.6.0 also includes the changes of the
unpublished 2.0.0 below.

* Added a brace-formatting engine using the Python mini-language, with
  positional, named, item, and attribute lookup; conversions; nested fields;
  and typed errors.
* Added `sprintf` and `vsprintf` with a C-style subset for text, integer,
  decimal floating-point, and hexadecimal floating-point conversions.
* Added Dart SDK and Python/C++-compatible decimal `double` profiles. Dart SDK
  conversion is the default; compatible mode preserves nearest-even rounding,
  exponent layout, extended precision, and `inf`/`nan` spellings.
* Added configurable `NaN`/`Infinity` or `nan`/`inf` spelling in Dart SDK mode,
  and applied the selected profile recursively to `!r` and `!a` conversions.
* Represent empty Dart `Map` and `Set` values as `{}`.
* Added immutable `Format` instances with configurable custom formatters,
  lookups, representations, number locales, and Unicode text units.
* Bounded the template cache by memory as well as by entry count:
  `templateCacheMemoryLimit` (8 MiB per mini-language by default) and
  `templateCacheMemory` join `templateCacheCapacity` and `templateCacheSize`.
  Whichever bound binds first evicts, an entry priced above the whole budget is
  formatted but not cached, and lowering either bound discards entries
  immediately. The figure is an estimate — a Dart program cannot measure the
  memory it holds — priced from the template text, the slices its literals
  keep, the code units prepared for them, and a constant per parse node, with
  the constants fitted to measured retention. Bytes rather than characters
  because the same amount of text costs from 1 to 154 bytes per character
  depending on how densely it is fielded, which is what a character count
  cannot see. An entry is repriced when an engine of the other Unicode text
  unit reaches it: the parse is shared, but the compiled program and the
  specifications memoized under it are held per unit, and that second copy
  measures between a quarter and three fifths of the first price.
* A template with no fields — or a printf template with no conversion — is now
  formatted without copying it: it compiles to a single op that hands the text
  back by reference. Measured on the VM at 2.6 times faster for a sixteen
  character template and 4600 times for one of a hundred thousand, where the
  copies were the whole cost, and a cached entry for such a template retains
  about a third of what it did.
* Integers beyond 2^53 no longer go through `BigInt` to reach base 2, 8 or 16
  on the web. Every radix this package supports is a power of two, and a
  binary double converts into one exactly, so the platform's own conversion
  already spells the value. Measured under dart2js at 2^53: `{:x}` 320 ns
  becomes 120, `{:o}` 4070 becomes 150, `{:b}` 11550 becomes 380. Decimal is
  unchanged — it still needs fixed-point conversion, and `BigInt` past 1e21.
* The `g`, `e` and bare-precision floating presentations take their digits
  from the platform's own exponential conversion instead of decomposing the
  double and rounding in `BigInt`. The exact path stays for what the platform
  cannot answer: past twenty-one significant digits, and on the values that
  round to an exact half, where the SDK and ECMAScript round away from zero
  while this package rounds to even. Output is unchanged everywhere — checked
  against exact rounding on 313 200 comparisons per runtime, where the only
  disagreements were those ties. Measured under dart2js: `{:g}` 1437 ns
  becomes 132, `{:e}` 1113 becomes 323, `%g` 1473 becomes 132, `{:.6}` 1462
  becomes 147. On the VM `{:g}` 448 becomes 266, under dart2wasm 457 becomes
  205. A value that does land on a tie pays for the attempt before falling
  back and costs about a third more than before, 1.7 times under dart2wasm.
* Fixed-point conversion keeps the platform's own spelling past the range
  where the scaled value is still an exact double, where it used to fall back
  to `BigInt`. Rounding ties are decided from the bits of the value there,
  which is exact at that range and needs no scaled product. Measured under
  dart2js: `{:.6f}` of 12345678901234.568 goes from 1849 ns to 86, and
  `{:.2f}` of 1.23e19 from 2070 to 87; on the VM 694 to 158 and under
  dart2wasm 606 to 94. Values inside the old range are untouched, and their
  cheaper arithmetic test is still what decides them.
* `formatWith` snapshots its named arguments as a plain copy instead of an
  unmodifiable view of one. The snapshot still guarantees that a `toString`
  reached during the call cannot change what that call reads. Measured on a
  template of three named fields at 4% faster on the VM, 16% under dart2js and
  18% under dart2wasm, where every named lookup had been going through the
  view.
* Lowered the `characters` constraint to `^1.3.0`. Flutter pins that package
  from its SDK, and stable releases pinning 1.3.0 could not resolve this
  package at all (issue #8). The two versions carry different Unicode grapheme
  tables — 15.0.0 and 16.0.0 — so `TextUnit.graphemeClusters` follows whichever
  version resolves; nothing else in the package depends on the difference, and
  CI now runs the whole test suite on the floor to keep that true.
* Added the companion `format_intl` package for opt-in locale symbols,
  grouping rules, and localized digits without coupling `format` to `intl`.
* Extended the configured `NumberLocale` to the printf integer conversions,
  which previously took their sign and digits from ASCII while `%f` and `%e`
  already read the locale. `%d`, `%i`, `%u`, `%o`, `%x` and `%X` now use the
  locale's signs and digits, padding zeros included; the `0x` marker of `%#x`
  stays ASCII, and the alternate zero of `%#o` localizes as the digit it is.
  Nothing changes under the default C locale.
* Cache parsed templates, and expose `templateCacheCapacity`,
  `templateCacheSize`, and `clearTemplateCache()` so an application whose
  working set is larger than the default can widen it, one whose templates
  never repeat can switch it off, and either can tell the two cases apart.
* Exported `TextUnitOperations`, so a configured `TextUnit` can measure and
  truncate text the same way the engine does.
* Defined consistent JavaScript number semantics and optimized decimal integer
  formatting, including large values and the minimum VM integer; decimal
  digits beyond 2^53 print exactly on the web instead of the JavaScript
  shortest or exponential forms.
* Rejected widths and printf options above 100000 with typed errors instead
  of attempting arbitrarily large allocations.
* Added cross-runtime compatibility fixtures and a reproducible JIT, AOT, and
  JavaScript benchmark harness, measured against the frozen Format 2 gate
  baseline and the published sprintf 7.0.0 and format 1.6.0 packages.
* Added an ANSI-colored example benchmark that displays the result and timing
  of both decimal `double` profiles side by side.
* Replaced `formatNamed` with `formatWith`; direct `format` and `sprintf` calls
  now accept up to ten values, while their collection-based counterparts are
  `formatWith` and `vsprintf`.
* Formatting exceptions render their type, payload, and full template context
  in `toString()`, and a value whose own `toString()` throws is reported
  safely. `FormatExceptionContext.fragment` is an excerpt rather than a copy:
  it is capped at 80 characters, ending in `…` and never cut inside a
  surrogate pair, while `template` is kept whole. Use `offset` with `template`
  when the exact span matters.
* Documented the whole public API surface with dartdoc, including the
  extension contracts an implementer otherwise had to read the engine for:
  what a throwing `canFormat`, `format`, `lookup`, or `represent` turns into,
  that built-in types take priority over an extension, and that a `Map` uses
  the string-key shortcut instead of a registered `AttributeLookup`.

## 2.0.0 (unpublished)

* Replaced the legacy and experimental engines with one `format`/`formatNamed`
  implementation.
* Added the public generic `Formatter<T>` API, immutable `FormatOptions`, and
  global `Format.registerFormatter`/`Format.unregisterFormatter` registry.
* Added typed formatting exceptions and Unicode-aware post-format alignment.
* Fixed closing-brace escaping, invalid precision handling, and zero padding
  combined with grouping.
* Removed `format2`, `format2m`, String extensions, positional convenience
  arguments, `Map<Symbol, Object?>`, and dynamic width/precision.

## 1.6.0

* Upgrade depencencies.
* Min sdk: 3.3.0.

## 1.5.2

* Upgrade intl. Fix tests.

## 1.5.1

* Update README.md.

## 1.5.0

* Add escaping of the `{`.

## 1.4.0

* Breaked changes: in numbers, if fill is specified, the zero flag is ignored.
* Fix: the zero flag was ignored in the strings.

## 1.3.1

* Remove dart_code_metrics from dependencies

## 1.3.0

* Upgrade dependencies

## 1.2.0

* Named arguments can now accept Symbol:

  ```dart
  format('{a} {b}', {#a: 123, #b: 234});
  ```

* Updated.
* Fixed bug: Formatting fails if 2 justifications used in a single string
  (<https://github.com/vi-k/format/issues/2>).

## 1.1.1

* English README.md.
* Add extension method `print` and top-level function `format`.

## 1.1.0

* Breaked changes: for named args use format({...}) instead of format([], {...}).

## 1.0.1-nullsafety.0

* Fixed A little.

## 1.0.0-nullsafety.0

* First release. The basic version is ready. The tests are written.
