part of 'engine.dart';

/// True when running on the web, where int is a JS double.
const bool _isWebInt = identical(1, 1.0);

/// Stands in for the literal representation the running platform ignores.
final Uint16List _noUnits = Uint16List(0);

/// True when |value| exceeds the largest integer magnitude a JS double can
/// represent exactly (2^53 - 1). Runs in negative space so `minInt` (which
/// has no positive counterpart) never overflows, and uses only comparison,
/// which stays exact at this magnitude even on dart2js.
bool _exceedsWebSafeInt(int value) {
  final negative = value <= 0 ? value : -value;
  return negative < -9007199254740991;
}

sealed class _BraceOp {
  const _BraceOp();

  void write(CharSink sink, _BraceProcessor frame);

  String describe();
}

final class _BraceProgram {
  final List<_BraceOp> ops;

  /// What the sink should preallocate, which is not the same as how long the
  /// output will be: a program that writes one string accumulates nothing and
  /// asks for nothing, however long that string is. See [_BraceSoleLiteralOp].
  final int estimatedCapacity;

  const _BraceProgram(this.ops, this.estimatedCapacity);
}

final class _BraceLiteralOp extends _BraceOp {
  // Both representations are prepared once, and each platform reads only its
  // own: the VM copies prepared units as a block, while a web target wants
  // the string it will concatenate. The unused one costs a field, never a
  // conversion, because the branch below folds at compile time.
  final String text;
  final Uint16List units;

  _BraceLiteralOp(this.text)
    : units = _isWeb ? _noUnits : Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    if (_isWeb) {
      sink.writeString(text);
    } else {
      sink.writeCodeUnits(units);
    }
  }

  @override
  String describe() => 'literal';
}

/// The literal of a template that has no fields, written by reference.
///
/// [CharSink.writeString] on an empty sink keeps the string instead of copying
/// it in, and `toString` hands that same string back, so the only op of a
/// program needs no prepared units at all: preparing them would buy two copies
/// of the whole template per call, and two retained bytes per character in the
/// template cache, to replace a write that costs nothing. Its program asks for
/// no buffer either, for the same reason.
///
/// Every other program keeps [_BraceLiteralOp], where the units do pay: once a
/// second write forces the held string into the buffer, copying it from a
/// `codeUnits` view runs 1.85 times the cost of copying prepared units, at
/// every length measured from 16 to 100 000.
final class _BraceSoleLiteralOp extends _BraceOp {
  final String text;

  const _BraceSoleLiteralOp(this.text);

  @override
  void write(CharSink sink, _BraceProcessor frame) => sink.writeString(text);

  @override
  String describe() => 'literal:sole';
}

final class _BraceFallbackOp extends _BraceOp {
  final _FieldNode field;
  final int automaticBase;

  const _BraceFallbackOp(this.field, this.automaticBase);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final resolver = frame.resolver.._automaticIndex = automaticBase;
    final value = resolver.resolveField(field);
    sink.writeString(frame._formatField(resolver, field, value));
  }

  @override
  String describe() => 'fallback';
}

final class _BraceDynamicValueOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;

  const _BraceDynamicValueOp(this.field, this.argumentIndex, this.argumentName);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    if (value is String) {
      sink.writeString(value);
      return;
    }
    if (value is int && _isIntegerValue(value)) {
      if (value.isNegative) sink.writeCharCode(0x2d);
      if (_isWebInt && _exceedsWebSafeInt(value)) {
        // On the web, int is a JS double, so the digit-by-digit `~/ 10`
        // extraction below is inexact above 2^53-1. _formatIntMagnitude
        // materializes exact digits through BigInt there, mirroring the
        // legacy _formatBraceInteger path for '{}' on an int.
        sink.writeString(_formatIntMagnitude(value, 10));
      } else {
        sink.writeMagnitude(value, 10);
      }
      return;
    }
    if (value is bool || value == null) {
      sink.writeString(value.toString());
      return;
    }
    if (value is double) {
      // Transliteration of _formatBraceDouble under an empty specification:
      // no presentation type, no precision, no width, no grouping, so the
      // body needs neither _displayFloatBody nor _applyNumericWidth. On the
      // web a whole double is an int, so the integer branch above already
      // claimed it; what reaches this point there is what _isIntegerValue
      // rejects — fractional values, negative zero, nan and the infinities —
      // which is exactly how legacy routes them too.
      final engine = frame.engine;
      final _AsciiFloat formatted;
      if (!value.isFinite) {
        formatted = _formatSpecialDouble(value, false, engine);
      } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
        formatted = _formatDartDouble(value, null, null, false);
      } else {
        formatted = _formatShortest(value, false);
      }
      if (!value.isNaN && value.isNegative) sink.writeCharCode(0x2d);
      sink.writeString(formatted.body);
      return;
    }
    // BigInt, custom formatters, unsupported values: the generic dispatch
    // reproduces today's behavior and errors exactly.
    sink.writeString(
      _formatParsedValue(
        value,
        const _FormatSpec(),
        frame.engine,
        _context(frame),
      ),
    );
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: '',
      );

  @override
  String describe() => 'dynamic';
}

