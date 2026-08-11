part of 'engine.dart';

_BraceTemplate _parseBraceTemplate(String template) =>
    _BraceParser(template).parse();

/// A structural test seam. It is deliberately not exported by `format.dart`.
String debugParseBraceTemplate(String template) =>
    _parseBraceTemplate(template).debugDescription();

enum _NumberingMode { unset, automatic, manual }

final class _BraceParser {
  static final BigInt _maximumIndex = BigInt.parse('9223372036854775807');

  /// The digit count of [_maximumIndex]: anything longer is out of range
  /// without being parsed.
  static const _maximumIndexDigits = 19;

  /// The widest index that plain `int` arithmetic gets exactly right on both
  /// number models: 10^15 is under 2^53, so a dart2js double still names every
  /// value below it, and it is far under 2^63.
  static const _exactIndexDigits = 15;

  final String template;
  var _index = 0;
  var _numberingMode = _NumberingMode.unset;

  _BraceParser(this.template);

  _BraceTemplate parse() => _BraceTemplate(_parseNodes(depth: 0));

  /// How far the web branch walks before handing the rest of a literal to
  /// the native search.
  ///
  /// A search costs about as much as walking ten characters under dart2js,
  /// so a window a little past that keeps a brace-dense template on the walk
  /// while a long literal still reaches the search after a fixed toll.
  static const _webWalkWindow = 12;

  /// The next `{` or `}` at or after [from], or -1 when the rest of the
  /// template is ordinary text. Web only; see [_parseNodes].
  int _nextBraceIndex(int from) {
    final open = template.indexOf('{', from);
    if (open < 0) return template.indexOf('}', from);
    final close = template.indexOf('}', from);
    if (close < 0) return open;

    return open < close ? open : close;
  }

  List<_BraceNode> _parseNodes({required int depth}) {
    final nodes = <_BraceNode>[];

    // A literal is normally a slice of the template, so scanning one only
    // advances an index and the text is taken in one piece at the end.
    // `{{` and `}}` are the exception: they stand for text the template does
    // not contain verbatim, so the first of them starts a buffer that the
    // slices either side are appended to.
    var plainStart = _index;
    StringBuffer? escaped;

    // A stack of `{{` offsets, and the reason escapes must balance inside a
    // specification while staying independent in ordinary text: what ends a
    // specification is the first unescaped `}`, so the parser has to know
    // whether a `}}` it meets closes an escape or is the end plus a stray
    // brace. Ordinary text has no such boundary to find and needs no stack.
    //
    // The cost of that rule is an expressive limit, documented in the README:
    // a specification — and therefore a formatter payload — cannot carry an
    // unbalanced brace at all.
    //
    // Only meaningful inside a specification, and most specifications have
    // no escapes at all, so this stays unallocated until one appears.
    List<int>? escapedOpeningOffsets;

    void takeEscape(String character) {
      final buffer = escaped ??= StringBuffer();
      if (_index > plainStart) {
        buffer.write(template.substring(plainStart, _index));
      }
      buffer.write(character);
      _index += 2;
      plainStart = _index;
    }

    void flushLiteral() {
      final buffer = escaped;
      if (buffer != null) {
        if (_index > plainStart) {
          buffer.write(template.substring(plainStart, _index));
        }
        nodes.add(_LiteralNode(buffer.toString()));
        escaped = null;
      } else if (_index > plainStart) {
        nodes.add(_LiteralNode(template.substring(plainStart, _index)));
      }
      plainStart = _index;
    }

    // Characters walked since the last brace; web only, see the loop below.
    var walked = 0;

    while (_index < template.length) {
      final codeUnit = template.codeUnitAt(_index);
      if (codeUnit != 0x7b && codeUnit != 0x7d) {
        // Ordinary text: nothing to copy, the slice is taken on flush.
        _index++;
        // Under dart2js every step of this walk is a bounds-checked call
        // into the string, and a long literal pays for all of them: forty
        // characters cost 129 ns to walk against 36 ns to find, four hundred
        // 1042 ns against 84. A native search is worth about ten walked
        // characters there, so the walk keeps short runs — where a search
        // would be pure overhead — and hands anything longer over once. On
        // the VM the walk beats the search on every shape tried, and
        // `_isWeb` being a const drops this branch there entirely.
        if (_isWeb && ++walked == _webWalkWindow) {
          final brace = _nextBraceIndex(_index);
          if (brace < 0) {
            _index = template.length;
            break;
          }
          _index = brace;
          walked = 0;
        }
        continue;
      }
      walked = 0;
      if (codeUnit == 0x7b) {
        if (_hasNextCodeUnit(0x7b)) {
          if (depth > 0) (escapedOpeningOffsets ??= <int>[]).add(_index);
          takeEscape('{');
          continue;
        }
        flushLiteral();
        if (depth > 1) {
          throw _invalid(
            _index,
            _index + 1,
            'Nested replacement fields may be only one level deep.',
          );
        }
        nodes.add(_parseField(depth: depth));
        plainStart = _index;
      } else if (codeUnit == 0x7d) {
        if (depth > 0) {
          final pending = escapedOpeningOffsets;
          if (_hasNextCodeUnit(0x7d) && pending != null && pending.isNotEmpty) {
            pending.removeLast();
            takeEscape('}');
            continue;
          }
          if (pending != null && pending.isNotEmpty) {
            throw _invalid(
              pending.last,
              _index + 1,
              'Escaped opening braces in a specification require }}.',
            );
          }
          flushLiteral();
          return nodes;
        }
        if (_hasNextCodeUnit(0x7d)) {
          takeEscape('}');
          continue;
        }
        throw _invalid(
          _index,
          _index + 1,
          'Single closing brace is not allowed.',
        );
      }
    }

    if (depth > 0) {
      final pending = escapedOpeningOffsets;
      if (pending != null && pending.isNotEmpty) {
        throw _invalid(
          pending.last,
          template.length,
          'Escaped opening braces in a specification require }}.',
        );
      }
      throw _invalid(
        template.length,
        template.length,
        'Expected a closing brace for the format specification.',
      );
    }
    flushLiteral();
    return nodes;
  }

