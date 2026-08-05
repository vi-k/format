# CHANGELOG

## 3.0.0

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
* Added the companion `format_intl` package for opt-in locale symbols,
  grouping rules, and localized digits without coupling `format` to `intl`.
* Defined consistent JavaScript number semantics and optimized decimal integer
  formatting, including large values and the minimum VM integer.
* Added cross-runtime compatibility fixtures and a reproducible JIT, AOT, and
  JavaScript benchmark harness with frozen Format 2 and sprintf baselines.
* Added an ANSI-colored example benchmark that displays the result and timing
  of both decimal `double` profiles side by side.
* Replaced `formatNamed` with `formatWith`; direct `format` and `sprintf` calls
  now accept up to ten values, while their collection-based counterparts are
  `formatWith` and `vsprintf`.
* Formatting exceptions render their type, payload, and full template context
  in `toString()`, and a value whose own `toString()` throws is reported
  safely.

## 2.0.0

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
