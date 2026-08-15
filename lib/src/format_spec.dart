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

/// Upper bound for a width or precision, in either mini-language: a brace
/// specification's own, a printf option resolved from a `*` argument, and a
/// static printf option the classifier gates at compile time. Also the lower
/// bound, negated, for a printf width.
///
/// It lives here, with the other bounds a specification has to satisfy, rather
/// than beside one of its readers: it used to be declared in
/// `printf_processor.dart` while the brace parser was its heaviest user, and
/// the precision validator in `number_format.dart` spelled the same number as
/// a literal — a pair the compiler would never have told anyone about.
const _maximumSafeFormatOption = 100000;

/// The most code units a field's padding may write.
///
/// Checked against `width * fill.length` rather than against the padding the
/// call turns out to need, so the promise is decided by the specification
/// alone: a width that is safe is safe for every value. The figure is what
/// [TextUnit.unicodeScalars] could already produce at the maximum width — a
/// scalar is at most two code units — so nothing that formatted before this
/// bound stops formatting, and the grapheme mode gains the bound it never had.
const _maximumSafePaddingUnits = 2 * _maximumSafeFormatOption;

_FormatSpec _parseFormatSpec(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  final simple = _simpleBuiltinFormatSpec(source);
  if (simple != null) return simple;
  return _parseFormatSpecGeneral(source, textUnit, context);
}

/// The largest specification for which the ordinary parser materializes text
/// units.
///
/// Keeping that parser for normal inputs preserves the measured hot path. A
/// larger specification uses the streaming twin below, so an untrusted digit
/// run can never amplify into an unbounded list of one-character strings.
const _maximumMaterializedSpecificationUnits = 256;

_FormatSpec _parseFormatSpecGeneral(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) =>
    source.length <= _maximumMaterializedSpecificationUnits
        ? _parseFormatSpecMaterialized(source, textUnit, context)
        : _parseFormatSpecStreaming(source, textUnit, context);

/// The units of a short [source], for the specification parser's own use.
///
/// [TextUnitOperations.split] is public and hands its caller a defensive
/// copy — a lazy iterable mapped into a growable list and then wrapped
/// unmodifiable, so two copies and a wrapper. The parser needs none of that:
/// it reads the list once, never mutates it and never keeps it.
List<String> _specificationUnits(String source, TextUnit textUnit) {
  for (var index = 0; index < source.length; index++) {
    final unit = source.codeUnitAt(index);
    // CRLF is the sole all-ASCII exception to one code unit being one
    // grapheme cluster.
    if (unit >= 0x80 || unit == 0x0d) return textUnit.split(source);
  }

  return List<String>.generate(
    source.length,
    (index) => source[index],
    growable: false,
  );
}

