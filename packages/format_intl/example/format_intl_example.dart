import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';

void main() {
  final kazakh = Format(numberLocale: IntlNumberLocale('kk_KZ'));
  final formatKk = kazakh.format;
  final sprintfKk = kazakh.sprintf;

  print(formatKk('{:n}', 1234567.5));
  print(sprintfKk('%.2f', 12.5));
}
