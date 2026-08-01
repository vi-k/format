part of 'engine.dart';

String formatBraceInteger(
  Object value,
  // ignore: library_private_types_in_public_api
  _FormatSpec spec,
  Format settings,
  FormatExceptionContext context,
) {
  final integer = switch (value) {
    int() => BigInt.from(value),
    BigInt() => value,
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final type = spec.type ?? 'd';
  _validateIntegerSpec(spec, type, context);

  final negative = integer.isNegative;
  final magnitude = negative ? -integer : integer;
  final isLocaleDecimal = type == 'n';
  final radix = switch (type) {
    'b' => 2,
    'o' => 8,
    'd' || 'n' => 10,
    'x' || 'X' => 16,
    _ => throw _invalidSpecifier(
      context,
      'This integer presentation type is not supported yet.',
    ),
  };
  var digits = formatMagnitude(magnitude, radix, uppercase: type == 'X');
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
      digits = groupDigits(digits, separator: separator!, grouping: grouping);
    }
    digits = _localizeDigits(digits, separator, locale, context);
    final sign = _localizedSign(negative, spec.sign, locale, context);
    return applyNumericWidth(
      sign: sign,
      prefix: prefix,
      digits: digits,
      spec: spec,
      textUnit: settings.textUnit,
    );
  }

  String Function(String)? grouping;
  if (spec.grouping != null) {
    final groupingSize = type == 'd' ? 3 : 4;
    grouping = (value) => groupDigits(
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
    group: grouping,
  );
}

String formatMagnitude(BigInt magnitude, int radix, {bool uppercase = false}) {
  final digits = magnitude.toRadixString(radix);
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
    final size = grouping[groupingIndex < grouping.length
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
  String Function(String digits)? group,
}) {
  final groupedDigits = group?.call(digits) ?? digits;
  final value = sign + prefix + groupedDigits;
  final width = spec.width;
  if (width == null) return value;

  final fill = spec.fill ?? (spec.zero ? '0' : ' ');
  final align = spec.align ?? (spec.zero ? '=' : '>');
  if (align == '=' && fill == '0' && group != null) {
    final padding = width - textUnit.length(value);
    if (padding <= 0) return value;
    return sign + prefix + group(fill * padding + digits);
  }

  final padding = width - textUnit.length(value);
  if (padding <= 0) return value;
  if (align == '=') return sign + prefix + fill * padding + groupedDigits;

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
