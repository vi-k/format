final class FormatExceptionContext {
  final String? template;
  final int? offset;
  final String? fragment;
  final String? specifier;
  final String? conversion;
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

sealed class FormattingException implements Exception {
  final String message;
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

final class InvalidFormatException extends FormattingException {
  final String reason;

  const InvalidFormatException(FormatExceptionContext context, this.reason)
    : super('The format is invalid.', context);

  String get fragment => context.fragment ?? '';
}

final class InvalidSpecifierException extends FormattingException {
  final String reason;

  const InvalidSpecifierException(FormatExceptionContext context, this.reason)
    : super('The format specifier is invalid.', context);

  String get specifier => context.specifier ?? '';
}

final class MissingFormatArgumentException extends FormattingException {
  final Object? key;

  const MissingFormatArgumentException(FormatExceptionContext context, this.key)
    : super('A required format argument is missing.', context);
}

final class FormatLookupException extends FormattingException {
  final Object? segment;
  final Object? value;

  const FormatLookupException(
    FormatExceptionContext context,
    this.segment,
    this.value,
  ) : super('A field lookup failed.', context);
}

final class UnsupportedConversionException extends FormattingException {
  final Object? value;

  const UnsupportedConversionException(
    FormatExceptionContext context,
    this.value,
  ) : super('The conversion is not supported for this value.', context);
}

final class UnsupportedFormatValueException extends FormattingException {
  final Object? value;

  const UnsupportedFormatValueException(
    FormatExceptionContext context,
    this.value,
  ) : super('The formatter does not accept this value.', context);

  String get specifier => context.specifier ?? '';
}

final class FormatConfigurationException extends FormattingException {
  final String reason;
  final String? name;

  const FormatConfigurationException(this.reason, {this.name})
    : super(
        'The format configuration is invalid.',
        const FormatExceptionContext(),
      );
}

final class AmbiguousFormatterException extends FormattingException {
  final Object? value;
  final List<String> matches;

  AmbiguousFormatterException(
    FormatExceptionContext context,
    this.value,
    Iterable<String> matches,
  ) : matches = List.unmodifiable(matches),
      super('Multiple formatting extensions accept this value.', context);

  List<String> get specifiers => matches;
}

final class FormatExtensionException extends FormattingException {
  final String extension;
  final Object error;
  final StackTrace stackTrace;

  const FormatExtensionException(
    FormatExceptionContext context,
    this.extension,
    this.error,
    this.stackTrace,
  ) : super('A formatting extension failed.', context);
}