final class _BraceIntOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final int radix;
  final bool uppercase;
  final String prefix; // '', '0b', '0o', '0x', '0X'
  final int requestedSign; // 0x2b '+', 0x20 ' ', 0 none
  final int width; // -1 none
  final int fillChar;
  final int align; // code unit of '<' '>' '^' '='
  final String type;
  final int groupSeparator; // 0 none, else ',' or '_'
  final int groupSize; // 3 for decimal, 4 for the power-of-two radixes

  /// Whether zero padding is grouped with the digits instead of filled
  /// around them — `{:010,d}`, where the separators land as if the number
  /// had that many digits.
  final bool zeroPaddingGrouped;

  /// Non-null for `n` only, whose result depends on the engine's locale.
  ///
  /// A compiled program is shared by every engine that formats the template,
  /// so the locale cannot be decided at compile time. Under the C locale `n`
  /// is `d` — grouping off, ASCII symbols, digits unchanged — and anything
  /// else, including a value this op does not write, goes to the legacy path
  /// with this specification.
  final _FormatSpec? localeSpec;

  const _BraceIntOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.radix,
    required this.uppercase,
    required this.prefix,
    required this.requestedSign,
    required this.width,
    required this.fillChar,
    required this.align,
    required this.type,
    this.groupSeparator = 0,
    this.groupSize = 3,
    this.zeroPaddingGrouped = false,
    this.localeSpec,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    final spec = localeSpec;
    if (spec != null &&
        (!identical(frame.engine.numberLocale, const CNumberLocale()) ||
            !((value is int && _isIntegerValue(value)) || value is BigInt))) {
      // `n` under any other locale localizes symbols and may group, and `n`
      // is a floating presentation too: both belong to the legacy path.
      sink.writeString(
        _formatParsedValue(value, spec, frame.engine, _context(frame)),
      );
      return;
    }
    if (value is int && _isIntegerValue(value)) {
      final signChar = value.isNegative ? 0x2d : requestedSign;
      if (_isWebInt && _exceedsWebSafeInt(value)) {
        // Same reasoning as _BraceDynamicValueOp: digit-by-digit extraction
        // is inexact above 2^53-1 on the web, so mirror the BigInt branch
        // below and write pre-materialized, exact digits instead.
        final digitsText = _formatIntMagnitude(
          value,
          radix,
          uppercase: uppercase,
        );
        _writeDigitsText(sink, digitsText, signChar);
        return;
      }
      final digits = CharSink.digitCount(value, radix);
      if (groupSeparator != 0) {
        if (zeroPaddingGrouped) {
          _writeLeading(sink, 0, signChar);
          sink.writeGroupedMagnitude(
            value,
            radix,
            groupSeparator,
            groupSize,
            leadingZeros: _groupedDigitCount(digits, signChar) - digits,
            uppercase: uppercase,
          );
          return;
        }
        final padding = _padding(
          CharSink.groupedLength(digits, groupSize),
          signChar,
        );
        _writeLeading(sink, padding, signChar);
        sink.writeGroupedMagnitude(
          value,
          radix,
          groupSeparator,
          groupSize,
          uppercase: uppercase,
        );
        _writeTrailing(sink, padding);
        return;
      }
      // Written out rather than delegated: this is the hottest arithmetic
      // in the op, and a call here measured 15% on `{:d}` under dart2js.
      final padding =
          width < 0
              ? 0
              : width - digits - prefix.length - (signChar == 0 ? 0 : 1);
      _writeLeading(sink, padding, signChar);
      sink.writeMagnitude(value, radix, uppercase: uppercase);
      _writeTrailing(sink, padding);
      return;
    }
    if (value is BigInt) {
      _writeDigitsText(
        sink,
        formatMagnitude(
          value.isNegative ? -value : value,
          radix,
          uppercase: uppercase,
        ),
        value.isNegative ? 0x2d : requestedSign,
      );
      return;
    }
    // Mirrors _formatParsedValue's dispatch order for the value types it
    // routes elsewhere before falling back to UnsupportedFormatValueException:
    // strings always go through _formatText, which rejects any non-'s' type;
    // doubles always go through _formatBraceDouble, whose _validateDoubleSpec
    // rejects every integer presentation type. Both raise
    // InvalidSpecifierException rather than UnsupportedFormatValueException.
    if (value is String) {
      throw InvalidSpecifierException(
        _context(frame),
        'This specification is not valid for text.',
      );
    }
    if (value is double) {
      throw InvalidSpecifierException(
        _context(frame),
        'Double values accept the presentation types e, E, f, F, g, G, n, '
        'and %, or none at all.',
      );
    }
    throw UnsupportedFormatValueException(_context(frame), value);
  }

  int _padding(int visibleDigits, int signChar) =>
      width < 0
          ? 0
          : width - visibleDigits - prefix.length - (signChar == 0 ? 0 : 1);

  int _groupedDigitCount(int digits, int signChar) =>
      width < 0
          ? digits
          : _fittedGroupedDigitCount(
            digits,
            groupSize,
            width - prefix.length - (signChar == 0 ? 0 : 1),
          );

  /// The layout for digits that arrived as a string: the magnitude of a
  /// `BigInt`, or of an int too large for exact digit extraction on the web.
  void _writeDigitsText(CharSink sink, String digitsText, int signChar) {
    if (groupSeparator == 0) {
      final padding = _padding(digitsText.length, signChar);
      _writeLeading(sink, padding, signChar);
      sink.writeString(digitsText);
      _writeTrailing(sink, padding);
      return;
    }
    if (zeroPaddingGrouped) {
      _writeLeading(sink, 0, signChar);
      sink.writeString(
        _groupDigitsText(
          digitsText,
          _groupedDigitCount(digitsText.length, signChar) - digitsText.length,
        ),
      );
      return;
    }
    final grouped = _groupDigitsText(digitsText, 0);
    final padding = _padding(grouped.length, signChar);
    _writeLeading(sink, padding, signChar);
    sink.writeString(grouped);
    _writeTrailing(sink, padding);
  }

  String _groupDigitsText(String digitsText, int leadingZeros) => groupDigits(
    leadingZeros == 0 ? digitsText : '${'0' * leadingZeros}$digitsText',
    separator: String.fromCharCode(groupSeparator),
    grouping: groupSize == 3 ? const [3] : const [4],
  );

  void _writeLeading(CharSink sink, int padding, int signChar) {
    if (align == 0x3e) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding ~/ 2);
    }
    if (signChar != 0) sink.writeCharCode(signChar);
    if (prefix.isNotEmpty) sink.writeString(prefix);
    if (align == 0x3d) sink.fill(fillChar, padding);
  }

  void _writeTrailing(CharSink sink, int padding) {
    if (align == 0x3c) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding - padding ~/ 2);
    }
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
      );

  @override
  String describe() {
    final buffer = StringBuffer('int:$type');
    if (width >= 0) buffer.write(':w$width');
    if (groupSeparator != 0) {
      buffer.write(':g${String.fromCharCode(groupSeparator)}$groupSize');
      if (zeroPaddingGrouped) buffer.write('z');
    }

    return buffer.toString();
  }
}

final class _BraceTextOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final _FormatSpec spec; // for the slow non-String branch
  final int width; // -1 none
  final int fillChar;
  final int align; // '<' '>' '^'
  final int precision; // -1 none
  final TextUnit textUnit;

  const _BraceTextOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.spec,
    required this.width,
    required this.fillChar,
    required this.align,
    required this.precision,
    required this.textUnit,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    if (value is! String) {
      // The generic path throws exactly today's errors for non-strings.
      sink.writeString(
        _formatParsedValue(value, spec, frame.engine, _context(frame)),
      );
      return;
    }
    final text = precision < 0 ? value : textUnit.take(value, precision);
    if (width < 0) {
      sink.writeString(text);
      return;
    }
    final padding = width - textUnit.length(text);
    if (align == 0x3e) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding ~/ 2);
    }
    sink.writeString(text);
    if (align == 0x3c) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding - padding ~/ 2);
    }
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
      );

  @override
  String describe() {
    final buffer = StringBuffer('text:s');
    if (width >= 0) buffer.write(':w$width');
    if (precision >= 0) buffer.write(':p$precision');
    return buffer.toString();
  }
}

/// How many digits grouped zero padding ends up with: the smallest count
/// whose grouped length still reaches [target].
///
/// Grouping makes that length jump by a separator at a time, so subtracting
/// one width from the other overshoots — `{:08,d}` of 12 is `0,000,012`,
/// nine characters wide, not ten. The legacy path finds the count by
/// bisection; the same count follows from the group size directly, since
/// grouped length grows by `groupSize + 1` per whole group.
int _fittedGroupedDigitCount(int digits, int groupSize, int target) {
  if (target <= 0) return digits;
  var count = (target * groupSize) ~/ (groupSize + 1);
  if (count < digits) count = digits;
  while (CharSink.groupedLength(count, groupSize) < target) {
    count++;
  }
  while (count > digits &&
      CharSink.groupedLength(count - 1, groupSize) >= target) {
    count--;
  }

  return count;
}

/// Where the integer digits of an ASCII float body end: at the point, at the
/// exponent, or at the end of the body.
int _asciiIntegerEnd(String body) {
  for (var index = 0; index < body.length; index++) {
    final unit = body.codeUnitAt(index);
    if (unit == 0x2e || unit == 0x65 || unit == 0x45) return index;
  }

  return body.length;
}

