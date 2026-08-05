/// A custom formatter selected by `{:name}` in a brace template.
///
/// The [specifier] must match `[A-Za-z][A-Za-z0-9_]*` and must not collide
/// with a built-in presentation type. For a placeholder without an explicit
/// specifier, built-in types take priority, followed by a unique matching
/// custom formatter, then `toString()`. Width, fill, and alignment are
/// applied by the engine after [format] returns.
abstract base class Formatter<T> {
  const Formatter();

  /// The name that selects this formatter in a format specification.
  String get specifier;

  /// Whether this formatter accepts [value].
  bool canFormat(Object? value);

  /// Formats [value] under the parsed [options].
  String format(T value, FormatOptions options);
}

/// The parsed format specification options handed to a [Formatter].
final class FormatOptions {
  /// The requested sign flag: `+`, `-`, or a space, if present.
  final String? sign;

  /// Whether the `z` flag requested normalizing `-0.0` to zero.
  final bool normalizeNegativeZero;

  /// Whether the `#` alternate-form flag is present.
  final bool alternate;

  /// Whether the `0` zero-padding flag is present.
  final bool zero;

  /// The grouping separator flag: `,` or `_`, if present.
  final String? grouping;

  /// The precision, if present.
  final int? precision;

  /// The additional template after `name:` in the specification, if any.
  final String? payload;

  const FormatOptions({
    this.sign,
    this.normalizeNegativeZero = false,
    this.alternate = false,
    this.zero = false,
    this.grouping,
    this.precision,
    this.payload,
  });
}

/// A custom resolver for `{value.attribute}` field access.
abstract base class AttributeLookup<T> {
  const AttributeLookup();

  /// Whether this lookup accepts [value].
  bool canLookup(Object? value);

  /// Resolves [attribute] on [value].
  Object? lookup(T value, String attribute);
}

/// A custom `!r`/`!a` representation for values of type [T].
abstract base class Representation<T> {
  const Representation();

  /// Whether this representation accepts [value].
  bool canRepresent(Object? value);

  /// The representation of [value].
  String represent(T value);
}
