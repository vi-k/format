import 'package:format/format.dart';
import 'package:sprintf/sprintf.dart' as sprintf70;

// ignore: avoid_relative_lib_imports
import '../packages/format_intl/lib/format_intl.dart';
import 'baselines/format20/format20.dart';
import 'model.dart';

const _braceScalarTemplate = '{:.1s}';

final List<BenchmarkScenario> benchmarkScenarios = List.unmodifiable([
  _braceComparable(
    'brace.literal',
    cold: true,
    template: 'literal {}',
    values: const [42],
    expected: 'literal 42',
  ),
  _braceComparable(
    'brace.parser_heavy',
    template: '{{{0:d}}}',
    values: const [42],
    expected: '{42}',
  ),
  _braceComparable(
    'brace.top_level',
    template: '{:d}',
    values: const [42],
    expected: '42',
    apiPath: BenchmarkApiPath.topLevel,
  ),
  _braceComparable(
    'brace.with',
    template: '{0:d}',
    values: const [42],
    expected: '42',
  ),
  _braceComparable(
    'brace.tear_off',
    template: '{:d}',
    values: const [42],
    expected: '42',
    apiPath: BenchmarkApiPath.tearOff,
  ),
  _braceComparable(
    'brace.fields.1',
    template: '{0:d}',
    values: const [1],
    expected: '1',
  ),
  _braceComparable(
    'brace.fields.5',
    template: '{0:d}{1:d}{2:d}{3:d}{4:d}',
    values: const [1, 2, 3, 4, 5],
    expected: '12345',
  ),
  _braceComparable(
    'brace.fields.10',
    template: '{0:d}{1:d}{2:d}{3:d}{4:d}{5:d}{6:d}{7:d}{8:d}{9:d}',
    values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    expected: '12345678910',
  ),
  _braceComparable(
    'brace.fields.50',
    template: _braceFields(50),
    values: List<Object?>.filled(50, 1),
    expected: '1' * 50,
  ),
  _braceInformation(
    'brace.text.scalars',
    template: _braceScalarTemplate,
    expected: const TextOutcome('e'),
    candidate: (_) => _capture(() => format(_braceScalarTemplate, 'e\u0301')),
  ),
  _braceComparable(
    'brace.text.graphemes_ascii',
    template: '{:.3s}',
    values: const ['abcde'],
    expected: 'abc',
    graphemes: true,
  ),
  _braceComparable(
    'brace.int.default',
    template: '{}',
    values: const [42],
    expected: '42',
    key: true,
  ),
  _braceComparable(
    'brace.int.large_decimal',
    template: '{:d}',
    values: const [9007199254740991],
    expected: '9007199254740991',
    key: true,
  ),
  _braceComparable(
    'brace.bigint.default',
    template: '{}',
    values: [BigInt.parse('9007199254740993')],
    expected: '9007199254740993',
  ),
  _braceComparable(
    'brace.double.fixed.dart',
    template: '{:.2f}',
    values: const [12.5],
    expected: '12.50',
  ),
  _braceComparable(
    'brace.double.fixed.compatible',
    template: '{:.2f}',
    values: const [12.5],
    expected: '12.50',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _braceComparable(
    'brace.double.fixed_large.dart',
    template: '{:.2f}',
    values: const [12345678901234.568],
    expected: '12345678901234.57',
  ),
  _braceComparable(
    'brace.double.fixed_large.compatible',
    template: '{:.2f}',
    values: const [12345678901234.568],
    expected: '12345678901234.57',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _braceInformation(
    'brace.double.half_tie.dart',
    template: '{:.0f}',
    expected: const TextOutcome('3'),
    candidate: (_) => _capture(() => format('{:.0f}', 2.5)),
  ),
  _braceInformation(
    'brace.double.half_tie.compatible',
    template: '{:.0f}',
    expected: const TextOutcome('2'),
    candidate: (_) => _capture(() => _compatibleFormat.format('{:.0f}', 2.5)),
  ),
  _braceComparable(
    'brace.grouping',
    template: '{:,d}',
    values: const [1234567],
    expected: '1,234,567',
  ),
  _braceComparable(
    'brace.sign',
    template: '{:+d}',
    values: const [42],
    expected: '+42',
  ),
  _braceComparable(
    'brace.alternate',
    template: '{:#x}',
    values: const [42],
    expected: '0x2a',
  ),
  _braceComparable(
    'brace.specials',
    template: '{:f}',
    values: const [double.nan],
    expected: 'nan',
    candidateFormat: _compatibleFormat,
  ),
  _braceInformation(
    'brace.auto_manual',
    template: '{} {1}',
    expected: const ErrorOutcome('InvalidFormatException'),
    candidate: (_) => _capture(() => format('{} {1}', 'zero', 'one')),
  ),
  _braceInformation(
    'brace.named',
    template: '{name}',
    expected: const TextOutcome('Ada'),
    candidate:
        (_) =>
            _capture(() => formatWith('{name}', named: const {'name': 'Ada'})),
  ),
  _braceInformation(
    'brace.mixed_named.hot.10',
    template: '{name} {} {} {} {} {} {} {} {} {}',
    expected: const TextOutcome('Ada 1 2 3 4 5 6 7 8 9'),
    candidate:
        (_) => _capture(
          () => formatWith(
            '{name} {} {} {} {} {} {} {} {} {}',
            positional: const [1, 2, 3, 4, 5, 6, 7, 8, 9],
            named: const {'name': 'Ada'},
          ),
        ),
    fieldCount: 10,
  ),
  _braceInformation(
    'brace.graphemes.hot',
    template: '{:.1s}',
    expected: const TextOutcome('e\u0301'),
    candidate:
        (_) => _capture(
          () => Format(
            textUnit: TextUnit.graphemeClusters,
          ).format('{:.1s}', 'e\u0301'),
        ),
  ),
  _braceInformation(
    'brace.double.exponential',
    template: '{:e}',
    expected: const TextOutcome('1.000000e+00'),
    candidate: (_) => _capture(() => _compatibleFormat.format('{:e}', 1.0)),
  ),
  _braceComparable(
    'brace.double.general',
    template: '{:g}',
    values: const [12.5],
    expected: '12.5',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _braceInformation(
    'brace.percent',
    template: '{:.1%}',
    expected: const TextOutcome('12.5%'),
    candidate: (_) => _capture(() => format('{:.1%}', .125)),
  ),
  _braceInformation(
    'brace.equals_width',
    template: '{:=+08d}',
    expected: const TextOutcome('+0000042'),
    candidate: (_) => _capture(() => format('{:=+08d}', 42)),
  ),
  _braceInformation(
    'brace.nested_precision.hot',
    template: '{value:{width}.{precision}f}',
    expected: const TextOutcome('   12.35'),
    candidate:
        (_) => _capture(
          () => formatWith(
            '{value:{width}.{precision}f}',
            named: const {'value': 12.3456, 'width': 8, 'precision': 2},
          ),
        ),
  ),
  _braceInformation(
    'brace.lookup',
    template: '{user[name]}',
    expected: const TextOutcome('Ada'),
    candidate:
        (_) => _capture(
          () => formatWith(
            '{user[name]}',
            named: const {
              'user': {'name': 'Ada'},
            },
          ),
        ),
  ),
  _braceInformation(
    'brace.conversion',
    template: '{!s:.2s}',
    expected: const TextOutcome('nu'),
    candidate: (_) => _capture(() => format('{!s:.2s}', null)),
  ),
  _braceInformation(
    'brace.custom_extension',
    template: '{:bench}',
    expected: const TextOutcome('bench:7'),
    candidate: (_) => _capture(() => _benchmarkFormat.format('{:bench}', 7)),
  ),
  _braceReference(
    'brace.locale.n',
    template: '{:n}',
    expected: const TextOutcome('1234567'),
    rationale:
        'Format 2 has no n conversion; explicit CNumberLocale is an '
        'output-only reference.',
    candidate: (_) => _capture(() => format('{:n}', 1234567)),
    reference: (_) => _capture(() => _cFormat.format('{:n}', 1234567)),
  ),
  _braceReference(
    'brace.format_intl',
    template: '{:n}',
    expected: const TextOutcome('1\u00a0234'),
    rationale:
        'Pinned kk_KZ Intl output is a golden reference, not a performance '
        'competitor.',
    candidate: (_) => _capture(() => _intlFormat.format('{:n}', 1234)),
    reference: (_) => const TextOutcome('1\u00a0234'),
    referenceKind: BenchmarkReferenceKind.golden,
    referenceLabel: 'golden-intl:kk_KZ:1234',
  ),
  _printfComparable(
    'printf.literal',
    cold: true,
    template: 'literal %%',
    values: const [],
    expected: 'literal %',
  ),
  _printfComparable(
    'printf.sprintf',
    template: '%d',
    values: const [42],
    expected: '42',
    apiPath: BenchmarkApiPath.topLevel,
  ),
  _printfComparable(
    'printf.vsprintf',
    template: '%s:%d',
    values: const ['value', 3],
    expected: 'value:3',
  ),
  _printfComparable(
    'printf.tear_off',
    template: '%d',
    values: const [42],
    expected: '42',
    apiPath: BenchmarkApiPath.tearOff,
  ),
  _printfComparable(
    'printf.conversions.1',
    template: '%d',
    values: const [1],
    expected: '1',
  ),
  _printfComparable(
    'printf.conversions.5',
    template: '%d%d%d%d%d',
    values: const [1, 2, 3, 4, 5],
    expected: '12345',
  ),
  _printfComparable(
    'printf.conversions.10',
    template: '%d%d%d%d%d%d%d%d%d%d',
    values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    expected: '12345678910',
  ),
  _printfComparable(
    'printf.conversions.50',
    template: _printfFields(50),
    values: List<Object?>.filled(50, 1),
    expected: '1' * 50,
  ),
  _printfComparable(
    'printf.dynamic.hot.10',
    template: '%*.*f',
    values: const [10, 2, 12.5],
    expected: '     12.50',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.text',
    template: '%.3s',
    values: const ['abcde'],
    expected: 'abc',
  ),
  _printfInformation(
    'printf.character',
    template: '%c',
    expected: const TextOutcome('A'),
    candidate: (_) => _capture(() => sprintf('%c', 65)),
  ),
  _printfComparable(
    'printf.signed',
    template: '%+d',
    values: const [42],
    expected: '+42',
  ),
  _printfInformation(
    'printf.unsigned',
    template: '%u',
    expected: const TextOutcome('42'),
    candidate: (_) => _capture(() => sprintf('%u', 42)),
  ),
  _printfComparable(
    'printf.fixed',
    template: '%.2f',
    values: const [12.5],
    expected: '12.50',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.flags',
    template: '%#08x',
    values: const [42],
    expected: '0x00002a',
  ),
  _printfComparable(
    'printf.exponential',
    template: '%e',
    values: const [1.0],
    expected: '1.000000e+00',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.general',
    template: '%g',
    values: const [12.5],
    expected: '12.5',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfInformation(
    'printf.hex_float.hot',
    template: '%a',
    expected: const TextOutcome('0x1.8p+0'),
    candidate: (_) => _capture(() => sprintf('%a', 1.5)),
  ),
  _printfInformation(
    'printf.uppercase',
    template: '%A',
    expected: const TextOutcome('0X1.8P+0'),
    candidate: (_) => _capture(() => sprintf('%A', 1.5)),
  ),
  _printfComparable(
    'printf.specials',
    template: '%.2F',
    values: const [double.infinity],
    expected: 'INF',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfInformation(
    'printf.unicode',
    template: '%.1s',
    expected: const TextOutcome('e'),
    candidate: (_) => _capture(() => sprintf('%.1s', 'e\u0301')),
  ),
  _printfInformation(
    'printf.locale',
    template: '%.1f',
    expected: const TextOutcome('1234,5'),
    candidate: (_) => _capture(() => _intlFormat.sprintf('%.1f', 1234.5)),
  ),
  _printfInformation(
    'printf.invalid.hot',
    template: '%q',
    expected: const ErrorOutcome('InvalidFormatException'),
    candidate: (_) => _capture(() => sprintf('%q', 1)),
  ),
  _braceComparable(
    'brace.parser_heavy',
    cold: true,
    template: '{{{0:d}}}',
    values: const [42],
    expected: '{42}',
  ),
  _braceComparable(
    'brace.fields.10',
    cold: true,
    template: '{0:d}{1:d}{2:d}{3:d}{4:d}{5:d}{6:d}{7:d}{8:d}{9:d}',
    values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    expected: '12345678910',
    key: true,
  ),
  _braceInformation(
    'brace.double.default',
    template: '{}',
    expected: const TextOutcome('1.23456789'),
    candidate: (_) => _capture(() => format('{}', 1.23456789)),
  ),
  _printfComparable(
    'printf.conversions',
    cold: true,
    template: '%d%d%d%d%d',
    values: const [1, 2, 3, 4, 5],
    expected: '12345',
    key: true,
  ),
  _printfComparable(
    'printf.dynamic',
    cold: true,
    template: '%*.*f',
    values: const [10, 2, 12.5],
    expected: '     12.50',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.uppercase_exponential',
    template: '%E',
    values: const [1.0],
    expected: '1.000000E+00',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.uppercase_general',
    template: '%G',
    values: const [12.5],
    expected: '12.5',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
  _printfComparable(
    'printf.uppercase_fixed',
    template: '%.2F',
    values: const [12.5],
    expected: '12.50',
    key: true,
    candidateFormat: _compatibleFormat,
  ),
]);

final Format _benchmarkFormat = Format(formatters: [_BenchmarkFormatter()]);
final Format _compatibleFormat = Format(
  doubleFormatMode: DoubleFormatMode.compatible,
);
final _braceTearOff = defaultFormat.format;
final _printfTearOff = defaultFormat.sprintf;
// The C locale is also the default, so spelling it is redundant to the
// analyzer — and load-bearing to the reader: `brace.locale.n` compares the
// top-level `format` against this instance precisely because both are C, and
// its rationale says so. Dropping the argument would leave the scenario
// comparing two engines with nothing written down to say they match.
// ignore: avoid_redundant_argument_values
final Format _cFormat = Format(numberLocale: const CNumberLocale());
final Format _intlFormat = Format(numberLocale: IntlNumberLocale('kk_KZ'));

BenchmarkScenario _braceComparable(
  String name, {
  bool cold = false,
  required String template,
  required List<Object?> values,
  required String expected,
  bool key = false,
  bool graphemes = false,
  BenchmarkApiPath apiPath = BenchmarkApiPath.withValues,
  Format? candidateFormat,
}) {
  final templateFor = _templateFor(cold, template);
  final engine =
      candidateFormat ??
      (graphemes ? Format(textUnit: TextUnit.graphemeClusters) : null);
  return BenchmarkScenario(
    id:
        name.contains('.cold') || name.contains('.hot')
            ? name
            : '$name.${cold ? 'cold' : 'hot'}',
    dialect: BenchmarkDialect.braces,
    phase: cold ? BenchmarkPhase.cold : BenchmarkPhase.hot,
    keyScenario: key,
    apiPath: apiPath,
    expected: TextOutcome(cold ? '$expected [0]' : expected),
    templateFor: templateFor,
    candidate:
        (iteration) => _capture(
          () => switch (apiPath) {
            BenchmarkApiPath.topLevel => format(
              templateFor(iteration),
              values.first,
            ),
            BenchmarkApiPath.tearOff => _braceTearOff(
              templateFor(iteration),
              values.first,
            ),
            _ => (engine?.formatWith ?? formatWith)(
              templateFor(iteration),
              positional: values,
            ),
          },
        ),
    baseline:
        (iteration) =>
            _capture(() => legacyFormat(templateFor(iteration), values)),
  );
}

BenchmarkScenario _printfComparable(
  String name, {
  bool cold = false,
  required String template,
  required List<Object?> values,
  required String expected,
  bool key = false,
  BenchmarkApiPath apiPath = BenchmarkApiPath.withValues,
  Format? candidateFormat,
}) {
  final templateFor = _templateFor(cold, template);
  return BenchmarkScenario(
    id:
        name.contains('.cold') || name.contains('.hot')
            ? name
            : '$name.${cold ? 'cold' : 'hot'}',
    dialect: BenchmarkDialect.printf,
    phase: cold ? BenchmarkPhase.cold : BenchmarkPhase.hot,
    keyScenario: key,
    apiPath: apiPath,
    expected: TextOutcome(cold ? '$expected [0]' : expected),
    templateFor: templateFor,
    candidate:
        (iteration) => _capture(
          () => switch (apiPath) {
            _ when candidateFormat != null => candidateFormat.vsprintf(
              templateFor(iteration),
              values,
            ),
            BenchmarkApiPath.topLevel => sprintf(
              templateFor(iteration),
              values.first,
            ),
            BenchmarkApiPath.tearOff => _printfTearOff(
              templateFor(iteration),
              values.first,
            ),
            _ => vsprintf(templateFor(iteration), values),
          },
        ),
    baseline:
        (iteration) =>
            _capture(() => sprintf70.sprintf(templateFor(iteration), values)),
  );
}

BenchmarkScenario _braceInformation(
  String name, {
  required String template,
  required BenchmarkOutcome expected,
  required BenchmarkOperation candidate,
  int fieldCount = 1,
}) => BenchmarkScenario(
  id: name.contains('.hot') ? name : '$name.hot',
  dialect: BenchmarkDialect.braces,
  phase: BenchmarkPhase.hot,
  keyScenario: false,
  expected: expected,
  templateFor: (_) => template,
  candidate: candidate,
  fieldCount: fieldCount,
  comparisonKind: BenchmarkComparisonKind.informational,
);

BenchmarkScenario _braceReference(
  String name, {
  required String template,
  required BenchmarkOutcome expected,
  required String rationale,
  required BenchmarkOperation candidate,
  required BenchmarkOperation reference,
  BenchmarkReferenceKind referenceKind = BenchmarkReferenceKind.executable,
  String? referenceLabel,
}) => BenchmarkScenario(
  id: '$name.hot',
  dialect: BenchmarkDialect.braces,
  phase: BenchmarkPhase.hot,
  keyScenario: false,
  expected: expected,
  templateFor: (_) => template,
  candidate: candidate,
  baseline: reference,
  comparisonKind: BenchmarkComparisonKind.correctnessOnly,
  comparisonRationale: rationale,
  referenceKind: referenceKind,
  referenceLabel: referenceLabel,
);

BenchmarkScenario _printfInformation(
  String name, {
  required String template,
  required BenchmarkOutcome expected,
  required BenchmarkOperation candidate,
}) => BenchmarkScenario(
  id: name.contains('.hot') ? name : '$name.hot',
  dialect: BenchmarkDialect.printf,
  phase: BenchmarkPhase.hot,
  keyScenario: false,
  expected: expected,
  templateFor: (_) => template,
  candidate: candidate,
  comparisonKind: BenchmarkComparisonKind.informational,
);

/// The template an iteration formats.
///
/// A cold scenario suffixes the iteration so that no two calls hand the
/// engine the same template, and a hot one hands over the same template every
/// time. Building the string costs both engines equally, so the ratio is
/// unaffected.
String Function(int) _templateFor(bool cold, String template) =>
    cold ? (iteration) => '$template [$iteration]' : (_) => template;

String _braceFields(int count) =>
    List.generate(count, (index) => '{$index:d}').join();

String _printfFields(int count) => List.filled(count, '%d').join();

BenchmarkOutcome _capture(String Function() operation) {
  try {
    return TextOutcome(operation());
  } on Object catch (error) {
    return ErrorOutcome(_errorCategory(error));
  }
}

String _errorCategory(Object error) => switch (error) {
  InvalidFormatException() => 'InvalidFormatException',
  InvalidSpecifierException() => 'InvalidSpecifierException',
  MissingFormatArgumentException() => 'MissingFormatArgumentException',
  FormatLookupException() => 'FormatLookupException',
  UnsupportedConversionException() => 'UnsupportedConversionException',
  UnsupportedFormatValueException() => 'UnsupportedFormatValueException',
  FormatConfigurationException() => 'FormatConfigurationException',
  AmbiguousFormatterException() => 'AmbiguousFormatterException',
  FormatExtensionException() => 'FormatExtensionException',
  _ => error.runtimeType.toString(),
};

final class _BenchmarkFormatter extends Formatter<int> {
  @override
  String get specifier => 'bench';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) => 'bench:$value';
}