/// Writes a formatted ASCII float — optional sign, [body], optional `%` —
/// into [sink] with the padding described by [width] (-1 for none),
/// [fillChar] and [align].
///
/// The body produced by the double generators is always ASCII, so
/// `body.length` is at once its code-unit count, its scalar count and its
/// grapheme count: the padding arithmetic below needs no TextUnit. The write
/// order per alignment mirrors `_applyNumericWidth`: `>` fill-sign-body-'%',
/// `=` sign-fill-body-'%', `<` sign-body-'%'-fill, `^` splits the fill
/// around sign-body-'%'. Shared by the brace and printf double ops.
void _writeAsciiFloatDirect(
  CharSink sink,
  String body,
  int signChar,
  bool percentSuffix,
  int width,
  int fillChar,
  int align, {
  int groupSeparator = 0,
  bool zeroPaddingGrouped = false,
}) {
  final signWidth = signChar == 0 ? 0 : 1;
  final suffixWidth = percentSuffix ? 1 : 0;
  final integerEnd = groupSeparator == 0 ? 0 : _asciiIntegerEnd(body);
  // Zero padding is grouped along with the digits, so it is not padding at
  // all here: the digit count grows until the grouped body reaches the
  // width, and nothing is filled around it.
  if (groupSeparator != 0 && zeroPaddingGrouped) {
    final target =
        (width < 0 ? 0 : width) -
        signWidth -
        suffixWidth -
        (body.length - integerEnd);
    final digits = _fittedGroupedDigitCount(integerEnd, 3, target);
    if (signChar != 0) sink.writeCharCode(signChar);
    sink.writeGroupedBody(
      body,
      integerEnd,
      groupSeparator,
      3,
      leadingZeros: digits - integerEnd,
    );
    if (percentSuffix) sink.writeCharCode(0x25);
    return;
  }

  final grouped =
      groupSeparator == 0 ? body.length : body.length + (integerEnd - 1) ~/ 3;
  final content = grouped + signWidth + suffixWidth;
  final padding = width < 0 ? 0 : width - content;
  if (align == 0x3e) {
    sink.fill(fillChar, padding);
  } else if (align == 0x5e) {
    sink.fill(fillChar, padding ~/ 2);
  }
  if (signChar != 0) sink.writeCharCode(signChar);
  if (align == 0x3d) sink.fill(fillChar, padding);
  if (groupSeparator == 0) {
    sink.writeString(body);
  } else {
    sink.writeGroupedBody(body, integerEnd, groupSeparator, 3);
  }
  if (percentSuffix) sink.writeCharCode(0x25);
  if (align == 0x3c) {
    sink.fill(fillChar, padding);
  } else if (align == 0x5e) {
    sink.fill(fillChar, padding - padding ~/ 2);
  }
}

/// Hot op for the floating presentations (`f F e E g G %`) and for typeless
/// specifications such as `{:10}` or `{:.3}`. The branch order in [write]
/// is a transliteration of `_formatBraceDouble`: it is the parity contract.
final class _BraceDoubleOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final _FormatSpec spec; // delegate branch + generator params
  final String? type; // null = default presentation
  final int? precision;
  final bool alternate;
  final int requestedSign; // 0x2b '+', 0x20 ' ', 0 none
  final bool normalizeNegativeZero;
  final bool percent;
  final int width; // -1 none
  final int fillChar;
  final int align;
  final bool uppercase; // 'E' 'F' 'G' spell their bodies in upper case
  final bool dartPrecisionRejected; // see _rejectsDartDoublePrecision
  final int groupSeparator; // 0 none, else ',' or '_'

  /// Whether zero padding is grouped with the integer digits rather than
  /// filled between the sign and them — `{:012,.2f}`.
  final bool zeroPaddingGrouped;

  const _BraceDoubleOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.spec,
    required this.type,
    required this.precision,
    required this.alternate,
    required this.requestedSign,
    required this.normalizeNegativeZero,
    required this.percent,
    required this.width,
    required this.fillChar,
    required this.align,
    required this.uppercase,
    required this.dartPrecisionRejected,
    this.groupSeparator = 0,
    this.zeroPaddingGrouped = false,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    final double converted;
    if (value is double && !(type == null && _isIntegerValue(value))) {
      converted = value;
    } else if (type != null &&
        ((value is int && _isIntegerValue(value)) || value is BigInt)) {
      // Only an explicit floating type converts integers here:
      // `_isFloatingFormatType(null)` is false, so under a typeless
      // specification legacy sends int/BigInt to _formatBraceInteger. The
      // `_isIntegerValue` guard above keeps the same split on the web,
      // where a whole double is an int and must take integer semantics.
      converted = switch (value) {
        final int number => number.toDouble(),
        final BigInt number => number.toDouble(),
        // Unreachable: the branch above admits int and BigInt only.
        _ => throw StateError('Unsupported floating value: $value'),
      };
      if (!converted.isFinite) {
        throw UnsupportedFormatValueException(_context(frame), value);
      }
    } else {
      // The generic path reproduces legacy exactly: text output for
      // strings under a null type, integer semantics for integers, and
      // today's errors for everything else.
      sink.writeString(
        _formatParsedValue(value, spec, frame.engine, _context(frame)),
      );
      return;
    }

    final engine = frame.engine;
    final formattingValue = percent ? converted * 100 : converted;
    if (engine.doubleFormatMode == DoubleFormatMode.dartSdk &&
        dartPrecisionRejected) {
      // Legacy validates before the finiteness check: bad precision on
      // nan must still throw. The verdict is static (see
      // _rejectsDartDoublePrecision), so only the throwing call pays for a
      // context; the throw itself stays inside the shared validator.
      _validateDartDoublePrecision(type, precision, _context(frame));
    }

    final _AsciiFloat formatted;
    if (!formattingValue.isFinite) {
      formatted = _formatSpecialDouble(formattingValue, uppercase, engine);
    } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      formatted = _formatDartDouble(
        formattingValue,
        type,
        precision,
        alternate,
      );
    } else if (type == null && precision == null) {
      formatted = _formatShortest(converted, alternate);
    } else {
      final effective = precision ?? 6;
      formatted = switch (type) {
        'f' || 'F' => _formatFixed(converted, effective, alternate),
        'e' || 'E' => _formatScientific(
          Binary64.fromDouble(converted),
          effective,
          alternate,
          type!,
        ),
        'g' || 'G' => _formatGeneral(
          Binary64.fromDouble(converted),
          effective == 0 ? 1 : effective,
          alternate,
          type == 'G' ? 'E' : 'e',
        ),
        '%' => _formatFixed(formattingValue, effective, alternate),
        null => _formatGeneral(
          Binary64.fromDouble(converted),
          effective == 0 ? 1 : effective,
          alternate,
          'e',
          emptyType: true,
        ),
        _ => throw StateError('Unsupported floating presentation: $type'),
      };
    }

    var negative = !formattingValue.isNaN && formattingValue.isNegative;
    if (normalizeNegativeZero && formatted.roundedZero) negative = false;
    final signChar = negative ? 0x2d : requestedSign;
    _writeAsciiFloatDirect(
      sink,
      formatted.body,
      signChar,
      percent,
      width,
      fillChar,
      align,
      // `nan` and `inf` have no digits to group, and the legacy display
      // returns such a body untouched.
      groupSeparator: formatted.special ? 0 : groupSeparator,
      zeroPaddingGrouped: zeroPaddingGrouped,
    );
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
      );

  @override
  String describe() {
    final buffer = StringBuffer('double:${type ?? '-'}');
    if (width >= 0) buffer.write(':w$width');
    if (precision != null) buffer.write(':p$precision');
    if (groupSeparator != 0) {
      buffer.write(':g${String.fromCharCode(groupSeparator)}');
      if (zeroPaddingGrouped) buffer.write('z');
    }

    return buffer.toString();
  }
}

