import 'package:format/format.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

part 'grouping_pattern.dart';

final class IntlNumberLocale implements NumberLocale {
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
