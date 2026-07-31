sealed class FormattingException implements Exception {
  final String message;

  const FormattingException(this.message);
}

final class InvalidFormatException extends FormattingException {
  final String fragment;
  final String reason;

  const InvalidFormatException({required this.fragment, required this.reason})
      : super('The format is invalid.');
}

final class InvalidSpecifierException extends FormattingException {
  final String specifier;

  const InvalidSpecifierException(this.specifier)
      : super('The formatter specifier is invalid.');
}

final class FormatterAlreadyRegisteredException extends FormattingException {
  final String specifier;

  const FormatterAlreadyRegisteredException(this.specifier)
      : super('A formatter is already registered for this specifier.');
}

final class BuiltInSpecifierException extends FormattingException {
  final String specifier;

  const BuiltInSpecifierException(this.specifier)
      : super('Built-in formatter specifiers cannot be changed.');
}

final class AmbiguousFormatterException extends FormattingException {
  final Object? value;
  final List<String> specifiers;

  const AmbiguousFormatterException(this.value, this.specifiers)
      : super('Multiple custom formatters accept this value.');
}

final class UnsupportedFormatValueException extends FormattingException {
  final String specifier;
  final Object? value;

  const UnsupportedFormatValueException(this.specifier, this.value)
      : super('The formatter does not accept this value.');
}