int _automaticFieldCount(_FieldNode field) {
  var count = field.root is _AutomaticRoot ? 1 : 0;
  for (final node in field.specification) {
    if (node is _FieldNode) count += _automaticFieldCount(node);
  }
  return count;
}

String? _staticBraceSpecification(_FieldNode field) {
  final specification = field.specification;
  if (specification.isEmpty) return '';
  if (specification case [_LiteralNode(:final text)]) return text;
  return null;
}

_BraceDoubleOp _buildBraceDoubleOp(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  String specText,
  _FormatSpec spec,
) => _BraceDoubleOp(
  field: field,
  argumentIndex: argumentIndex,
  argumentName: argumentName,
  specifierText: specText,
  spec: spec,
  type: spec.type,
  precision: spec.precision,
  alternate: spec.alternate,
  requestedSign: switch (spec.sign) {
    '+' => 0x2b,
    ' ' => 0x20,
    _ => 0,
  },
  normalizeNegativeZero: spec.normalizeNegativeZero,
  percent: spec.type == '%',
  width: spec.width ?? -1,
  fillChar: (spec.fill ?? (spec.zero ? '0' : ' ')).codeUnitAt(0),
  align: (spec.align ?? (spec.zero ? '=' : '>')).codeUnitAt(0),
  uppercase: spec.type == 'E' || spec.type == 'F' || spec.type == 'G',
  dartPrecisionRejected: _rejectsDartDoublePrecision(spec.type, spec.precision),
  groupSeparator: spec.grouping == null ? 0 : spec.grouping!.codeUnitAt(0),
  zeroPaddingGrouped:
      spec.grouping != null &&
      (spec.align ?? (spec.zero ? '=' : '>')) == '=' &&
      (spec.fill ?? (spec.zero ? '0' : ' ')) == '0',
);

/// Probes `_validateDartDoublePrecision` once, at compile time: its verdict
/// depends only on the static type/precision pair, so the write path can
/// skip both the call and the exception context it would need when the pair
/// is valid. The probe calls the validator itself, so the rule stays in one
/// place.
bool _rejectsDartDoublePrecision(String? type, int? precision) {
  try {
    _validateDartDoublePrecision(
      type,
      precision,
      const FormatExceptionContext(),
    );
    return false;
  } on FormattingException {
    return true;
  }
}

/// True for specifications the double op cannot write directly: grouping
/// needs `_displayFloatBody`, and anything `_validateDoubleSpec` rejects
/// must keep its legacy per-call error, which the op never raises. The
/// validator is probed instead of copied so its rules cannot drift away
/// from the classifier (same pattern as _rejectsDartDoublePrecision).
/// True for integer specifications the int op cannot write directly. Only
/// the validator's own verdict, probed once at compile time: every rejection
/// it raises is a per-call error the op does not reproduce.
bool _rejectsHotInteger(_FormatSpec spec, String type) {
  try {
    _validateIntegerSpec(spec, type, const FormatExceptionContext());
    return false;
  } on FormattingException {
    return true;
  }
}

bool _rejectsHotDouble(_FormatSpec spec) {
  // Grouping inside the fraction regroups a part the op writes through.
  if (spec.fractionalGrouping != null) return true;
  try {
    _validateDoubleSpec(spec, spec.type, const FormatExceptionContext());
    return false;
  } on FormattingException {
    return true;
  }
}

_BraceOp? _classifyBraceField(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  TextUnit textUnit,
) {
  final specText = _staticBraceSpecification(field);
  if (specText == null) return null;
  if (specText.isEmpty) {
    return _BraceDynamicValueOp(field, argumentIndex, argumentName);
  }
  var spec = field.memoizedSpec(textUnit);
  if (spec == null) {
    try {
      spec = _parseFormatSpec(
        specText,
        textUnit,
        const FormatExceptionContext(),
      );
    } on FormattingException {
      return null; // Invalid static specs keep today's per-call errors.
    }
    field.memoizeSpec(textUnit, spec);
  }
  if (spec.customName != null || spec.payload != null) return null;
  final fill = spec.fill;
  if (fill != null && fill.length != 1) return null; // multi-unit fill
  if (spec.type == null) {
    // A non-empty specification without a type; empty ones already left
    // through _BraceDynamicValueOp. Doubles format here, every other value
    // type keeps its legacy dispatch through the op's delegate branch.
    if (_rejectsHotDouble(spec)) return null;
    return _buildBraceDoubleOp(
      field,
      argumentIndex,
      argumentName,
      specText,
      spec,
    );
  }
  switch (spec.type) {
    case 'd' || 'b' || 'o' || 'x' || 'X' || 'n':
      final type = spec.type!;
      // Anything the validator rejects keeps its legacy per-call error,
      // which the op never raises. Probed rather than copied, so the rules
      // stay in one place (same pattern as _rejectsHotDouble).
      if (_rejectsHotInteger(spec, type)) return null;
      final grouping = spec.grouping;
      return _BraceIntOp(
        field: field,
        argumentIndex: argumentIndex,
        argumentName: argumentName,
        specifierText: specText,
        radix: switch (type) {
          'b' => 2,
          'o' => 8,
          'd' || 'n' => 10,
          _ => 16,
        },
        uppercase: type == 'X',
        prefix: _integerPrefix(type, spec.alternate),
        requestedSign: switch (spec.sign) {
          '+' => 0x2b,
          ' ' => 0x20,
          _ => 0,
        },
        width: spec.width ?? -1,
        fillChar: (spec.fill ?? (spec.zero ? '0' : ' ')).codeUnitAt(0),
        align: (spec.align ?? (spec.zero ? '=' : '>')).codeUnitAt(0),
        type: type,
        groupSeparator: grouping == null ? 0 : grouping.codeUnitAt(0),
        groupSize: type == 'd' ? 3 : 4,
        localeSpec: type == 'n' ? spec : null,
        zeroPaddingGrouped:
            grouping != null &&
            (spec.align ?? (spec.zero ? '=' : '>')) == '=' &&
            (spec.fill ?? (spec.zero ? '0' : ' ')) == '0',
      );
    // 'n' is deliberately absent: locale-aware doubles stay on fallback.
    case 'f' || 'F' || 'e' || 'E' || 'g' || 'G' || '%':
      if (_rejectsHotDouble(spec)) return null;
      return _buildBraceDoubleOp(
        field,
        argumentIndex,
        argumentName,
        specText,
        spec,
      );
    case 's':
      if (spec.sign != null ||
          spec.normalizeNegativeZero ||
          spec.alternate ||
          spec.zero ||
          spec.grouping != null ||
          spec.fractionalGrouping != null ||
          spec.align == '=') {
        return null; // Invalid-for-text specs keep today's errors.
      }
      return _BraceTextOp(
        field: field,
        argumentIndex: argumentIndex,
        argumentName: argumentName,
        specifierText: specText,
        spec: spec,
        width: spec.width ?? -1,
        fillChar: (spec.fill ?? ' ').codeUnitAt(0),
        align: (spec.align ?? '<').codeUnitAt(0),
        precision: spec.precision ?? -1,
        textUnit: textUnit,
      );
    default:
      return null;
  }
}

