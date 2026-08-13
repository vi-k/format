import 'package:format/format.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

part 'grouping_pattern.dart';

/// A [NumberLocale] backed by the number symbols `intl` carries for a locale.
///
/// ```dart
/// final german = Format(numberLocale: IntlNumberLocale('de_DE'));
/// german.format('{:n}', 12345678);    // 12.345.678
/// german.sprintf('%.2f', 1234567.5);  // 1234567,50
/// ```
///
/// Separators, signs, digits and grouping come from `intl`'s data; the
/// grouping sizes are read out of the locale's decimal pattern, so a locale
/// that groups its highest digits differently — `1,23,45,678` in `hi` — groups
/// that way here too.
///
/// **The exponent separator is a trap worth naming.** `intl` gives it as `E`
/// for 108 of its 119 locales, and printf writes the locale's separator, so
/// under such a locale `%e` and `%E` produce the same text and stop being
/// distinguishable. Seven locales spell it as something that is not a letter
/// at all (`×10^` in `sv`, `أس` in `ar_EG`), and there `%E` cannot uppercase
/// it either. The brace dialect is unaffected: `{:e}` does not read the locale
/// — only `{:n}` does — which is the same split as everywhere else between
/// Python's rules and C's.
final class IntlNumberLocale implements NumberLocale {
  /// The locale `Intl.getCurrentLocale()` names, resolved as by the unnamed
  /// constructor.
  factory IntlNumberLocale.fromDefault() =>
      IntlNumberLocale(Intl.getCurrentLocale());

  /// The locale [localeName] names, canonicalized and then verified against
  /// `intl`'s data — `en_us` finds `en_US`, and a locale `intl` knows only by
  /// its language falls back to that language.
  ///
  /// Throws `FormatConfigurationException` when no number symbols exist for
  /// the name, and when the locale's zero digit is not a single Unicode
  /// scalar: both would otherwise surface much later, as wrong output.
  factory IntlNumberLocale(String localeName) {
    final verifiedLocale = Intl.verifiedLocale(
      Intl.canonicalizedLocale(localeName),
      numberFormatSymbols.containsKey,
      onFailure:
          (_) =>
              throw FormatConfigurationException(
                'No number symbols are available for locale "$localeName".',
                name: localeName,
              ),
    );
    if (verifiedLocale == null) {
      throw FormatConfigurationException(
        'No number symbols are available for locale "$localeName".',
        name: localeName,
      );
    }

    final symbols = numberFormatSymbols[verifiedLocale];
    if (symbols == null) {
      throw FormatConfigurationException(
        'No number symbols are available for locale "$localeName".',
        name: localeName,
      );
    }
    return IntlNumberLocale._(verifiedLocale, localeName, symbols);
  }

  IntlNumberLocale._(
    this.localeName,
    String requestedLocale,
    NumberSymbols symbols,
  ) : _decimalSeparator = symbols.DECIMAL_SEP,
      _groupSeparator = symbols.GROUP_SEP,
      _plusSign = symbols.PLUS_SIGN,
      _minusSign = symbols.MINUS_SIGN,
      _exponentSeparator = symbols.EXP_SYMBOL,
      _grouping = _groupingFromDecimalPattern(symbols.DECIMAL_PATTERN),
      _zeroDigit = _zeroDigitRune(symbols.ZERO_DIGIT, requestedLocale);

  /// The locale whose symbols are in use, as `intl` resolved it — which is not
  /// always what was asked for: a request for `en_ZZ` resolves to `en`.
  final String localeName;
  final String _decimalSeparator;
  final String _groupSeparator;
  final String _plusSign;
  final String _minusSign;
  final String _exponentSeparator;
  final List<int> _grouping;
  final int _zeroDigit;

  @override
  String get decimalSeparator => _decimalSeparator;

  @override
  String get groupSeparator => _groupSeparator;

  @override
  String get plusSign => _plusSign;

  @override
  String get minusSign => _minusSign;

  @override
  String get exponentSeparator => _exponentSeparator;

  @override
  bool get groupingEnabled => _grouping.isNotEmpty;

  @override
  List<int> get grouping => _grouping;

  @override
  String localizeDigits(String asciiDigits) => String.fromCharCodes(
    asciiDigits.runes.map(
      (rune) => rune >= 0x30 && rune <= 0x39 ? _zeroDigit + rune - 0x30 : rune,
    ),
  );
}

int _zeroDigitRune(String zeroDigit, String localeName) {
  final runes = zeroDigit.runes.toList(growable: false);
  if (runes.length != 1) {
    throw FormatConfigurationException(
      'The ZERO_DIGIT for locale "$localeName" must be one Unicode scalar.',
      name: localeName,
    );
  }
  return runes.single;
}
