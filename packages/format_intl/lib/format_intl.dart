/// Locale data from `intl` as a `NumberLocale` for the `format` package.
///
/// ```dart
/// final kazakh = Format(numberLocale: IntlNumberLocale('kk_KZ'));
/// kazakh.format('{:n}', 12345678);  // 12 345 678
/// ```
///
/// This package exists so that `format` itself depends on nothing: an
/// application that wants `intl`'s symbols and grouping rules adds this
/// adapter, and one that does not, does not carry `intl`.
library;

export 'src/intl_number_locale.dart' show IntlNumberLocale;
