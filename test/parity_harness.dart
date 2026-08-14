/// Shared IR-vs-legacy parity harness.
///
/// The compiled IR is an optimization of a path that already worked, so it has
/// an oracle the rest of the suite does not: the legacy processors
/// ([debugFormatBraceWithoutIr], [debugFormatPrintfWithoutIr]), which are kept
/// in the package for exactly this reason. Every specification the IR
/// specializes can be run through both and compared, which is what makes it
/// affordable to check hundreds of thousands of cases — no expectation has to
/// be written by hand, and none can be wrong in the same way the code is.
///
/// Parity is defined here as more than equal strings. Two paths agree only if
/// they produce the same output *or* fail the same way: same exception type,
/// same type-specific payload, and the same [FormatExceptionContext] down to
/// the offset. An IR op that rejected a specification with a different message,
/// or pointed at a different position, would be a regression a
/// string-comparison harness would miss entirely.
///
/// The engines below cover the configuration axes the ops behave differently
/// on — text unit, double profile, special-value spelling, and a number locale
/// where every symbol and digit differs from the default — because a hot op
/// that silently ignored one of them still matches on a default engine.
///
/// Deliberately NOT named `*_test.dart`: the runner must not pick this file
/// up as a suite, it only carries the engines and the comparison helpers that
/// `template_ir_diff_test.dart` and `template_ir_fuzz_test.dart` share.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

/// A deliberately non-default locale, modeled on `_PrintfNumberLocale` in
/// test/sprintf_double_test.dart: every symbol and every digit differs from
/// [CNumberLocale], so any hot op that skipped localization would show up
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

/// A value type the engine knows nothing about.
///
/// Built-in handling takes priority over extensions, so an extension is only
/// ever consulted for a type the package has no branch of its own for: a
/// [Representation] registered for `String` or `int` would never be called,
/// and a fuzzer built on those types would exercise nothing.
final class IrTestPoint {
  final int x;
  final int y;

  const IrTestPoint(this.x, this.y);

  @override
  String toString() => 'IrTestPoint($x, $y)';
}

/// Resolves `{value.x}` on an [IrTestPoint], and explodes on `.boom`.
///
/// The explosion is deliberate: a lookup that throws anything other than a
/// [FormattingException] has it wrapped as [FormatExtensionException] with the
/// template location attached, and that is the only route by which the corpus
/// reaches that payload at all.
final class IrTestPointLookup extends AttributeLookup<IrTestPoint> {
  const IrTestPointLookup();

  @override
  Object? lookup(IrTestPoint value, String attribute) => switch (attribute) {
    'x' => value.x,
    'y' => value.y,
    'boom' => throw StateError('lookup exploded on purpose'),
    // An absent attribute is the lookup's own decision to report. Returning
    // null keeps it a formatting case instead of a second error class, so the
    // corpus still draws values through the ordinary paths behind it.
    _ => null,
  };
}

/// A second lookup accepting the same type as [IrTestPointLookup].
///
/// An engine holding both has no way to choose between them, which is
/// [AmbiguousFormatterException] — the other payload no engine could produce.
final class IrTestPointMirrorLookup extends AttributeLookup<IrTestPoint> {
  const IrTestPointMirrorLookup();

  @override
  Object? lookup(IrTestPoint value, String attribute) => 'mirror:$attribute';
}

/// Gives [IrTestPoint] its own `!r`/`!a` form, so representation conversions
/// reach extension code instead of falling back to `toString()`.
final class IrTestPointRepresentation extends Representation<IrTestPoint> {
  const IrTestPointRepresentation();

  @override
  String represent(IrTestPoint value) => '<${value.x};${value.y}>';
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
final extensionFormat = Format(
  lookups: const [IrTestPointLookup()],
  representations: const [IrTestPointRepresentation()],
);
final ambiguousFormat = Format(
  lookups: const [IrTestPointLookup(), IrTestPointMirrorLookup()],
);

/// Runs one brace template through both paths and requires they agree.
///
/// Both calls are wrapped, because a rejection is as much a result as a string:
/// a case where one path formats and the other throws fails on the output
/// comparison, and a case where both throw is compared by type, payload and
/// context. [label] names the axis a case came from, so a failure in a
/// generated matrix says which combination produced it.
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

/// The printf counterpart of [expectBraceParity], with the same contract.
///
/// Separate rather than shared: the dialects have separate parsers, separate
/// processors and separate legacy paths, so a single generic helper would only
/// hide which of them was being compared.
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
