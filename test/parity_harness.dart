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
  String? label,
}) {
  final where = label == null ? template : '$template [$label]';
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
  expect(ir, legacy, reason: where);
  expect(irError.runtimeType, legacyError.runtimeType, reason: '$where errors');
  if (irError is FormattingException && legacyError is FormattingException) {
    expect(
      describeErrorPayload(irError),
      describeErrorPayload(legacyError),
      reason: '$where payload',
    );
    expectContextParity(irError.context, legacyError.context, where);
  }
}

void expectPrintfParity(
  String template,
  List<Object?> values, {
  Format? engine,
  String? label,
}) {
  final where = label == null ? template : '$template [$label]';
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
  expect(ir, legacy, reason: where);
  expect(irError.runtimeType, legacyError.runtimeType, reason: '$where errors');
  if (irError is FormattingException && legacyError is FormattingException) {
    expect(
      describeErrorPayload(irError),
      describeErrorPayload(legacyError),
      reason: '$where payload',
    );
    expectContextParity(irError.context, legacyError.context, where);
  }
}

/// Renders the type-specific payload of a [FormattingException].
///
/// FormattingException overrides no toString(), so comparing `toString()`
/// between the two paths restated the runtimeType check and nothing else:
/// two rejections of the same type with different reasons, keys or values
/// were indistinguishable. This switch is exhaustive over the sealed
/// hierarchy and deliberately has NO default arm, so a new subclass in
/// lib/src/errors.dart breaks compilation here instead of silently dropping
/// out of the parity comparison.
String describeErrorPayload(FormattingException error) => switch (error) {
  InvalidFormatException(:final reason) => 'invalidFormat($reason)',
  InvalidSpecifierException(:final reason) => 'invalidSpecifier($reason)',
  MissingFormatArgumentException(:final key) =>
    'missingArgument(${_describeValue(key)})',
  FormatLookupException(:final segment, :final value) =>
    'lookup(${_describeValue(segment)}, ${_describeValue(value)})',
  UnsupportedConversionException(:final value) =>
    'unsupportedConversion(${_describeValue(value)})',
  UnsupportedFormatValueException(:final value) =>
    'unsupportedValue(${_describeValue(value)})',
  FormatConfigurationException(:final reason, :final name) =>
    'configuration($reason, name: $name)',
  AmbiguousFormatterException(:final value, :final matches) =>
    'ambiguous(${_describeValue(value)}, $matches)',
  // Name only: the wrapped error and its stack trace come from user code and
  // carry no guarantee of being identical (or even stable) between paths.
  FormatExtensionException(:final extension) => 'extension($extension)',
};

/// Describes a value carried inside an exception payload.
///
/// The type is part of the description because `'1'` and `1` are different
/// rejections that stringify the same. `toString()` of an arbitrary value can
/// itself throw (the representation path guards exactly that), and a payload
/// comparison must never turn a parity check into that failure.
String _describeValue(Object? value) {
  if (value == null) return 'null';
  try {
    return '${value.runtimeType}:$value';
  } on Object catch (_) {
    return '${value.runtimeType}:<toString threw>';
  }
}

/// Compares every FormatExceptionContext field between the IR and legacy
/// paths. These fields, together with the per-type payload above, are what
/// error consumers actually read.
void expectContextParity(
  FormatExceptionContext ir,
  FormatExceptionContext legacy,
  String where,
) {
  expect(ir.template, legacy.template, reason: '$where context.template');
  expect(ir.offset, legacy.offset, reason: '$where context.offset');
  expect(ir.fragment, legacy.fragment, reason: '$where context.fragment');
  expect(ir.specifier, legacy.specifier, reason: '$where context.specifier');
  expect(ir.conversion, legacy.conversion, reason: '$where context.conversion');
  expect(
    ir.argumentIndex,
    legacy.argumentIndex,
    reason: '$where context.argumentIndex',
  );
}
