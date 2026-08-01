part of 'engine.dart';

enum _MissingValue { value }

final defaultFormat = Format();

String format(
  String template, [
  Object? value1 = _MissingValue.value,
  Object? value2 = _MissingValue.value,
  Object? value3 = _MissingValue.value,
  Object? value4 = _MissingValue.value,
  Object? value5 = _MissingValue.value,
  Object? value6 = _MissingValue.value,
  Object? value7 = _MissingValue.value,
  Object? value8 = _MissingValue.value,
  Object? value9 = _MissingValue.value,
  Object? value10 = _MissingValue.value,
]) => defaultFormat.format(
  template,
  value1,
  value2,
  value3,
  value4,
  value5,
  value6,
  value7,
  value8,
  value9,
  value10,
);

String formatWith(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) => defaultFormat.formatWith(template, positional: positional, named: named);
