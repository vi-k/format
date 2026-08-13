part of 'engine.dart';

bool _isIntegerValue(Object? value) {
  if (value is BigInt) return true;
  if (value is! int) return false;
  if (value is! double) return true;
  return value.isFinite && !(value == 0 && value.isNegative);
}

String _formatBraceInteger(
  Object value,
  _FormatSpec spec,
  Format settings,
  FormatExceptionContext context,
) {
  final type = spec.type ?? 'd';
  _validateIntegerSpec(spec, type, context);

  final isLocaleDecimal = type == 'n';
  final radix = switch (type) {
    'b' => 2,
    'o' => 8,
    'd' || 'n' => 10,
    'x' || 'X' => 16,
    _ =>
      throw _invalidSpecifier(
        context,
        'Integer values accept the presentation types b, d, n, o, x, and X.',
      ),
  };
  final negative = switch (value) {
    int() => value.isNegative,
    BigInt() => value.isNegative,
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final digits = switch (value) {
    int() => _formatIntMagnitude(value, radix, uppercase: type == 'X'),
    BigInt() => formatMagnitude(
      value.isNegative ? -value : value,
      radix,
      uppercase: type == 'X',
    ),
    _ => throw UnsupportedFormatValueException(context, value),
  };
  final prefix = _integerPrefix(type, spec.alternate);

  if (isLocaleDecimal) {
    final locale = settings.numberLocale;
    final groupingEnabled = _readLocale(
      context,
      locale,
      () => locale.groupingEnabled,
    );
    List<int>? grouping;
    String? separator;
    if (groupingEnabled) {
      grouping = List.of(
        _readLocale(context, locale, () => locale.grouping),
        growable: false,
      );
      _validateGrouping(grouping, context);
      separator = _readLocale(context, locale, () => locale.groupSeparator);
    }
    final sign = _localizedSign(negative, spec.sign, locale, context);
    return _applyNumericWidth(
      sign: sign,
      prefix: prefix,
      digits: digits,
      spec: spec,
      textUnit: settings.textUnit,
      formatDigits: (asciiDigits) {
        final grouped =
            grouping == null
                ? asciiDigits
                : groupDigits(
                  asciiDigits,
                  separator: separator!,
                  grouping: grouping,
                );
        return _localizeDigits(grouped, separator, locale, context);
      },
    );
  }

  String Function(String)? grouping;
  if (spec.grouping != null) {
    final groupingSize = type == 'd' ? 3 : 4;
    grouping =
        (value) => groupDigits(
          value,
          separator: spec.grouping!,
          grouping: [groupingSize],
        );
  }
  return _applyNumericWidth(
    sign: _asciiSign(negative, spec.sign),
    prefix: prefix,
    digits: digits,
    spec: spec,
    textUnit: settings.textUnit,
    formatDigits: grouping,
  );
}

String formatMagnitude(BigInt magnitude, int radix, {bool uppercase = false}) {
  final digits =
      radix == 10 ? magnitude.toString() : magnitude.toRadixString(radix);
  return uppercase ? digits.toUpperCase() : digits;
}

/// Where a web double stops printing its digits and starts printing an
/// exponent. Below it, fixed-point conversion is exact and cheap; at it and
/// above, only BigInt still spells the value out.
const double _webFixedPointCeiling = 1e21;

String _formatIntMagnitude(int value, int radix, {bool uppercase = false}) {
  // Only decimal needs help past the web-safe range. Every other radix this
  // package supports is a power of two, and a binary double converts into one
  // exactly — there are no digits for a detour to recover. Checked against
  // BigInt on 1254 comparisons over radices 2, 8 and 16, both signs, and
  // values from 2^53 to 1e21: the two agree everywhere, on dart2js, on
  // dart2wasm and on the VM.
  if (_isWebInt && radix == 10 && _exceedsWebSafeInt(value)) {
    // On the web an int is a JS double, and JS String(n) prints the
    // shortest-roundtrip form above 2^53-1 and switches to exponential
    // notation at 1e21.
    final magnitude = (value as num).toDouble().abs();
    if (magnitude < _webFixedPointCeiling) {
      // Fixed-point conversion names the integer nearest the double, which
      // for a double that is already an integer is the double itself — the
      // same digits BigInt produces, for a twentieth of the cost.
      return magnitude.toStringAsFixed(0);
    }
    // BigInt.from carries the double's exact value, so its digits stay exact
    // where fixed-point conversion has given up.
    final exact = BigInt.from(value);
    return formatMagnitude(
      exact.isNegative ? -exact : exact,
      radix,
      uppercase: uppercase,
    );
  }
  final raw = radix == 10 ? value.toString() : value.toRadixString(radix);
  final digits = value.isNegative ? raw.substring(1) : raw;
  return uppercase ? digits.toUpperCase() : digits;
}

String groupDigits(
  String digits, {
  required String separator,
  required List<int> grouping,
}) {
  if (digits.isEmpty) return digits;
  final groups = <String>[];
  var end = digits.length;
  var groupingIndex = 0;
  while (end > 0) {
    final size =
        grouping[groupingIndex < grouping.length
            ? groupingIndex
            : grouping.length - 1];
    final start = (end - size).clamp(0, end);
    groups.add(digits.substring(start, end));
    end = start;
    groupingIndex++;
  }
  return groups.reversed.join(separator);
}

String _applyNumericWidth({
  required String sign,
  required String prefix,
  required String digits,
  required _FormatSpec spec,
  required TextUnit textUnit,
  String Function(String digits)? formatDigits,
}) {
  final displayedDigits = formatDigits?.call(digits) ?? digits;
  final value = _signed(sign, prefix, displayedDigits);
  final width = spec.width;
  if (width == null) return value;

  final fill = spec.fill ?? (spec.zero ? '0' : ' ');
  final align = spec.align ?? (spec.zero ? '=' : '>');
  // Zero padding under a regrouping [formatDigits] cannot be counted: every
  // zero added may pull in a separator and widen the result by more than one.
  // The count is searched for instead — the smallest number of leading zeros
  // whose regrouped form reaches the width.
  if (align == '=' && fill == '0' && formatDigits != null) {
    var lower = 0;
    var upper = width - textUnit.length(value);
    while (lower < upper) {
      final middle = (lower + upper) ~/ 2;
      final candidate = formatDigits('${'0' * middle}$digits');
      if (textUnit.length(_signed(sign, prefix, candidate)) < width) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }

    return _signed(sign, prefix, formatDigits('${'0' * lower}$digits'));
  }

  final padding = width - textUnit.length(value);
  if (padding <= 0) return value;
  if (align == '=') return '$sign$prefix${fill * padding}$displayedDigits';

  switch (align) {
    case '<':
      return value + fill * padding;
    case '>':
      return fill * padding + value;
    case '^':
      final half = padding ~/ 2;
      return '${fill * half}$value${fill * (padding - half)}';
    default:
      throw StateError('Unsupported numeric alignment: $align');
  }
}

/// [sign], [prefix] and [body] joined, without copying when there is nothing
/// to join.
///
/// Both leading parts are empty for the ordinary case — a non-negative value
/// under a specification that asks for neither a sign nor a base prefix — and
/// `sign + prefix + body` would then allocate two copies of the digits to
/// arrive back at the digits. Where they are not empty, one interpolation
/// allocates once where the chained `+` allocated twice.
String _signed(String sign, String prefix, String body) =>
    sign.isEmpty && prefix.isEmpty ? body : '$sign$prefix$body';

String _formatBraceDouble(
  Object value,
  _FormatSpec spec,
  Format settings,
  FormatExceptionContext context,
) {
  final converted = switch (value) {
    double() => value,
    int() => value.toDouble(),
    BigInt() => value.toDouble(),
    _ => throw UnsupportedFormatValueException(context, value),
  };
  if (_isIntegerValue(value) && !converted.isFinite) {
    throw UnsupportedFormatValueException(context, value);
  }

  final type = spec.type;
  _validateDoubleSpec(spec, type, context);
  final uppercase = type == 'E' || type == 'F' || type == 'G';
  final percent = type == '%';
  final formattingValue = percent ? converted * 100 : converted;
  if (settings.doubleFormatMode == DoubleFormatMode.dartSdk) {
    _validateDartDoublePrecision(type, spec.precision, context);
  }

  late final _AsciiFloat formatted;
  if (!formattingValue.isFinite) {
    formatted = _formatSpecialDouble(formattingValue, uppercase, settings);
  } else if (settings.doubleFormatMode == DoubleFormatMode.dartSdk) {
    formatted = _formatDartDouble(
      formattingValue,
      type,
      spec.precision,
      spec.alternate,
    );
  } else if (type == null && spec.precision == null) {
    formatted = _formatShortest(converted, spec.alternate);
  } else {
    final precision = spec.precision ?? 6;
    formatted = switch (type) {
      'f' || 'F' => _formatFixed(converted, precision, spec.alternate),
      'e' ||
      'E' => _formatScientific(converted, precision, spec.alternate, type!),
      'g' || 'G' || 'n' => _formatGeneral(
        converted,
        precision == 0 ? 1 : precision,
        spec.alternate,
        type == 'G' ? 'E' : 'e',
      ),
      '%' => _formatFixed(formattingValue, precision, spec.alternate),
      null => _formatGeneral(
        converted,
        precision == 0 ? 1 : precision,
        spec.alternate,
        'e',
        emptyType: true,
      ),
      _ => throw StateError('Unsupported floating presentation: $type'),
    };
  }

  var negative = !formattingValue.isNaN && formattingValue.isNegative;
  if (spec.normalizeNegativeZero && formatted.roundedZero) negative = false;
  final locale = type == 'n' ? settings.numberLocale : null;
  final sign =
      locale == null
          ? _asciiSign(negative, spec.sign)
          : _localizedSign(negative, spec.sign, locale, context);
  final suffix = percent ? '%' : '';
  return _applyNumericWidth(
    sign: sign,
    prefix: '',
    digits: formatted.body + suffix,
    spec: spec,
    textUnit: settings.textUnit,
    formatDigits:
        (body) =>
            _displayFloatBody(body, spec, locale, context, formatted.special),
  );
}

final class _AsciiFloat {
  final String body;
  final bool roundedZero;
  final bool special;

  const _AsciiFloat(this.body, this.roundedZero, {this.special = false});
}

_AsciiFloat _formatFixed(double source, int precision, bool alternate) {
  final fast = _formatFixedFast(source, precision, alternate);
  if (fast != null) return fast;

  final rounded = Binary64.fromDouble(source).roundDecimal(precision);
  return _AsciiFloat(
    _fixedFromRounded(rounded, precision, alternate),
    rounded == BigInt.zero,
  );
}

/// The most fraction digits an SDK fixed-point conversion will spell.
const _nativeFixedFractionCeiling = 20;

const _fixedDecimalScales = <double>[
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
  10000000000000000,
  100000000000000000,
  1000000000000000000,
  10000000000000000000,
  100000000000000000000,
];

const _maximumExactDoubleInteger = 4503599627370496.0;

_AsciiFloat? _formatFixedFast(double source, int precision, bool alternate) {
  if (precision < 0 || precision > _nativeFixedFractionCeiling) return null;
  final magnitude = source.abs();
  // Past this the SDK conversion stops writing fixed-point notation and hands
  // back an exponent, which is not what this presentation promises.
  if (magnitude >= _webFixedPointCeiling) return null;

  // Two ways to answer the same question — does rounding land on a tie, where
  // the SDK rounds away from zero and this package rounds to even — and the
  // cheaper one is tried first because it covers the ordinary case. While the
  // scaled value is an exact double the tie is visible in the value itself,
  // and reading the bits instead measured 5–9% slower on `{:.2f}`.
  final scaled = magnitude * _fixedDecimalScales[precision];
  if (scaled < _maximumExactDoubleInteger) {
    final integer = scaled.truncateToDouble();
    final evenHalfTie = scaled - integer == 0.5 && integer.toInt().isEven;
    if (evenHalfTie) return null;

    var body = magnitude.toStringAsFixed(precision);
    if (alternate && precision == 0) body += '.';
    return _AsciiFloat(body, scaled < 0.5);
  }

  // Past the exact range the product says nothing — and this is where the
  // fast path used to give up and the value went to BigInt, which costs 20
  // times as much under dart2js. The tie is still decidable, from the bits:
  // `x * 10^precision` is a half-integer only when
  // `2 * m * 2^(k + precision) * 5^precision` is an odd integer, and an odd
  // `m` pins `k` to `-(precision + 1)` with nothing left to check. Verified
  // against a BigInt oracle on 46 400 comparisons over the three runtimes:
  // 1391 ties, 1391 firings, none missed.
  if (_canonicalBinaryExponent(magnitude) == -(precision + 1)) return null;

  var body = magnitude.toStringAsFixed(precision);
  if (alternate && precision == 0) body += '.';
  // The scaled value reached the exact-integer ceiling, so the result cannot
  // be zero and needs no test.
  return _AsciiFloat(body, false);
}

/// The most significant digits an SDK exponential conversion will spell.
///
/// `toStringAsExponential` takes the number of digits after the point and
/// the SDK caps that at twenty; one digit stands before it.
const _nativeSignificantDigitCeiling = 21;

/// Scratch space for reading a double's bits.
///
/// Mutable global state, and safe rather than tolerated for the same reason
/// as [decimalPower]'s table: Dart isolates share no mutable memory, so this
/// is per-isolate by construction, and nothing can observe it half-written —
/// every reader fills it before reading it back.
final ByteData _binaryScratch = ByteData(8);

int _trailingZeros32(int value) {
  var remaining = value;
  var count = 0;
  if ((remaining & 0xffff) == 0) {
    remaining >>= 16;
    count += 16;
  }
  if ((remaining & 0xff) == 0) {
    remaining >>= 8;
    count += 8;
  }
  if ((remaining & 0xf) == 0) {
    remaining >>= 4;
    count += 4;
  }
  if ((remaining & 0x3) == 0) {
    remaining >>= 2;
    count += 2;
  }
  if ((remaining & 0x1) == 0) count += 1;
  return count;
}

/// The binary exponent of a finite non-zero [magnitude] written with an odd
/// significand.
///
/// Every double is `m * 2^k`, and the pair is only unique once `m` is odd:
/// `12.5` is `25 * 2^-1`, not `100 * 2^-3`. The odd form is what decides
/// where the exact decimal expansion ends, which is what [_mayRoundOnTie]
/// asks about. Read through 32-bit halves on purpose: the significand does
/// not fit a web int, but each half does.
int _canonicalBinaryExponent(double magnitude) {
  _binaryScratch.setFloat64(0, magnitude);
  final high = _binaryScratch.getUint32(0);
  final low = _binaryScratch.getUint32(4);
  final exponentBits = (high >> 20) & 0x7ff;
  final subnormal = exponentBits == 0;
  final highFraction = (high & 0x000fffff) | (subnormal ? 0 : 0x00100000);
  final exponent2 = subnormal ? -1074 : exponentBits - 1075;
  final trailing =
      low != 0 ? _trailingZeros32(low) : 32 + _trailingZeros32(highFraction);
  return exponent2 + trailing;
}

/// Whether rounding [magnitude] to [significantDigits] digits can land
/// exactly on a half.
///
/// This is the one place the platform conversion and this package disagree:
/// both round to nearest, but a tie goes up in the SDK and in ECMAScript and
/// to even here, the rule Python follows. `{:.2g}` of `12.5` is `12`, not
/// `13`.
///
/// A tie needs the exact expansion of the value to stop right after the
/// rounding position, that is, to hold exactly `significantDigits + 1`
/// significant digits. For `m * 2^k` with an odd `m` that pins `k` to
/// `exponent - significantDigits`, so the whole question is one comparison
/// of integers. [exponent] is read back from the conversion, where a carry
/// may have raised it (`9.99` at two digits reports 1, not 0), so the
/// position below it is asked about too.
///
/// The test is necessary, not sufficient: it also stops on values that would
/// have agreed, and those only pay for the exact path. Checked against a
/// BigInt oracle on 567 000 probes over VM, dart2js and dart2wasm — 5421
/// ties, none of them missed.
bool _mayRoundOnTie(double magnitude, int significantDigits, int exponent) {
  final canonical = _canonicalBinaryExponent(magnitude);
  return canonical == exponent - significantDigits ||
      canonical == exponent - 1 - significantDigits;
}

/// The [significantDigits] leading digits of [magnitude] and its decimal
/// exponent, taken from the platform conversion.
///
/// Returns null where that conversion cannot stand in for the exact path:
/// outside the range the SDK spells, and on values that may tie.
_ShortestDecimal? _nativeSignificantDigits(
  double magnitude,
  int significantDigits,
) {
  if (significantDigits < 1 ||
      significantDigits > _nativeSignificantDigitCeiling) {
    return null;
  }
  if (magnitude == 0) {
    return _ShortestDecimal(_zeroDigits(significantDigits), 0);
  }

  final text = magnitude.toStringAsExponential(significantDigits - 1);
  final marker = _exponentMarkerIndex(text);
  var index = marker + 1;
  final signUnit = text.codeUnitAt(index);
  final negative = signUnit == 0x2d;
  if (negative || signUnit == 0x2b) index++;
  var exponent = 0;
  for (; index < text.length; index++) {
    exponent = exponent * 10 + (text.codeUnitAt(index) - 0x30);
  }
  if (negative) exponent = -exponent;

  if (_mayRoundOnTie(magnitude, significantDigits, exponent)) return null;

  // The conversion writes one digit, a point, then the rest; at one digit it
  // writes no point at all.
  final digits =
      significantDigits == 1
          ? text.substring(0, marker)
          : text.substring(0, 1) + text.substring(2, marker);
  return _ShortestDecimal(digits, exponent);
}

String _zeroDigits(int count) {
  const zeros = '00000000000000000000000';
  return count <= zeros.length ? zeros.substring(0, count) : '0' * count;
}

bool _allZeroDigits(String digits) {
  for (var index = 0; index < digits.length; index++) {
    if (digits.codeUnitAt(index) != 0x30) return false;
  }
  return true;
}

/// Spells [digits] in fixed-point notation, where the value is
/// `0.<digits> * 10^(exponent + 1)`.
///
/// Only ever called where the point falls inside the digits or right after
/// them, which is what the general presentation guarantees on this branch.
String _fixedFromDigits(String digits, int exponent, bool alternate) {
  final point = exponent + 1;
  if (point <= 0) {
    return '0.${_zeroDigits(-point)}$digits';
  }
  if (point >= digits.length) {
    return digits + (alternate ? '.' : '');
  }
  return '${digits.substring(0, point)}.${digits.substring(point)}';
}

_AsciiFloat _scientificFromDigits(
  String digits,
  int exponent,
  int precision,
  bool alternate,
  String exponentCharacter,
) {
  final fraction = precision == 0 ? '' : digits.substring(1);
  final point = precision > 0 || alternate ? '.' : '';
  return _AsciiFloat(
    digits[0] + point + fraction + _asciiExponent(exponentCharacter, exponent),
    _allZeroDigits(digits),
  );
}

_AsciiFloat _generalFromDigits(
  String digits,
  int exponent,
  int precision,
  bool alternate,
  String exponentCharacter,
  bool emptyType,
) {
  String body;
  final scientificCutoff = emptyType ? precision - 1 : precision;
  if (exponent < -4 || exponent >= scientificCutoff) {
    var fraction = precision == 1 ? '' : digits.substring(1);
    if (!alternate) fraction = _trimTrailingZeros(fraction);
    final point = fraction.isNotEmpty || alternate ? '.' : '';
    body =
        digits[0] +
        point +
        fraction +
        _asciiExponent(exponentCharacter, exponent);
  } else {
    body = _fixedFromDigits(digits, exponent, alternate);
    if (!alternate) body = _trimFixedZeros(body);
    if (emptyType && !body.contains('.')) body += '.0';
  }
  return _AsciiFloat(body, _allZeroDigits(digits));
}

/// The digits of [source] rounded to [significantDigits], spelled exactly.
///
/// The slow half of the two paths: it decomposes the double and rounds in
/// BigInt, which is right everywhere and costs the most where doubles are
/// the native numbers. [_nativeSignificantDigits] handles the rest.
_ShortestDecimal _exactSignificantDigits(double source, int significantDigits) {
  final value = Binary64.fromDouble(source);
  var exponent = value.isZero ? 0 : value.decimalExponent();
  var rounded = value.roundDecimal(significantDigits - 1 - exponent);
  var text = rounded.toString();
  if (text.length > significantDigits) {
    rounded ~/= BigInt.from(10);
    text = rounded.toString();
    exponent++;
  }
  return _ShortestDecimal(text.padLeft(significantDigits, '0'), exponent);
}

_AsciiFloat _formatScientific(
  double source,
  int precision,
  bool alternate,
  String exponentCharacter,
) {
  final significantDigits = precision + 1;
  final magnitude = source.abs();
  final digits =
      _nativeSignificantDigits(magnitude, significantDigits) ??
      _exactSignificantDigits(source, significantDigits);
  return _scientificFromDigits(
    digits.digits,
    digits.exponent,
    precision,
    alternate,
    exponentCharacter,
  );
}

_AsciiFloat _formatGeneral(
  double source,
  int precision,
  bool alternate,
  String exponentCharacter, {
  bool emptyType = false,
}) {
  final magnitude = source.abs();
  final digits =
      _nativeSignificantDigits(magnitude, precision) ??
      _exactSignificantDigits(source, precision);
  return _generalFromDigits(
    digits.digits,
    digits.exponent,
    precision,
    alternate,
    exponentCharacter,
    emptyType,
  );
}

_AsciiFloat _formatShortest(double value, bool alternate) {
  final source = value.abs().toString();
  final parsed = _parseShortest(source);
  if (parsed.digits == '0') return const _AsciiFloat('0.0', true);
  final scientific = parsed.exponent < -4 || parsed.exponent >= 16;
  if (scientific) {
    final fraction =
        parsed.digits.length == 1 ? '' : parsed.digits.substring(1);
    final point = fraction.isNotEmpty || alternate ? '.' : '';
    return _AsciiFloat(
      parsed.digits[0] +
          point +
          fraction +
          _asciiExponent('e', parsed.exponent),
      false,
    );
  }
  final decimalPosition = parsed.exponent + 1;
  late String body;
  if (decimalPosition <= 0) {
    body = '0.${'0' * -decimalPosition}${parsed.digits}';
  } else if (decimalPosition >= parsed.digits.length) {
    body =
        '${parsed.digits}'
        '${'0' * (decimalPosition - parsed.digits.length)}.0';
  } else {
    body =
        '${parsed.digits.substring(0, decimalPosition)}.'
        '${parsed.digits.substring(decimalPosition)}';
  }
  return _AsciiFloat(body, false);
}

final class _ShortestDecimal {
  final String digits;
  final int exponent;

  const _ShortestDecimal(this.digits, this.exponent);
}

String _pythonShortestDouble(double value) {
  final binary = Binary64.fromDouble(value);
  if (binary.isNaN) return 'nan';
  if (binary.isInfinite) return binary.signBit ? '-inf' : 'inf';
  final sign = binary.signBit ? '-' : '';
  return sign + _formatShortest(value, false).body;
}

/// Splits the Dart `toString()` of a non-negative double into significant
/// digits and a decimal exponent.
///
/// The scan reads code units rather than matching patterns. `indexOf` with a
/// `RegExp` runs the matcher at every position of the string, and this input
/// needs no matcher: it is `double.toString()`, so digits, at most one `.`,
/// and an optional `e`/`E` with a signed exponent, all ASCII.
_ShortestDecimal _parseShortest(String source) {
  var exponentIndex = -1;
  var point = -1;
  var first = -1;
  for (var index = 0; index < source.length; index++) {
    final unit = source.codeUnitAt(index);
    if (unit == 0x65 || unit == 0x45) {
      exponentIndex = index;
      break;
    }
    if (unit == 0x2e) {
      point = index;
    } else if (first < 0 && unit > 0x30 && unit <= 0x39) {
      first = index;
    }
  }
  if (first < 0) return const _ShortestDecimal('0', 0);

  final mantissaEnd = exponentIndex < 0 ? source.length : exponentIndex;
  // Trailing zeros carry nothing, and once they reach back past the point
  // the point goes with them: `100.0` is one digit with an exponent of two.
  var end = mantissaEnd;
  while (end > first + 1) {
    final unit = source.codeUnitAt(end - 1);
    if (unit != 0x30 && unit != 0x2e) break;
    end--;
  }

  // The point only has to be cut out when significant digits straddle it.
  final digits =
      point < first || point >= end
          ? source.substring(first, end)
          : source.substring(first, point) + source.substring(point + 1, end);
  // Counted without the point, which is what the exponent is relative to.
  final firstDigit = point >= 0 && point < first ? first - 1 : first;
  final decimalPosition = point < 0 ? mantissaEnd : point;
  final externalExponent =
      exponentIndex < 0 ? 0 : int.parse(source.substring(exponentIndex + 1));

  return _ShortestDecimal(
    digits,
    decimalPosition - firstDigit - 1 + externalExponent,
  );
}

String _fixedFromRounded(BigInt rounded, int precision, bool alternate) {
  var digits = rounded.toString();
  if (precision == 0) return digits + (alternate ? '.' : '');
  digits = digits.padLeft(precision + 1, '0');
  final split = digits.length - precision;
  return '${digits.substring(0, split)}.${digits.substring(split)}';
}

String _trimTrailingZeros(String value) {
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0x30) {
    end--;
  }
  return value.substring(0, end);
}

