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

  /// Rounds the significand to a binary fraction of [fractionBits] bits.
  ///
  /// The binary point remains after bit 52, including for subnormal values,
  /// so callers can keep the canonical exponent -1022 for subnormals.
  BigInt roundBinaryFraction(int fractionBits) {
    assert(isFinite);
    if (fractionBits < 0) {
      throw ArgumentError.value(
        fractionBits,
        'fractionBits',
        'must not be negative',
      );
    }
    if (fractionBits >= 52) return significand << (fractionBits - 52);

    final shift = 52 - fractionBits;
    final quotient = significand >> shift;
    final remainder = significand - (quotient << shift);
    final halfway = BigInt.one << (shift - 1);
    if (remainder > halfway || (remainder == halfway && quotient.isOdd)) {
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

/// Powers of ten, filled in as they are asked for and never dropped.
///
/// Three decisions are frozen here, and none of them is obvious from the code.
///
/// It is mutable global state, and that is safe rather than tolerated: Dart
/// isolates do not share mutable memory, so this list is per-isolate by
/// construction. There is nothing to lock and nothing another thread can
/// observe half-built.
///
/// It has no eviction policy because it needs none. The list is capped, so its
/// worst case is a fixed cost paid once rather than growth without a bound:
/// filled to [_cachedPowerCeiling] it holds 401 entries totalling 80601
/// decimal digits, about 33 KB of magnitudes. A policy would add a decision to
/// every lookup in exchange for reclaiming that.
///
/// The ceiling is not the largest exponent this package can be asked for, and
/// deliberately so. `%.1074f` on the smallest subnormal spells the value out
/// exactly and asks for `10^1074`; that request falls through to an uncached
/// `pow`. Measured, the uncached call happens once per formatting and costs
/// 0.7% of it, which does not pay for holding another 674 `BigInt`s —
/// recorded as M16 and rejected by measurement.
final List<BigInt> _smallDecimalPowers = <BigInt>[BigInt.one];

const _cachedPowerCeiling = 400;

BigInt decimalPower(int exponent) {
  if (exponent < 0) {
    throw ArgumentError.value(exponent, 'exponent', 'must not be negative');
  }
  while (_smallDecimalPowers.length <= exponent &&
      _smallDecimalPowers.length <= _cachedPowerCeiling) {
    _smallDecimalPowers.add(_smallDecimalPowers.last * BigInt.from(10));
  }
  if (exponent < _smallDecimalPowers.length) {
    return _smallDecimalPowers[exponent];
  }

  return BigInt.from(10).pow(exponent);
}
