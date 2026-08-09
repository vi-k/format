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
  // Unreachable, and not removable: a switch expression must be exhaustive,
  // and a String cannot be. The parser admits no conversion outside the
  // cases above.
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
  // C defines `#` on octal as forcing the first *digit* of the result to be a
  // zero, not as prefixing a marker, so that zero belongs with the digits and
  // is localized with them. The `0x`/`0X` of `x` and `X` are markers and stay
  // ASCII, exactly as `%a` keeps its own. Under the C locale both spellings
  // produce the same characters, padded or not.
  if (alternate && type == 'o' && !digits.startsWith('0')) digits = '0$digits';
  final prefix = switch (type) {
    'x' when alternate && !isZero => '0x',
    'X' when alternate && !isZero => '0X',
    _ => '',
  };
  final locale = engine.numberLocale;
  final sign = _localizedSign(
    signed && negative,
    _hasPrintfFlag(conversion.flags, _PrintfFlags.sign)
        ? '+'
        : _hasPrintfFlag(conversion.flags, _PrintfFlags.space)
        ? ' '
        : null,
    locale,
    context,
  );
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
    // The C locale maps every digit to itself, and passing no callback at
    // all keeps its zero padding on the counted path rather than the search
    // `applyNumericWidth` runs when digits may change width under it.
    formatDigits:
        identical(locale, const CNumberLocale())
            ? null
            : (asciiDigits) => _localizeAsciiRuns(asciiDigits, locale, context),
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
  final exponentStart = _hexadecimalExponentStart(body);
  if (exponentStart < 0) {
    throw StateError('Invalid internal hexadecimal float: $body');
  }
  // Under the C locale every part below maps to itself, and the body is this
  // package's own output: taking it apart and putting it back returns the
  // same string. The shape check above still runs, so a body that is not
  // what this package writes still fails the same way.
  if (identical(locale, const CNumberLocale())) return body;

  final mantissa = body.substring(0, exponentStart);
  final point = mantissa.indexOf('.');
  final integer = _localizeAsciiRuns(
    point < 0 ? mantissa : mantissa.substring(0, point),
    locale,
    context,
  );
  final displayedPoint =
      point < 0 ? '' : _readLocale(context, () => locale.decimalSeparator);
  final displayedFraction =
      point < 0
          ? ''
          : _localizeAsciiRuns(mantissa.substring(point + 1), locale, context);
  final exponentDigits = body.substring(exponentStart + 2);
  final exponentSign = _localizedSign(
    body.codeUnitAt(exponentStart + 1) == 0x2d,
    '+',
    locale,
    context,
  );

  return integer +
      displayedPoint +
      displayedFraction +
      body[exponentStart] +
      exponentSign +
      _readLocale(context, () => locale.localizeDigits(exponentDigits));
}

/// The index of the `p` or `P` in [_formatHexadecimal] output, or -1 when
/// [body] is not that shape: hexadecimal digits, an optional `.` with more
/// of them, then the marker, a sign, and decimal digits.
int _hexadecimalExponentStart(String body) {
  var index = body.length;
  while (index > 0 && _isAsciiDigitUnit(body.codeUnitAt(index - 1))) {
    index--;
  }
  // A marker, a sign, and at least one digit each side of them.
  if (index == body.length || index < 3) return -1;
  final sign = body.codeUnitAt(index - 1);
  if (sign != 0x2b && sign != 0x2d) return -1;
  final marker = body.codeUnitAt(index - 2);
  if (marker != 0x70 && marker != 0x50) return -1;

  final mantissaEnd = index - 2;
  var digits = 0;
  var points = 0;
  for (var scan = 0; scan < mantissaEnd; scan++) {
    final unit = body.codeUnitAt(scan);
    if (unit == 0x2e) {
      // At most one point, and never before the first digit.
      if (points > 0 || digits == 0) return -1;
      points++;
    } else if (_isHexadecimalDigitUnit(unit)) {
      digits++;
    } else {
      return -1;
    }
  }

  return digits == 0 ? -1 : mantissaEnd;
}

bool _isHexadecimalDigitUnit(int codeUnit) =>
    _isAsciiDigitUnit(codeUnit) ||
    (codeUnit >= 0x61 && codeUnit <= 0x66) ||
    (codeUnit >= 0x41 && codeUnit <= 0x46);