String _trimFixedZeros(String value) {
  if (!value.contains('.')) return value;
  var result = _trimTrailingZeros(value);
  if (result.endsWith('.')) result = result.substring(0, result.length - 1);
  return result;
}

String _asciiExponent(String character, int exponent) {
  final sign = exponent < 0 ? '-' : '+';
  final digits = exponent.abs().toString().padLeft(2, '0');
  return '$character$sign$digits';
}

bool _isAsciiDigitUnit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// The index of the `e` or `E` in an ASCII float body, or -1.
///
/// Only ever asked about text the engine or the Dart SDK produced, where a
/// scan is the whole job; `indexOf` with a `RegExp` would start a matcher at
/// every position instead.
int _exponentMarkerIndex(String body) {
  for (var index = 0; index < body.length; index++) {
    final unit = body.codeUnitAt(index);
    if (unit == 0x65 || unit == 0x45) return index;
  }

  return -1;
}

/// Where the trailing `e+12`-shaped exponent of [body] starts, or -1.
///
/// [_asciiExponent] writes the marker, a sign, and digits, in that order, at
/// the end of the body, so reading it back is a scan from the end.
int _trailingExponentStart(String body) {
  var index = body.length;
  while (index > 0 && _isAsciiDigitUnit(body.codeUnitAt(index - 1))) {
    index--;
  }
  if (index == body.length || index < 2) return -1;
  final sign = body.codeUnitAt(index - 1);
  if (sign != 0x2b && sign != 0x2d) return -1;
  final marker = body.codeUnitAt(index - 2);
  if (marker != 0x65 && marker != 0x45) return -1;

  return index - 2;
}

