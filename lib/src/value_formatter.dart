part of 'engine.dart';

String formatValue(
  Object? value,
  String specification,
  Format engine,
  FormatExceptionContext context,
) => _formatParsedValue(
  value,
  _parseFormatSpec(specification, engine.textUnit, context),
  engine,
  context,
);

String _formatParsedValue(
  Object? value,
  _FormatSpec spec,
  Format engine,
  FormatExceptionContext context,
) {
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
  if (_isIntegerValue(value)) {
    if (_isFloatingFormatType(spec.type) || _demandsFloating(spec)) {
      return _formatBraceDouble(value!, spec, engine, context);
    }
    return _formatBraceInteger(value!, spec, engine, context);
  }
  if (value is double) {
    return _formatBraceDouble(value, spec, engine, context);
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
        matches.map(_describeExtension),
      );
    }
    if (matches.length == 1) {
      return _formatCustom(matches.single, value, spec, engine, context);
    }
    return _fallbackToString(value, context);
  }

  // A formatter is reached by name, or by the specification being empty. A
  // specification that carries options but names nothing therefore never asks
  // the registry — and reporting that as "the formatter does not accept this
  // value" points at the one thing that is not the problem, since
  // `{:>12money}` formats the very same value. Only on the failure path, so
  // the extra pass over the registry costs nothing that matters.
  for (final formatter in engine.formatters) {
    if (_canFormat(formatter, value, context)) {
      throw InvalidSpecifierException(
        context,
        'A custom formatter is chosen by name, as in "{:>12name}", or by an '
        'empty specification. This one carries options but no name.',
      );
    }
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

/// Reads a formatter's specifier, converting a failure in that user-written
/// getter into the same typed failure the rest of the engine promises.
String _readExtensionSpecifier(Formatter<dynamic> formatter) {
  try {
    return formatter.specifier;
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      const FormatExceptionContext(),
      formatter.runtimeType.toString(),
      error,
      stackTrace,
    );
  }
}

/// Names a formatter for a failure report. Reporting must never fail, so a
/// specifier that throws here degrades to the type name instead of replacing
/// the failure being reported.
String _describeExtension(Formatter<dynamic> formatter) {
  try {
    return formatter.specifier;
  } on Object {
    return formatter.runtimeType.toString();
  }
}

bool _canFormat(
  Formatter<dynamic> formatter,
  Object? value,
  FormatExceptionContext context,
) {
  try {
    return formatterAccepts(formatter, value);
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      _describeExtension(formatter),
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
        context: context,
      ),
    );
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      _describeExtension(formatter),
      error,
      stackTrace,
    );
  }
}

String _fallbackToString(Object? value, FormatExceptionContext context) {
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

/// Whether a specification carrying no floating type can still only have been
/// meant for a floating value.
///
/// Asked only under dart2js, and only of a value that reached the integer
/// branch there — which is every whole `double`, because `2.0 is int` holds.
/// Without this, `format('{:.3}', 2.0)` met the integer validator, which
/// rejects a precision outright: the same source formatted on the VM and under
/// dart2wasm and threw in the browser, on values that merely happened to come
/// out whole. That is the worst shape a defect can take — it depends on data,
/// it does not reproduce where the author develops, and it reaches the user as
/// an exception rather than as a wrong string.
///
/// A precision, `z` and a fraction separator are the three options an integer
/// specification cannot carry at all, so a specification carrying one of them
/// is a floating specification whatever the runtime believes the value to be.
///
/// dart2js cannot tell `2` from `2.0`, so one divergence from CPython here is
/// unavoidable. This is the milder one: it formats where CPython raises,
/// instead of raising where CPython formats.
bool _demandsFloating(_FormatSpec spec) =>
    _isWebInt &&
    (spec.precision != null ||
        spec.normalizeNegativeZero ||
        spec.fractionalGrouping != null);

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
      final half = padding ~/ 2;
      return '${fillUnit * half}$value${fillUnit * (padding - half)}';
    default:
      // Unreachable, and not removable: `=` is the only other alignment the
      // parser produces, and every path into here rejects it first, but a
      // switch statement that returns needs a branch that cannot fall out of
      // the bottom.
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
  const maximum = 0x10ffff;
  const surrogateStart = 0xd800;
  const surrogateEnd = 0xdfff;

  if (value is int && _isIntegerValue(value)) {
    if (value >= 0 &&
        value <= maximum &&
        (value < surrogateStart || value > surrogateEnd)) {
      return value;
    }
  } else if (value is BigInt) {
    if (value >= BigInt.zero &&
        value <= BigInt.from(maximum) &&
        (value < BigInt.from(surrogateStart) ||
            value > BigInt.from(surrogateEnd))) {
      return value.toInt();
    }
  }
  throw UnsupportedFormatValueException(context, value);
}
