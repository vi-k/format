/// The hand-written half of the IR parity suite: every specification the
/// compiler specializes, run through both paths and compared.
///
/// `template_ir_compile_test.dart` checks that a specification compiles to the
/// op it should. This file checks that the op then *behaves* like the path it
/// replaced — output, exception type, payload and offset alike (see
/// `parity_harness.dart` for what parity means here). Between them, a hot op
/// cannot go wrong silently: either it stops being selected, or it stops
/// agreeing.
///
/// The tests are matrices rather than cases, because the interesting failures
/// live in combinations. A hot op is written once and then has to hold for
/// every value that can reach it — both integer types, both signs, zero, the
/// special doubles, values of the wrong type entirely — under every layout the
/// option grammar allows, and under every engine configuration the op is meant
/// to respect. Multiplying those axes is affordable precisely because the
/// expectations come from the oracle rather than from an author.
///
/// A few matrices are large on purpose: grouped integer layouts, grouped double
/// layouts and locale-aware `n` each run into the hundreds of thousands of
/// comparisons. Those are the three areas where the hot ops reimplement
/// arithmetic the legacy path derives some other way — fitted padding by
/// formula instead of bisection, localization inline instead of as a tail — and
/// so the three where a hand-written matrix would be least likely to find the
/// disagreement.
///
/// The values of the wrong type in each matrix are not padding. A hot op must
/// reject what it cannot format with the same complaint the general path makes,
/// and that is the easiest part of the contract to forget when writing a
/// specialization.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

import 'parity_harness.dart';

/// Values that reach the double pipeline through every non-finite and
/// signed-zero branch, plus the exponent threshold where the dartSdk mode
/// switches representation. Precision validation must fire for all of them
/// alike, so they are the value axis of the rejection matrices below.
const _specialDoubles = <Object?>[
  2.5,
  -2.5,
  0.0,
  -0.0,
  double.nan,
  double.infinity,
  double.negativeInfinity,
  1e21,
];

/// The extreme integers of whatever platform is running, built by parsing
/// rather than written down.
///
/// `-9223372036854775808` is not a literal dart2js will compile, so the
/// matrices below used to stop at the web-safe extremes and the platforms with
/// wider integers — the VM and dart2wasm — were never asked about their own.
/// That gap hid a real defect: under dart2wasm the minimum int printed
/// `--9223372036854775808`, because the web branch of `CharSink` negated
/// before converting and the minimum has no positive counterpart.
///
/// Parsing sidesteps the literal on every backend. What the digits resolve to
/// differs — dart2js rounds the maximum to 2^63 — and that does not matter
/// here: parity asks whether the two paths agree about a value, not which
/// value it is.
final _platformMinInt = int.parse('-9223372036854775808');
final _platformMaxInt = int.parse('9223372036854775807');