String _displayFloatBody(
  String body,
  _FormatSpec spec,
  NumberLocale? locale,
  FormatExceptionContext context,
  bool special, {
  bool localeGrouping = true,
}) {
  var suffix = '';
  if (body.endsWith('%')) {
    suffix = '%';
    body = body.substring(0, body.length - 1);
  }
  if (special) {
    final localized =
        locale == null ? body : _localizeAsciiRuns(body, locale, context);
    return suffix.isEmpty ? localized : '$localized$suffix';
  }

  final exponentStart = _trailingExponentStart(body);
  final mantissa = exponentStart < 0 ? body : body.substring(0, exponentStart);
  final point = mantissa.indexOf('.');
  var integer = point < 0 ? mantissa : mantissa.substring(0, point);
  var fraction = point < 0 ? '' : mantissa.substring(point + 1);

  String? localeGroupSeparator;
  if (locale != null && localeGrouping) {
    final enabled = _readLocale(context, locale, () => locale.groupingEnabled);
    if (enabled) {
      final grouping = List.of(
        _readLocale(context, locale, () => locale.grouping),
        growable: false,
      );
      _validateGrouping(grouping, context);
      final separator = _readLocale(
        context,
        locale,
        () => locale.groupSeparator,
      );
      localeGroupSeparator = separator;
      integer = groupDigits(integer, separator: separator, grouping: grouping);
    }
  } else if (spec.grouping != null) {
    integer = groupDigits(
      integer,
      separator: spec.grouping!,
      grouping: const [3],
    );
  }
  if (spec.fractionalGrouping != null && fraction.isNotEmpty) {
    fraction = groupFractionDigits(fraction, spec.fractionalGrouping!);
  }

  final decimalSeparator =
      point < 0
          ? ''
          : locale == null
          ? '.'
          : _readLocale(context, locale, () => locale.decimalSeparator);
  if (locale != null) {
    integer =
        localeGroupSeparator == null
            ? _readLocale(context, locale, () => locale.localizeDigits(integer))
            : integer
                .split(localeGroupSeparator)
                .map(
                  (group) => _readLocale(
                    context,
                    locale,
                    () => locale.localizeDigits(group),
                  ),
                )
                .join(localeGroupSeparator);
    if (fraction.isNotEmpty) {
      fraction = _readLocale(
        context,
        locale,
        () => locale.localizeDigits(fraction),
      );
    }
  }
  // A body without a fractional part leaves both tails empty, and joining
  // three pieces where two are empty copies the integer twice to arrive back
  // at the integer.
  var displayed =
      decimalSeparator.isEmpty && fraction.isEmpty
          ? integer
          : '$integer$decimalSeparator$fraction';
  if (exponentStart >= 0) {
    final marker = body[exponentStart];
    final signCharacter = body[exponentStart + 1];
    final digits = body.substring(exponentStart + 2);
    var exponentSeparator =
        locale == null
            ? marker
            : _readLocale(context, locale, () => locale.exponentSeparator);
    if (marker == 'E') exponentSeparator = exponentSeparator.toUpperCase();
    final exponentSign =
        locale == null
            ? signCharacter
            : _localizedSign(signCharacter == '-', '+', locale, context);
    final exponentDigits =
        locale == null
            ? digits
            : _readLocale(context, locale, () => locale.localizeDigits(digits));
    displayed = '$displayed$exponentSeparator$exponentSign$exponentDigits';
  }

  return suffix.isEmpty ? displayed : '$displayed$suffix';
}

