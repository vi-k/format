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
  // Counted first, then allocated once. Walking a literal of all ten slots
  // built a second list nobody outside this function ever saw, and appending
  // into a growing one reallocated on the way to a length already known — two
  // allocations and a copy for a call that usually carries one value.
  const missing = _MissingValue.value;
  final count =
      identical(value1, missing)
          ? 0
          : identical(value2, missing)
          ? 1
          : identical(value3, missing)
          ? 2
          : identical(value4, missing)
          ? 3
          : identical(value5, missing)
          ? 4
          : identical(value6, missing)
          ? 5
          : identical(value7, missing)
          ? 6
          : identical(value8, missing)
          ? 7
          : identical(value9, missing)
          ? 8
          : identical(value10, missing)
          ? 9
          : 10;

  // Each arm is a literal of its exact length, so the list is allocated at
  // the size it ends at and never grown.
  return switch (count) {
    0 => const <Object?>[],
    1 => <Object?>[value1],
    2 => <Object?>[value1, value2],
    3 => <Object?>[value1, value2, value3],
    4 => <Object?>[value1, value2, value3, value4],
    5 => <Object?>[value1, value2, value3, value4, value5],
    6 => <Object?>[value1, value2, value3, value4, value5, value6],
    7 => <Object?>[value1, value2, value3, value4, value5, value6, value7],
    8 => <Object?>[
      value1,
      value2,
      value3,
      value4,
      value5,
      value6,
      value7,
      value8,
    ],
    9 => <Object?>[
      value1,
      value2,
      value3,
      value4,
      value5,
      value6,
      value7,
      value8,
      value9,
    ],
    _ => <Object?>[
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
    ],
  };
}
