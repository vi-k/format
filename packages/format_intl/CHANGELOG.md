# Changelog

## 1.0.1

- Widened the `format` constraint to `>=3.0.0 <5.0.0`. This package implements
  `NumberLocale`, which `format` 4.0.0 did not change, so the same adapter
  works on both majors.

## 1.0.0

- Initial `intl` adapter for locale-aware `format` and `sprintf` number
  formatting.