String groupFractionDigits(String digits, String separator) {
  final groups = <String>[];
  for (var start = 0; start < digits.length; start += 3) {
    groups.add(digits.substring(start, (start + 3).clamp(0, digits.length)));
  }
  return groups.join(separator);
}

String _localizeAsciiRuns(
  String value,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  final output = StringBuffer();
  var start = 0;
  var index = 0;
  while (index < value.length) {
    if (!_isAsciiDigitUnit(value.codeUnitAt(index))) {
      index++;
      continue;
    }
    final run = index;
    while (index < value.length && _isAsciiDigitUnit(value.codeUnitAt(index))) {
      index++;
    }
    final digits = value.substring(run, index);
    output
      ..write(value.substring(start, run))
      ..write(
        _readLocale(context, locale, () => locale.localizeDigits(digits)),
      );
    start = index;
  }
  return (output..write(value.substring(start))).toString();
}

void _validateDoubleSpec(
  _FormatSpec spec,
  String? type,
  FormatExceptionContext context,
) {
  const doubleTypes = {null, 'e', 'E', 'f', 'F', 'g', 'G', 'n', '%'};
  if (!doubleTypes.contains(type)) {
    throw _invalidSpecifier(
      context,
      'Double values accept the presentation types e, E, f, F, g, G, n, '
      'and %, or none at all.',
    );
  }
  if (type == 'n' &&
      (spec.grouping != null || spec.fractionalGrouping != null)) {
    throw _invalidSpecifier(
      context,
      'Explicit grouping is not valid for locale-aware formatting.',
    );
  }
  // "Safely" here means bounded, not cheap. The exact path spells the value
  // through `BigInt`, whose `toString` is superlinear, so the cost climbs
  // faster than the precision: measured at 11 ms for 12 500 digits, 39 ms for
  // 25 000 and 142 ms for 50 000, which is about O(n^1.85) and puts the
  // ceiling itself at roughly half a second of CPU — per field, so a template
  // of a hundred such fields is a minute.
  //
  // The ceiling is not lowered, and that is the trade: this validator runs in
  // `compatible` mode, whose whole purpose is to answer as CPython answers,
  // and CPython formats `'{:.50000f}'` without complaint. Refusing it here
  // would buy time by introducing exactly the kind of divergence the mode
  // exists to remove. The default mode is unaffected — the SDK caps precision
  // at 20 and 21 there.
  if (spec.precision != null && spec.precision! > 100000) {
    throw _invalidSpecifier(
      context,
      'Precision is too large to format safely.',
    );
  }
}

