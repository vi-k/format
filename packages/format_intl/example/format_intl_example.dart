import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';

void main() {
  final ukrainian = Format(numberLocale: IntlNumberLocale('uk_UA'));
  final formatUk = ukrainian.format;
  final sprintfUk = ukrainian.sprintf;

  print(formatUk('{:n}', 1234567.5));
  print(sprintfUk('%.2f', 12.5));
}
