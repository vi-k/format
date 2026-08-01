part of 'engine.dart';

String formatValue(
  Object? value,
  String specification,
  Format engine,
  FormatExceptionContext context,
) {
  final spec = parseFormatSpec(specification, engine.textUnit, context);

  if (spec.customName case final name?) {
    _validateCustomLayout(spec, context);
    return _formatExplicitCustom(value, name, spec, engine, context);
  }
  if (spec.type == 'c') {
    return _formatCharacter(value, spec, engine, context);
  }
  if (value is String) {
    return _formatText(value, spec, engine.textUnit, context);
  }
  if (value is double) {
    return formatBraceDouble(value, spec, engine, context);
  }
  if (value is int || value is BigInt) {
    if (_isFloatingFormatType(spec.type)) {
      return formatBraceDouble(value!, spec, engine, context);
    }
    return formatBraceInteger(value!, spec, engine, context);
  }

  if (_isEmptySpecification(spec)) {
    if (value is bool || value == null) return value.toString();
    final matches = <Formatter<dynamic>>[];
    for (final formatter in engine.formatters) {
      if (_canFormat(formatter, value, context)) matches.add(formatter);
    }
    if (matches.length > 1) {
      throw AmbiguousFormatterException(
        context,
        value,
        matches.map((formatter) => formatter.specifier),
      );
    }
    if (matches.length == 1) {
      return _formatCustom(matches.single, value, spec, engine, context);
    }
    return _fallbackToString(value, context);
  }

  if (_isNumericFormatType(spec.type) || _hasNumericOptions(spec)) {
    throw UnsupportedFormatValueException(context, value);
  }
  throw UnsupportedFormatValueException(context, value);
}

String _formatExplicitCustom(
  Object? value,
  String name,
  _FormatSpec spec,
  Format engine,
  FormatExceptionContext context,
) {
  final formatter = engine.formatterFor(name);
  if (formatter == null) {
    throw _invalidSpecifier(context, 'Unknown custom formatter: $name.');
  }
  if (!_canFormat(formatter, value, context)) {
    throw UnsupportedFormatValueException(context, value);
  }
  return _formatCustom(formatter, value, spec, engine, context);
}

bool _canFormat(
  Formatter<dynamic> formatter,
  Object? value,
  FormatExceptionContext context,
) {
  try {
    return formatter.canFormat(value);
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      formatter.specifier,
      error,
      stackTrace,
    );
  }
}

String _formatCustom(
  Formatter<dynamic> formatter,
  Object? value,
  _FormatSpec spec,
  Format engine,
  FormatExceptionContext context,
) {
  final output = _invokeFormatter(formatter, value, spec, context);
  return applyFieldWidth(
    output,
    width: spec.width,
    fill: spec.fill,
    align: spec.align ?? '<',
    textUnit: engine.textUnit,
  );
}

void _validateCustomLayout(_FormatSpec spec, FormatExceptionContext context) {
  if (spec.align == '=') {
    throw _invalidSpecifier(
      context,
      'Custom formatter output cannot use numeric alignment.',
    );
  }
}

String _invokeFormatter(
  Formatter<dynamic> formatter,
  Object? value,
  _FormatSpec spec,
  FormatExceptionContext context,
) {
  try {
    return formatter.format(
      value,
      FormatOptions(
        sign: spec.sign,
        normalizeNegativeZero: spec.normalizeNegativeZero,
        alternate: spec.alternate,
        zero: spec.zero,
        grouping: spec.grouping,
        precision: spec.precision,
        payload: spec.payload,
      ),
    );
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      formatter.specifier,
      error,
      stackTrace,
    );
  }
}

String _fallbackToString(Object value, FormatExceptionContext context) {
  try {
    return value.toString();
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      value.runtimeType.toString(),
      error,
      stackTrace,
    );
  }
}

bool _isEmptySpecification(_FormatSpec spec) =>
    spec.fill == null &&
    spec.align == null &&
    spec.sign == null &&
    !spec.normalizeNegativeZero &&
    !spec.alternate &&
    !spec.zero &&
    spec.width == null &&
    spec.grouping == null &&
    spec.precision == null &&
    spec.fractionalGrouping == null &&
    spec.type == null &&
    spec.customName == null &&
    spec.payload == null;

