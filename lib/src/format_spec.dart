part of 'engine.dart';

final class _FormatSpec {
  final String? fill;
  final String? align;
  final String? sign;
  final bool normalizeNegativeZero;
  final bool alternate;
  final bool zero;
  final int? width;
  final String? grouping;
  final int? precision;
  final String? fractionalGrouping;
  final String? type;
  final String? customName;
  final String? payload;

  const _FormatSpec({
    this.fill,
    this.align,
    this.sign,
    this.normalizeNegativeZero = false,
    this.alternate = false,
    this.zero = false,
    this.width,
    this.grouping,
    this.precision,
    this.fractionalGrouping,
    this.type,
    this.customName,
    this.payload,
  });
}

// ignore: library_private_types_in_public_api
_FormatSpec parseFormatSpec(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  final simple = _simpleBuiltinFormatSpec(source);
  if (simple != null) return simple;
  return _parseFormatSpecGeneral(source, textUnit, context);
}

_FormatSpec _parseFormatSpecGeneral(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  final units = textUnit.split(source);
  var index = 0;
  String? fill;
  String? align;
  String? sign;
  var normalizeNegativeZero = false;
  var alternate = false;
  var zero = false;
  int? width;
  String? grouping;
  int? precision;
  String? fractionalGrouping;
  String? type;
  String? customName;
  String? payload;

  bool at(String value) => index < units.length && units[index] == value;
  String take() => units[index++];

  if (index + 1 < units.length && _isAlign(units[index + 1])) {
    fill = take();
    align = take();
  } else if (index < units.length && _isAlign(units[index])) {
    align = take();
  }

  if (index < units.length && _isSign(units[index])) sign = take();
  if (at('z')) {
    normalizeNegativeZero = true;
    take();
  }
  if (at('#')) {
    alternate = true;
    take();
  }
  if (at('0')) {
    zero = true;
    take();
  }
  if (index < units.length && _isAsciiDigit(units[index])) {
    width = _readDecimal(units, index, () => index++, context);
  }
  if (index < units.length && _isGrouping(units[index])) grouping = take();
  if (at('.')) {
    take();
    if (index >= units.length || !_isAsciiDigit(units[index])) {
      throw _invalidSpecifier(
        context,
        'Precision must contain decimal digits.',
      );
    }
    precision = _readDecimal(units, index, () => index++, context);
    if (index < units.length && _isGrouping(units[index])) {
      fractionalGrouping = take();
    }
  }

  if (index < units.length) {
    if (at('%')) {
      type = take();
      if (index != units.length) {
        throw _invalidSpecifier(
          context,
          'A built-in type must terminate the format specification.',
        );
      }
    } else if (_isCustomNameStart(units[index])) {
      final name = StringBuffer();
      do {
        name.write(take());
      } while (index < units.length && _isCustomNameContinue(units[index]));

      final parsedName = name.toString();
      if (_builtInTypes.contains(parsedName)) {
        type = parsedName;
        if (index != units.length) {
          throw _invalidSpecifier(
            context,
            'A built-in type must terminate the format specification.',
          );
        }
      } else {
        customName = parsedName;
        if (index < units.length) {
          if (!at(':')) {
            throw _invalidSpecifier(context, 'Invalid custom format name.');
          }
          take();
          payload = units.skip(index).join();
          index = units.length;
        }
      }
    } else {
      throw _invalidSpecifier(context, 'Invalid format type.');
    }
  }

  return _FormatSpec(
    fill: fill,
    align: align,
    sign: sign,
    normalizeNegativeZero: normalizeNegativeZero,
    alternate: alternate,
    zero: zero,
    width: width,
    grouping: grouping,
    precision: precision,
    fractionalGrouping: fractionalGrouping,
    type: type,
    customName: customName,
    payload: payload,
  );
}

const _builtInTypes = {
  'b',
  'c',
  'd',
  'e',
  'E',
  'f',
  'F',
  'g',
  'G',
  'n',
  'o',
  's',
  'x',
  'X',
  '%',
};

/// Test seam for the cold parser allocation fast path. It is deliberately not
/// exported by `format.dart`.
bool debugUsesSimpleBuiltinFormatSpec(String source) =>
    _simpleBuiltinFormatSpec(source) != null;

/// Test seam companion to [debugUsesSimpleBuiltinFormatSpec]: true only when
/// the fast path recognizes [source] and produces the same specification as
/// the general parser for both text units. It is deliberately not exported by
/// `format.dart`.
bool debugSimpleBuiltinFormatSpecMatchesGeneralParser(String source) {
  final fast = _simpleBuiltinFormatSpec(source);
  if (fast == null) return false;
  const context = FormatExceptionContext();
  return TextUnit.values.every(
    (textUnit) => _debugFormatSpecEquals(
      fast,
      _parseFormatSpecGeneral(source, textUnit, context),
    ),
  );
}

bool _debugFormatSpecEquals(_FormatSpec a, _FormatSpec b) =>
    a.fill == b.fill &&
    a.align == b.align &&
    a.sign == b.sign &&
    a.normalizeNegativeZero == b.normalizeNegativeZero &&
    a.alternate == b.alternate &&
    a.zero == b.zero &&
    a.width == b.width &&
    a.grouping == b.grouping &&
    a.precision == b.precision &&
    a.fractionalGrouping == b.fractionalGrouping &&
    a.type == b.type &&
    a.customName == b.customName &&
    a.payload == b.payload;

