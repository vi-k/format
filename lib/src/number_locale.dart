abstract interface class NumberLocale {
  String get decimalSeparator;
  String get groupSeparator;
  String get plusSign;
  String get minusSign;
  String get exponentSeparator;
  bool get groupingEnabled;
  List<int> get grouping;
  String localizeDigits(String asciiDigits);
}

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