void _validateIntegerSpec(
  _FormatSpec spec,
  String type,
  FormatExceptionContext context,
) {
  const integerTypes = {'b', 'd', 'n', 'o', 'x', 'X'};
  if (!integerTypes.contains(type)) {
    throw _invalidSpecifier(
      context,
      'Integer values accept the presentation types b, d, n, o, x, and X.',
    );
  }
  if (spec.normalizeNegativeZero ||
      spec.precision != null ||
      spec.fractionalGrouping != null) {
    throw _invalidSpecifier(
      context,
      'This option is not valid for integer formatting.',
    );
  }
  if ((spec.grouping == ',' && type != 'd') ||
      (spec.grouping == '_' && type == 'n')) {
    throw _invalidSpecifier(
      context,
      'This grouping option is not valid for this integer presentation.',
    );
  }
}

String _integerPrefix(String type, bool alternate) {
  if (!alternate) return '';
  return switch (type) {
    'b' => '0b',
    'o' => '0o',
    'x' => '0x',
    'X' => '0X',
    _ => '',
  };
}

String _asciiSign(bool negative, String? requestedSign) {
  if (negative) return '-';
  return switch (requestedSign) {
    '+' => '+',
    ' ' => ' ',
    _ => '',
  };
}

String _localizedSign(
  bool negative,
  String? requestedSign,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  if (negative) return _readLocale(context, locale, () => locale.minusSign);
  return switch (requestedSign) {
    '+' => _readLocale(context, locale, () => locale.plusSign),
    ' ' => ' ',
    _ => '',
  };
}