_FormatSpec? _simpleBuiltinFormatSpec(String source) {
  final length = source.length;
  if (length == 0) return null;
  if (length == 1) {
    return source.codeUnitAt(0) <= 0x7f && _builtInTypes.contains(source)
        ? _FormatSpec(type: source)
        : null;
  }
  if (source.codeUnitAt(0) != 0x2e) {
    return _simpleAsciiFlagWidthSpec(source, length);
  }
  if (length < 3) return null;

  final type = source.codeUnitAt(length - 1);
  if (type != 0x46 && type != 0x66) return null;
  var precision = 0;
  for (var index = 1; index < length - 1; index++) {
    final digit = source.codeUnitAt(index) - 0x30;
    if (digit < 0 || digit > 9) return null;
    precision = precision * 10 + digit;
    if (precision > 20) return null;
  }
  return type == 0x66
      ? _simpleFixedLowerSpecs[precision]
      : _simpleFixedUpperSpecs[precision];
}

/// Parses `sign? z? #? 0? width? type?` specifications made of ASCII code
/// units only. Fill, align, grouping, precision, custom formats and anything
/// non-ASCII stay on the general parser.
_FormatSpec? _simpleAsciiFlagWidthSpec(String source, int length) {
  var index = 0;
  final sign = switch (source.codeUnitAt(0)) {
    0x2b => '+',
    0x2d => '-',
    0x20 => ' ',
    _ => null,
  };
  if (sign != null) index++;
  var normalizeNegativeZero = false;
  if (index < length && source.codeUnitAt(index) == 0x7a) {
    normalizeNegativeZero = true;
    index++;
  }
  var alternate = false;
  if (index < length && source.codeUnitAt(index) == 0x23) {
    alternate = true;
    index++;
  }
  var zero = false;
  if (index < length && source.codeUnitAt(index) == 0x30) {
    zero = true;
    index++;
  }
  int? width;
  var digits = 0;
  var value = 0;
  while (index < length) {
    final digit = source.codeUnitAt(index) - 0x30;
    if (digit < 0 || digit > 9) break;
    value = value * 10 + digit;
    if (++digits > 6) return null;
    index++;
  }
  if (digits > 0) width = value;
  String? type;
  if (index < length) {
    if (index != length - 1) return null;
    type = _builtInTypeFromCodeUnit(source.codeUnitAt(index));
    if (type == null) return null;
  }
  return _FormatSpec(
    sign: sign,
    normalizeNegativeZero: normalizeNegativeZero,
    alternate: alternate,
    zero: zero,
    width: width,
    type: type,
  );
}

String? _builtInTypeFromCodeUnit(int codeUnit) => switch (codeUnit) {
  0x62 => 'b',
  0x63 => 'c',
  0x64 => 'd',
  0x65 => 'e',
  0x45 => 'E',
  0x66 => 'f',
  0x46 => 'F',
  0x67 => 'g',
  0x47 => 'G',
  0x6e => 'n',
  0x6f => 'o',
  0x73 => 's',
  0x78 => 'x',
  0x58 => 'X',
  0x25 => '%',
  _ => null,
};

final _simpleFixedLowerSpecs = List<_FormatSpec>.unmodifiable(
  List.generate(
    21,
    (precision) => _FormatSpec(precision: precision, type: 'f'),
  ),
);

final _simpleFixedUpperSpecs = List<_FormatSpec>.unmodifiable(
  List.generate(
    21,
    (precision) => _FormatSpec(precision: precision, type: 'F'),
  ),
);

bool _isAlign(String value) =>
    value == '<' || value == '>' || value == '=' || value == '^';

bool _isSign(String value) => value == '+' || value == '-' || value == ' ';

bool _isGrouping(String value) => value == ',' || value == '_';

bool _isAsciiDigit(String value) =>
    value.length == 1 &&
    value.codeUnitAt(0) >= 0x30 &&
    value.codeUnitAt(0) <= 0x39;

bool _isCustomNameStart(String value) =>
    value.length == 1 &&
    ((value.codeUnitAt(0) >= 0x41 && value.codeUnitAt(0) <= 0x5a) ||
        (value.codeUnitAt(0) >= 0x61 && value.codeUnitAt(0) <= 0x7a));

bool _isCustomNameContinue(String value) =>
    _isCustomNameStart(value) ||
    _isAsciiDigit(value) ||
    (value.length == 1 && value.codeUnitAt(0) == 0x5f);

int _readDecimal(
  List<String> units,
  int start,
  void Function() advance,
  FormatExceptionContext context,
) {
  final digits = StringBuffer();
  var index = start;
  while (index < units.length && _isAsciiDigit(units[index])) {
    digits.write(units[index]);
    advance();
    index++;
  }
  return int.tryParse(digits.toString()) ??
      (throw _invalidSpecifier(context, 'Decimal value is out of range.'));
}

InvalidSpecifierException _invalidSpecifier(
  FormatExceptionContext context,
  String reason,
) => InvalidSpecifierException(context, reason);
