part of 'engine.dart';

_PrintfTemplate _parsePrintfTemplate(String template) =>
    _PrintfParser(template).parse();

/// A structural test seam. It is deliberately not exported by `format.dart`.
String debugParsePrintfTemplate(String template) =>
    _parsePrintfTemplate(template).debugDescription();

/// Mutation test seam. It is deliberately not exported by `format.dart`.
void debugClearPrintfTemplateNodes(String template) =>
    _parsePrintfTemplate(template).nodes.clear();

final class _PrintfParser {
  final String template;
  var _index = 0;

  _PrintfParser(this.template);

  _PrintfTemplate parse() {
    final nodes = <_PrintfNode>[];
    var literalStart = 0;

    while (_index < template.length) {
      if (template.codeUnitAt(_index) != 0x25) {
        _index++;
        continue;
      }
      if (literalStart < _index) {
        final text = template.substring(literalStart, _index);
        nodes.add(_PrintfLiteralNode(literalStart, text, text));
      }
      nodes.add(_parseConversion());
      literalStart = _index;
    }

    if (literalStart < template.length) {
      final text = template.substring(literalStart);
      nodes.add(_PrintfLiteralNode(literalStart, text, text));
    }
    return _PrintfTemplate(nodes);
  }

  _PrintfConversionNode _parseConversion() {
    final offset = _index++;
    if (_index == template.length) {
      throw _invalid(offset, _index, 'A percent token must have a type.');
    }

    var flags = 0;
    while (_index < template.length) {
      final flag = _flagBitFor(template.codeUnitAt(_index));
      if (flag == 0) break;
      flags |= flag;
      _index++;
    }

    final width = _parseOption(offset);
    _PrintfOption? precision;
    if (_at(0x2e)) {
      _index++;
      precision = _parseOption(offset, allowEmpty: true);
    }

    if (_index == template.length) {
      throw _invalid(
        offset,
        _index,
        'A percent token must terminate in a supported conversion.',
      );
    }

    final typeOffset = _index;
    final typeScalar = _readScalarFrom(template, _index)!;
    final type = template.substring(_index, typeScalar.end);
    _index = typeScalar.end;
    if (!_supportedTypes.contains(type)) {
      final (:end, :conversion) = _invalidTail(typeOffset, type);
      throw _invalid(
        offset,
        end,
        'Unsupported printf conversion syntax.',
        specifier: type,
        conversion: conversion,
      );
    }

    final fragment = template.substring(offset, _index);
    final node = _PrintfConversionNode(
      offset: offset,
      fragment: fragment,
      flags: flags,
      width: width,
      precision: precision,
      type: type,
    );
    _validate(node);
    return node;
  }

  _PrintfOption? _parseOption(int conversionOffset, {bool allowEmpty = false}) {
    if (_at(0x2a)) {
      _index++;
      return const _DynamicPrintfOption();
    }
    final start = _index;
    while (_index < template.length && _isAsciiDigitAt(_index)) {
      _index++;
    }
    if (start == _index) {
      return allowEmpty ? const _LiteralPrintfOption(0) : null;
    }
    final value = int.tryParse(template.substring(start, _index));
    if (value != null && value <= _maximumSafeFormatOption) {
      return _LiteralPrintfOption(value);
    }
    // Past the safety ceiling — and on the web `tryParse` cannot even tell
    // "past it" from "too long to be an int", since an int is a double
    // there and the parse rounds rather than failing. The exact value
    // cannot matter to a formatter that refuses the option either way, so
    // both platforms carry the same marker and both report the refusal in
    // the same place, with the same type, naming the option that caused it.
    return const _LiteralPrintfOption(_maximumSafeFormatOption + 1);
  }

  void _validate(_PrintfConversionNode node) {
    final allowedFlags = _allowedPrintfFlags(node.type);

    final hasInvalidFlag = (node.flags & ~allowedFlags) != 0;
    final invalidWidth = node.type == '%' && node.width != null;
    final invalidPrecision =
        (node.type == 'c' || node.type == '%') && node.precision != null;
    if (hasInvalidFlag || invalidWidth || invalidPrecision) {
      throw InvalidSpecifierException(
        _context(
          node.offset,
          node.offset + node.fragment.length,
          specifier: node.type,
          conversion: node.type,
        ),
        'The printf options do not apply to this conversion.',
      );
    }
  }

  bool _at(int codeUnit) =>
      _index < template.length && template.codeUnitAt(_index) == codeUnit;

  bool _isAsciiDigitAt(int index) {
    final codeUnit = template.codeUnitAt(index);
    return codeUnit >= 0x30 && codeUnit <= 0x39;
  }

  int _flagBitFor(int codeUnit) => switch (codeUnit) {
    0x2d => _PrintfFlags.left,
    0x2b => _PrintfFlags.sign,
    0x20 => _PrintfFlags.space,
    0x23 => _PrintfFlags.alternate,
    0x30 => _PrintfFlags.zero,
    _ => 0,
  };

  bool _isLengthModifier(String value) =>
      value == 'h' ||
      value == 'l' ||
      value == 'j' ||
      value == 'z' ||
      value == 't' ||
      value == 'L';

