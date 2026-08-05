part of 'engine.dart';

final class _ResolvedPrintfConversion {
  final _PrintfConversionNode node;
  final int flags;
  final int? width;
  final int? precision;

  const _ResolvedPrintfConversion({
    required this.node,
    required this.flags,
    required this.width,
    required this.precision,
  });
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
  'f' ||
  'F' ||
  'e' ||
  'E' ||
  'g' ||
  'G' ||
  'a' ||
  'A' => _formatPrintfDouble(value, conversion, engine, context),
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
  // Same contract as the brace path's _fallbackToString: a throwing
  // toString() surfaces as FormatExtensionException with the cause kept.
  final text = _fallbackToString(value, context);
  final truncated =
      conversion.precision == null
          ? text
          : engine.textUnit.take(text, conversion.precision!);
  return applyFieldWidth(
    truncated,
    width: conversion.width,
    fill: null,
    align: _hasPrintfFlag(conversion.flags, _PrintfFlags.left) ? '<' : '>',
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
  align: _hasPrintfFlag(conversion.flags, _PrintfFlags.left) ? '<' : '>',
  textUnit: engine.textUnit,
);

String _formatPrintfInteger(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) {
  final type = conversion.node.type;
  final signed = type == 'd' || type == 'i';
  final radix = switch (type) {
    'o' => 8,
    'x' || 'X' => 16,
    _ => 10,
  };
  late final bool negative;
  late final bool isZero;
  late final String magnitudeDigits;
  switch (value) {
    case int() when _isIntegerValue(value):
      negative = value.isNegative;
      isZero = value == 0;
      magnitudeDigits = _formatIntMagnitude(
        value,
        radix,
        uppercase: type == 'X',
      );
    case BigInt():
      negative = value.isNegative;
      isZero = value == BigInt.zero;
      magnitudeDigits = formatMagnitude(
        negative ? -value : value,
        radix,
        uppercase: type == 'X',
      );
    default:
      throw UnsupportedFormatValueException(context, value);
  }
  if (!signed && negative) {
    throw UnsupportedFormatValueException(context, value);
  }

  var digits = magnitudeDigits;
  if (isZero && conversion.precision == 0) digits = '';
  final precision = conversion.precision;
  if (precision != null && precision > digits.length) {
    digits = '0' * (precision - digits.length) + digits;
  }

  final alternate = _hasPrintfFlag(conversion.flags, _PrintfFlags.alternate);
  final prefix = switch (type) {
    'o' when alternate && !digits.startsWith('0') => '0',
    'x' when alternate && !isZero => '0x',
    'X' when alternate && !isZero => '0X',
    _ => '',
  };
  final sign =
      signed && negative
          ? '-'
          : _hasPrintfFlag(conversion.flags, _PrintfFlags.sign)
          ? '+'
          : _hasPrintfFlag(conversion.flags, _PrintfFlags.space)
          ? ' '
          : '';
  final left = _hasPrintfFlag(conversion.flags, _PrintfFlags.left);
  final zero =
      _hasPrintfFlag(conversion.flags, _PrintfFlags.zero) &&
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

String _formatPrintfDouble(
  Object? value,
  _ResolvedPrintfConversion conversion,
  Format engine,
  FormatExceptionContext context,
) {
  if (value is! double) {
    throw UnsupportedFormatValueException(context, value);
  }
  final type = conversion.node.type;
  final uppercase = type == 'E' || type == 'F' || type == 'G' || type == 'A';
  final dartDecimal =
      engine.doubleFormatMode == DoubleFormatMode.dartSdk &&
      type != 'a' &&
      type != 'A';
  if (dartDecimal) {
    _validateDartDoublePrecision(type, conversion.precision, context);
  }
  late final _AsciiFloat formatted;
  if (!value.isFinite) {
    formatted = _formatSpecialDouble(value, uppercase, engine);
  } else if (dartDecimal) {
    formatted = _formatDartDouble(
      value,
      type,
      conversion.precision,
      _hasPrintfFlag(conversion.flags, _PrintfFlags.alternate),
    );
  } else {
    final precision = conversion.precision ?? 6;
    final alternate = _hasPrintfFlag(conversion.flags, _PrintfFlags.alternate);
    formatted = switch (type) {
      'f' || 'F' => _formatFixed(value, precision, alternate),
      'e' || 'E' => _formatScientific(
        Binary64.fromDouble(value),
        precision,
        alternate,
        type,
      ),
      'g' || 'G' => _formatGeneral(
        Binary64.fromDouble(value),
        precision == 0 ? 1 : precision,
        alternate,
        type == 'G' ? 'E' : 'e',
      ),
      'a' || 'A' => _formatHexadecimal(
        Binary64.fromDouble(value),
        conversion.precision,
        alternate,
        uppercase,
      ),
      _ => throw StateError('Unsupported decimal printf conversion: $type'),
    };
  }

  final locale = engine.numberLocale;
  final negative = !value.isNaN && value.isNegative;
  final requestedSign =
      _hasPrintfFlag(conversion.flags, _PrintfFlags.sign)
          ? '+'
          : _hasPrintfFlag(conversion.flags, _PrintfFlags.space)
          ? ' '
          : null;
  final sign = _localizedSign(negative, requestedSign, locale, context);
  final left = _hasPrintfFlag(conversion.flags, _PrintfFlags.left);
  final zero =
      _hasPrintfFlag(conversion.flags, _PrintfFlags.zero) &&
      !left &&
      !formatted.special;
  final spec = _FormatSpec(
    align: left ? '<' : null,
    alternate: _hasPrintfFlag(conversion.flags, _PrintfFlags.alternate),
    zero: zero,
    width: conversion.width,
    precision: conversion.precision,
    type: type,
  );
  final hexadecimal = (type == 'a' || type == 'A') && !formatted.special;
  return applyNumericWidth(
    sign: sign,
    prefix: hexadecimal ? (uppercase ? '0X' : '0x') : '',
    digits: formatted.body,
    spec: spec,
    textUnit: engine.textUnit,
    fitRegroupedZeroPadding: true,
    formatDigits:
        (body) =>
            hexadecimal
                ? _displayPrintfHexBody(body, locale, context)
                : _displayFloatBody(
                  body,
                  spec,
                  locale,
                  context,
                  formatted.special,
                  localeGrouping: false,
                ),
  );
}

_AsciiFloat _formatHexadecimal(
  Binary64 value,
  int? precision,
  bool alternate,
  bool uppercase,
) {
  final exponent =
      value.isZero
          ? 0
          : value.exponentBits == 0
          ? -1022
          : value.exponentBits - 1023;
  late String leading;
  late String fraction;
  if (precision == null) {
    leading = value.exponentBits == 0 ? '0' : '1';
    fraction = value.fractionBits.toRadixString(16).padLeft(13, '0');
    fraction = _trimTrailingZeros(fraction);
  } else {
    final fractionBits = precision * 4;
    final rounded = value.roundBinaryFraction(fractionBits);
    leading = (rounded >> fractionBits).toRadixString(16);
    if (precision == 0) {
      fraction = '';
    } else {
      final mask = (BigInt.one << fractionBits) - BigInt.one;
      fraction = (rounded & mask).toRadixString(16).padLeft(precision, '0');
    }
  }
  if (uppercase) {
    leading = leading.toUpperCase();
    fraction = fraction.toUpperCase();
  }
  final point = fraction.isNotEmpty || alternate ? '.' : '';
  final exponentMarker = uppercase ? 'P' : 'p';
  final exponentSign = exponent < 0 ? '-' : '+';
  return _AsciiFloat(
    '$leading$point$fraction$exponentMarker$exponentSign${exponent.abs()}',
    value.isZero,
  );
}

String _displayPrintfHexBody(
  String body,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  final match = RegExp(
    r'^([0-9a-fA-F]+)(?:\.([0-9a-fA-F]*))?([pP])([+-])(\d+)$',
  ).firstMatch(body);
  if (match == null) {
    throw StateError('Invalid internal hexadecimal float: $body');
  }
  final integer = _localizeAsciiRuns(match.group(1)!, locale, context);
  final fraction = match.group(2);
  final point =
      fraction == null
          ? ''
          : _readLocale(context, () => locale.decimalSeparator);
  final displayedFraction =
      fraction == null ? '' : _localizeAsciiRuns(fraction, locale, context);
  final exponentNegative = match.group(4) == '-';
  final exponentSign = _localizedSign(exponentNegative, '+', locale, context);
  final exponentDigits = _readLocale(
    context,
    () => locale.localizeDigits(match.group(5)!),
  );
  return integer +
      point +
      displayedFraction +
      match.group(3)! +
      exponentSign +
      exponentDigits;
}
