part of 'engine.dart';

final class _ResolvedPrintfConversion {
  final _PrintfConversionNode node;
  final Set<_PrintfFlag> flags;
  final int? width;
  final int? precision;

  _ResolvedPrintfConversion({
    required this.node,
    required Iterable<_PrintfFlag> flags,
    required this.width,
    required this.precision,
  }) : flags = Set.unmodifiable(flags);
}

String _formatPrintfValue(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) => switch (conversion.node.type) {
  's' => _formatPrintfString(value, conversion, engine, context),
  'c' => _formatPrintfCharacter(value, conversion, engine, context),
  'd' ||
  'i' ||
  'u' ||
  'o' ||
  'x' ||
  'X' => _formatPrintfInteger(value, conversion, engine, context),
  _ =>
    throw InvalidSpecifierException(
      context,
      'This printf conversion is not implemented yet.',
    ),
};

String _formatPrintfString(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) {
  late final String text;
  try {
    text = value.toString();
  } on FormattingException {
    rethrow;
  } on Object catch (_) {
    throw UnsupportedConversionException(context, value);
  }
  final truncated =
      conversion.precision == null
          ? text
          : engine.textUnit.take(text, conversion.precision!);
  return applyFieldWidth(
    truncated,
    width: conversion.width,
    fill: null,
    align: conversion.flags.contains(_PrintfFlag.left) ? '<' : '>',
    textUnit: engine.textUnit,
  );
}

String _formatPrintfCharacter(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) => applyFieldWidth(
  String.fromCharCode(_unicodeScalar(value, context)),
  width: conversion.width,
  fill: null,
  align: conversion.flags.contains(_PrintfFlag.left) ? '<' : '>',
  textUnit: engine.textUnit,
);

String _formatPrintfInteger(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) {
  final integer = switch (value) {
    int() when _isIntegerValue(value) => BigInt.from(value),
    BigInt() => value,
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final type = conversion.node.type;
  final signed = type == 'd' || type == 'i';
  if (!signed && integer.isNegative) {
    throw UnsupportedFormatValueException(context, value);
  }

  final negative = signed && integer.isNegative;
  final magnitude = negative ? -integer : integer;
  final radix = switch (type) {
    'o' => 8,
    'x' || 'X' => 16,
    _ => 10,
  };
  var digits = formatMagnitude(magnitude, radix, uppercase: type == 'X');
  if (magnitude == BigInt.zero && conversion.precision == 0) digits = '';
  final precision = conversion.precision;
  if (precision != null && precision > digits.length) {
    digits = '0' * (precision - digits.length) + digits;
  }

  final alternate = conversion.flags.contains(_PrintfFlag.alternate);
  final prefix = switch (type) {
    'o' when alternate && !digits.startsWith('0') => '0',
    'x' when alternate && magnitude != BigInt.zero => '0x',
    'X' when alternate && magnitude != BigInt.zero => '0X',
    _ => '',
  };
  final sign =
      negative
          ? '-'
          : conversion.flags.contains(_PrintfFlag.sign)
          ? '+'
          : conversion.flags.contains(_PrintfFlag.space)
          ? ' '
          : '';
  final left = conversion.flags.contains(_PrintfFlag.left);
  final zero =
      conversion.flags.contains(_PrintfFlag.zero) &&
      !left &&
      conversion.precision == null;
  return applyNumericWidth(
    sign: sign,
    prefix: prefix,
    digits: digits,
    spec: _FormatSpec(
      align: left ? '<' : null,
      zero: zero,
      width: conversion.width,
    ),
    textUnit: engine.textUnit,
  );
}