_FormatSpec _parseFormatSpecMaterialized(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  final units = _specificationUnits(source, textUnit);
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
    width = _readDecimal(units, index, () => index++);
    if (width > _maximumSafeFormatOption) {
      throw _invalidSpecifier(
        context,
        'The width is too large to format safely.',
      );
    }
    if (fill != null && width * fill.length > _maximumSafePaddingUnits) {
      throw _invalidSpecifier(
        context,
        'The width is too large to format safely with this fill.',
      );
    }
  }
  if (index < units.length && _isGrouping(units[index])) grouping = take();
  if (at('.')) {
    take();
    if (index < units.length && _isGrouping(units[index])) {
      fractionalGrouping = take();
    } else {
      if (index >= units.length || !_isAsciiDigit(units[index])) {
        throw _invalidSpecifier(
          context,
          'Precision must contain decimal digits.',
        );
      }
      precision = _readDecimal(units, index, () => index++);
      if (precision > _maximumSafeFormatOption) {
        throw _invalidSpecifier(
          context,
          'The precision is too large to format safely.',
        );
      }
      if (index < units.length && _isGrouping(units[index])) {
        fractionalGrouping = take();
      }
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

/// Whether [source] can be walked one code unit at a time under either text
/// model.
///
/// CRLF is the sole all-ASCII exception: one grapheme cluster but two Unicode
/// scalars. Everything non-ASCII goes through the model's own iterator rather
/// than duplicating either boundary algorithm here.
bool _hasSimpleAsciiUnits(String source) {
  for (var index = 0; index < source.length; index++) {
    final unit = source.codeUnitAt(index);
    if (unit >= 0x80 || unit == 0x0d) return false;
  }
  return true;
}

/// A sequential view of a specification's text units.
///
/// The grammar only needs two units of lookahead to distinguish `fill +
/// align`. Materializing every unit before reading a numeric option turned a
/// five-million-zero width into about 29 MiB of transient references, and a
/// malformed option could exhaust memory before reaching its controlled
/// [InvalidSpecifierException]. The cursor retains only its bounded lookahead
/// and discards each consumed unit.
final class _FormatSpecCursor {
  final String? _asciiSource;
  late final Iterator<String> _nonAsciiUnits;
  late final List<String> _lookahead;
  var _asciiIndex = 0;

  factory _FormatSpecCursor(String source, TextUnit textUnit) {
    if (_hasSimpleAsciiUnits(source)) {
      return _FormatSpecCursor._ascii(source);
    }
    final units = switch (textUnit) {
      TextUnit.unicodeScalars => source.runes.map(String.fromCharCode).iterator,
      TextUnit.graphemeClusters => source.characters.iterator,
    };
    return _FormatSpecCursor._nonAscii(units);
  }

  _FormatSpecCursor._ascii(this._asciiSource);

  _FormatSpecCursor._nonAscii(this._nonAsciiUnits)
    : _asciiSource = null,
      _lookahead = [];

  String? peek([int offset = 0]) {
    assert(offset <= 1);
    final source = _asciiSource;
    if (source != null) {
      final index = _asciiIndex + offset;
      return index < source.length ? source[index] : null;
    }
    while (_lookahead.length <= offset) {
      final next = _next();
      if (next == null) break;
      _lookahead.add(next);
    }
    return offset < _lookahead.length ? _lookahead[offset] : null;
  }

  bool get isDone => peek() == null;

  String take() {
    final source = _asciiSource;
    if (source != null) {
      if (_asciiIndex == source.length) {
        throw StateError('The format specifier is exhausted.');
      }
      return source[_asciiIndex++];
    }
    if (peek() == null) throw StateError('The format specifier is exhausted.');
    return _lookahead.removeAt(0);
  }

  String takeRest() {
    final source = _asciiSource;
    if (source != null) {
      final output = source.substring(_asciiIndex);
      _asciiIndex = source.length;
      return output;
    }
    final output = StringBuffer();
    while (!isDone) {
      output.write(take());
    }
    return output.toString();
  }

  String? _next() {
    final units = _nonAsciiUnits;
    return units.moveNext() ? units.current : null;
  }
}

_FormatSpec _parseFormatSpecStreaming(
  String source,
  TextUnit textUnit,
  FormatExceptionContext context,
) {
  final cursor = _FormatSpecCursor(source, textUnit);
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

  bool at(String value) => cursor.peek() == value;
  String take() => cursor.take();

  final second = cursor.peek(1);
  if (second != null && _isAlign(second)) {
    fill = take();
    align = take();
  } else if (cursor.peek() case final unit? when _isAlign(unit)) {
    align = take();
  }

  if (cursor.peek() case final unit? when _isSign(unit)) sign = take();
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
  if (cursor.peek() case final unit? when _isAsciiDigit(unit)) {
    width = _readDecimalFromCursor(cursor);
    if (width > _maximumSafeFormatOption) {
      throw _invalidSpecifier(
        context,
        'The width is too large to format safely.',
      );
    }
    // The width counts text units, and that bounds the result only while a
    // unit is bounded. Under [TextUnit.graphemeClusters] a fill unit is a whole
    // cluster of any length, so `fill * padding` writes `fill.length * width`
    // code units however small the width reads — a seven-character template
    // with the fill arriving in a value reached 500 095 000 characters, and one
    // cluster larger threw OutOfMemoryError, which is not a FormattingException
    // and takes the isolate with it.
    if (fill != null && width * fill.length > _maximumSafePaddingUnits) {
      throw _invalidSpecifier(
        context,
        'The width is too large to format safely with this fill.',
      );
    }
  }
  if (cursor.peek() case final unit? when _isGrouping(unit)) grouping = take();
  if (at('.')) {
    take();
    // `.` may introduce a precision, a fraction separator, or a precision and
    // then a separator — CPython's grammar is
    // `["." (precision [grouping] | grouping)]`, and the separator-only form
    // was the one branch missing here. It asks for a grouped fraction at the
    // presentation's own default precision, so `'{:.,f}'` of 1234.5678 is
    // `1234.567,800`, exactly as CPython writes it.
    if (cursor.peek() case final unit? when _isGrouping(unit)) {
      fractionalGrouping = take();
    } else {
      final unit = cursor.peek();
      if (unit == null || !_isAsciiDigit(unit)) {
        throw _invalidSpecifier(
          context,
          'Precision must contain decimal digits.',
        );
      }
      precision = _readDecimalFromCursor(cursor);
      if (precision > _maximumSafeFormatOption) {
        throw _invalidSpecifier(
          context,
          'The precision is too large to format safely.',
        );
      }
      if (cursor.peek() case final unit? when _isGrouping(unit)) {
        fractionalGrouping = take();
      }
    }
  }

  if (!cursor.isDone) {
    if (at('%')) {
      type = take();
      if (!cursor.isDone) {
        throw _invalidSpecifier(
          context,
          'A built-in type must terminate the format specification.',
        );
      }
    } else if (_isCustomNameStart(cursor.peek()!)) {
      final name = StringBuffer();
      do {
        name.write(take());
      } while (!cursor.isDone && _isCustomNameContinue(cursor.peek()!));

      final parsedName = name.toString();
      if (_builtInTypes.contains(parsedName)) {
        type = parsedName;
        if (!cursor.isDone) {
          throw _invalidSpecifier(
            context,
            'A built-in type must terminate the format specification.',
          );
        }
      } else {
        customName = parsedName;
        if (!cursor.isDone) {
          if (!at(':')) {
            throw _invalidSpecifier(context, 'Invalid custom format name.');
          }
          take();
          payload = cursor.takeRest();
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

/// Test seam, deliberately not exported by `format.dart`.
Set<String> debugBraceBuiltInTypes() => _builtInTypes;

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

/// Test seam for the bounded materialized parser and its streaming twin.
///
/// Production chooses between them by source length; the seam forces both on
/// the same short corpus so grammar changes cannot drift between the paths.
bool debugFormatSpecParsersAgree(String source) {
  for (final textUnit in TextUnit.values) {
    final context = FormatExceptionContext(specifier: source);
    (_FormatSpec?, Object?) parse(bool streaming) {
      try {
        return (
          streaming
              ? _parseFormatSpecStreaming(source, textUnit, context)
              : _parseFormatSpecMaterialized(source, textUnit, context),
          null,
        );
      } on Object catch (error) {
        return (null, error);
      }
    }

    final materialized = parse(false);
    final streaming = parse(true);
    final materializedSpec = materialized.$1;
    final streamingSpec = streaming.$1;
    if (materializedSpec != null && streamingSpec != null) {
      if (!_debugFormatSpecEquals(materializedSpec, streamingSpec)) {
        return false;
      }
      continue;
    }
    final materializedError = materialized.$2;
    final streamingError = streaming.$2;
    if (materializedError.runtimeType != streamingError.runtimeType ||
        materializedError.toString() != streamingError.toString()) {
      return false;
    }
  }
  return true;
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
    // No ASCII guard before the lookup: every built-in type is a
    // single-character ASCII string, so membership already implies it.
    return _builtInTypes.contains(source) ? _FormatSpec(type: source) : null;
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

/// Parses `fill? align? sign? z? #? 0? width? type?` specifications made of
/// ASCII code units only. A fill is recognized exactly like in the general
/// parser: only when the next unit is an align. Grouping, precision, custom
/// formats and anything non-ASCII stay on the general parser.
_FormatSpec? _simpleAsciiFlagWidthSpec(String source, int length) {
  var index = 0;
  String? fill;
  String? align;
  if (_isAsciiAlignCodeUnit(source.codeUnitAt(1))) {
    if (source.codeUnitAt(0) > 0x7f) return null;
    fill = source[0];
    align = source[1];
    index = 2;
  } else if (_isAsciiAlignCodeUnit(source.codeUnitAt(0))) {
    align = source[0];
    index = 1;
  }
  String? sign;
  if (index < length) {
    sign = switch (source.codeUnitAt(index)) {
      0x2b => '+',
      0x2d => '-',
      0x20 => ' ',
      _ => null,
    };
    if (sign != null) index++;
  }
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
  if (digits > 0) {
    // Widths above the safety ceiling fall back to the general parser,
    // which reports them with the full context.
    if (value > _maximumSafeFormatOption) return null;
    width = value;
  }
  String? type;
  if (index < length) {
    if (index != length - 1) return null;
    type = _builtInTypeFromCodeUnit(source.codeUnitAt(index));
    if (type == null) return null;
  }
  return _FormatSpec(
    fill: fill,
    align: align,
    sign: sign,
    normalizeNegativeZero: normalizeNegativeZero,
    alternate: alternate,
    zero: zero,
    width: width,
    type: type,
  );
}

bool _isAsciiAlignCodeUnit(int codeUnit) =>
    codeUnit == 0x3c ||
    codeUnit == 0x3e ||
    codeUnit == 0x3d ||
    codeUnit == 0x5e;

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

/// A decimal run, or a marker one past [_maximumSafeFormatOption] when the
/// digits spell something larger.
///
/// Accumulated rather than collected and parsed. The old shape built a
/// `StringBuffer`, wrote every digit into it, took its string and handed that
/// to `int.tryParse` — four allocations to read the `8` of `{:>8,d}`, on a
/// path that runs once per field of every template parsed. It also made the
/// cost of *rejecting* a width scale with the digits it was spelled with,
/// which is the property H3 removed from field indexes for the same reason:
/// a template is untrusted input.
///
/// Accumulation stops as soon as the value passes the ceiling, so nothing can
/// overflow — the largest value reachable is ten times the ceiling plus nine —
/// while the loop still walks the rest of the run, because the caller's
/// position has to end up past it either way.
///
/// A run too long to be an int is not a different failure from one merely
/// past the ceiling, and on the web the two cannot even be told apart: an int
/// is a double there. Both come back as the same marker, and the caller
/// reports it against its own option, so a template rejected on the server is
/// rejected in the browser too.
int _readDecimal(List<String> units, int start, void Function() advance) {
  var value = 0;
  var index = start;
  while (index < units.length && _isAsciiDigit(units[index])) {
    if (value <= _maximumSafeFormatOption) {
      value = value * 10 + (units[index].codeUnitAt(0) - 0x30);
    }
    advance();
    index++;
  }

  return value > _maximumSafeFormatOption
      ? _maximumSafeFormatOption + 1
      : value;
}

int _readDecimalFromCursor(_FormatSpecCursor cursor) {
  var value = 0;
  while (true) {
    final unit = cursor.peek();
    if (unit == null || !_isAsciiDigit(unit)) break;
    if (value <= _maximumSafeFormatOption) {
      value = value * 10 + (unit.codeUnitAt(0) - 0x30);
    }
    cursor.take();
  }

  return value > _maximumSafeFormatOption
      ? _maximumSafeFormatOption + 1
      : value;
}

InvalidSpecifierException _invalidSpecifier(
  FormatExceptionContext context,
  String reason,
) => InvalidSpecifierException(context, reason);
