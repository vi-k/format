/// Where the digits of a floating conversion come from, and the one rule the
/// platform does not share.
///
/// The `g`, `e` and bare-precision presentations take their digits from the
/// platform's own exponential conversion and fall back to exact decomposition
/// where that conversion cannot stand in for it. The two are not
/// interchangeable in one place: both round to nearest, but a tie goes away
/// from zero in the SDK and in ECMAScript, while this package rounds to even,
/// the rule CPython follows. `{:.2g}` of `12.5` is `12`, not `13`.
///
/// So this file pins two things. The first is agreement: on a corpus loaded
/// with the values that can tie, the shipped output equals what exact
/// decimal rounding produces — the oracle here spells the value out in
/// [BigInt] and rounds half to even, which is what the platform conversion is
/// standing in for. The second is the ties themselves, written out with the
/// answer CPython gives; without the guard that detects them, every one of
/// those cases moves by one in the last digit.
///
/// Both matter on every runtime and for reasons that differ per runtime: the
/// VM, dart2js and dart2wasm each bring their own double-to-string, and the
/// agreement is a property of all three, not of the one a laptop runs.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:format/format.dart';
import 'package:test/test.dart';

final Format compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

void main() {
  group('digit source', () {
    // The breadth case. Every value is formatted through the scientific
    // presentation, where the layout is a single shape and the digits are the
    // whole answer, so a disagreement can only come from the rounding. The
    // corpus is deliberately loaded with short binary fractions: those are the
    // values whose exact decimal expansion ends, and only such a value can
    // land on a tie.
    test('platform digits match exact half-to-even rounding', () {
      final values = _corpus();
      var ties = 0;

      for (final value in values) {
        for (final significantDigits in const [1, 2, 6, 17, 21]) {
          final exact = _exactDigits(value, significantDigits);
          final expected =
              '${exact.digits[0]}'
              '${significantDigits == 1 ? '' : '.${exact.digits.substring(1)}'}'
              'e${exact.exponent < 0 ? '-' : '+'}'
              '${exact.exponent.abs().toString().padLeft(2, '0')}';
          expect(
            compatible.format('{:.${significantDigits - 1}e}', value),
            expected,
            reason: 'value $value at $significantDigits significant digits',
          );
          if (exact.tie) ties++;
        }
      }

      // A corpus without ties would pass no matter what the guard did. This
      // pins that the case above is load-bearing, not that it is quiet.
      expect(ties, greaterThan(80), reason: 'corpus must contain ties');
    });

    // The ties themselves, with the answer CPython gives. Each of these moves
    // by one in the last digit if the digits are taken from the platform
    // without the guard, which is exactly what the guard is for.
    test('exact ties round to even, where the platform rounds up', () {
      const braces = <String, double>{
        '{:.2g}': 12.5,
        '{:.1g}': 2.5,
        '{:.6g}': 1.015625,
        '{:.3}': 12.5,
        '{:.1e}': 1.25,
        '{:.0e}': 2.5,
        '{:.2e}': 1.0625,
      };
      const expected = <String>[
        '12',
        '2',
        '1.01562',
        '12.5',
        '1.2e+00',
        '2e+00',
        '1.06e+00',
      ];

      var index = 0;
      for (final MapEntry(:key, :value) in braces.entries) {
        expect(compatible.format(key, value), expected[index], reason: key);
        index++;
      }

      // Two more shapes of the same rule: a tie below one, where the general
      // presentation stays in fixed notation, and a tie whose neighbour digit
      // is odd, where rounding to even and rounding up agree and the guard
      // must not change the answer.
      expect(compatible.format('{:.2g}', 0.125), '0.12');
      expect(compatible.format('{:.6g}', 0.0009765625), '0.000976562');
      expect(compatible.format('{:.1e}', 1.75), '1.8e+00');
    });

    // The sign and the alternate form are applied around the digits, so a
    // guard that fired on the magnitude only would still be right here; this
    // says so out loud, because the fallback path receives the signed value
    // and the fast path the magnitude.
    test('the tie rule survives the sign and the alternate form', () {
      expect(compatible.format('{:.2g}', -12.5), '-12');
      expect(compatible.format('{:#.2g}', 12.5), '12.');
      expect(
        compatible.format('{:.17g}', 544561739248577.1),
        '544561739248577.12',
      );
    });

    // The printf dialect reaches the same conversions through its own
    // formatter and its own IR op, so it is asked separately rather than
    // assumed.
    test('the printf dialect takes the same digits', () {
      expect(compatible.sprintf('%.2g', 12.5), '12');
      expect(compatible.sprintf('%.1g', 2.5), '2');
      expect(compatible.sprintf('%.1e', 1.25), '1.2e+00');
      expect(compatible.sprintf('%.0e', 2.5), '2e+00');
      expect(compatible.sprintf('%.3g', 0.0625), '0.0625');
    });

    // The platform conversion spells at most twenty-one significant digits.
    // Past that the exact path answers alone, and it has to keep spelling the
    // value rather than the shortest form that round-trips to it: `0.1` is not
    // one tenth, and at thirty digits that shows.
    test('past the platform ceiling the exact path still spells the value', () {
      expect(compatible.format('{:.21g}', 0.1), '0.100000000000000005551');
      expect(compatible.format('{:.25g}', 0.1), '0.1000000000000000055511151');
      expect(
        compatible.format('{:.30g}', 0.1),
        '0.100000000000000005551115123126',
      );
    });
  });
}

