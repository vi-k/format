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

_FormatSpec? _simpleBuiltinFormatSpec(String source) {
  if (source.length == 1 && source.codeUnitAt(0) <= 0x7f) {
    return _builtInTypes.contains(source) ? _FormatSpec(type: source) : null;
  }
  if (source.length < 3 || source.codeUnitAt(0) != 0x2e) return null;

  final type = source.codeUnitAt(source.length - 1);
  if (type != 0x46 && type != 0x66) return null;
  var precision = 0;
  for (var index = 1; index < source.length - 1; index++) {
    final digit = source.codeUnitAt(index) - 0x30;
    if (digit < 0 || digit > 9) return null;
    precision = precision * 10 + digit;
    if (precision > 20) return null;
  }
  return type == 0x66
      ? _simpleFixedLowerSpecs[precision]
      : _simpleFixedUpperSpecs[precision];
}

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
