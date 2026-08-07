/// Where in a template a formatting failure happened.
///
/// Every field is optional: a failure carries as much location as the
/// engine had at that point.
final class FormatExceptionContext {
  /// The whole template being formatted.
  final String? template;

  /// The UTF-16 offset of [fragment] within [template].
  final int? offset;

  /// The placeholder or conversion text the failure belongs to.
  final String? fragment;

  /// The format specification (after `:`) or printf option role.
  final String? specifier;

  /// The `!s`/`!r`/`!a` conversion or the printf conversion type.
  final String? conversion;

  /// The index of the argument being formatted.
  final int? argumentIndex;

  const FormatExceptionContext({
    this.template,
    this.offset,
    this.fragment,
    this.specifier,
    this.conversion,
    this.argumentIndex,
  });
}

/// Renders [value] for diagnostics without trusting its `toString()`:
/// strings come back quoted and escaped, and a throwing `toString()` falls
/// back to the safe default description.
String _describeGuarded(Object? value) {
  if (value is String) return Error.safeToString(value);
  try {
    return value.toString();
  } on Object {
    return Error.safeToString(value);
  }
}

/// The base of every failure thrown by the formatting engine.
///
/// The hierarchy is sealed: a `switch` over it can be exhaustive.
/// [toString] reports the type, [message], the subclass payload, and the
/// full [context].
sealed class FormattingException implements Exception {
  /// A short, fixed description of the failure class.
  final String message;

  /// Where in the template the failure happened.
  final FormatExceptionContext context;

  const FormattingException(this.message, this.context);

  @override
  String toString() {
    // Exhaustive over the sealed hierarchy: adding a subclass must extend
    // this switch before it compiles, so no payload can go unreported.
    final details = switch (this) {
      InvalidFormatException(:final reason) => ['reason: $reason'],
      InvalidSpecifierException(:final reason) => ['reason: $reason'],
      MissingFormatArgumentException(:final key) => [
        'key: ${_describeGuarded(key)}',
      ],
      FormatLookupException(:final segment, :final value) => [
        'segment: ${_describeGuarded(segment)}',
        'value: ${_describeGuarded(value)}',
      ],
      UnsupportedConversionException(:final value) => [
        'value: ${_describeGuarded(value)}',
      ],
      UnsupportedFormatValueException(:final value) => [
        'value: ${_describeGuarded(value)}',
      ],
      FormatConfigurationException(:final reason, :final name) => [
        'reason: $reason',
        if (name != null) 'name: $name',
      ],
      AmbiguousFormatterException(:final value, :final matches) => [
        'value: ${_describeGuarded(value)}',
        'matches: ${matches.join(', ')}',
      ],
      FormatExtensionException(
        extension: final extensionName,
        error: final error,
      ) =>
        ['extension: $extensionName', 'error: ${_describeGuarded(error)}'],
    };
    final parts = [
      ...details,
      if (context.specifier != null)
        'specifier: ${Error.safeToString(context.specifier)}',
      if (context.conversion != null) 'conversion: ${context.conversion}',
      if (context.argumentIndex != null)
        'argument index: ${context.argumentIndex}',
      if (context.fragment != null)
        'fragment: ${Error.safeToString(context.fragment)}',
      if (context.offset != null) 'offset: ${context.offset}',
      if (context.template != null)
        'template: ${Error.safeToString(context.template)}',
    ];
    final buffer =
        StringBuffer()
          ..write(runtimeType)
          ..write(': ')
          ..write(message);
    if (parts.isNotEmpty) {
      buffer
        ..write(' (')
        ..write(parts.join('; '))
        ..write(')');
    }
    return buffer.toString();
  }
}

/// The template itself does not parse: an unmatched brace, a bad field
/// name, an unterminated or unknown printf conversion.
final class InvalidFormatException extends FormattingException {
  /// Why the template does not parse.
  final String reason;

  const InvalidFormatException(FormatExceptionContext context, this.reason)
    : super('The format is invalid.', context);

  /// The template text the parser rejected.
  String get fragment => context.fragment ?? '';
}

