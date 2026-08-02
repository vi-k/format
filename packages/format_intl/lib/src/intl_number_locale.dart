import 'package:format/format.dart';
import 'package:intl/intl.dart';

final class IntlNumberLocale implements NumberLocale {
  IntlNumberLocale(String localeName)
      : localeName = Intl.canonicalizedLocale(localeName);

  final String localeName;

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
