import 'package:format/src/engine.dart';
import 'package:test/test.dart';

final graphemeFormat = Format(textUnit: TextUnit.graphemeClusters);

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