  _FieldNode _parseField({required int depth}) {
    final fieldOffset = _index;
    _index++;
    final root = _parseRoot(fieldOffset);
    final accesses = <_FieldAccess>[];

    while (_index < template.length) {
      final codeUnit = template.codeUnitAt(_index);
      if (codeUnit == 0x2e) {
        accesses.add(_parseAttribute());
      } else if (codeUnit == 0x5b) {
        accesses.add(_parseItem());
      } else {
        break;
      }
    }

    String? conversion;
    if (_atCodeUnit(0x21)) {
      final conversionOffset = _index;
      _index++;
      // One scalar, not one code unit. Taking a single UTF-16 unit here cut
      // an astral conversion in half: the parse then tripped over the low
      // surrogate left behind, and the rejection named an offset inside a
      // character and carried half of one as its fragment. `_readScalar`
      // returns null only past the end of the template, which is the same
      // condition the explicit length check used to catch.
      final scalar = _readScalar(_index);
      if (scalar == null) {
        throw _invalid(
          conversionOffset,
          _index,
          'Expected a conversion after !.',
        );
      }
      conversion = template.substring(_index, scalar.end);
      _index = scalar.end;
    }

    var specification = const <_BraceNode>[];
    if (_atCodeUnit(0x3a)) {
      _index++;
      specification = _parseNodes(depth: depth + 1);
    }

    if (!_atCodeUnit(0x7d)) {
      if (_index >= template.length) {
        throw _invalid(
          fieldOffset,
          template.length,
          'Expected a closing brace for replacement field.',
        );
      }
      throw _invalid(
        _index,
        _index + 1,
        'Expected a lookup, conversion, format specification, '
        'or closing brace.',
      );
    }
    _index++;
    return _FieldNode(
      offset: fieldOffset,
      template: template,
      end: _index,
      root: root,
      // Most fields have no lookups at all, and a cached template holds one
      // node per field: handing over the shared empty list rather than the
      // one built above is what keeps a field-dense template from retaining
      // a list object per field for nothing, the way an empty specification
      // already does.
      accesses: accesses.isEmpty ? const <_FieldAccess>[] : accesses,
      conversion: conversion,
      specification: specification,
    );
  }