_BraceProgram _compileBraceProgram(_BraceTemplate template, TextUnit textUnit) {
  // A template that is one literal is its own output. It compiles to the op
  // that writes it by reference, so that neither the compiler nor the call
  // prepares a copy of it; see _BraceSoleLiteralOp.
  if (template.nodes case [_LiteralNode(:final text)]) {
    return _BraceProgram([_BraceSoleLiteralOp(text)], 0);
  }

  final ops = <_BraceOp>[];
  var automatic = 0;
  var capacity = 0;
  for (final node in template.nodes) {
    if (node case _LiteralNode(:final text)) {
      ops.add(_BraceLiteralOp(text));
      capacity += text.length;
      continue;
    }
    final field = node as _FieldNode;
    final automaticBase = automatic;
    automatic += _automaticFieldCount(field);
    capacity += 16;
    final (argumentIndex, argumentName) = switch (field.root) {
      _AutomaticRoot() => (automaticBase, null),
      _PositionalRoot(:final index) => (index, null),
      _NamedRoot(:final name) => (-1, name),
    };
    final op =
        field.conversion == null && field.accesses.isEmpty
            ? _classifyBraceField(field, argumentIndex, argumentName, textUnit)
            : null;
    if (op == null) {
      ops.add(_BraceFallbackOp(field, automaticBase));
    } else {
      ops.add(op);
    }
  }
  return _BraceProgram(ops, capacity);
}

sealed class _PrintfOp {
  const _PrintfOp();

  void write(CharSink sink, _PrintfProcessor frame);

  String describe();
}

final class _PrintfProgram {
  final List<_PrintfOp> ops;

  /// What the sink should preallocate; see [_BraceProgram.estimatedCapacity].
  final int estimatedCapacity;

  const _PrintfProgram(this.ops, this.estimatedCapacity);
}

final class _PrintfLiteralOp extends _PrintfOp {
  // Both representations are prepared once, and each platform reads only its
  // own: the VM copies prepared units as a block, while a web target wants
  // the string it will concatenate. The unused one costs a field, never a
  // conversion, because the branch below folds at compile time.
  final String text;
  final Uint16List units;

  _PrintfLiteralOp(this.text)
    : units = _isWeb ? _noUnits : Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    if (_isWeb) {
      sink.writeString(text);
    } else {
      sink.writeCodeUnits(units);
    }
  }

  @override
  String describe() => 'literal';
}

/// The literal of a template that has no conversion, written by reference.
/// The printf counterpart of [_BraceSoleLiteralOp], and it covers one case
/// more: `%%` folds into the literal, so `'50%%'` is a sole literal too.
final class _PrintfSoleLiteralOp extends _PrintfOp {
  final String text;

  const _PrintfSoleLiteralOp(this.text);

  @override
  void write(CharSink sink, _PrintfProcessor frame) => sink.writeString(text);

  @override
  String describe() => 'literal:sole';
}

final class _PrintfFallbackOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int widthArgIndex;
  final int precisionArgIndex;
  final int valueArgIndex;

  const _PrintfFallbackOp(
    this.node,
    this.widthArgIndex,
    this.precisionArgIndex,
    this.valueArgIndex,
  );

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    // Same consumption order as the legacy cursor (width, precision,
    // value) and the same _staticResolved/_staticContext memoization, so
    // static fallback conversions (e.g. %f) keep today's performance.
    var resolved = node._staticResolved;
    if (resolved == null) {
      var flags = node.flags;
      var width = _fallbackOption(frame, node.width, widthArgIndex, 'width');
      var precision = _fallbackOption(
        frame,
        node.precision,
        precisionArgIndex,
        'precision',
      );
      if (width case final value? when value < 0) {
        flags |= _PrintfFlags.left;
        width = -value;
      }
      if (precision case final value? when value < 0) precision = null;
      resolved = _ResolvedPrintfConversion(
        node: node,
        flags: flags,
        width: width,
        precision: precision,
      );
      if (!node.hasDynamicOptions) node._staticResolved = resolved;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    var context = node._staticContext;
    if (context == null) {
      context = _printfContext(
        frame.template,
        node,
        argumentIndex: valueArgIndex,
      );
      if (!node.hasDynamicOptions) node._staticContext = context;
    }
    sink.writeString(
      _formatPrintfValue(argument, resolved, frame.engine, context),
    );
  }

  int? _fallbackOption(
    _PrintfProcessor frame,
    _PrintfOption? option,
    int argumentIndex,
    String role,
  ) {
    if (option == null) return null;
    if (option case _LiteralPrintfOption(:final value)) {
      return frame._validateOption(node, value, role);
    }
    final argument = frame._argumentAt(argumentIndex, node, specifier: role);
    if (argument is! int || !_isIntegerValue(argument)) {
      throw UnsupportedFormatValueException(
        _printfContext(
          frame.template,
          node,
          specifier: role,
          argumentIndex: argumentIndex,
        ),
        argument,
      );
    }
    return frame._validateOption(
      node,
      argument,
      role,
      argumentIndex: argumentIndex,
    );
  }

  @override
  String describe() => 'fallback';
}

/// Hot op for `%s`. Width/precision are resolved to plain ints at compile
/// time when static; -1 argument indices mean "no dynamic lookup needed" —
/// `hasWidth`/`hasPrecision` carry presence separately since 0 is a legal
/// width/precision and can't double as an absence sentinel.
final class _PrintfStringOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int valueArgIndex;
  final bool left;
  final bool hasWidth;
  final int staticWidth; // meaningful when hasWidth && widthArgIndex < 0
  final int widthArgIndex; // -1 static
  final bool hasPrecision;
  final int staticPrecision;
  final int precisionArgIndex; // -1 static
  final TextUnit textUnit;

  const _PrintfStringOp({
    required this.node,
    required this.valueArgIndex,
    required this.left,
    required this.hasWidth,
    required this.staticWidth,
    required this.widthArgIndex,
    required this.hasPrecision,
    required this.staticPrecision,
    required this.precisionArgIndex,
    required this.textUnit,
  });

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    var effectiveLeft = left;
    int? width;
    if (hasWidth) {
      var resolved =
          widthArgIndex < 0
              ? staticWidth
              : _resolveIrPrintfOption(frame, node, widthArgIndex, 'width');
      if (resolved < 0) {
        effectiveLeft = true;
        resolved = -resolved;
      }
      width = resolved;
    }
    int? precision;
    if (hasPrecision) {
      final resolved =
          precisionArgIndex < 0
              ? staticPrecision
              : _resolveIrPrintfOption(
                frame,
                node,
                precisionArgIndex,
                'precision',
              );
      if (resolved >= 0) precision = resolved;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    late final String text;
    try {
      text = argument.toString();
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      // Transliteration of _fallbackToString (the context stays lazy: this
      // is a hot op, so it must not allocate on the success path).
      throw FormatExtensionException(
        _printfContext(frame.template, node, argumentIndex: valueArgIndex),
        argument.runtimeType.toString(),
        error,
        stackTrace,
      );
    }
    final truncated = precision == null ? text : textUnit.take(text, precision);
    if (width == null) {
      sink.writeString(truncated);
      return;
    }
    final padding = width - textUnit.length(truncated);
    if (!effectiveLeft) sink.fill(0x20, padding);
    sink.writeString(truncated);
    if (effectiveLeft) sink.fill(0x20, padding);
  }

  @override
  String describe() {
    final buffer = StringBuffer('str');
    if (hasWidth) buffer.write(widthArgIndex < 0 ? ':w$staticWidth' : ':w*');
    if (hasPrecision) {
      buffer.write(precisionArgIndex < 0 ? ':p$staticPrecision' : ':p*');
    }
    return buffer.toString();
  }
}

