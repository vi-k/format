/// Shared IR-vs-legacy parity harness.
///
/// Deliberately NOT named `*_test.dart`: the runner must not pick this file
/// up as a suite, it only carries the engines and the comparison helpers that
/// `template_ir_diff_test.dart` and `template_ir_fuzz_test.dart` share.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

/// A deliberately non-default locale, modeled on `_PrintfNumberLocale` in
/// test/sprintf_double_test.dart: every symbol and every digit differs from
/// `CNumberLocale`, so any hot op that skipped localization would show up
/// immediately in the parity comparison.
final class IrTestNumberLocale implements NumberLocale {
  const IrTestNumberLocale();

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
final localeFormat = Format(numberLocale: const IrTestNumberLocale());
final shortSpellingFormat = Format(
  doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
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
