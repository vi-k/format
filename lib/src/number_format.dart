part of 'engine.dart';

bool _isIntegerValue(Object? value) {
  if (value is BigInt) return true;
  if (value is! int) return false;
  if (value is! double) return true;
  return value.isFinite && !(value == 0 && value.isNegative);
}

String formatBraceInteger(
  Object value,
  // ignore: library_private_types_in_public_api
  _FormatSpec spec,
  Format settings,
  FormatExceptionContext context,
) {
  final type = spec.type ?? 'd';
  _validateIntegerSpec(spec, type, context);

  final isLocaleDecimal = type == 'n';
  final radix = switch (type) {
    'b' => 2,
    'o' => 8,
    'd' || 'n' => 10,
    'x' || 'X' => 16,
    _ =>
      throw _invalidSpecifier(
        context,
        'This integer presentation type is not supported yet.',
      ),
  };
  final negative = switch (value) {
    int() => value.isNegative,
    BigInt() => value.isNegative,
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final digits = switch (value) {
    int() => _formatIntMagnitude(value, radix, uppercase: type == 'X'),
    BigInt() => formatMagnitude(
      value.isNegative ? -value : value,
      radix,
      uppercase: type == 'X',
    ),
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final prefix = _integerPrefix(type, spec.alternate);

  if (isLocaleDecimal) {
    final locale = settings.numberLocale;
    final groupingEnabled = _readLocale(context, () => locale.groupingEnabled);
    List<int>? grouping;
    String? separator;
    if (groupingEnabled) {
      grouping = List<int>.from(_readLocale(context, () => locale.grouping));
      _validateGrouping(grouping, context);
      separator = _readLocale(context, () => locale.groupSeparator);
    }
    final sign = _localizedSign(negative, spec.sign, locale, context);
    return applyNumericWidth(
      sign: sign,
      prefix: prefix,
      digits: digits,
      spec: spec,
      textUnit: settings.textUnit,
      formatDigits: (asciiDigits) {
        final grouped =
            grouping == null
                ? asciiDigits
                : groupDigits(
                  asciiDigits,
                  separator: separator!,
                  grouping: grouping,
                );
        return _localizeDigits(grouped, separator, locale, context);
      },
    );
  }

  String Function(String)? grouping;
  if (spec.grouping != null) {
    final groupingSize = type == 'd' ? 3 : 4;
    grouping =
        (value) => groupDigits(
          value,
          separator: spec.grouping!,
          grouping: [groupingSize],
        );
  }
  return applyNumericWidth(
    sign: _asciiSign(negative, spec.sign),
    prefix: prefix,
    digits: digits,
    spec: spec,
    textUnit: settings.textUnit,
    formatDigits: grouping,
  );
}

String formatMagnitude(BigInt magnitude, int radix, {bool uppercase = false}) {
  final digits =
      radix == 10 ? magnitude.toString() : magnitude.toRadixString(radix);
  return uppercase ? digits.toUpperCase() : digits;
}

String _formatIntMagnitude(int value, int radix, {bool uppercase = false}) {
  final raw = radix == 10 ? value.toString() : value.toRadixString(radix);
  final digits = value.isNegative ? raw.substring(1) : raw;
  return uppercase ? digits.toUpperCase() : digits;
}

String groupDigits(
  String digits, {
  required String separator,
  required List<int> grouping,
}) {
  if (digits.isEmpty) return digits;
  final groups = <String>[];
  var end = digits.length;
  var groupingIndex = 0;
  while (end > 0) {
    final size =
        grouping[groupingIndex < grouping.length
            ? groupingIndex
            : grouping.length - 1];
    final start = (end - size).clamp(0, end);
    groups.add(digits.substring(start, end));
    end = start;
    groupingIndex++;
  }
  return groups.reversed.join(separator);
}

String applyNumericWidth({
  required String sign,
  required String prefix,
  required String digits,
  // ignore: library_private_types_in_public_api
  required _FormatSpec spec,
  required TextUnit textUnit,
  String Function(String digits)? formatDigits,
  bool fitRegroupedZeroPadding = false,
}) {
  final displayedDigits = formatDigits?.call(digits) ?? digits;
  final value = sign + prefix + displayedDigits;
  final width = spec.width;
  if (width == null) return value;

  final fill = spec.fill ?? (spec.zero ? '0' : ' ');
  final align = spec.align ?? (spec.zero ? '=' : '>');
  if (align == '=' && fill == '0' && formatDigits != null) {
    if (fitRegroupedZeroPadding) {
      var lower = 0;
      var upper = width - textUnit.length(sign + prefix + displayedDigits);
      while (lower < upper) {
        final middle = (lower + upper) ~/ 2;
        final candidate = formatDigits('${'0' * middle}$digits');
        if (textUnit.length(sign + prefix + candidate) < width) {
          lower = middle + 1;
        } else {
          upper = middle;
        }
      }
      return sign + prefix + formatDigits('${'0' * lower}$digits');
    }
    final padding = width - textUnit.length(value);
    if (padding <= 0) return value;
    return sign + prefix + formatDigits(fill * padding + digits);
  }

  final padding = width - textUnit.length(value);
  if (padding <= 0) return value;
  if (align == '=') return sign + prefix + fill * padding + displayedDigits;

  switch (align) {
    case '<':
      return value + fill * padding;
    case '>':
      return fill * padding + value;
    case '^':
      final left = fill * (padding ~/ 2);
      final right = fill * (padding - padding ~/ 2);
      return left + value + right;
    default:
      throw StateError('Unsupported numeric alignment: $align');
  }
}

String formatBraceDouble(
  Object value,
  // ignore: library_private_types_in_public_api
  _FormatSpec spec,
  Format settings,
  FormatExceptionContext context,
) {
  final converted = switch (value) {
    double() => value,
    int() => value.toDouble(),
    BigInt() => value.toDouble(),
    _ => throw UnsupportedFormatValueException(context, value),
  };
  if (_isIntegerValue(value) && !converted.isFinite) {
    throw UnsupportedFormatValueException(context, value);
  }

  final type = spec.type;
  _validateDoubleSpec(spec, type, context);
  final binary = Binary64.fromDouble(converted);
  final uppercase = type == 'E' || type == 'F' || type == 'G';
  final percent = type == '%';
  final formattingBinary =
      percent ? Binary64.fromDouble(converted * 100) : binary;

  late final _AsciiFloat formatted;
  if (!formattingBinary.isFinite) {
    final nan = formattingBinary.isNaN;
    final word = nan ? 'nan' : 'inf';
    formatted = _AsciiFloat(
      uppercase ? word.toUpperCase() : word,
      false,
      special: true,
    );
  } else if (type == null && spec.precision == null) {
    formatted = _formatShortest(converted, spec.alternate);
  } else {
    final precision = spec.precision ?? 6;
    formatted = switch (type) {
      'f' || 'F' => _formatFixed(converted, binary, precision, spec.alternate),
      'e' || 'E' => _formatScientific(binary, precision, spec.alternate, type!),
      'g' || 'G' || 'n' => _formatGeneral(
        binary,
        precision == 0 ? 1 : precision,
        spec.alternate,
        type == 'G' ? 'E' : 'e',
      ),
      '%' => _formatFixed(
        converted * 100,
        formattingBinary,
        precision,
        spec.alternate,
      ),
      null => _formatGeneral(
        binary,
        precision == 0 ? 1 : precision,
        spec.alternate,
        'e',
        emptyType: true,
      ),
      _ => throw StateError('Unsupported floating presentation: $type'),
    };
  }

  var negative = !formattingBinary.isNaN && formattingBinary.signBit;
  if (spec.normalizeNegativeZero && formatted.roundedZero) negative = false;
  final locale = type == 'n' ? settings.numberLocale : null;
  final sign =
      locale == null
          ? _asciiSign(negative, spec.sign)
          : _localizedSign(negative, spec.sign, locale, context);
  final suffix = percent ? '%' : '';
  return applyNumericWidth(
    sign: sign,
    prefix: '',
    digits: formatted.body + suffix,
    spec: spec,
    textUnit: settings.textUnit,
    fitRegroupedZeroPadding: true,
    formatDigits:
        (body) =>
            _displayFloatBody(body, spec, locale, context, formatted.special),
  );
}

final class _AsciiFloat {
  final String body;
  final bool roundedZero;
  final bool special;

  const _AsciiFloat(this.body, this.roundedZero, {this.special = false});
}

const _fixedDecimalScales = <double>[
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
  10000000000000000,
  100000000000000000,
  1000000000000000000,
  10000000000000000000,
  100000000000000000000,
];

const _maximumExactDoubleInteger = 4503599627370496.0;

_AsciiFloat _formatFixed(
  double source,
  Binary64 binary,
  int precision,
  bool alternate,
) {
  final fast = _formatFixedFast(source, precision, alternate);
  if (fast != null) return fast;

  final rounded = binary.roundDecimal(precision);
  return _AsciiFloat(
    _fixedFromRounded(rounded, precision, alternate),
    rounded == BigInt.zero,
  );
}

_AsciiFloat? _formatFixedFast(double source, int precision, bool alternate) {
  if (precision < 0 || precision >= _fixedDecimalScales.length) return null;
  final magnitude = source.abs();
  if (magnitude >= 1e21) return null;

  final scaled = magnitude * _fixedDecimalScales[precision];
  if (scaled >= _maximumExactDoubleInteger) return null;
  final integer = scaled.truncateToDouble();
  final evenHalfTie = scaled - integer == 0.5 && integer.toInt().isEven;
  if (evenHalfTie) return null;

  var body = magnitude.toStringAsFixed(precision);
  if (alternate && precision == 0) body += '.';
  return _AsciiFloat(body, scaled < 0.5);
}

_AsciiFloat _formatScientific(
  Binary64 value,
  int precision,
  bool alternate,
  String exponentCharacter,
) {
  var exponent = value.isZero ? 0 : value.decimalExponent();
  var rounded = value.roundDecimal(precision - exponent);
  final expectedDigits = precision + 1;
  if (rounded.toString().length > expectedDigits) {
    rounded ~/= BigInt.from(10);
    exponent++;
  }
  final digits = rounded.toString().padLeft(expectedDigits, '0');
  final fraction = precision == 0 ? '' : digits.substring(1);
  final point = precision > 0 || alternate ? '.' : '';
  return _AsciiFloat(
    digits[0] + point + fraction + _asciiExponent(exponentCharacter, exponent),
    rounded == BigInt.zero,
  );
}

_AsciiFloat _formatGeneral(
  Binary64 value,
  int precision,
  bool alternate,
  String exponentCharacter, {
  bool emptyType = false,
}) {
  var exponent = value.isZero ? 0 : value.decimalExponent();
  var rounded = value.roundDecimal(precision - 1 - exponent);
  if (rounded.toString().length > precision) {
    rounded ~/= BigInt.from(10);
    exponent++;
  }
  final digits = rounded.toString().padLeft(precision, '0');
  String body;
  final scientificCutoff = emptyType ? precision - 1 : precision;
  if (exponent < -4 || exponent >= scientificCutoff) {
    var fraction = precision == 1 ? '' : digits.substring(1);
    if (!alternate) fraction = _trimTrailingZeros(fraction);
    final point = fraction.isNotEmpty || alternate ? '.' : '';
    body =
        digits[0] +
        point +
        fraction +
        _asciiExponent(exponentCharacter, exponent);
  } else {
    final requestedFractionalDigits = precision - 1 - exponent;
    final fractionalDigits =
        requestedFractionalDigits < 0 ? 0 : requestedFractionalDigits;
    body = _fixedFromRounded(rounded, fractionalDigits, alternate);
    if (!alternate) body = _trimFixedZeros(body);
    if (emptyType && !body.contains('.')) body += '.0';
  }
  return _AsciiFloat(body, rounded == BigInt.zero);
}

_AsciiFloat _formatShortest(double value, bool alternate) {
  final source = value.abs().toString();
  final parsed = _parseShortest(source);
  if (parsed.digits == '0') return const _AsciiFloat('0.0', true);
  final scientific = parsed.exponent < -4 || parsed.exponent >= 16;
  if (scientific) {
    final fraction =
        parsed.digits.length == 1 ? '' : parsed.digits.substring(1);
    final point = fraction.isNotEmpty || alternate ? '.' : '';
    return _AsciiFloat(
      parsed.digits[0] +
          point +
          fraction +
          _asciiExponent('e', parsed.exponent),
      false,
    );
  }
  final decimalPosition = parsed.exponent + 1;
  late String body;
  if (decimalPosition <= 0) {
    body = '0.${'0' * -decimalPosition}${parsed.digits}';
  } else if (decimalPosition >= parsed.digits.length) {
    body =
        '${parsed.digits}'
        '${'0' * (decimalPosition - parsed.digits.length)}.0';
  } else {
    body =
        '${parsed.digits.substring(0, decimalPosition)}.'
        '${parsed.digits.substring(decimalPosition)}';
  }
  return _AsciiFloat(body, false);
}

final class _ShortestDecimal {
  final String digits;
  final int exponent;

  const _ShortestDecimal(this.digits, this.exponent);
}

String _pythonShortestDouble(double value) {
  final binary = Binary64.fromDouble(value);
  if (binary.isNaN) return 'nan';
  if (binary.isInfinite) return binary.signBit ? '-inf' : 'inf';
  final sign = binary.signBit ? '-' : '';
  return sign + _formatShortest(value, false).body;
}

_ShortestDecimal _parseShortest(String source) {
  final exponentIndex = source.indexOf(RegExp('[eE]'));
  final mantissa =
      exponentIndex < 0 ? source : source.substring(0, exponentIndex);
  final externalExponent =
      exponentIndex < 0 ? 0 : int.parse(source.substring(exponentIndex + 1));
  final point = mantissa.indexOf('.');
  final decimalPosition = point < 0 ? mantissa.length : point;
  final rawDigits = mantissa.replaceAll('.', '');
  final first = rawDigits.indexOf(RegExp('[1-9]'));
  if (first < 0) return const _ShortestDecimal('0', 0);
  var digits = rawDigits.substring(first);
  while (digits.length > 1 && digits.endsWith('0')) {
    digits = digits.substring(0, digits.length - 1);
  }
  return _ShortestDecimal(
    digits,
    decimalPosition - first - 1 + externalExponent,
  );
}

String _fixedFromRounded(BigInt rounded, int precision, bool alternate) {
  var digits = rounded.toString();
  if (precision == 0) return digits + (alternate ? '.' : '');
  digits = digits.padLeft(precision + 1, '0');
  final split = digits.length - precision;
  return '${digits.substring(0, split)}.${digits.substring(split)}';
}

String _trimTrailingZeros(String value) {
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0x30) {
    end--;
  }
  return value.substring(0, end);
}

String _trimFixedZeros(String value) {
  if (!value.contains('.')) return value;
  var result = _trimTrailingZeros(value);
  if (result.endsWith('.')) result = result.substring(0, result.length - 1);
  return result;
}

String _asciiExponent(String character, int exponent) {
  final sign = exponent < 0 ? '-' : '+';
  final digits = exponent.abs().toString().padLeft(2, '0');
  return '$character$sign$digits';
}

String _displayFloatBody(
  String body,
  // ignore: library_private_types_in_public_api
  _FormatSpec spec,
  NumberLocale? locale,
  FormatExceptionContext context,
  bool special, {
  bool localeGrouping = true,
}) {
  var suffix = '';
  if (body.endsWith('%')) {
    suffix = '%';
    body = body.substring(0, body.length - 1);
  }
  if (special) {
    return (locale == null ? body : _localizeAsciiRuns(body, locale, context)) +
        suffix;
  }

  final exponentMatch = RegExp(r'([eE])([+-])(\d+)$').firstMatch(body);
  final mantissa =
      exponentMatch == null ? body : body.substring(0, exponentMatch.start);
  final point = mantissa.indexOf('.');
  var integer = point < 0 ? mantissa : mantissa.substring(0, point);
  var fraction = point < 0 ? '' : mantissa.substring(point + 1);

  String? localeGroupSeparator;
  if (locale != null && localeGrouping) {
    final enabled = _readLocale(context, () => locale.groupingEnabled);
    if (enabled) {
      final grouping = List<int>.from(
        _readLocale(context, () => locale.grouping),
      );
      _validateGrouping(grouping, context);
      final separator = _readLocale(context, () => locale.groupSeparator);
      localeGroupSeparator = separator;
      integer = groupDigits(integer, separator: separator, grouping: grouping);
    }
  } else if (spec.grouping != null) {
    integer = groupDigits(
      integer,
      separator: spec.grouping!,
      grouping: const [3],
    );
  }
  if (spec.fractionalGrouping != null && fraction.isNotEmpty) {
    fraction = groupFractionDigits(fraction, spec.fractionalGrouping!);
  }

  final decimalSeparator =
      point < 0
          ? ''
          : locale == null
          ? '.'
          : _readLocale(context, () => locale.decimalSeparator);
  if (locale != null) {
    integer =
        localeGroupSeparator == null
            ? _readLocale(context, () => locale.localizeDigits(integer))
            : integer
                .split(localeGroupSeparator)
                .map(
                  (group) =>
                      _readLocale(context, () => locale.localizeDigits(group)),
                )
                .join(localeGroupSeparator);
    if (fraction.isNotEmpty) {
      fraction = _readLocale(context, () => locale.localizeDigits(fraction));
    }
  }
  var displayed = integer + decimalSeparator + fraction;
  if (exponentMatch != null) {
    var exponentSeparator =
        locale == null
            ? exponentMatch.group(1)!
            : _readLocale(context, () => locale.exponentSeparator);
    if (exponentMatch.group(1) == 'E') {
      exponentSeparator = exponentSeparator.toUpperCase();
    }
    final exponentNegative = exponentMatch.group(2) == '-';
    final exponentSign =
        locale == null
            ? exponentMatch.group(2)!
            : _localizedSign(exponentNegative, '+', locale, context);
    final exponentDigits =
        locale == null
            ? exponentMatch.group(3)!
            : _readLocale(
              context,
              () => locale.localizeDigits(exponentMatch.group(3)!),
            );
    displayed += exponentSeparator + exponentSign + exponentDigits;
  }
  return displayed + suffix;
}

String groupFractionDigits(String digits, String separator) {
  final groups = <String>[];
  for (var start = 0; start < digits.length; start += 3) {
    groups.add(digits.substring(start, (start + 3).clamp(0, digits.length)));
  }
  return groups.join(separator);
}

String _localizeAsciiRuns(
  String value,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  final output = StringBuffer();
  var start = 0;
  for (final match in RegExp(r'\d+').allMatches(value)) {
    output
      ..write(value.substring(start, match.start))
      ..write(
        _readLocale(context, () => locale.localizeDigits(match.group(0)!)),
      );
    start = match.end;
  }
  return (output..write(value.substring(start))).toString();
}

void _validateDoubleSpec(
  _FormatSpec spec,
  String? type,
  FormatExceptionContext context,
) {
  const doubleTypes = {null, 'e', 'E', 'f', 'F', 'g', 'G', 'n', '%'};
  if (!doubleTypes.contains(type)) {
    throw _invalidSpecifier(
      context,
      'This floating-point presentation type is not supported.',
    );
  }
  if (type == 'n' &&
      (spec.grouping != null || spec.fractionalGrouping != null)) {
    throw _invalidSpecifier(
      context,
      'Explicit grouping is not valid for locale-aware formatting.',
    );
  }
  if (spec.precision != null && spec.precision! > 100000) {
    throw _invalidSpecifier(
      context,
      'Precision is too large to format safely.',
    );
  }
}

void _validateIntegerSpec(
  _FormatSpec spec,
  String type,
  FormatExceptionContext context,
) {
  const integerTypes = {'b', 'd', 'n', 'o', 'x', 'X'};
  if (!integerTypes.contains(type)) {
    throw _invalidSpecifier(
      context,
      'This integer presentation type is not supported yet.',
    );
  }
  if (spec.normalizeNegativeZero ||
      spec.precision != null ||
      spec.fractionalGrouping != null) {
    throw _invalidSpecifier(
      context,
      'This option is not valid for integer formatting.',
    );
  }
  if ((spec.grouping == ',' && type != 'd') ||
      (spec.grouping == '_' && type == 'n')) {
    throw _invalidSpecifier(
      context,
      'This grouping option is not valid for this integer presentation.',
    );
  }
}

String _integerPrefix(String type, bool alternate) {
  if (!alternate) return '';
  return switch (type) {
    'b' => '0b',
    'o' => '0o',
    'x' => '0x',
    'X' => '0X',
    _ => '',
  };
}

String _asciiSign(bool negative, String? requestedSign) {
  if (negative) return '-';
  return switch (requestedSign) {
    '+' => '+',
    ' ' => ' ',
    _ => '',
  };
}

String _localizedSign(
  bool negative,
  String? requestedSign,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  if (negative) return _readLocale(context, () => locale.minusSign);
  return switch (requestedSign) {
    '+' => _readLocale(context, () => locale.plusSign),
    ' ' => ' ',
    _ => '',
  };
}

String _localizeDigits(
  String digits,
  String? separator,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  if (separator == null) {
    return _readLocale(context, () => locale.localizeDigits(digits));
  }
  return digits
      .split(separator)
      .map((group) => _readLocale(context, () => locale.localizeDigits(group)))
      .join(separator);
}

T _readLocale<T>(FormatExceptionContext context, T Function() read) {
  try {
    return read();
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(context, 'NumberLocale', error, stackTrace);
  }
}

void _validateGrouping(List<int> grouping, FormatExceptionContext context) {
  if (grouping.isEmpty || grouping.any((size) => size <= 0)) {
    throw _invalidSpecifier(context, 'The number locale has invalid grouping.');
  }
}
