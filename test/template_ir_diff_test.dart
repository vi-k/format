import 'package:format/src/engine.dart';
import 'package:test/test.dart';

/// A deliberately non-default locale, modeled on `_PrintfNumberLocale` in
/// test/sprintf_double_test.dart: every symbol and every digit differs from
/// `CNumberLocale`, so any hot op that skipped localization would show up
/// immediately in the parity comparison.
final class _IrTestNumberLocale implements NumberLocale {
  const _IrTestNumberLocale();

  @override
  String get decimalSeparator => ',';

  @override
  String get exponentSeparator => '×10^';

  @override
  String get groupSeparator => '.';

  @override
  List<int> get grouping => const [3];

  @override
  bool get groupingEnabled => true;

  @override
  String get minusSign => '−';

  @override
  String get plusSign => '＋';

  @override
  String localizeDigits(String asciiDigits) => asciiDigits
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');
}

final graphemeFormat = Format(textUnit: TextUnit.graphemeClusters);
final compatibleFormat = Format(doubleFormatMode: DoubleFormatMode.compatible);
final compatibleGraphemes = Format(
  doubleFormatMode: DoubleFormatMode.compatible,
  textUnit: TextUnit.graphemeClusters,
);

void expectBraceParity(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
  Format? engine,
}) {
  final format = engine ?? defaultFormat;
  Object? irError;
  String? ir;
  try {
    ir = format.formatWith(template, positional: positional, named: named);
  } on FormattingException catch (error) {
    irError = error;
  }
  Object? legacyError;
  String? legacy;
  try {
    legacy = debugFormatBraceWithoutIr(
      template,
      format,
      positional: positional,
      named: named,
    );
  } on FormattingException catch (error) {
    legacyError = error;
  }
  expect(ir, legacy, reason: template);
  expect(
    irError.runtimeType,
    legacyError.runtimeType,
    reason: '$template errors',
  );
  if (irError is FormattingException && legacyError is FormattingException) {
    expect(irError.toString(), legacyError.toString(), reason: template);
    expectContextParity(irError.context, legacyError.context, template);
  }
}

void expectPrintfParity(
  String template,
  List<Object?> values, {
  Format? engine,
}) {
  final format = engine ?? defaultFormat;
  Object? irError;
  String? ir;
  try {
    ir = format.vsprintf(template, values);
  } on FormattingException catch (error) {
    irError = error;
  }
  Object? legacyError;
  String? legacy;
  try {
    legacy = debugFormatPrintfWithoutIr(template, format, values);
  } on FormattingException catch (error) {
    legacyError = error;
  }
  expect(ir, legacy, reason: template);
  expect(
    irError.runtimeType,
    legacyError.runtimeType,
    reason: '$template errors',
  );
  if (irError is FormattingException && legacyError is FormattingException) {
    expect(irError.toString(), legacyError.toString(), reason: template);
    expectContextParity(irError.context, legacyError.context, template);
  }
}

/// Compares every FormatExceptionContext field between the IR and legacy
/// paths. FormattingException does not override toString(), so without this
/// the toString() comparison above only ever compares runtimeType — it adds
/// nothing on its own. These fields are what error consumers actually read.
void expectContextParity(
  FormatExceptionContext ir,
  FormatExceptionContext legacy,
  String template,
) {
  expect(ir.template, legacy.template, reason: '$template context.template');
  expect(ir.offset, legacy.offset, reason: '$template context.offset');
  expect(ir.fragment, legacy.fragment, reason: '$template context.fragment');
  expect(
    ir.specifier,
    legacy.specifier,
    reason: '$template context.specifier',
  );
  expect(
    ir.conversion,
    legacy.conversion,
    reason: '$template context.conversion',
  );
  expect(
    ir.argumentIndex,
    legacy.argumentIndex,
    reason: '$template context.argumentIndex',
  );
}

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

  test('printf double op falls back to slow path for custom locales', () {
    final locale = Format(numberLocale: const _IrTestNumberLocale());
    for (final template in ['%.2f', '%10.2f', '%e', '%.3g']) {
      for (final value in [2.5, -2.5, double.nan, 1e21]) {
        expectPrintfParity(template, [value], engine: locale);
      }
    }
    // Dynamic options too: the slow branch has to rebuild the resolved
    // conversion by hand, folding a runtime-negative width into the left
    // flag and passing the width on as a magnitude, exactly as
    // _PrintfProcessor._resolve does before calling the same tail.
    for (final width in [12, -12]) {
      expectPrintfParity('%*.2f', [width, 2.5], engine: locale);
      expectPrintfParity('%0*.2f', [width, -2.5], engine: locale);
      expectPrintfParity('%*e', [width, 12.0], engine: locale);
    }
    expectPrintfParity('%.*f', [-1, 2.5], engine: locale);
    expectPrintfParity('%*.*f', [-14, 3, -2.5], engine: locale);
    expectPrintfParity('%*.2f', [100001, 2.5], engine: locale);
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
    expectPrintfParity(
      '[%s] %05.1f%% (%d of %d, %#x) %-8s|',
      ['run', 99.95, 3, 10, 255, 'ok'],
    );
    expectPrintfParity('%0*d/%.*s/%%', [6, 42, 2, 'abcdef']);
  });

  test('cache clearing does not change IR results', () {
    final before = format('{:10d}|{:<6s}', 42, 'ab');
    debugClearTemplateCaches();
    expect(format('{:10d}|{:<6s}', 42, 'ab'), before);
  });
}
