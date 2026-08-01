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

sealed class FormattingException implements Exception {
  final String message;
  final FormatExceptionContext context;

  const FormattingException(this.message, this.context);
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