/// Hot op for `d/i/u/o/x/X`. Width/precision resolution mirrors
/// `_PrintfStringOp`; the value branch (int vs. BigInt) mirrors
/// `_formatPrintfInteger`, writing digits straight into the sink instead of
/// building an intermediate string.
final class _PrintfIntOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int valueArgIndex;
  final bool left;
  final bool hasWidth;
  final int staticWidth; // meaningful when hasWidth && widthArgIndex < 0
  final int widthArgIndex; // -1 static
  final bool hasPrecision;
  final int staticPrecision;
  final int precisionArgIndex; // -1 static
  final String type; // d i u o x X
  final int radix;
  final bool uppercase;
  final bool signed; // false for 'u'
  final bool alternate;
  final bool spaceFlag;
  final bool signFlag;
  final bool zeroFlag;

  const _PrintfIntOp({
    required this.node,
    required this.valueArgIndex,
    required this.left,
    required this.hasWidth,
    required this.staticWidth,
    required this.widthArgIndex,
    required this.hasPrecision,
    required this.staticPrecision,
    required this.precisionArgIndex,
    required this.type,
    required this.radix,
    required this.uppercase,
    required this.signed,
    required this.alternate,
    required this.spaceFlag,
    required this.signFlag,
    required this.zeroFlag,
  });

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    var effectiveLeft = left;
    int? width;
    if (hasWidth) {
      var resolved =
          widthArgIndex < 0
              ? staticWidth
              : _resolveIrPrintfOption(frame, node, widthArgIndex, 'width');
      if (resolved < 0) {
        effectiveLeft = true;
        resolved = -resolved;
      }
      width = resolved;
    }
    int? precision;
    if (hasPrecision) {
      final resolved =
          precisionArgIndex < 0
              ? staticPrecision
              : _resolveIrPrintfOption(
                frame,
                node,
                precisionArgIndex,
                'precision',
              );
      if (resolved >= 0) precision = resolved;
    }
    final argument = frame._argumentAt(valueArgIndex, node);

    if (!identical(frame.engine.numberLocale, const CNumberLocale())) {
      // Same escape as _PrintfDoubleOp: a non-default locale replaces the
      // sign and the digits, which this op writes straight into the sink as
      // ASCII. The legacy tail reproduces that exactly, at legacy cost.
      var flags = node.flags;
      if (effectiveLeft) flags |= _PrintfFlags.left;
      sink.writeString(
        _formatPrintfInteger(
          argument,
          _ResolvedPrintfConversion(
            node: node,
            flags: flags,
            width: width,
            precision: precision,
          ),
          frame.engine,
          _valueContext(frame),
        ),
      );
      return;
    }

    late final bool negative;
    late final bool isZero;
    var magnitudeString = ''; // used when digits are pre-materialized below
    var digitCount = 0;
    // BigInt, and web-unsafe int, write pre-materialized digit strings
    // instead of going through sink.writeMagnitude.
    var digitsAsString = false;
    var intValue = 0; // int branch only; avoids re-casting argument below
    if (argument is int && _isIntegerValue(argument)) {
      negative = argument.isNegative;
      isZero = argument == 0;
      if (_isWebInt && _exceedsWebSafeInt(argument)) {
        // Same reasoning as the brace int ops: digit-by-digit extraction is
        // inexact above 2^53-1 on the web, so mirror the BigInt branch and
        // materialize exact digits via _formatIntMagnitude, which goes
        // through BigInt at these magnitudes.
        digitsAsString = true;
        magnitudeString = _formatIntMagnitude(
          argument,
          radix,
          uppercase: uppercase,
        );
        digitCount = magnitudeString.length;
      } else {
        intValue = argument;
        digitCount = CharSink.digitCount(argument, radix);
      }
    } else if (argument is BigInt) {
      digitsAsString = true;
      negative = argument.isNegative;
      isZero = argument == BigInt.zero;
      magnitudeString = formatMagnitude(
        negative ? -argument : argument,
        radix,
        uppercase: uppercase,
      );
      digitCount = magnitudeString.length;
    } else {
      throw UnsupportedFormatValueException(_valueContext(frame), argument);
    }
    if (!signed && negative) {
      throw UnsupportedFormatValueException(_valueContext(frame), argument);
    }

    // digits='' for zero with precision 0, as in _formatPrintfInteger.
    var effectiveDigits = digitCount;
    if (isZero && precision == 0) effectiveDigits = 0;
    final zeroPad =
        precision != null && precision > effectiveDigits
            ? precision - effectiveDigits
            : 0;
    // Alternate prefix rules from _formatPrintfInteger: octal adds '0'
    // unless the digits already start with '0'; hex adds 0x/0X unless zero.
    final digitsStartWithZero = zeroPad > 0 || (isZero && effectiveDigits > 0);
    final prefix = switch (type) {
      'o' when alternate && !digitsStartWithZero => '0',
      'x' when alternate && !isZero => '0x',
      'X' when alternate && !isZero => '0X',
      _ => '',
    };
    final signChar =
        signed && negative
            ? 0x2d
            : signFlag
            ? 0x2b
            : spaceFlag
            ? 0x20
            : 0;
    final zero = zeroFlag && !effectiveLeft && precision == null;
    final content =
        effectiveDigits + zeroPad + prefix.length + (signChar == 0 ? 0 : 1);
    final padding = width == null ? 0 : width - content;
    final fillChar = zero ? 0x30 : 0x20;
    final align =
        effectiveLeft
            ? 0x3c
            : zero
            ? 0x3d
            : 0x3e;

    if (align == 0x3e) sink.fill(fillChar, padding);
    if (signChar != 0) sink.writeCharCode(signChar);
    if (prefix.isNotEmpty) sink.writeString(prefix);
    if (align == 0x3d) sink.fill(fillChar, padding);
    sink.fill(0x30, zeroPad);
    if (effectiveDigits > 0) {
      if (digitsAsString) {
        sink.writeString(magnitudeString);
      } else {
        sink.writeMagnitude(intValue, radix, uppercase: uppercase);
      }
    }
    if (align == 0x3c) sink.fill(fillChar, padding);
  }

  FormatExceptionContext _valueContext(_PrintfProcessor frame) =>
      _printfContext(frame.template, node, argumentIndex: valueArgIndex);

  @override
  String describe() {
    final buffer = StringBuffer('int:$type');
    if (hasWidth) buffer.write(widthArgIndex < 0 ? ':w$staticWidth' : ':w*');
    if (hasPrecision) {
      buffer.write(precisionArgIndex < 0 ? ':p$staticPrecision' : ':p*');
    }
    return buffer.toString();
  }
}

