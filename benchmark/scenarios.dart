import 'package:format/format.dart';

// ignore: avoid_relative_lib_imports
import '../packages/format_intl/lib/format_intl.dart';
import 'baselines/format2/format2.dart';
// ignore: avoid_relative_lib_imports
import 'baselines/sprintf7/lib/sprintf.dart' as sprintf7;
import 'model.dart';

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
    apiPath: BenchmarkApiPath.withValues,
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
    template: '{:.3s}',
    expected: const TextOutcome('e'),
    candidate: (_) => _capture(() => format('{:.1s}', 'e\u0301')),
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
    'brace.bigint.default',
    template: '{}',
    values: [BigInt.parse('9007199254740993')],
    expected: '9007199254740993',
  ),
  _braceComparable(
    'brace.double.fixed',
    template: '{:.2f}',
    values: const [12.5],
    expected: '12.50',
    key: true,
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
    candidate: (_) => _capture(() => format('{:e}', 1.0)),
  ),
  _braceComparable(
    'brace.double.general',
    template: '{:g}',
    values: const [12.5],
    expected: '12.5',
    key: true,
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
        'Pinned uk_UA Intl output is a golden reference, not a performance competitor.',
    candidate: (_) => _capture(() => _intlFormat.format('{:n}', 1234)),
    reference: (_) => const TextOutcome('1\u00a0234'),
    referenceKind: BenchmarkReferenceKind.golden,
    referenceLabel: 'golden-intl:uk_UA:1234',
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
    apiPath: BenchmarkApiPath.withValues,
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
  ),
  _printfComparable(
    'printf.general',
    template: '%g',
    values: const [12.5],
    expected: '12.5',
    key: true,
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
  ),
  _printfComparable(
    'printf.uppercase_exponential',
    template: '%E',
    values: const [1.0],
    expected: '1.000000E+00',
    key: true,
  ),
  _printfComparable(
    'printf.uppercase_general',
    template: '%G',
    values: const [12.5],
    expected: '12.5',
    key: true,
  ),
  _printfComparable(
    'printf.uppercase_fixed',
    template: '%.2F',
    values: const [12.5],
    expected: '12.50',
    key: true,
  ),
]);

final Format _benchmarkFormat = Format(formatters: [_BenchmarkFormatter()]);
final _braceTearOff = defaultFormat.format;
final _printfTearOff = defaultFormat.sprintf;
final Format _cFormat = Format(numberLocale: const CNumberLocale());
final Format _intlFormat = Format(numberLocale: IntlNumberLocale('uk_UA'));

BenchmarkScenario _braceComparable(
  String name, {
  bool cold = false,
  required String template,
  required List<Object?> values,
  required String expected,
  bool key = false,
  bool graphemes = false,
  BenchmarkApiPath apiPath = BenchmarkApiPath.withValues,
}) {
  final templates = _templates(cold, template);
  final engine = graphemes ? Format(textUnit: TextUnit.graphemeClusters) : null;
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
    templates: templates,
    candidate:
        (iteration) => _capture(
          () => switch (apiPath) {
            BenchmarkApiPath.topLevel => format(
              templates[iteration % templates.length],
              values.first,
            ),
            BenchmarkApiPath.tearOff => _braceTearOff(
              templates[iteration % templates.length],
              values.first,
            ),
            _ => (engine?.formatWith ?? formatWith)(
              templates[iteration % templates.length],
              positional: values,
            ),
          },
        ),
    baseline:
        (iteration) => _capture(
          () => legacyFormat(templates[iteration % templates.length], values),
        ),
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
}) {
  final templates = _templates(cold, template);
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
    templates: templates,
    candidate:
        (iteration) => _capture(
          () => switch (apiPath) {
            BenchmarkApiPath.topLevel => sprintf(
              templates[iteration % templates.length],
              values.first,
            ),
            BenchmarkApiPath.tearOff => _printfTearOff(
              templates[iteration % templates.length],
              values.first,
            ),
            _ => vsprintf(templates[iteration % templates.length], values),
          },
        ),
    baseline:
        (iteration) => _capture(
          () =>
              sprintf7.sprintf(templates[iteration % templates.length], values),
        ),
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
  templates: [template],
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
  templates: [template],
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
  templates: [template],
  candidate: candidate,
  comparisonKind: BenchmarkComparisonKind.informational,
);

List<String> _templates(bool cold, String template) =>
    cold
        ? List.unmodifiable(List.generate(200, (index) => '$template [$index]'))
        : List.unmodifiable([template]);

String _braceFields(int count) =>
    List.generate(count, (index) => '{$index:d}').join();

String _printfFields(int count) => List.filled(count, '%d').join();

BenchmarkOutcome _capture(String Function() operation) {
  try {
    return TextOutcome(operation());
  } on Object catch (error) {
    return ErrorOutcome(error.runtimeType.toString());
  }
}

final class _BenchmarkFormatter extends Formatter<int> {
  @override
  String get specifier => 'bench';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) => 'bench:$value';
}
