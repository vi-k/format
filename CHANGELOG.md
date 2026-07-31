# CHANGELOG

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
