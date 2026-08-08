/// A custom formatter selected by `{:name}` in a brace template.
///
/// The [specifier] must match `[A-Za-z][A-Za-z0-9_]*` and must not collide
/// with a built-in presentation type. For a placeholder without an explicit
/// specifier, built-in types take priority, followed by a unique matching
/// custom formatter, then `toString()`. Width, fill, and alignment are
/// applied by the engine after [format] returns.
///
/// Built-in types taking priority means a formatter is never consulted for a
/// value the engine already knows how to render: registering one that accepts
/// every value still leaves `{}` on a `String` or an `int` to the built-in
/// path. Only an explicit `{:name}` reaches such a value.
///
/// When two registered formatters accept the same value and the placeholder
/// names neither, the engine throws `AmbiguousFormatterException` rather than
/// picking one.
///
/// {@template format.extension_failure}
/// Anything this method throws is caught and rethrown as
/// `FormatExtensionException`, which carries the original `error` and
/// `stackTrace` along with the template location. The one exception is a
/// `FormattingException`: an extension that reports a formatting failure in
/// the engine's own vocabulary has that failure passed through unchanged.
/// Errors Dart raises on the extension's behalf are wrapped the same way — a
/// `canFormat` that accepts a value of the wrong type produces a `TypeError`
/// when the engine calls `format`, and an extension that formats by calling
/// the engine again on the same value produces a `StackOverflowError`.
/// {@endtemplate}
abstract base class Formatter<T> {
  const Formatter();

  /// The name that selects this formatter in a format specification.
  ///
  /// Read while resolving a placeholder, so a getter that throws fails the
  /// formatting call rather than the construction of the `Format` instance.
  ///
  /// {@macro format.extension_failure}
  String get specifier;

  /// Whether this formatter accepts [value].
  ///
  /// Returning true commits to [format] accepting the same value as a `T`.
  ///
  /// {@macro format.extension_failure}
  bool canFormat(Object? value);

  /// Formats [value] under the parsed [options].
  ///
  /// Width, fill, and alignment are not applied here: the engine applies them
  /// to whatever this returns.
  ///
  /// {@macro format.extension_failure}
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
///
/// Dart has no reflection to fall back on, so `{value.attribute}` resolves
/// only through a registered lookup. Without one the engine throws
/// `FormatLookupException`.
///
/// A `Map` is the exception: `{value.name}` on a map is a shorthand for the
/// string key `'name'`, resolved before any lookup is consulted. A lookup
/// that accepts maps is therefore never called for one.
abstract base class AttributeLookup<T> {
  const AttributeLookup();

  /// Whether this lookup accepts [value].
  ///
  /// Returning true commits to [lookup] accepting the same value as a `T`.
  ///
  /// {@macro format.extension_failure}
  bool canLookup(Object? value);

  /// Resolves [attribute] on [value].
  ///
  /// An absent attribute is this method's decision to report: throw, or
  /// return a value that formats the way the absence should read.
  ///
  /// {@macro format.extension_failure}
  Object? lookup(T value, String attribute);
}

/// A custom `!r`/`!a` representation for values of type [T].
///
/// Built-in representations take priority the same way built-in formatters
/// do: a representation is consulted only for a value the engine has no
/// representation of its own for.
abstract base class Representation<T> {
  const Representation();

  /// Whether this representation accepts [value].
  ///
  /// Returning true commits to [represent] accepting the same value as a `T`.
  ///
  /// {@macro format.extension_failure}
  bool canRepresent(Object? value);

  /// The representation of [value].
  ///
  /// `!a` escapes non-ASCII characters in whatever this returns, so a
  /// representation does not need an ASCII variant of its own.
  ///
  /// {@macro format.extension_failure}
  String represent(T value);
}