/// Values chosen so that ties are common rather than incidental.
///
/// Short binary fractions terminate in decimal and are the only doubles that
/// can tie; the random bit patterns are there so agreement is not claimed
/// only for the shapes that were expected to work.
List<double> _corpus() {
  final random = math.Random(20260812);
  final values = <double>[
    1,
    12.5,
    2.5,
    0.125,
    1.015625,
    0.0009765625,
    9.5,
    99.5,
    1e21,
    5e-324,
    2.2250738585072014e-308,
    1.7976931348623157e308,
  ];

  final bytes = ByteData(8);
  while (values.length < 200) {
    bytes
      ..setUint32(0, random.nextInt(0xffffffff))
      ..setUint32(4, random.nextInt(0xffffffff));
    final value = bytes.getFloat64(0).abs();
    if (value.isFinite && value != 0) values.add(value);
  }

  for (var index = 0; index < 200; index++) {
    final numerator = random.nextInt(1 << 20) + 1;
    values.add(numerator / math.pow(2, random.nextInt(24)));
  }

  // Ties by construction, at the digit counts the case asks about. A value
  // with exactly `digits + 1` significant decimal digits, the last of them a
  // five, is what rounding to `digits` has to decide, and `n + 0.5` with an
  // `n` of `digits` digits is the shortest way to write one.
  for (final digits in const [1, 2, 6]) {
    final lower = math.pow(10, digits - 1).toInt();
    for (var index = 0; index < 20; index++) {
      values.add(lower + random.nextInt(lower * 9) + 0.5);
    }
  }

  return values;
}

/// The exact answer, spelled out rather than converted.
///
/// [BigInt] stands here as the oracle, not as an implementation: the value is
/// decomposed into `significand * 2^exponent`, scaled by a power of ten and
/// divided, so the digits and the tie are facts about the number rather than
/// about any platform's conversion.
({String digits, int exponent, bool tie}) _exactDigits(
  double magnitude,
  int significantDigits,
) {
  final bytes = ByteData(8)..setFloat64(0, magnitude);
  final high = bytes.getUint32(0);
  final low = bytes.getUint32(4);
  final exponentBits = (high >> 20) & 0x7ff;
  final fraction = (BigInt.from(high & 0x000fffff) << 32) | BigInt.from(low);
  final significand =
      exponentBits == 0 ? fraction : fraction | (BigInt.one << 52);
  final exponent2 = exponentBits == 0 ? -1074 : exponentBits - 1075;

  var exponent = _decimalExponent(significand, exponent2);
  var scale = significantDigits - 1 - exponent;
  var rounded = _roundScaled(significand, exponent2, scale);
  var tie = _isTie(significand, exponent2, scale);
  var text = rounded.toString();
  if (text.length > significantDigits) {
    exponent++;
    scale = significantDigits - 1 - exponent;
    rounded = _roundScaled(significand, exponent2, scale);
    tie = _isTie(significand, exponent2, scale);
    text = rounded.toString();
  }
  return (
    digits: text.padLeft(significantDigits, '0'),
    exponent: exponent,
    tie: tie,
  );
}

/// `significand * 2^exponent2 * 10^scale`, as an exact fraction.
(BigInt, BigInt) _scaled(BigInt significand, int exponent2, int scale) {
  var numerator = significand;
  var denominator = BigInt.one;
  if (exponent2 >= 0) {
    numerator <<= exponent2;
  } else {
    denominator <<= -exponent2;
  }
  final ten = BigInt.from(10);
  if (scale >= 0) {
    numerator *= ten.pow(scale);
  } else {
    denominator *= ten.pow(-scale);
  }
  return (numerator, denominator);
}

BigInt _roundScaled(BigInt significand, int exponent2, int scale) {
  final (numerator, denominator) = _scaled(significand, exponent2, scale);
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator);
  final comparison = (remainder << 1).compareTo(denominator);
  if (comparison > 0 || (comparison == 0 && quotient.isOdd)) {
    return quotient + BigInt.one;
  }
  return quotient;
}

bool _isTie(BigInt significand, int exponent2, int scale) {
  final (numerator, denominator) = _scaled(significand, exponent2, scale);
  return (numerator.remainder(denominator) << 1) == denominator;
}

int _decimalExponent(BigInt significand, int exponent2) {
  var candidate =
      ((significand.bitLength - 1 + exponent2) * 0.3010299956639812).floor();
  int compare(int exponent10) {
    final (numerator, denominator) = _scaled(
      significand,
      exponent2,
      -exponent10,
    );
    return numerator.compareTo(denominator);
  }

  while (compare(candidate) < 0) {
    candidate--;
  }
  while (compare(candidate + 1) >= 0) {
    candidate++;
  }
  return candidate;
}
