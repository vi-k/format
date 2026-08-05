final class BenchmarkScenario {
  final String? brace;
  final String? sprintf;
  final bool skipLegacy;
  final bool skipSprintf7;
  final List<(List<Object?>, String)> cases;

  const BenchmarkScenario({
    required this.brace,
    required this.sprintf,
    this.skipLegacy = false,
    this.skipSprintf7 = false,
    required this.cases,
  });
}

final benchmarkScenarios = <BenchmarkScenario>[
  BenchmarkScenario(
    brace: '{}',
    sprintf: '%d',
    cases: [
      ([0], '0'),
      ([9223372036854775807], '9223372036854775807'),
    ],
  ),
  // The minimum int case deliberately stays on all four runners: sprintf7
  // prints a double minus ("--9223372036854775808"), and the benchmark
  // shows that ERROR so users can see the competitor's incorrect output.
  BenchmarkScenario(
    brace: '{:d}',
    sprintf: '%d',
    cases: [
      ([9223372036854775807], '9223372036854775807'),
      ([-12345], '-12345'),
      ([-9223372036854775808], '-9223372036854775808'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:10d}',
    sprintf: '%10d',
    cases: [
      ([1], '         1'),
      ([9223372036854775807], '9223372036854775807'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:010d}',
    sprintf: '%010d',
    cases: [
      ([1], '0000000001'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:+d}',
    sprintf: '%+d',
    cases: [
      ([42], '+42'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:x}',
    sprintf: '%x',
    cases: [
      ([3735928559], 'deadbeef'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:X}',
    sprintf: '%X',
    cases: [
      ([3735928559], 'DEADBEEF'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:#x}',
    sprintf: '%#x',
    cases: [
      ([255], '0xff'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:o}',
    sprintf: '%o',
    cases: [
      ([493], '755'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:b}',
    sprintf: null,
    cases: [
      ([170], '10101010'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:,d}',
    sprintf: null,
    cases: [
      ([1234567], '1,234,567'),
    ],
  ),
  // Zero padding fitted to the grouped width (Python semantics): the
  // regression scenario for the fitRegroupedZeroPadding integer fix.
  // Format 2.0 produces the same output, so the legacy runner stays on.
  BenchmarkScenario(
    brace: '{:010,d}',
    sprintf: null,
    cases: [
      ([1234], '00,001,234'),
    ],
  ),
  // Oracle: sprintf7_baseline throws "Unknown format type c" for %c, while
  // format3's own printf engine supports it and agrees ("A").
  BenchmarkScenario(
    brace: '{:c}',
    sprintf: '%c',
    skipSprintf7: true,
    cases: [
      ([65], 'A'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:.2f}',
    sprintf: '%.2f',
    cases: [
      ([0.1], '0.10'),
      ([12345678901234.56789], '12345678901234.57'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:f}',
    sprintf: '%f',
    cases: [
      ([3.141592653589793], '3.141593'),
    ],
  ),
  // Oracle: with no explicit precision, format3's default DoubleFormatMode
  // (dartSdk) renders 'e' with the shortest round-tripping mantissa and an
  // unpadded exponent ("1.23456789e+4") in both syntaxes, while legacy 2.0
  // and sprintf7 both default to a fixed 6-digit mantissa with sprintf7
  // also zero-padding the exponent ("1.234568e+4" / "1.234568e+04"). This
  // is a systematic default policy difference (confirmed by brute-force
  // search: no replacement value makes all four engines agree), so legacy
  // 2.0 and sprintf7 are skipped, leaving format3's own output as the
  // expected value.
  BenchmarkScenario(
    brace: '{:e}',
    sprintf: '%e',
    skipLegacy: true,
    skipSprintf7: true,
    cases: [
      ([12345.6789], '1.23456789e+4'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:g}',
    sprintf: '%g',
    cases: [
      ([0.00012345], '0.00012345'),
    ],
  ),
  // Oracle: with the original 1234.5678 value, sprintf7 zero-pads the
  // exponent to two digits ("1.23e+03") while the other three engines
  // don't ("1.23e+3"). Replacing the value with one whose exponent already
  // has two digits (1234567890123.0 -> exponent 12) makes the padding
  // moot, so all four engines agree on '1.23e+12'.
  BenchmarkScenario(
    brace: '{:.3g}',
    sprintf: '%.3g',
    cases: [
      ([1234567890123.0], '1.23e+12'),
    ],
  ),
  // Oracle: legacy 2.0's format spec regex has no '%' presentation type, so
  // '{:%}' fails to match and is left untouched ("{:%}" literal) instead of
  // being formatted. Only legacy 2.0 disagrees, so it is skipped.
  BenchmarkScenario(
    brace: '{:%}',
    sprintf: null,
    skipLegacy: true,
    cases: [
      ([0.756], '75.600000%'),
    ],
  ),
  BenchmarkScenario(
    brace: '{}',
    sprintf: '%s',
    cases: [
      (['hello world'], 'hello world'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:s}',
    sprintf: '%s',
    cases: [
      (['hello world'], 'hello world'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:>10s}',
    sprintf: '%10s',
    cases: [
      (['dart'], '      dart'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:<10s}',
    sprintf: '%-10s',
    cases: [
      (['dart'], 'dart      '),
    ],
  ),
  BenchmarkScenario(
    brace: '{:^10s}',
    sprintf: null,
    cases: [
      (['dart'], '   dart   '),
    ],
  ),
  BenchmarkScenario(
    brace: '{:*^10s}',
    sprintf: null,
    cases: [
      (['dart'], '***dart***'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:é^10s}',
    sprintf: null,
    cases: [
      (['dart'], 'ééédartééé'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:d} ' * 10,
    sprintf: '%d ' * 10,
    cases: [
      ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], '1 2 3 4 5 6 7 8 9 10 '),
    ],
  ),
  // Placeholder scaling: migrated from the retired format2 gate benchmark,
  // where 50 auto-numbered placeholders were the widest template measured.
  BenchmarkScenario(
    brace: List.filled(50, '{}').join('|'),
    sprintf: List.filled(50, '%d').join('|'),
    cases: [
      (
        List<Object?>.generate(50, (index) => index),
        List.generate(50, (index) => '$index').join('|'),
      ),
    ],
  ),
];
