part of 'engine.dart';

final class _PrintfProcessor {
  final String template;
  final List<Object?> values;
  var _argumentIndex = 0;

  _PrintfProcessor(this.template, this.values);

  String format() {
    final output = StringBuffer();
    for (var offset = 0; offset < template.length; offset++) {
      final codeUnit = template.codeUnitAt(offset);
      if (codeUnit != 0x25) {
        output.writeCharCode(codeUnit);
        continue;
      }

      if (++offset == template.length) {
        throw _invalid(offset - 1, '%', 'A percent token must have a type.');
      }
      final conversion = template[offset];
      switch (conversion) {
        case '%':
          output.write('%');
        case 's':
          final argument = _nextValue(offset - 1, conversion);
          output.write(
            _formatString(
              argument.value,
              _context(
                offset - 1,
                '%$conversion',
                specifier: conversion,
                argumentIndex: argument.index,
              ),
            ),
          );
        case 'd':
          final argument = _nextValue(offset - 1, conversion);
          output.write(
            _formatDecimal(
              argument.value,
              _context(
                offset - 1,
                '%$conversion',
                specifier: conversion,
                argumentIndex: argument.index,
              ),
            ),
          );
        default:
          throw _invalid(
            offset - 1,
            '%$conversion',
            'Unsupported percent token.',
            specifier: conversion,
          );
      }
    }
    return output.toString();
  }

  ({Object? value, int index}) _nextValue(int offset, String specifier) {
    final argumentIndex = _argumentIndex;
    if (argumentIndex == values.length) {
      throw MissingFormatArgumentException(
        _context(
          offset,
          '%$specifier',
          specifier: specifier,
          argumentIndex: argumentIndex,
        ),
        argumentIndex,
      );
    }
    _argumentIndex++;
    return (value: values[argumentIndex], index: argumentIndex);
  }

  String _formatString(Object? value, FormatExceptionContext context) {
    try {
      return value.toString();
    } on FormattingException {
      rethrow;
    } on Object catch (_) {
      throw UnsupportedConversionException(context, value);
    }
  }

  String _formatDecimal(Object? value, FormatExceptionContext context) {
    if (value is BigInt) return value.toString();
    if (value is int && _isIntegerValue(value)) {
      return BigInt.from(value).toString();
    }
    throw UnsupportedConversionException(context, value);
  }

  InvalidFormatException _invalid(
    int offset,
    String fragment,
    String reason, {
    String? specifier,
  }) => InvalidFormatException(
    _context(offset, fragment, specifier: specifier),
    reason,
  );

  FormatExceptionContext _context(
    int offset,
    String fragment, {
    String? specifier,
    int? argumentIndex,
  }) => FormatExceptionContext(
    template: template,
    offset: offset,
    fragment: fragment,
    specifier: specifier,
    argumentIndex: argumentIndex,
  );
}
