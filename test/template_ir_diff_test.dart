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
  if (irError is FormattingException &&
      legacyError is FormattingException) {
    expect(irError.toString(), legacyError.toString(), reason: template);
  }
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
      '{:d}', '{:10d}', '{:<10d}', '{:>10d}', '{:^10d}', '{:=10d}',
      '{:010d}', '{:+d}', '{: d}', '{:-d}', '{:*<8d}', '{:x}', '{:X}',
      '{:#x}', '{:#X}', '{:o}', '{:#o}', '{:b}', '{:#b}', '{:#010x}',
      '{:1d}',
    ];
    final values = <Object?>[
      0, 1, -1, 42, -42, 9007199254740991, -9007199254740991,
      BigInt.parse('-340282366920938463463374607431768211456'),
      BigInt.zero,
      'not a number', 3.5, null,
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
      '{:s}', '{:10s}', '{:<10s}', '{:>10s}', '{:^10s}', '{:.3s}',
      '{:10.3s}', '{:*^10s}', '{:.0s}', '{:2s}',
    ];
    final values = <Object?>[
      'hello', '', 'ab', 'ééé', '\u{1F600}\u{1F600}',
      'exactly10!', 42, null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
      }
    }
  });
}