  _FieldRoot _parseRoot(int fieldOffset) {
    if (_index >= template.length ||
        _isRootTerminator(template.codeUnitAt(_index))) {
      _useAutomaticNumbering(fieldOffset);
      return const _AutomaticRoot();
    }

    final start = _index;
    // Never null here: `_readScalarFrom` returns null only past the end of
    // the template, and the guard above has already taken that case. A lone
    // surrogate is a scalar like any other and does not produce null either.
    final scalar = _readScalar(_index)!;
    if (pythonDecimalDigitValue(scalar.value) != null) {
      final digits = _readDecimalDigits();
      if (_index < template.length &&
          !_isRootTerminator(template.codeUnitAt(_index))) {
        throw _invalid(
          start,
          _fieldNameEnd(start),
          'A numeric argument name may contain only decimal digits.',
        );
      }
      _useManualNumbering(fieldOffset);
      return _PositionalRoot(_decimalIndex(digits, start, _index));
    }
    if (!isPythonIdentifierStart(scalar.value)) {
      throw _invalid(
        start,
        _fieldNameEnd(start),
        'Argument names must be Python identifiers.',
      );
    }
    _index = scalar.end;
    while (_index < template.length) {
      final next = _readScalar(_index);
      if (next == null || !isPythonIdentifierContinue(next.value)) break;
      _index = next.end;
    }
    return _NamedRoot(template.substring(start, _index));
  }

  _AttributeAccess _parseAttribute() {
    final dotOffset = _index;
    _index++;
    final start = _index;
    final scalar = _readScalar(_index);
    if (scalar == null || !isPythonIdentifierStart(scalar.value)) {
      throw _invalid(
        dotOffset,
        _fieldNameEnd(start),
        'Attribute names must be Python identifiers.',
      );
    }
    _index = scalar.end;
    while (_index < template.length) {
      final next = _readScalar(_index);
      if (next == null || !isPythonIdentifierContinue(next.value)) break;
      _index = next.end;
    }
    return _AttributeAccess(template.substring(start, _index));
  }

  _FieldAccess _parseItem() {
    final openOffset = _index;
    _index++;
    final start = _index;
    while (_index < template.length && !_atCodeUnit(0x5d)) {
      if (template[_index] == '"' || template[_index] == "'") {
        throw _invalid(
          start,
          _index + 1,
          'Item keys use literal text, not quote syntax.',
        );
      }
      _index++;
    }
    if (_index >= template.length) {
      throw _invalid(
        openOffset,
        template.length,
        'Expected a closing bracket for item lookup.',
      );
    }
    final key = template.substring(start, _index);
    if (key.isEmpty) {
      throw _invalid(
        openOffset,
        _index + 1,
        'Item lookup keys cannot be empty.',
      );
    }
    _index++;
    final decimalDigits = _decimalDigits(key);
    if (decimalDigits != null) {
      return _IntegerItemAccess(
        _decimalIndex(decimalDigits, start, start + key.length),
      );
    }
    return _StringItemAccess(key);
  }

  List<int> _readDecimalDigits() {
    final digits = <int>[];
    while (_index < template.length) {
      final scalar = _readScalar(_index);
      if (scalar == null) break;
      final digit = pythonDecimalDigitValue(scalar.value);
      if (digit == null) break;
      digits.add(digit);
      _index = scalar.end;
    }
    return digits;
  }

  List<int>? _decimalDigits(String text) {
    if (text.isEmpty) return null;
    final digits = <int>[];
    var offset = 0;
    while (offset < text.length) {
      final scalar = _readScalarFrom(text, offset);
      if (scalar == null) return null;
      final digit = pythonDecimalDigitValue(scalar.value);
      if (digit == null) return null;
      digits.add(digit);
      offset = scalar.end;
    }
    return digits;
  }

  /// Converts a non-empty run of decimal digits into an argument index.
  ///
  /// The digits come from an untrusted template, so the number is never
  /// materialized before its length has ruled it out: `BigInt.parse` costs
  /// O(n^2), while no index wider than [_maximumIndexDigits] digits can fit
  /// in a signed 64-bit integer anyway.
  int _decimalIndex(List<int> digits, int offset, int end) {
    var start = 0;
    while (start < digits.length - 1 && digits[start] == 0) {
      start++;
    }
    final significant = digits.length - start;
    // Almost every index in a real template is one or two digits, and the wide
    // path costs three allocations to say so: a lazy iterable, the string it
    // joins to, and the BigInt parsed out of it. Up to fifteen digits the
    // value fits a JavaScript double exactly as well as it fits a 64-bit int,
    // so plain arithmetic gets the same answer on every platform with none of
    // them. Wider indexes stay on the old path rather than being reasoned
    // about: they cannot occur in a template anyone meant to write, and the
    // point of keeping them identical is that the boundary is not a behaviour.
    if (significant <= _exactIndexDigits) {
      var value = 0;
      for (var index = start; index < digits.length; index++) {
        value = value * 10 + digits[index];
      }

      return value;
    }
    if (significant <= _maximumIndexDigits) {
      final value = BigInt.parse(digits.skip(start).join());
      if (value <= _maximumIndex) return value.toInt();
    }

    throw _invalid(
      offset,
      end,
      'Numeric indexes must fit in a signed 64-bit integer.',
    );
  }