void main() {
  setUp(debugClearTemplateCaches);

  // The `dynamic` op dispatches on the runtime type, so the matrix is a type
  // census: both integer kinds, strings, booleans, null, doubles including
  // negative zero and NaN, and an arbitrary object that reaches the `toString`
  // fallback. A type the op forgot would format through a different branch than
  // the legacy path and show up here.
  test('dynamic value op matches the legacy path per runtime type', () {
    for (final value in <Object?>[
      'text',
      '',
      'é',
      42,
      -42,
      0,
      9007199254740991,
      BigInt.parse('123456789012345678901234567890'),
      true,
      false,
      null,
      3.5,
      -0.0,
      double.nan,
      const Duration(seconds: 1),
    ]) {
      expectBraceParity('<{}>', positional: [value]);
      expectBraceParity('<{}>', positional: [value], engine: graphemeFormat);
    }
  });

  // A bare `{}` on a double picks its notation by threshold, and the thresholds
  // differ between the two profiles — so the same values are compared under
  // both rather than under the default alone.
  test('empty-spec doubles stay identical across modes', () {
    for (final value in <double>[
      // Spelled as double literals: the signed zero pair is the point of
      // these two rows, so they stay readable instead of int-literal short.
      // ignore: prefer_int_literals
      0.0,
      // ignore: prefer_int_literals
      -0.0,
      0.1,
      2.5,
      3.14159,
      1e21,
      1e-7,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expectBraceParity('<{}>', positional: [value]);
      expectBraceParity('<{}>', positional: [value], engine: compatibleFormat);
    }
  });

  // The special values under the third configuration axis: how they are spelled
  // is engine state, not a property of the op, and an op that hard-coded one
  // spelling would still match on a default engine.
  test('empty-spec specials keep parity for short spelling', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expectBraceParity(
        '<{}>',
        positional: [value],
        engine: shortSpellingFormat,
      );
    }
  });

  // The op has to fail before it looks at a value, and with the same complaint:
  // a missing argument is not something a specialization gets to report
  // differently.
  test('dynamic value op keeps missing-argument errors', () {
    expectBraceParity('{} {}', positional: ['only one']);
    expectBraceParity('{name}', named: {});
  });

  // Twenty-one integer layouts against twelve values, in both text units. The
  // layouts cover every alignment, both padding modes, all three sign flags,
  // every radix with and without the alternate prefix; the values cover both
  // integer types, both signs, zero, the exact-double boundary, a `BigInt` far
  // past any of it — and three values that are not integers at all.
  test('int op matches the legacy path across specs and values', () {
    const specs = [
      '{:d}',
      '{:10d}',
      '{:<10d}',
      '{:>10d}',
      '{:^10d}',
      '{:=10d}',
      '{:010d}',
      '{:+d}',
      '{: d}',
      '{:-d}',
      '{:*<8d}',
      '{:x}',
      '{:X}',
      '{:#x}',
      '{:#X}',
      '{:o}',
      '{:#o}',
      '{:b}',
      '{:#b}',
      '{:#010x}',
      '{:1d}',
    ];
    final values = <Object?>[
      0,
      1,
      -1,
      42,
      -42,
      9007199254740991,
      -9007199254740991,
      _platformMaxInt,
      _platformMinInt,
      BigInt.parse('-340282366920938463463374607431768211456'),
      BigInt.zero,
      'not a number',
      3.5,
      null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
      }
    }
  });

  // Text layouts against values chosen where the unit choice matters: an empty
  // string, precomposed accents, astral characters, a string exactly at the
  // width, and two non-strings. Run under both text units, since width and
  // precision count differently in each.
  test('text op matches the legacy path across specs and values', () {
    const specs = [
      '{:s}',
      '{:10s}',
      '{:<10s}',
      '{:>10s}',
      '{:^10s}',
      '{:.3s}',
      '{:10.3s}',
      '{:*^10s}',
      '{:.0s}',
      '{:2s}',
    ];
    final values = <Object?>[
      'hello',
      '',
      'ab',
      'ééé',
      '\u{1F600}\u{1F600}',
      'exactly10!',
      42,
      null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
      }
    }
  });

  // The largest of the per-op matrices: every double conversion, with and
  // without a precision, under every alignment and fill, against the values
  // that reach each branch of the pipeline. The percent cases are padded in
  // every direction on purpose — its suffix rides along inside the digits, so
  // padding is where it would be lost or misplaced.
  test('double op matches the legacy path across specs and values', () {
    const specs = [
      '{:f}',
      '{:.0f}',
      '{:.2f}',
      '{:10.2f}',
      '{:<10.2f}',
      '{:^10.2f}',
      '{:=10.2f}',
      '{:010.2f}',
      '{:+.2f}',
      '{: .2f}',
      '{:z.1f}',
      '{:#.0f}',
      '{:e}',
      '{:.3e}',
      '{:E}',
      '{:g}',
      '{:.3g}',
      '{:G}',
      '{:.1%}',
      // The '%' suffix rides inside _applyNumericWidth's digits, so pad it
      // in every direction; a non-space fill exercises fillChar.
      '{:010.1%}',
      '{:<10.1%}',
      '{:*>10.2f}',
      '{:*=10.2f}',
      '{:+010.2f}',
      '{:.3}',
      '{:10.3}',
      '{:>10}',
      '{:F}',
      '{:.25f}',
    ];
    final values = <Object?>[
      0.0,
      -0.0,
      0.1,
      2.5,
      -2.5,
      12345678901234.568,
      1e21,
      1e-7,
      double.minPositive,
      double.maxFinite,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      42,
      -7,
      BigInt.parse('123456789012345678901234567890'),
      'text',
      true,
      null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
        expectBraceParity(spec, positional: [value], engine: compatibleFormat);
        expectBraceParity(
          spec,
          positional: [value],
          engine: compatibleGraphemes,
        );
      }
    }
  });

  // A precision past the ceiling stays on the general path, and the refusal
  // must be identical there — the compiler declining a specification is not a
  // licence to fail differently.
  test('oversized double precision keeps the legacy error', () {
    expectBraceParity('{:.100001f}', positional: [2.5]);
    expectBraceParity(
      '{:.100001f}',
      positional: [2.5],
      engine: compatibleFormat,
    );
  });

  // The precision range the SDK imposes, at every boundary of both shapes —
  // and the note below is why this test is long: two conversions do not follow
  // the shape their syntax suggests. Every value in `_specialDoubles` is run
  // through, because the rejection must fire before the value is looked at.
  test('brace dartSdk precision rejection keeps parity', () {
    // dartSdk rejects precision outside [0,20] for f/F/e/E and outside
    // [1,21] for g/G/n. The two remaining presentations split: the empty
    // conversion is g-shaped ([1,21]) while '%' is f-shaped ([0,20]) — see
    // _validateDartDoublePrecision in lib/src/dart_double_format.dart, where
    // `general` covers null/g/G/n only. Both shapes are pinned at both of
    // their boundaries below.
    const specs = [
      '{:.21f}',
      '{:.25f}',
      '{:.21e}',
      '{:.0g}', // g: min 1 -> rejected
      '{:.22g}',
      '{:.0}', // no conversion: still g-shaped validation
      '{:.22}',
      '{:.21%}', // %: f-shaped max 20 -> rejected (g-shaped would accept)
      '{:.25%}',
      // Accepted boundaries, which must NOT throw.
      '{:.20f}',
      '{:.21g}',
      '{:.1}',
      '{:.21}',
      '{:.0%}', // %: f-shaped min 0 -> accepted (g-shaped would reject)
      '{:.20%}',
    ];
    for (final spec in specs) {
      for (final value in _specialDoubles) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: compatibleFormat);
      }
    }
  });

  // A locale where every symbol and digit differs from the default, applied to
  // conversions that must *ignore* it and to `n`, which must not. Both halves
  // matter: an op that localized `%f` would be as wrong as one that failed to
  // localize `n`.
  test('brace doubles keep parity under a custom locale', () {
    for (final spec in [
      // f/e/g/% stay ASCII in the brace dialect (only 'n' consults the
      // locale), so these pin that the hot ops keep ignoring it exactly as
      // the legacy tail does.
      '{:.2f}',
      '{:10.2f}',
      '{:e}',
      '{:.3g}',
      '{:.1%}',
      // 'n' is deliberately absent from the hot double op, so these rows
      // pin the localized fallback: digits, separators, and signs all come
      // from the custom locale.
      '{:n}',
      '{:.3n}',
      '{:+012n}',
    ]) {
      for (final value in <Object?>[2.5, -2.5, double.nan, 1e21]) {
        expectBraceParity(spec, positional: [value], engine: localeFormat);
      }
    }
  });

  // Two edges the matrices cannot reach: a negative value that becomes zero
  // only after rounding, and a `BigInt` whose conversion to double overflows.
  // Both are branch selectors rather than layout cases.
  test('double edge values keep parity', () {
    // Negative value that rounds to zero: exercises the z-flag suppression
    // through roundedZero, not the trivial -0.0 route.
    expectBraceParity('{:z.1f}', positional: [-0.04]);
    expectBraceParity('{:z.1f}', positional: [-0.04], engine: compatibleFormat);
    // BigInt whose toDouble() overflows to infinity: the typed branch must
    // throw like legacy, before any precision validation.
    final huge = BigInt.two.pow(2000);
    expectBraceParity('{:.2f}', positional: [huge]);
    expectBraceParity('{:.2f}', positional: [-huge]);
  });

  // The printf string op across its layouts, with non-string values included:
  // `%s` accepts anything, so the conversion to text is part of what has to
  // match.
  test('%s op matches the legacy path', () {
    const templates = ['%s', '%10s', '%-10s', '%.3s', '%10.3s', '%-10.3s'];
    final values = <Object?>['hello', '', 'éé', 42, null, 3.5, true];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: graphemeFormat);
      }
    }
    // Dynamic options, including negative width and negative precision.
    for (final width in [0, 3, 12, -12, 100001]) {
      expectPrintfParity('%*s', [width, 'dyn']);
    }
    for (final precision in [0, 2, -1, 100001]) {
      expectPrintfParity('%.*s', [precision, 'dyn']);
    }
    expectPrintfParity('%*.*s', [8, 2, 'dynamic']);
    expectPrintfParity('%*s', ['not int', 'dyn']);
    expectPrintfParity('%s', []);
    // A throwing toString() must surface as the same FormatExtensionException
    // (with the cause kept) on both paths.
    expectPrintfParity('%s', [_ThrowingToString()]);
    expectPrintfParity('%10.3s', [_ThrowingToString()]);
  });

  // The printf integer matrix. Wider than the brace one because printf has
  // flags the brace grammar has no equivalent for — repeated flags, integer
  // precision, dynamic width — each of which the hot op resolves itself.
  test('printf int op matches the legacy path', () {
    const templates = [
      '%d',
      '%i',
      '%10d',
      '%-10d',
      '%010d',
      '%+d',
      '% d',
      '%+010d',
      '%u',
      '%o',
      '%#o',
      '%x',
      '%#x',
      '%X',
      '%#X',
      '%.5d',
      '%10.5d',
      '%-10.5d',
      '%.0d',
      '%#.0o',
      '%#o',
      '%08x',
    ];
    final values = <Object?>[
      0,
      1,
      -1,
      42,
      -42,
      9007199254740991,
      -9007199254740991,
      _platformMaxInt,
      _platformMinInt,
      BigInt.parse('123456789012345678901234567890'),
      BigInt.parse('-123456789012345678901234567890'),
      'nope',
      3.5,
      null,
    ];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
      }
    }
    for (final width in [0, 5, -5, 100001]) {
      expectPrintfParity('%*d', [width, 42]);
      expectPrintfParity('%0*d', [width, 42]);
    }
    for (final precision in [0, 5, -1, 100001]) {
      expectPrintfParity('%.*d', [precision, 42]);
    }
    expectPrintfParity('%*.*d', [10, 4, -42]);
  });

  // The printf double matrix, with the same value axis as the brace one so the
  // two dialects can be compared against each other as well as against the
  // oracle.
  test('printf double op matches the legacy path', () {
    const templates = [
      '%f',
      '%.0f',
      '%.2f',
      '%10.2f',
      '%-10.2f',
      '%010.2f',
      '%+.2f',
      '% .2f',
      '%#.0f',
      '%e',
      '%.3e',
      '%E',
      '%g',
      '%.3g',
      '%G',
      '%F',
    ];
    final values = <Object?>[
      0.0,
      -0.0,
      0.1,
      2.5,
      -2.5,
      12345678901234.568,
      1e21,
      1e-7,
      double.maxFinite,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      42,
      'text',
      null,
    ];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: compatibleFormat);
      }
    }
    for (final width in [0, 8, -8, 100001]) {
      expectPrintfParity('%*.2f', [width, 2.5]);
    }
    for (final precision in [0, 3, -1, 100001]) {
      expectPrintfParity('%.*f', [precision, 2.5]);
    }
    expectPrintfParity('%*.*f', [12, 3, -2.5]);
  });

  // Two axes the double matrix above holds constant: the text unit, which
  // affects padding, and a missing argument, which must fail before any of the
  // layout runs.
  test('printf doubles keep parity for graphemes and missing args', () {
    expectPrintfParity('%10.2f', [2.5], engine: graphemeFormat);
    expectPrintfParity('%f', const []);
    expectPrintfParity('%*.2f', const []);
  });

  // The SDK precision range in the printf dialect, where it is enforced by
  // separate code and so can regress separately.
  test('printf static precision rejected by dartSdk keeps parity', () {
    const templates = [
      '%.21f', // f: max 20 -> rejected
      '%.25f',
      '%.30F',
      '%.21e',
      '%.99E',
      '%.0g', // g: min 1 -> rejected
      '%.22g',
      '%.0G',
      '%.22G',
      // Accepted boundaries, which must NOT throw.
      '%.20f',
      '%.20e',
      '%.1g',
      '%.21g',
      '%.0f',
    ];
    for (final template in templates) {
      for (final value in _specialDoubles) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: compatibleFormat);
      }
    }
    // Width in front of a rejected precision: validation must still win over
    // padding, so the baked static conversion cannot short-circuit it.
    for (final template in ['%10.25f', '%-10.0g', '%010.22G', '%+.21e']) {
      for (final value in _specialDoubles) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: compatibleFormat);
      }
    }
  });

  // And the same range when the precision arrives as an argument rather than
  // in the template — a different code path to the same refusal.
  test('printf dynamic precision rejected by dartSdk keeps parity', () {
    // Precisions the option resolver accepts (it only rejects values past the
    // 100000 guard), so rejection has to happen inside the double conversion.
    const precisions = [-1, 0, 1, 20, 21, 22, 25, 99];
    for (final precision in precisions) {
      for (final value in _specialDoubles) {
        expectPrintfParity('%.*f', [precision, value]);
        expectPrintfParity('%.*e', [precision, value]);
        expectPrintfParity('%.*g', [precision, value]);
        expectPrintfParity('%.*G', [precision, value]);
        expectPrintfParity('%.*f', [
          precision,
          value,
        ], engine: compatibleFormat);
        expectPrintfParity('%.*g', [
          precision,
          value,
        ], engine: compatibleFormat);
      }
      expectPrintfParity('%*.*f', [12, precision, 2.5]);
      expectPrintfParity('%*.*g', [-12, precision, 2.5]);
    }
  });

  // Where the printf double op declines and hands over. The hand-over is the
  // risk: the slow branch has to reconstruct the resolved conversion from the
  // op's own state, and a dynamic width that was negative at runtime has to
  // become a left-alignment flag plus a magnitude on the way. Both signs, both
  // dynamic positions and an over-ceiling width are compared.
  test('printf double op falls back to slow path for custom locales', () {
    for (final template in ['%.2f', '%10.2f', '%e', '%.3g']) {
      for (final value in [2.5, -2.5, double.nan, 1e21]) {
        expectPrintfParity(template, [value], engine: localeFormat);
      }
    }
    // Dynamic options too: the slow branch has to rebuild the resolved
    // conversion by hand, folding a runtime-negative width into the left
    // flag and passing the width on as a magnitude, exactly as
    // _PrintfProcessor._resolve does before calling the same tail.
    for (final width in [12, -12]) {
      expectPrintfParity('%*.2f', [width, 2.5], engine: localeFormat);
      expectPrintfParity('%0*.2f', [width, -2.5], engine: localeFormat);
      expectPrintfParity('%*e', [width, 12.0], engine: localeFormat);
    }
    expectPrintfParity('%.*f', [-1, 2.5], engine: localeFormat);
    expectPrintfParity('%*.*f', [-14, 3, -2.5], engine: localeFormat);
    expectPrintfParity('%*.2f', [100001, 2.5], engine: localeFormat);
  });

  // The same hand-over on the integer side, which the op gained when printf
  // integers started reading the locale (L18). It is the riskier of the two:
  // the int op writes digits straight into the sink as ASCII, so *everything*
  // it produces — sign, digits, and the zero padding around them — has to come
  // from the legacy tail instead, not just a decorated body. All six
  // conversions are walked, since the alternate prefix differs between them
  // and `#` on octal is a digit rather than a marker.
  test('printf integer op falls back to slow path for custom locales', () {
    for (final template in [
      '%d',
      '%i',
      '%u',
      '%o',
      '%#o',
      '%x',
      '%#x',
      '%X',
      '%#X',
      '%+d',
      '% d',
      '%08d',
      '%-8d',
      '%.5d',
      '%.0d',
      '%10.5d',
    ]) {
      for (final value in [0, 42, 7, BigInt.two]) {
        expectPrintfParity(template, [value], engine: localeFormat);
      }
    }
    // Negatives only where the conversion is signed: the unsigned ones reject
    // them, and the rejection is compared separately below.
    for (final template in ['%d', '%i', '%+d', '%08d', '%-8d', '%.5d']) {
      for (final value in [-42, BigInt.from(-7)]) {
        expectPrintfParity(template, [value], engine: localeFormat);
      }
    }
    for (final template in ['%u', '%o', '%x']) {
      expectPrintfParity(template, [-1], engine: localeFormat);
    }
    // Dynamic options, where the slow branch rebuilds the resolved conversion
    // by hand — the same reconstruction the double op does, exercised through
    // the other op.
    for (final width in [12, -12]) {
      expectPrintfParity('%*d', [width, -42], engine: localeFormat);
      expectPrintfParity('%0*d', [width, 42], engine: localeFormat);
      expectPrintfParity('%*.*d', [width, 5, 42], engine: localeFormat);
    }
    expectPrintfParity('%.*d', [-1, 42], engine: localeFormat);
    expectPrintfParity('%*d', [100001, 42], engine: localeFormat);
  });

  // Above the exact-double range in both dialects and every radix. `int.parse`
  // rather than literals so the file still compiles under dart2js, where these
  // values exist but cannot be written down.
  test('integers beyond 2^53 keep legacy digits on every platform', () {
    final values = <Object?>[
      int.parse('9007199254740993'),
      int.parse('-9007199254740993'),
      int.parse('1234567890123456789'),
      int.parse('-1234567890123456789'),
      int.parse('1000000000000000000'),
    ];
    for (final value in values) {
      for (final spec in ['{}', '{:d}', '{:30d}', '{:x}', '{:o}', '{:b}']) {
        expectBraceParity(spec, positional: [value]);
      }
      expectPrintfParity('%d', [value]);
      expectPrintfParity('%20d', [value]);
    }
  });

  // Realistic templates rather than isolated fields: hot and fallback ops in
  // one program, automatic and manual numbering side by side, a field used
  // twice, a nested specification between two automatic ones. A program is a
  // sequence, and the ops share a cursor over the values — this is where a
  // fallback that consumed an argument differently would surface.
  test('mixed templates with hot and fallback ops stay identical', () {
    expectBraceParity(
      'id={:08d} name={:<12s} score={:+.2f} raw={} hex={:#x}',
      positional: [77, 'Ann', 12.5, true, 255],
    );
    expectBraceParity(
      '{0} {1:>6s} {0:d} {value:^9d} {2:.1f}',
      positional: [1, 'x', 2.5],
      named: {'value': 42},
    );
    expectBraceParity(
      'auto {} then {:{}d} then {}',
      positional: [1, 2, 5, 'tail'],
    );
    expectPrintfParity('[%s] %05.1f%% (%d of %d, %#x) %-8s|', [
      'run',
      99.95,
      3,
      10,
      255,
      'ok',
    ]);
    expectPrintfParity('%0*d/%.*s/%%', [6, 42, 2, 'abcdef']);
  });

  // The sole-op shortcut, stated as its own invariant. A template that is one
  // field assembles its padded result as a single string
  // ([CharSink.writePadded]); every other template writes the fill around the
  // body into the accumulator. Both halves are checked against the legacy path
  // elsewhere in this file, but only separately — nothing there requires the
  // two to agree with each other on the same specification. Bracketing is what
  // turns the sole op into three.
  test('a padded field renders the same alone as inside a template', () {
    const cases = <(String, Object?)>[
      ('{:>12.2f}', 12.5),
      ('{:<12.2f}', 12.5),
      ('{:^12.2f}', 12.5),
      ('{:012.2f}', 12.5),
      ('{:>12.2f}', -12.5),
      ('{:*^13.3e}', 1234.5),
      ('{:>12.2%}', 0.125),
      ('{:>14,.2f}', 12345.5),
      ('{:>12.2f}', double.nan),
      ('{:>10s}', 'abc'),
      ('{:<10s}', 'abc'),
      ('{:^10s}', 'abc'),
      ('{:*>10s}', 'ééé'),
      ('{:>4s}', 'exactly8'),
      ('{:>10d}', 42),
    ];
    for (final (spec, value) in cases) {
      for (final engine in [defaultFormat, graphemeFormat]) {
        final alone = engine.format(spec, value);
        expect('[$alone]', engine.format('[$spec]', value), reason: spec);
      }
    }
    const printfCases = <(String, Object?)>[
      ('%10s', 'abc'),
      ('%-10s', 'abc'),
      ('%12.2f', 12.5),
      ('%012.2f', -12.5),
      ('%4s', 'exactly8'),
    ];
    for (final (template, value) in printfCases) {
      final alone = sprintf(template, value);
      expect('[$alone]', sprintf('[$template]', value), reason: template);
    }
  });

  // The exhaustive grouping sweep: both separators, every radix each one
  // allows, eight layout prefixes and five widths, against values on both sides
  // of every group boundary plus a `BigInt` far beyond them. Tens of thousands
  // of comparisons, and the reason they are worth it is in the note below.
  test('grouped integer layouts match the legacy path', () {
    // Grouping and zero padding interact: under '=' with a '0' fill the
    // zeros are grouped with the digits, so the result can end up wider
    // than the width asked for. The legacy path finds that count by
    // bisection and the op computes it; this matrix is where the two are
    // held to the same answer.
    final values = <Object?>[
      0,
      1,
      999,
      1000,
      1234567,
      -1234567,
      9007199254740991,
      -9007199254740991,
      _platformMaxInt,
      _platformMinInt,
    ];
    final wide = BigInt.parse('123456789012345678901234567890');
    for (final separator in [',', '_']) {
      for (final type in separator == ',' ? ['d'] : ['d', 'x', 'X', 'b', 'o']) {
        for (final layout in ['', '0', '=', '0=', '0>', '*^', '+0', ' ']) {
          for (final width in ['', '1', '8', '10', '13']) {
            final template = '{:$layout$width$separator$type}';
            for (final value in values) {
              expectBraceParity(template, positional: [value]);
            }
            expectBraceParity(template, positional: [wide]);
            expectBraceParity(template, positional: [-wide]);
          }
        }
      }
    }
  });

  // The same exhaustive sweep for doubles: every conversion, layout, width and
  // precision that can carry grouping, under both profiles. Grouping applies
  // after rounding and around a decimal point, so the arithmetic is not the
  // integer one with a different constant.
  test('grouped double layouts match the legacy path', () {
    const values = <Object?>[
      0.0,
      -0.0,
      1234.5,
      -1234567.891,
      0.0001,
      1e21,
      double.nan,
      double.infinity,
      42,
    ];
    for (final type in ['', 'f', 'e', 'G', '%']) {
      for (final layout in ['', '0', '=', '0=', '0>', '*^', '+0']) {
        for (final width in ['', '1', '8', '12', '16']) {
          for (final precision in ['', '.0', '.2']) {
            final template = '{:$layout$width,$precision$type}';
            for (final value in values) {
              expectBraceParity(template, positional: [value]);
              expectBraceParity(
                template,
                positional: [value],
                engine: compatibleFormat,
              );
            }
          }
        }
      }
    }
  });

  // `n` under four engines, because the op is compiled once and then has to
  // decide per call — including the case that catches an identity check written
  // too narrowly: a non-const `CNumberLocale()`, which is the default locale by
  // value but not by reference. Values include several the op cannot write at
  // all, which must reach the legacy path rather than be mangled.
  test('locale-aware n matches the legacy path per engine', () {
    // A compiled program is shared by every engine, so the n op decides per
    // call: the C locale writes digits directly, anything else — and any
    // value the op does not write — goes to the legacy path.
    const values = <Object?>[
      0,
      1234567,
      -1234567,
      9007199254740991,
      0.0,
      1234.5,
      -0.0,
      double.nan,
      'text',
      true,
      null,
    ];
    final engines = [
      defaultFormat,
      // ignore: prefer_const_constructors
      Format(numberLocale: CNumberLocale()),
      localeFormat,
      compatibleFormat,
    ];
    final wide = BigInt.parse('123456789012345678901234567890');
    for (final engine in engines) {
      for (final layout in ['', '0', '=', '0=', '*^', '+', '0>']) {
        for (final width in ['', '1', '12']) {
          for (final precision in ['', '.3']) {
            final template = '{:$layout$width$precision n}'.replaceAll(' ', '');
            for (final value in values) {
              expectBraceParity(template, positional: [value], engine: engine);
            }
            expectBraceParity(template, positional: [wide], engine: engine);
          }
        }
      }
    }
  });

  // A compiled program is cached, so this pins that recompiling from scratch
  // gives the same answer — the compilation is a pure function of the template,
  // with no state accumulated on first use.
  test('cache clearing does not change IR results', () {
    final before = format('{:10d}|{:<6s}', 42, 'ab');
    debugClearTemplateCaches();
    expect(format('{:10d}|{:<6s}', 42, 'ab'), before);
  });
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('broken toString');
}
