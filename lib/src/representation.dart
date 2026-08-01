part of 'engine.dart';

Object? applyConversion(
  String? conversion,
  Object? value,
  Format engine,
  FormatExceptionContext context,
) {
  switch (conversion) {
    case null:
      return value;
    case 's':
      return value?.toString();
    case 'r':
      return _RepresentationWriter(engine, context).represent(value);
    case 'a':
      return _asciiEscape(
        _RepresentationWriter(engine, context).represent(value),
      );
    default:
      throw StateError('Unknown conversion: $conversion');
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
      case num():
        output.write(_number(value));
      case Map<Object?, Object?>():
        _writeMap(value, output);
      case Set<Object?>():
        _writeSet(value, output);
      case Iterable<Object?>():
        _writeIterable(value, output);
      default:
        output.write(_representExtension(value));
    }
  }

  String _number(num value) {
    if (value is double) {
      if (value.isNaN) return 'nan';
      if (value.isInfinite) return value.isNegative ? '-inf' : 'inf';
    }
    return value.toString();
  }

  String _quoteString(String value) {
    final singleQuoteEscapes = "'".allMatches(value).length;
    final doubleQuoteEscapes = '"'.allMatches(value).length;
    final quote = singleQuoteEscapes <= doubleQuoteEscapes ? "'" : '"';
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
      } else if (_isControlScalar(scalar)) {
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
        output.write('set()');
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
      return representation.canRepresent(value);
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

bool _isControlScalar(int scalar) =>
    scalar < 0x20 || (scalar >= 0x7f && scalar <= 0x9f);

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
