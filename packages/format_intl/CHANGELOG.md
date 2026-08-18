# Changelog

## Unreleased

- Lowered the SDK floor from `^3.7.2` to `^3.6.0`, matching `format`. Under
  Flutter this changes nothing: `flutter_localizations` pins `intl` 0.19.0
  until Flutter 3.32.0, and this package needs 0.20.2, so 3.32.0 remains the
  first Flutter it installs on. A Dart application without
  `flutter_localizations` can now use it from 3.6.0.

## 1.0.1

- Widened the `format` constraint to `>=3.0.0 <5.0.0`. This package implements
  `NumberLocale`, which `format` 4.0.0 did not change, so the same adapter
  works on both majors.

## 1.0.0

- Initial `intl` adapter for locale-aware `format` and `sprintf` number
  formatting.
