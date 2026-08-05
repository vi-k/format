part of 'engine.dart';

enum _MissingValue { value }

/// The default engine behind the top-level [format], [formatWith],
/// [sprintf], and [vsprintf] functions: C locale, Unicode scalars, Dart
/// SDK double conversion, no custom extensions.
final defaultFormat = Format();

/// Formats [template] with Python-style braces and up to ten positional
/// values.
///
/// `format('{} {:.2f}', 'pi', 3.14159)` returns `'pi 3.14'`. A `List`
/// passed here is one value; use [formatWith] to spread collections.
/// Failures throw a [FormattingException].
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

/// Formats [template] with the printf mini-language and up to ten
/// positional values.
///
/// `sprintf('%s: %#08x', 'answer', 42)` returns `'answer: 0x00002a'`.
/// Use [vsprintf] for a list of values. Failures throw a
/// [FormattingException].
String sprintf(
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
]) => defaultFormat.sprintf(
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

/// Formats a brace [template] with [positional] and [named] value
/// collections.
///
/// `formatWith('{name}: {0}', positional: [1], named: {'name': 'n'})`
/// returns `'n: 1'`. Failures throw a [FormattingException].
String formatWith(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) => defaultFormat.formatWith(template, positional: positional, named: named);

/// Formats a printf [template] with a list of [values].
///
/// Failures throw a [FormattingException].
String vsprintf(String template, List<Object?> values) =>
    defaultFormat.vsprintf(template, values);

List<Object?> _collectOptionalValues([
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
]) {
  final values = <Object?>[];
  for (final value in [
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
  ]) {
    if (identical(value, _MissingValue.value)) break;
    values.add(value);
  }
  return values;
}