/// Hot op for `f F e E g G`. Width/precision resolution mirrors
/// `_PrintfStringOp`; the body branches are a transliteration of
/// `_formatPrintfDouble`, whose order is the parity contract. `a`/`A` are
/// deliberately absent: their bodies ride an `0x`/`0X` prefix through
/// `_displayPrintfHexBody`, which this op does not reproduce.
final class _PrintfDoubleOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int valueArgIndex;
  final bool left;
  final bool hasWidth;
  final int staticWidth; // meaningful when hasWidth && widthArgIndex < 0
  final int widthArgIndex; // -1 static
  final bool hasPrecision;
  final int staticPrecision;
  final int precisionArgIndex; // -1 static
  final String type; // f F e E g G
  final bool uppercase; // 'E' 'F' 'G' spell their bodies in upper case
  // Meaningful when precisionArgIndex < 0; see _rejectsDartDoublePrecision.
  final bool staticPrecisionRejected;
  final bool alternate;
  final bool spaceFlag;
  final bool signFlag;
  final bool zeroFlag;

  const _PrintfDoubleOp({
    required this.node,
    required this.valueArgIndex,
    required this.left,
    required this.hasWidth,
    required this.staticWidth,
    required this.widthArgIndex,
    required this.hasPrecision,
    required this.staticPrecision,
    required this.precisionArgIndex,
    required this.type,
    required this.uppercase,
    required this.staticPrecisionRejected,
    required this.alternate,
    required this.spaceFlag,
    required this.signFlag,
    required this.zeroFlag,
  });

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    var effectiveLeft = left;
    int? width;
    if (hasWidth) {
      var resolved =
          widthArgIndex < 0
              ? staticWidth
              : _resolveIrPrintfOption(frame, node, widthArgIndex, 'width');
      if (resolved < 0) {
        effectiveLeft = true;
        resolved = -resolved;
      }
      width = resolved;
    }
    int? precision;
    if (hasPrecision) {
      final resolved =
          precisionArgIndex < 0
              ? staticPrecision
              : _resolveIrPrintfOption(
                frame,
                node,
                precisionArgIndex,
                'precision',
              );
      if (resolved >= 0) precision = resolved;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    if (argument is! double) {
      throw UnsupportedFormatValueException(_valueContext(frame), argument);
    }
    final engine = frame.engine;

    if (!identical(engine.numberLocale, const CNumberLocale())) {
      // Non-default locales localize digits/signs/separators; the legacy
      // tail reproduces that exactly, at legacy cost.
      var flags = node.flags;
      if (effectiveLeft) flags |= _PrintfFlags.left;
      sink.writeString(
        _formatPrintfDouble(
          argument,
          _ResolvedPrintfConversion(
            node: node,
            flags: flags,
            width: width,
            precision: precision,
          ),
          engine,
          _valueContext(frame),
        ),
      );
      return;
    }

    if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      // Legacy validates before the finiteness check, so a bad precision on
      // nan must still throw. A static precision has its verdict baked at
      // classification time, exactly like the brace op; `%.*f` resolves its
      // precision per call, so it keeps a live probe, which allocates
      // nothing while the precision is valid (a null precision is what the
      // validator returns from at once). Only a rejected precision pays for
      // an exception context, and the throw itself stays inside the shared
      // validator.
      final rejected =
          precisionArgIndex < 0
              ? staticPrecisionRejected
              : _rejectsDartDoublePrecision(type, precision);
      if (rejected) {
        _validateDartDoublePrecision(type, precision, _valueContext(frame));
      }
    }
    final _AsciiFloat formatted;
    if (!argument.isFinite) {
      formatted = _formatSpecialDouble(argument, uppercase, engine);
    } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      formatted = _formatDartDouble(argument, type, precision, alternate);
    } else {
      final effective = precision ?? 6;
      formatted = switch (type) {
        'f' || 'F' => _formatFixed(argument, effective, alternate),
        'e' || 'E' => _formatScientific(
          Binary64.fromDouble(argument),
          effective,
          alternate,
          type,
        ),
        'g' || 'G' => _formatGeneral(
          Binary64.fromDouble(argument),
          effective == 0 ? 1 : effective,
          alternate,
          type == 'G' ? 'E' : 'e',
        ),
        _ => throw StateError('Unsupported decimal printf conversion: $type'),
      };
    }

    final negative = !argument.isNaN && argument.isNegative;
    final signChar =
        negative
            ? 0x2d
            : signFlag
            ? 0x2b
            : spaceFlag
            ? 0x20
            : 0;
    // Unlike printf integers, a precision does not suppress the zero flag
    // for doubles; only left alignment and the special spellings do.
    final zero = zeroFlag && !effectiveLeft && !formatted.special;
    _writeAsciiFloatDirect(
      sink,
      formatted.body,
      signChar,
      false,
      width ?? -1,
      zero ? 0x30 : 0x20,
      effectiveLeft
          ? 0x3c
          : zero
          ? 0x3d
          : 0x3e,
    );
  }

  FormatExceptionContext _valueContext(_PrintfProcessor frame) =>
      _printfContext(frame.template, node, argumentIndex: valueArgIndex);

  @override
  String describe() {
    final buffer = StringBuffer('double:$type');
    if (hasWidth) buffer.write(widthArgIndex < 0 ? ':w$staticWidth' : ':w*');
    if (hasPrecision) {
      buffer.write(precisionArgIndex < 0 ? ':p$staticPrecision' : ':p*');
    }
    return buffer.toString();
  }
}

