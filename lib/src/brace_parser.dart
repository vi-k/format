part of 'engine.dart';

_BraceTemplate _parseBraceTemplate(String template) =>
    _BraceParser(template).parse();

/// A structural test seam. It is deliberately not exported by `format.dart`.
String debugParseBraceTemplate(String template) =>
    _parseBraceTemplate(template).debugDescription();

enum _NumberingMode { unset, automatic, manual }

final class _BraceParser {
  static final BigInt _maximumIndex = BigInt.parse('9223372036854775807');

  final String template;
  var _index = 0;
  var _numberingMode = _NumberingMode.unset;

  _BraceParser(this.template);

  _BraceTemplate parse() => _BraceTemplate(_parseNodes(depth: 0));

  List<_BraceNode> _parseNodes({required int depth}) {
    final nodes = <_BraceNode>[];
    var literalStart = _index;
    final literal = StringBuffer();

    void flushLiteral() {
      if (literal.isNotEmpty) {
        nodes.add(
          _LiteralNode(
            literalStart,
            template.substring(literalStart, _index),
            literal.toString(),
          ),
        );
        literal.clear();
      }
    }

    while (_index < template.length) {
      final codeUnit = template.codeUnitAt(_index);
      if (codeUnit == 0x7b) {
        if (_hasNextCodeUnit(0x7b)) {
          if (depth > 0) {
            throw _invalid(
              _index,
              _index + 2,
              'Opening braces in format specifications must start a field.',
            );
          }
          literal.write('{');
          _index += 2;
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
        literalStart = _index;
      } else if (codeUnit == 0x7d) {
        if (depth > 0) {
          flushLiteral();
          return nodes;
        }
        if (_hasNextCodeUnit(0x7d)) {
          literal.write('}');
          _index += 2;
          continue;
        }
        throw _invalid(
          _index,
          _index + 1,
          'Single closing brace is not allowed.',
        );
      } else {
        literal.writeCharCode(codeUnit);
        _index++;
      }
    }

    if (depth > 0) {
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
    final root = _parseRoot();
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
      if (_index >= template.length) {
        throw _invalid(
          conversionOffset,
          _index,
          'Expected a conversion after !.',
        );
      }
      final candidate = template[_index];
      if (candidate != 's' && candidate != 'r' && candidate != 'a') {
        throw _invalid(
          conversionOffset,
          _index + 1,
          'Conversion must be one of !s, !r, or !a.',
        );
      }
      conversion = candidate;
      _index++;
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
      fragment: template.substring(fieldOffset, _index),
      root: root,
      accesses: accesses,
      conversion: conversion,
      specification: specification,
    );
  }

  _FieldRoot _parseRoot() {
    if (_index >= template.length ||
        _isRootTerminator(template.codeUnitAt(_index))) {
      _useAutomaticNumbering(_index);
      return const _AutomaticRoot();
    }

    final start = _index;
    final scalar = _readScalar(_index);
    if (scalar == null) {
      throw _invalid(start, _fieldNameEnd(start), 'Expected an argument name.');
    }
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
      _useManualNumbering(start);
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

  int _decimalIndex(List<int> digits, int offset, int end) {
    final asciiDigits = digits.join();
    final value = BigInt.parse(asciiDigits);
    if (value > _maximumIndex) {
      throw _invalid(
        offset,
        end,
        'Numeric indexes must fit in a signed 64-bit integer.',
      );
    }
    return value.toInt();
  }

  void _useAutomaticNumbering(int offset) {
    if (_numberingMode == _NumberingMode.manual) {
      throw _invalid(
        offset,
        offset,
        'Cannot switch from manual to automatic field numbering.',
      );
    }
    _numberingMode = _NumberingMode.automatic;
  }

  void _useManualNumbering(int offset) {
    if (_numberingMode == _NumberingMode.automatic) {
      throw _invalid(
        offset,
        offset,
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
