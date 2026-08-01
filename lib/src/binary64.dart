import 'dart:typed_data';

/// Exact decomposition of an IEEE-754 binary64 value.
final class Binary64 {
  final bool signBit;
  final int exponentBits;
  final BigInt fractionBits;
  final BigInt significand;
  final int exponent2;

  const Binary64._(
    this.signBit,
    this.exponentBits,
    this.fractionBits,
    this.significand,
    this.exponent2,
  );

  factory Binary64.fromDouble(double value) {
    final bytes = ByteData(8)..setFloat64(0, value);
    final highBits = bytes.getUint32(0);
    final lowBits = bytes.getUint32(4);
    final exponentBits = (highBits >> 20) & 0x7ff;
    final fractionBits =
        (BigInt.from(highBits & 0x000fffff) << 32) | BigInt.from(lowBits);
    final finite = exponentBits != 0x7ff;
    final significand =
        !finite
            ? BigInt.zero
            : exponentBits == 0
            ? fractionBits
            : fractionBits | (BigInt.one << 52);
    final exponent2 =
        !finite
            ? 0
            : exponentBits == 0
            ? -1074
            : exponentBits - 1023 - 52;
    return Binary64._(
      (highBits >> 31) != 0,
      exponentBits,
      fractionBits,
      significand,
      exponent2,
    );
  }

  bool get isFinite => exponentBits != 0x7ff;
  bool get isNaN => exponentBits == 0x7ff && fractionBits != BigInt.zero;
  bool get isInfinite => exponentBits == 0x7ff && fractionBits == BigInt.zero;
  bool get isZero => isFinite && significand == BigInt.zero;

  /// Rounds `abs(value) * 10^decimalScale` using round-half-even.
  BigInt roundDecimal(int decimalScale) {
    assert(isFinite);
    if (significand == BigInt.zero) return BigInt.zero;

    var numerator = significand;
    var denominator = BigInt.one;
    if (exponent2 >= 0) {
      numerator <<= exponent2;
    } else {
      denominator <<= -exponent2;
    }
    if (decimalScale >= 0) {
      numerator *= decimalPower(decimalScale);
    } else {
      denominator *= decimalPower(-decimalScale);
    }
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    final comparison = (remainder << 1).compareTo(denominator);
    if (comparison > 0 || (comparison == 0 && quotient.isOdd)) {
      return quotient + BigInt.one;
    }
    return quotient;
  }

  /// Returns floor(log10(abs(value))) for a finite non-zero value.
  int decimalExponent() {
    assert(isFinite && !isZero);
    final binaryExponent = significand.bitLength - 1 + exponent2;
    var candidate = (binaryExponent * 0.3010299956639812).floor();
    while (_compareToDecimalPower(candidate) < 0) {
      candidate--;
    }
    while (_compareToDecimalPower(candidate + 1) >= 0) {
      candidate++;
    }
    return candidate;
  }

  int _compareToDecimalPower(int exponent10) {
    var numerator = significand;
    var denominator = BigInt.one;
    if (exponent2 >= 0) {
      numerator <<= exponent2;
    } else {
      denominator <<= -exponent2;
    }
    if (exponent10 >= 0) {
      denominator *= decimalPower(exponent10);
    } else {
      numerator *= decimalPower(-exponent10);
    }
    return numerator.compareTo(denominator);
  }
}

final List<BigInt> _smallDecimalPowers = <BigInt>[BigInt.one];

BigInt decimalPower(int exponent) {
  if (exponent < 0) {
    throw ArgumentError.value(exponent, 'exponent', 'must not be negative');
  }
  while (_smallDecimalPowers.length <= exponent &&
      _smallDecimalPowers.length <= 400) {
    _smallDecimalPowers.add(_smallDecimalPowers.last * BigInt.from(10));
  }
  if (exponent < _smallDecimalPowers.length) {
    return _smallDecimalPowers[exponent];
  }
  return BigInt.from(10).pow(exponent);
}