_PrintfOp? _classifyPrintfConversion(
  _PrintfConversionNode node,
  int widthArgIndex,
  int precisionArgIndex,
  int valueArgIndex,
  TextUnit textUnit,
) {
  if (node.type == 's') {
    final width = node.width;
    final precision = node.precision;
    var left = _hasPrintfFlag(node.flags, _PrintfFlags.left);
    var staticWidth = 0;
    if (width case _LiteralPrintfOption(:final value)) {
      if (value < -_maximumSafeFormatOption ||
          value > _maximumSafeFormatOption) {
        return null; // Unsafe static width keeps today's per-call error.
      }
      staticWidth = value < 0 ? -value : value;
      if (value < 0) left = true;
    }
    var staticPrecision = 0;
    var hasPrecision = precision != null;
    if (precision case _LiteralPrintfOption(:final value)) {
      if (value > _maximumSafeFormatOption) return null;
      if (value < 0) hasPrecision = false;
      staticPrecision = value < 0 ? 0 : value;
    }
    return _PrintfStringOp(
      node: node,
      valueArgIndex: valueArgIndex,
      left: left,
      hasWidth: width != null,
      staticWidth: staticWidth,
      widthArgIndex: widthArgIndex,
      hasPrecision: hasPrecision,
      staticPrecision: staticPrecision,
      precisionArgIndex: precisionArgIndex,
      textUnit: textUnit,
    );
  }
  if (const {'d', 'i', 'u', 'o', 'x', 'X'}.contains(node.type)) {
    final width = node.width;
    final precision = node.precision;
    var left = _hasPrintfFlag(node.flags, _PrintfFlags.left);
    var staticWidth = 0;
    if (width case _LiteralPrintfOption(:final value)) {
      if (value < -_maximumSafeFormatOption ||
          value > _maximumSafeFormatOption) {
        return null; // Unsafe static width keeps today's per-call error.
      }
      staticWidth = value < 0 ? -value : value;
      if (value < 0) left = true;
    }
    var staticPrecision = 0;
    var hasPrecision = precision != null;
    if (precision case _LiteralPrintfOption(:final value)) {
      if (value > _maximumSafeFormatOption) return null;
      if (value < 0) hasPrecision = false;
      staticPrecision = value < 0 ? 0 : value;
    }
    final type = node.type;
    return _PrintfIntOp(
      node: node,
      valueArgIndex: valueArgIndex,
      left: left,
      hasWidth: width != null,
      staticWidth: staticWidth,
      widthArgIndex: widthArgIndex,
      hasPrecision: hasPrecision,
      staticPrecision: staticPrecision,
      precisionArgIndex: precisionArgIndex,
      type: type,
      radix: switch (type) {
        'o' => 8,
        'x' || 'X' => 16,
        _ => 10,
      },
      uppercase: type == 'X',
      signed: type == 'd' || type == 'i',
      alternate: _hasPrintfFlag(node.flags, _PrintfFlags.alternate),
      spaceFlag: _hasPrintfFlag(node.flags, _PrintfFlags.space),
      signFlag: _hasPrintfFlag(node.flags, _PrintfFlags.sign),
      zeroFlag: _hasPrintfFlag(node.flags, _PrintfFlags.zero),
    );
  }
  // 'a'/'A' are deliberately absent: they keep the legacy hex tail.
  if (const {'f', 'F', 'e', 'E', 'g', 'G'}.contains(node.type)) {
    final width = node.width;
    final precision = node.precision;
    var left = _hasPrintfFlag(node.flags, _PrintfFlags.left);
    var staticWidth = 0;
    if (width case _LiteralPrintfOption(:final value)) {
      if (value < -_maximumSafeFormatOption ||
          value > _maximumSafeFormatOption) {
        return null; // Unsafe static width keeps today's per-call error.
      }
      staticWidth = value < 0 ? -value : value;
      if (value < 0) left = true;
    }
    var staticPrecision = 0;
    var hasPrecision = precision != null;
    if (precision case _LiteralPrintfOption(:final value)) {
      if (value > _maximumSafeFormatOption) return null;
      if (value < 0) hasPrecision = false;
      staticPrecision = value < 0 ? 0 : value;
    }
    return _PrintfDoubleOp(
      node: node,
      valueArgIndex: valueArgIndex,
      left: left,
      hasWidth: width != null,
      staticWidth: staticWidth,
      widthArgIndex: widthArgIndex,
      hasPrecision: hasPrecision,
      staticPrecision: staticPrecision,
      precisionArgIndex: precisionArgIndex,
      type: node.type,
      uppercase: node.type == 'E' || node.type == 'F' || node.type == 'G',
      // A static precision is the value `write` would resolve, so its
      // verdict is decided here once; a dynamic `*` keeps a live probe.
      staticPrecisionRejected:
          precisionArgIndex < 0 &&
          hasPrecision &&
          _rejectsDartDoublePrecision(node.type, staticPrecision),
      alternate: _hasPrintfFlag(node.flags, _PrintfFlags.alternate),
      spaceFlag: _hasPrintfFlag(node.flags, _PrintfFlags.space),
      signFlag: _hasPrintfFlag(node.flags, _PrintfFlags.sign),
      zeroFlag: _hasPrintfFlag(node.flags, _PrintfFlags.zero),
    );
  }
  return null;
}

_PrintfProgram _compilePrintfProgram(
  _PrintfTemplate template,
  TextUnit textUnit,
) {
  final ops = <_PrintfOp>[];
  final literal = StringBuffer();
  var argument = 0;
  var capacity = 0;

  void flushLiteral() {
    if (literal.isEmpty) return;
    final text = literal.toString();
    ops.add(_PrintfLiteralOp(text));
    capacity += text.length;
    literal.clear();
  }

  for (final node in template.nodes) {
    if (node case _PrintfLiteralNode(:final text)) {
      literal.write(text);
      continue;
    }
    final conversion = node as _PrintfConversionNode;
    final widthArgIndex =
        conversion.width is _DynamicPrintfOption ? argument++ : -1;
    final precisionArgIndex =
        conversion.precision is _DynamicPrintfOption ? argument++ : -1;
    final valueArgIndex = conversion.type == '%' ? -1 : argument++;
    if (conversion.type == '%') {
      // Unconditional: the parser rejects a width or a precision on `%`
      // (`printf_parser.dart`, `invalidWidth`/`invalidPrecision`), so a `%`
      // never carries dynamic options and never reaches the generic op.
      literal.write('%');
      continue;
    }
    flushLiteral();
    capacity += 16;
    final op = _classifyPrintfConversion(
      conversion,
      widthArgIndex,
      precisionArgIndex,
      valueArgIndex,
      textUnit,
    );
    ops.add(
      op ??
          _PrintfFallbackOp(
            conversion,
            widthArgIndex,
            precisionArgIndex,
            valueArgIndex,
          ),
    );
  }
  // Nothing but literal text, so what has accumulated is the whole program:
  // one op, written by reference, with no units prepared for it. See
  // _PrintfSoleLiteralOp.
  if (ops.isEmpty && literal.isNotEmpty) {
    return _PrintfProgram([_PrintfSoleLiteralOp(literal.toString())], 0);
  }
  flushLiteral();
  return _PrintfProgram(ops, capacity);
}

/// Resolves a dynamic printf width/precision for a hot op, mirroring
/// _PrintfProcessor._resolveOption including error contexts. Static
/// options never pass through here: they are baked into ops at compile
/// time.
int _resolveIrPrintfOption(
  _PrintfProcessor frame,
  _PrintfConversionNode node,
  int argumentIndex,
  String role,
) {
  final argument = frame._argumentAt(argumentIndex, node, specifier: role);
  if (argument is! int || !_isIntegerValue(argument)) {
    throw UnsupportedFormatValueException(
      _printfContext(
        frame.template,
        node,
        specifier: role,
        argumentIndex: argumentIndex,
      ),
      argument,
    );
  }
  return frame._validateOption(
    node,
    argument,
    role,
    argumentIndex: argumentIndex,
  );
}

/// Test seams. Deliberately not exported by `format.dart`.
List<String> debugCompiledProgramDescription(
  String template, {
  required bool printf,
  required TextUnit textUnit,
}) =>
    printf
        ? [
          for (final op
              in _cachedPrintfTemplate(template).programFor(textUnit).ops)
            op.describe(),
        ]
        : [
          for (final op
              in _cachedBraceTemplate(template).programFor(textUnit).ops)
            op.describe(),
        ];

String debugFormatBraceWithoutIr(
  String template,
  Format engine, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) =>
    _BraceProcessor(
      template,
      positional: positional,
      named: named,
      engine: engine,
    ).formatWithoutIr();

String debugFormatPrintfWithoutIr(
  String template,
  Format engine,
  List<Object?> values,
) =>
    _PrintfProcessor(
      template,
      List<Object?>.unmodifiable(values),
      engine,
    ).formatWithoutIr();
