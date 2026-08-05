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

void main() {
  setUp(debugClearTemplateCaches);

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

  test('dynamic value op keeps missing-argument errors', () {
    expectBraceParity('{} {}', positional: ['only one']);
    expectBraceParity('{name}', named: {});
  });

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
      // The '%' suffix rides inside applyNumericWidth's digits, so pad it
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

  test('oversized double precision keeps the legacy error', () {
    expectBraceParity('{:.100001f}', positional: [2.5]);
    expectBraceParity(
      '{:.100001f}',
      positional: [2.5],
      engine: compatibleFormat,
    );
  });

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

  test('printf doubles keep parity for graphemes and missing args', () {
    expectPrintfParity('%10.2f', [2.5], engine: graphemeFormat);
    expectPrintfParity('%f', const []);
    expectPrintfParity('%*.2f', const []);
  });

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
