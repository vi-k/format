part of 'intl_number_locale.dart';

List<int> _groupingFromDecimalPattern(String decimalPattern) {
  final positivePattern = decimalPattern.split(';').first;
  final integerSection = positivePattern.split('.').first;
  final lastComma = integerSection.lastIndexOf(',');
  if (lastComma == -1) return const <int>[];

  final primary = integerSection.length - lastComma - 1;
  final previousComma = integerSection.lastIndexOf(',', lastComma - 1);
  if (previousComma == -1) return List<int>.unmodifiable([primary]);

  final secondary = lastComma - previousComma - 1;
  return List<int>.unmodifiable([primary, secondary]);
}
