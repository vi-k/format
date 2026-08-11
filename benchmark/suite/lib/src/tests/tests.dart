import 'widest_int.dart';

final class BenchmarkScenario {
  final String? brace;
  final String? sprintf;
  final bool skipSprintf70;
  final bool skipFormat16;
  final List<(List<Object?>, String)> cases;

  const BenchmarkScenario({
    required this.brace,
    required this.sprintf,
    this.skipSprintf70 = false,
    this.skipFormat16 = false,
    required this.cases,
  });
}

final benchmarkScenarios = _scenarios();

/// Refuses a build whose widest-integer constants do not match the platform
/// it ended up running on.
///
/// `widest_int.dart` picks between two files at compile time, and one way of
/// getting that wrong is loud — dart2js will not compile a 64-bit literal —
/// while the other is silent: dart2wasm has real 64-bit integers, so handing
/// it the web constants would still run, still print, and quietly measure
/// narrower numbers than the platform can hold. `identical(1, 1.0)` asks at
/// runtime the question the conditional export answers at compile time, so a
/// disagreement between the two means the wrong file was chosen.
void checkWidestInt() {
  if (widestIntIsWeb == identical(1, 1.0)) return;

  throw StateError(
    'Widest-integer constants are '
    '${widestIntIsWeb ? 'the web ones' : '64-bit'}, but this platform\'s int '
    'is ${identical(1, 1.0) ? 'a JavaScript double' : 'a 64-bit integer'}. '
    'The conditional export in widest_int.dart picked the wrong file.',
  );
}

List<BenchmarkScenario> _scenarios() {
  checkWidestInt();

  return [
    BenchmarkScenario(
      brace: '{}',
      sprintf: '%d',
      cases: [
        ([0], '0'),
        ([widestInt], widestIntText),
      ],
    ),
    // The minimum int case deliberately stays on all four runners: on a 64-bit
    // int sprintf7 prints a double minus ("--9223372036854775808"), and the
    // benchmark shows that ERROR so users can see the competitor's incorrect
    // output. Under dart2js the narrowest int is -(2^53-1), which negates
    // without overflowing, so there the competitor is right and no ERROR
    // appears — a difference in what the platform holds, not a change here.
    BenchmarkScenario(
      brace: '{:d}',
      sprintf: '%d',
      cases: [
        ([widestInt], widestIntText),
        ([-12345], '-12345'),
        ([narrowestInt], narrowestIntText),
      ],
    ),
    BenchmarkScenario(
      brace: '{:10d}',
      sprintf: '%10d',
      cases: [
        ([1], '         1'),
        ([widestInt], widestIntText),
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
    // Pub 1.6 produces the same output, so its runner stays on.
    BenchmarkScenario(
      brace: '{:010,d}',
      sprintf: null,
      cases: [
        ([1234], '00,001,234'),
      ],
    ),
    // Oracle: sprintf 7.0 throws "Unknown format type c" for %c, while
    // format3's own printf engine supports it and agrees ("A").
    BenchmarkScenario(
      brace: '{:c}',
      sprintf: '%c',
      skipSprintf70: true,
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
    // unpadded exponent ("1.23456789e+4") in both syntaxes, while pub 1.6
    // and sprintf7 both default to a fixed 6-digit mantissa with sprintf7
    // also zero-padding the exponent ("1.234568e+4" / "1.234568e+04").
    // This is a systematic default policy difference (confirmed by
    // brute-force search: no replacement value makes the engines agree),
    // so the competitors are skipped, leaving format3's own output as the
    // expected value.
    BenchmarkScenario(
      brace: '{:e}',
      sprintf: '%e',
      skipSprintf70: true,
      skipFormat16: true,
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
    // Oracle: the 1.6 format spec regex has no '%' presentation type, so
    // '{:%}' fails to match and is left untouched ("{:%}" literal) instead
    // of being formatted, so 1.6 is skipped.
    BenchmarkScenario(
      brace: '{:%}',
      sprintf: null,
      skipFormat16: true,
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
}

/// The templates the cold phase measures.
///
/// A deliberately small set: the cold phase runs every engine over each of
/// these, so the cost is four measurements per case, and the point is to
/// separate shapes of parsing work rather than to repeat the whole matrix.
/// A field on its own, a field with a specification, a double, several
/// fields, and a template that is mostly literal text — enough to tell "the
/// parser walks the template" apart from "the parser handles a field".
final coldScenarios = _coldScenarios();

List<BenchmarkScenario> _coldScenarios() {
  checkWidestInt();

  return [
    BenchmarkScenario(
      brace: '{}',
      sprintf: '%d',
      cases: [
        ([42], '42'),
      ],
    ),
    BenchmarkScenario(
      brace: '{:10d}',
      sprintf: '%10d',
      cases: [
        ([12345], '     12345'),
      ],
    ),
    BenchmarkScenario(
      brace: '{:.2f}',
      sprintf: '%.2f',
      cases: [
        ([0.1], '0.10'),
      ],
    ),
    BenchmarkScenario(
      brace: '{}|{}|{}',
      sprintf: '%d|%d|%d',
      cases: [
        ([1, 2, 3], '1|2|3'),
      ],
    ),
    BenchmarkScenario(
      brace: 'a mostly literal template with one {} in it',
      sprintf: 'a mostly literal template with one %d in it',
      cases: [
        ([7], 'a mostly literal template with one 7 in it'),
      ],
    ),
  ];
}