  // Both spans run from the opening brace of the offending field through the
  // character that revealed its numbering style — the terminator after an
  // empty name, or the one after the digits. A zero-width span was the one
  // thing these could not afford: it left the diagnostic with an empty
  // fragment, so it said that something failed without showing what.
  void _useAutomaticNumbering(int fieldOffset) {
    if (_numberingMode == _NumberingMode.manual) {
      throw _invalid(
        fieldOffset,
        _index + 1,
        'Cannot switch from manual to automatic field numbering.',
      );
    }
    _numberingMode = _NumberingMode.automatic;
  }

  void _useManualNumbering(int fieldOffset) {
    if (_numberingMode == _NumberingMode.automatic) {
      throw _invalid(
        fieldOffset,
        _index + 1,
        'Cannot switch from automatic to manual field numbering.',
      );
    }
    _numberingMode = _NumberingMode.manual;
  }

  bool _hasNextCodeUnit(int codeUnit) =>
      _index + 1 < template.length &&
      template.codeUnitAt(_index + 1) == codeUnit;

  bool _atCodeUnit(int codeUnit) =>
      _index < template.length && template.codeUnitAt(_index) == codeUnit;

  bool _isRootTerminator(int codeUnit) =>
      codeUnit == 0x2e ||
      codeUnit == 0x5b ||
      codeUnit == 0x21 ||
      codeUnit == 0x3a ||
      codeUnit == 0x7d;

  int _fieldNameEnd(int start) {
    var end = start;
    while (end < template.length &&
        !_isRootTerminator(template.codeUnitAt(end))) {
      end++;
    }
    return end;
  }

  _Scalar? _readScalar(int offset) => _readScalarFrom(template, offset);

  InvalidFormatException _invalid(int offset, int end, String reason) {
    final safeOffset = offset.clamp(0, template.length);
    final safeEnd = end.clamp(safeOffset, template.length);
    return InvalidFormatException(
      FormatExceptionContext(
        template: template,
        offset: safeOffset,
        fragment: template.substring(safeOffset, safeEnd),
      ),
      reason,
    );
  }
}

final class _Scalar {
  final int value;
  final int end;

  const _Scalar(this.value, this.end);
}

_Scalar? _readScalarFrom(String text, int offset) {
  if (offset >= text.length) return null;
  final first = text.codeUnitAt(offset);
  if (first >= 0xd800 && first <= 0xdbff && offset + 1 < text.length) {
    final second = text.codeUnitAt(offset + 1);
    if (second >= 0xdc00 && second <= 0xdfff) {
      return _Scalar(
        0x10000 + ((first - 0xd800) << 10) + second - 0xdc00,
        offset + 2,
      );
    }
  }
  return _Scalar(first, offset + 1);
}

extension on _BraceTemplate {
  String debugDescription() => nodes.map(_debugNode).join(' | ');

  String _debugNode(_BraceNode node) {
    if (node case _LiteralNode(:final text)) {
      return 'literal=$text';
    }
    final field = node as _FieldNode;
    final parts = <String>[_debugRoot(field.root)];
    for (final access in field.accesses) {
      parts.add(_debugAccess(access));
    }
    if (field.conversion case final conversion?) {
      parts.add('conversion=$conversion');
    }
    for (final node in field.specification) {
      if (node case _FieldNode(:final root)) {
        parts.add('nested=${_debugRootValue(root)}');
      }
      parts.add(_debugNode(node));
    }
    return parts.join(', ');
  }

  String _debugRoot(_FieldRoot root) => 'root=${_debugRootValue(root)}';

  String _debugRootValue(_FieldRoot root) => switch (root) {
    _AutomaticRoot() => 'automatic',
    _PositionalRoot(:final index) => '$index',
    _NamedRoot(:final name) => name,
  };

  String _debugAccess(_FieldAccess access) => switch (access) {
    _AttributeAccess(:final name) => 'attribute=$name',
    _IntegerItemAccess(:final index) => 'item=$index',
    _StringItemAccess(:final key) => 'item=$key',
  };
}