  ({int end, String? conversion}) _invalidTail(
    int candidateOffset,
    String candidate,
  ) {
    if (_isLengthModifier(candidate)) {
      var end = candidateOffset + candidate.length;
      while (end < template.length && _isLengthModifier(template[end])) {
        end++;
      }
      return _scanInvalidTail(end);
    }
    if (candidate == r'$') return _scanInvalidTail(_index);
    if (!_isConversionCandidate(candidate)) {
      return _scanInvalidTail(_index);
    }
    return (
      end: candidateOffset + candidate.length,
      conversion: _isConversionCandidate(candidate) ? candidate : null,
    );
  }

  ({int end, String? conversion}) _scanInvalidTail(int start) {
    var end = start;
    while (end < template.length) {
      final scalar = _readScalarFrom(template, end)!;
      final candidate = template.substring(end, scalar.end);
      if (_isConversionCandidate(candidate)) {
        return (end: scalar.end, conversion: candidate);
      }
      end = scalar.end;
    }
    return (end: end, conversion: null);
  }

  bool _isConversionCandidate(String value) {
    if (value == '%') return true;
    if (value.length != 1) return false;
    final codeUnit = value.codeUnitAt(0);
    return (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
  }

  InvalidFormatException _invalid(
    int offset,
    int end,
    String reason, {
    String? specifier,
    String? conversion,
  }) => InvalidFormatException(
    _context(offset, end, specifier: specifier, conversion: conversion),
    reason,
  );

  FormatExceptionContext _context(
    int offset,
    int end, {
    String? specifier,
    String? conversion,
  }) {
    final safeOffset = offset.clamp(0, template.length);
    final safeEnd = end.clamp(safeOffset, template.length);
    return FormatExceptionContext(
      template: template,
      offset: safeOffset,
      fragment: template.substring(safeOffset, safeEnd),
      specifier: specifier,
      conversion: conversion,
    );
  }
}

const _supportedTypes = {
  'c',
  's',
  'd',
  'i',
  'u',
  'o',
  'x',
  'X',
  'a',
  'A',
  'e',
  'E',
  'f',
  'F',
  'g',
  'G',
  '%',
};

int _allowedPrintfFlags(String type) => switch (type) {
  'c' || 's' => _PrintfFlags.left,
  'd' || 'i' =>
    _PrintfFlags.left |
        _PrintfFlags.sign |
        _PrintfFlags.space |
        _PrintfFlags.zero,
  'u' => _PrintfFlags.left | _PrintfFlags.zero,
  'o' ||
  'x' ||
  'X' => _PrintfFlags.left | _PrintfFlags.alternate | _PrintfFlags.zero,
  'a' || 'A' || 'e' || 'E' || 'f' || 'F' || 'g' || 'G' =>
    _PrintfFlags.left |
        _PrintfFlags.sign |
        _PrintfFlags.space |
        _PrintfFlags.alternate |
        _PrintfFlags.zero,
  '%' => 0,
  _ => throw StateError('Unsupported printf conversion $type.'),
};

/// Test seam, deliberately not exported by `format.dart`.
Set<String> debugPrintfConversionTypes() => _supportedTypes;

/// Test seam, deliberately not exported by `format.dart`.
Map<String, Set<String>> debugPrintfFlagTokensByConversion() =>
    Map<String, Set<String>>.unmodifiable({
      for (final type in _supportedTypes)
        type: Set<String>.unmodifiable({
          for (final entry in const [
            (_PrintfFlags.left, '-'),
            (_PrintfFlags.sign, '+'),
            (_PrintfFlags.space, ' '),
            (_PrintfFlags.alternate, '#'),
            (_PrintfFlags.zero, '0'),
          ])
            if ((_allowedPrintfFlags(type) & entry.$1) != 0) entry.$2,
        }),
    });

extension on _PrintfTemplate {
  String debugDescription() => nodes.map(_debugNode).join(' | ');

  String _debugNode(_PrintfNode node) => switch (node) {
    _PrintfLiteralNode(:final offset, :final fragment, :final text) =>
      'literal(offset=$offset,fragment=$fragment,text=$text)',
    _PrintfConversionNode(
      :final offset,
      :final fragment,
      :final flags,
      :final width,
      :final precision,
      :final type,
    ) =>
      'conversion(offset=$offset,fragment=$fragment,'
          'flags=${_debugFlags(flags)},width=${_debugOption(width)},'
          'precision=${_debugOption(precision)},type=$type)',
  };

  String _debugFlags(int flags) {
    const ordered = [
      (_PrintfFlags.left, '-'),
      (_PrintfFlags.sign, '+'),
      (_PrintfFlags.space, ' '),
      (_PrintfFlags.alternate, '#'),
      (_PrintfFlags.zero, '0'),
    ];
    return [
      for (final (flag, symbol) in ordered)
        if (_hasPrintfFlag(flags, flag)) symbol,
    ].join();
  }

  String _debugOption(_PrintfOption? option) => switch (option) {
    null => 'absent',
    _LiteralPrintfOption(:final value) => '$value',
    _DynamicPrintfOption() => 'dynamic',
  };
}
