/// Symbols and grouping rules for locale-aware number formatting.
///
/// The `n` presentation type applies the locale's grouping automatically;
/// the printf dialect, which has no `n`, uses the locale's separators, signs,
/// and digits on every numeric conversion but never groups on its own — a
/// template that did not ask for separators does not get them. Syntax markers
/// stay ASCII: the `0x` of `%#x` and of `%a` is not a digit. The alternate
/// zero of `%#o` is, and is localized with the rest.
///
/// A locale supplies symbols only: precision, rounding, and notation remain
/// the responsibility of the engine. The companion `format_intl` package
/// adapts `intl` locale data to this interface.
abstract interface class NumberLocale {
  /// The symbol between the integer and fractional parts.
  String get decimalSeparator;

  /// The symbol between digit groups of the integer part.
  String get groupSeparator;

  /// The symbol for an explicitly requested positive sign.
  String get plusSign;

  /// The symbol for negative values.
  String get minusSign;

  /// The symbol before the exponent in scientific notation.
  ///
  /// An uppercase presentation type uses its uppercase form.
  String get exponentSeparator;

  /// Whether the `n` presentation type groups integer digits at all.
  bool get groupingEnabled;

  /// Group sizes from the least significant digits outward.
  ///
  /// The last size repeats: `[3]` produces `1,234,567`, `[3, 2]` produces
  /// the Indian-style `12,34,567`.
  List<int> get grouping;

  /// Maps ASCII digits in [asciiDigits] to the locale's digit symbols.
  String localizeDigits(String asciiDigits);
}

/// The default locale: C-style ASCII symbols with grouping disabled for
/// the `n` presentation type.
final class CNumberLocale implements NumberLocale {
  const CNumberLocale();

  @override
  String get decimalSeparator => '.';

  @override
  String get groupSeparator => ',';

  @override
  String get plusSign => '+';

  @override
  String get minusSign => '-';

  @override
  String get exponentSeparator => 'e';

  @override
  bool get groupingEnabled => false;

  @override
  List<int> get grouping => const [3];

  @override
  String localizeDigits(String asciiDigits) => asciiDigits;
}