bool _isFloatingFormatType(String? type) => switch (type) {
  'e' || 'E' || 'f' || 'F' || 'g' || 'G' || '%' => true,
  _ => false,
};

bool _isNumericFormatType(String? type) => switch (type) {
  'b' ||
  'd' ||
  'e' ||
  'E' ||
  'f' ||
  'F' ||
  'g' ||
  'G' ||
  'n' ||
  'o' ||
  'x' ||
  'X' ||
  '%' => true,
  _ => false,
};

bool _hasNumericOptions(_FormatSpec spec) =>
    spec.sign != null ||
    spec.normalizeNegativeZero ||
    spec.alternate ||
    spec.zero ||
    spec.grouping != null ||
    spec.precision != null ||
    spec.fractionalGrouping != null ||
    spec.align == '=';

String _formatText(
  String value,
  _FormatSpec spec,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  _validateTextSpec(spec, context);
  final truncated =
      spec.precision == null ? value : textUnit.take(value, spec.precision!);
  return applyFieldWidth(
    truncated,
    width: spec.width,
    fill: spec.fill,
    align: spec.align ?? '<',
    textUnit: textUnit,
  );
}

String _formatCharacter(
  Object? value,
  _FormatSpec spec,
  Format engine,
  FormatExceptionContext context,
) {
  _validateCharacterSpec(spec, context);
  final scalar = _unicodeScalar(value, context);
  return applyFieldWidth(
    String.fromCharCode(scalar),
    width: spec.width,
    fill: spec.fill,
    align: spec.align ?? '>',
    textUnit: engine.textUnit,
  );
}

String applyFieldWidth(
  String value, {
  required int? width,
  required String? fill,
  required String align,
  required TextUnit textUnit,
}) {
  if (width == null) return value;
  final padding = width - textUnit.length(value);
  if (padding <= 0) return value;

  final fillUnit = fill ?? ' ';
  switch (align) {
    case '<':
      return value + fillUnit * padding;
    case '>':
      return fillUnit * padding + value;
    case '^':
      final left = fillUnit * (padding ~/ 2);
      final right = fillUnit * (padding - padding ~/ 2);
      return left + value + right;
    default:
      // ignore: prefer_interpolation_to_compose_strings
      throw StateError('Unsupported text alignment: ' + align);
  }
}

void _validateTextSpec(_FormatSpec spec, FormatExceptionContext context) {
  if (spec.sign != null ||
      spec.normalizeNegativeZero ||
      spec.alternate ||
      spec.zero ||
      spec.grouping != null ||
      spec.fractionalGrouping != null ||
      spec.align == '=' ||
      spec.type == 'c' ||
      (spec.type != null && spec.type != 's') ||
      spec.customName != null ||
      spec.payload != null) {
    throw _invalidSpecifier(
      context,
      'This specification is not valid for text.',
    );
  }
}

void _validateCharacterSpec(_FormatSpec spec, FormatExceptionContext context) {
  if (spec.sign != null ||
      spec.normalizeNegativeZero ||
      spec.alternate ||
      spec.zero ||
      spec.grouping != null ||
      spec.precision != null ||
      spec.fractionalGrouping != null ||
      spec.align == '=' ||
      spec.customName != null ||
      spec.payload != null) {
    throw _invalidSpecifier(
      context,
      'This specification is not valid for Unicode characters.',
    );
  }
}

int _unicodeScalar(Object? value, FormatExceptionContext context) {
  final candidate = switch (value) {
    int() => BigInt.from(value),
    BigInt() => value,
    _ => null,
  };
  const maximum = 0x10ffff;
  const surrogateStart = 0xd800;
  const surrogateEnd = 0xdfff;
  if (candidate == null ||
      candidate < BigInt.zero ||
      candidate > BigInt.from(maximum) ||
      (candidate >= BigInt.from(surrogateStart) &&
          candidate <= BigInt.from(surrogateEnd))) {
    throw UnsupportedFormatValueException(context, value);
  }
  return candidate.toInt();
}