/// The template parses, but a format specification is not valid: an
/// unknown presentation type, an option that the type does not accept, or
/// a width/precision outside the supported range.
///
/// Brace formatting decides what a specification means from the value's
/// own type, so a specification meant for another type lands here too:
/// `format('{:d}', 'text')` and `format('{:d}', 1.5)` both raise this,
/// not [UnsupportedFormatValueException]. Printf works the other way
/// round; see [UnsupportedFormatValueException].
final class InvalidSpecifierException extends FormattingException {
  /// Why the specification was rejected.
  final String reason;

  const InvalidSpecifierException(FormatExceptionContext context, this.reason)
    : super('The format specifier is invalid.', context);

  /// The rejected specification text.
  String get specifier => context.specifier ?? '';
}

/// A placeholder refers to an argument that was not supplied.
final class MissingFormatArgumentException extends FormattingException {
  /// The positional index or the name that had no argument.
  final Object? key;

  const MissingFormatArgumentException(FormatExceptionContext context, this.key)
    : super('A required format argument is missing.', context);
}

/// A `.attribute` or `[key]` step in a field access chain failed.
final class FormatLookupException extends FormattingException {
  /// The attribute name or item key that failed to resolve.
  final Object? segment;

  /// The value the lookup was attempted on.
  final Object? value;

  const FormatLookupException(
    FormatExceptionContext context,
    this.segment,
    this.value,
  ) : super('A field lookup failed.', context);
}

/// A `!s`/`!r`/`!a` conversion (or a printf conversion) cannot be applied
/// to the given value.
final class UnsupportedConversionException extends FormattingException {
  /// The value the conversion rejected.
  final Object? value;

  const UnsupportedConversionException(
    FormatExceptionContext context,
    this.value,
  ) : super('The conversion is not supported for this value.', context);
}

/// A conversion or specification cannot render the value it was given:
/// `sprintf('%d', 1.5)`, `sprintf('%d', 'text')`, an out-of-range scalar
/// for `c`, or a value no configured formatter accepts.
///
/// Printf decides what to do from the conversion letter, so a value the
/// conversion cannot render is reported here. Brace formatting decides
/// from the value's type instead, so its counterpart is
/// [InvalidSpecifierException]; this exception stays for values that no
/// dispatch path accepts at all, such as `format('{:d}', true)`.
final class UnsupportedFormatValueException extends FormattingException {
  /// The rejected value.
  final Object? value;

  const UnsupportedFormatValueException(
    FormatExceptionContext context,
    this.value,
  ) : super('The formatter does not accept this value.', context);

  /// The specification the value does not satisfy.
  String get specifier => context.specifier ?? '';
}

/// A `Format` instance was constructed with an invalid configuration,
/// such as a reserved or duplicated custom formatter name.
final class FormatConfigurationException extends FormattingException {
  /// Why the configuration was rejected.
  final String reason;

  /// The offending formatter name, if the failure concerns one.
  final String? name;

  const FormatConfigurationException(this.reason, {this.name})
    : super(
        'The format configuration is invalid.',
        const FormatExceptionContext(),
      );
}

/// More than one configured extension accepts the same value, so the
/// engine cannot choose between them.
final class AmbiguousFormatterException extends FormattingException {
  /// The value that several extensions accept.
  final Object? value;

  /// Names the competing extensions: a formatter's specifier, or the type
  /// name of a lookup or representation, which have no specifier.
  final List<String> matches;

  AmbiguousFormatterException(
    FormatExceptionContext context,
    this.value,
    Iterable<String> matches,
  ) : matches = List.unmodifiable(matches),
      super('Multiple formatting extensions accept this value.', context);
}

/// User-provided code threw during formatting: a custom formatter,
/// lookup, representation, locale, or a value's own `toString()`.
///
/// The original failure is preserved in [error] and [stackTrace].
final class FormatExtensionException extends FormattingException {
  /// The extension that failed — a formatter specifier or a type name.
  final String extension;

  /// The original error thrown by the extension.
  final Object error;

  /// The stack trace of the original error.
  final StackTrace stackTrace;

  const FormatExtensionException(
    FormatExceptionContext context,
    this.extension,
    this.error,
    this.stackTrace,
  ) : super('A formatting extension failed.', context);
}