String _localizeDigits(
  String digits,
  String? separator,
  NumberLocale locale,
  FormatExceptionContext context,
) {
  if (separator == null) {
    return _readLocale(context, locale, () => locale.localizeDigits(digits));
  }
  return digits
      .split(separator)
      .map(
        (group) =>
            _readLocale(context, locale, () => locale.localizeDigits(group)),
      )
      .join(separator);
}

/// Runs [read] on [locale], reporting a failure the way every other
/// extension point reports one.
///
/// The name is taken from the instance rather than written down as
/// `'NumberLocale'`, which is what lookups, representations and formatters all
/// do. A literal names the interface, and a diagnostic naming the interface is
/// the one that helps least: an application with three locales learns that a
/// locale failed, not which. `runtimeType` is read on the failure path only.
T _readLocale<T>(
  FormatExceptionContext context,
  NumberLocale locale,
  T Function() read,
) {
  try {
    return read();
  } on FormattingException {
    rethrow;
  } catch (error, stackTrace) {
    throw FormatExtensionException(
      context,
      locale.runtimeType.toString(),
      error,
      stackTrace,
    );
  }
}

void _validateGrouping(List<int> grouping, FormatExceptionContext context) {
  if (grouping.isEmpty || grouping.any((size) => size <= 0)) {
    throw _invalidSpecifier(context, 'The number locale has invalid grouping.');
  }
}
