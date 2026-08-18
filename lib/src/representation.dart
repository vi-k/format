part of 'engine.dart';

Object? applyConversion(
  String? conversion,
  Object? value,
  Format engine,
  FormatExceptionContext context,
) {
  // The null conversion is answered before the switch, not by a `case null`
  // inside it. dart2wasm from 3.6.0 through 3.9.0 miscompiles a switch
  // statement whose scrutinee is a nullable String and whose cases include
  // `null`: a string equal to a case constant but not identical to it takes
  // `default` instead. Every conversion reaching here is exactly that,
  // because the parser cuts it out of the template with `substring`, so
  // `'{!r}'` and `'{!a}'` threw UnsupportedConversionException on values they
  // represent perfectly well — on every SDK below 3.10.0 that this package
  // claims to support, and on no runtime a CI job watches. Only that one
  // shape is affected: the same switch without a null case, the switch
  // expression form, and the Object? switch in
  // `_RepresentationWriter._write` all compile correctly.
  if (conversion == null) return value;
  switch (conversion) {
    case 's':
      return _fallbackToString(value, context);
    case 'r':
      return _represent(value, engine, context);
    case 'a':
      return _asciiEscape(_represent(value, engine, context));
    default:
      throw UnsupportedConversionException(context, value);
  }
}

/// Walks [value] under the same failure contract as `_fallbackToString`.
///
/// `_active` catches a structure that refers to itself, which is the loop that
/// has no depth at all. A structure that is merely very deep has one, and the
/// walk is recursive, so past some nesting it exhausts the stack — twenty
/// thousand levels does it. Left alone, that arrived as a bare
/// `StackOverflowError`, which is not a `FormattingException` and which the
/// README promises callers will not see; `'{}'` and `'{!s}'` on the same value
/// already reported it as a `FormatExtensionException`, because they go through
/// `_fallbackToString`. This makes `'{!r}'` and `'{!a}'` answer the same way.
String _represent(
  Object? value,
  Format engine,
  FormatExceptionContext context,
) {
  try {
    return _RepresentationWriter(engine, context).represent(value);
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

final class _RepresentationWriter {
  final Format engine;
  final FormatExceptionContext context;
  final Set<Object> _active = Set<Object>.identity();

  _RepresentationWriter(this.engine, this.context);

  String represent(Object? value) {
    final output = StringBuffer();
    _write(value, output);
    return output.toString();
  }

  void _write(Object? value, StringBuffer output) {
    switch (value) {
      case null:
        output.write('null');
      case bool():
        output.write(value ? 'true' : 'false');
      case String():
        output.write(_quoteString(value));
      case BigInt():
        output.write(value.toString());
      case int() when _isIntegerValue(value):
        output.write(BigInt.from(value).toString());
      case double():
        output.write(_representDouble(value, engine));
      case Map<Object?, Object?>():
        _writeMap(value, output);
      case Set<Object?>():
        _writeSet(value, output);
      case List<Object?>():
        _writeIterable(value, output);
      default:
        output.write(_representExtension(value));
    }
  }

  String _quoteString(String value) {
    final quote = value.contains("'") && !value.contains('"') ? '"' : "'";
    final output = StringBuffer(quote);
    for (final scalar in value.runes) {
      if (scalar == 0x5c) {
        output.write(r'\\');
      } else if (scalar == quote.codeUnitAt(0)) {
        output.write('\\$quote');
      } else if (scalar == 0x09) {
        output.write(r'\t');
      } else if (scalar == 0x0a) {
        output.write(r'\n');
      } else if (scalar == 0x0d) {
        output.write(r'\r');
      } else if (!isPythonPrintable(scalar)) {
        output.write(_scalarEscape(scalar));
      } else {
        output.writeCharCode(scalar);
      }
    }
    output.write(quote);
    return output.toString();
  }

  void _writeMap(Map<Object?, Object?> value, StringBuffer output) {
    if (!_enter(value)) {
      output.write('{...}');
      return;
    }
    try {
      output.write('{');
      var first = true;
      for (final entry in value.entries) {
        if (!first) output.write(', ');
        _write(entry.key, output);
        output.write(': ');
        _write(entry.value, output);
        first = false;
      }
      output.write('}');
    } finally {
      _active.remove(value);
    }
  }

  void _writeSet(Set<Object?> value, StringBuffer output) {
    if (!_enter(value)) {
      output.write('{...}');
      return;
    }
    try {
      if (value.isEmpty) {
        output.write('{}');
        return;
      }
      output.write('{');
      _writeValues(value, output);
      output.write('}');
    } finally {
      _active.remove(value);
    }
  }

  void _writeIterable(Iterable<Object?> value, StringBuffer output) {
    if (!_enter(value)) {
      output.write('[...]');
      return;
    }
    try {
      output.write('[');
      _writeValues(value, output);
      output.write(']');
    } finally {
      _active.remove(value);
    }
  }

  void _writeValues(Iterable<Object?> values, StringBuffer output) {
    var first = true;
    for (final value in values) {
      if (!first) output.write(', ');
      _write(value, output);
      first = false;
    }
  }

  bool _enter(Object value) => _active.add(value);

  String _representExtension(Object? value) {
    final matches = <Representation<dynamic>>[];
    for (final representation in engine.representations) {
      if (_canRepresent(representation, value)) matches.add(representation);
    }
    if (matches.isEmpty) {
      throw UnsupportedConversionException(context, value);
    }
    if (matches.length > 1) {
      throw AmbiguousFormatterException(
        context,
        value,
        matches.map(_extensionName),
      );
    }
    return _represent(matches.single, value);
  }

  bool _canRepresent(Representation<dynamic> representation, Object? value) {
    try {
      return representationAccepts(representation, value);
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      throw FormatExtensionException(
        context,
        _extensionName(representation),
        error,
        stackTrace,
      );
    }
  }

  String _represent(Representation<dynamic> representation, Object? value) {
    try {
      return representation.represent(value);
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      throw FormatExtensionException(
        context,
        _extensionName(representation),
        error,
        stackTrace,
      );
    }
  }

  String _extensionName(Representation<dynamic> representation) =>
      representation.runtimeType.toString();
}

String _representDouble(double value, Format engine) {
  if (engine.doubleFormatMode == DoubleFormatMode.compatible) {
    return _pythonShortestDouble(value);
  }
  if (value.isFinite) return value.toString();
  final body = _formatSpecialDouble(value, false, engine).body;
  return value.isNegative ? '-$body' : body;
}

String _asciiEscape(String value) {
  final output = StringBuffer();
  for (final scalar in value.runes) {
    if (scalar >= 0x20 && scalar <= 0x7e) {
      output.writeCharCode(scalar);
    } else {
      output.write(_scalarEscape(scalar));
    }
  }
  return output.toString();
}

String _scalarEscape(int scalar) {
  final hex = scalar.toRadixString(16);
  if (scalar <= 0xff) return r'\x' + hex.padLeft(2, '0');
  if (scalar <= 0xffff) return r'\u' + hex.padLeft(4, '0');
  return r'\U' + hex.padLeft(8, '0');
}
