/// Verifies that the format-reference catalog is internally consistent before
/// documentation or executable projections consume it.
///
/// These tests keep malformed semantic ids, translations, tokens, option
/// references, and evidence links from becoming valid generated artifacts.
library;

import 'package:test/test.dart';

import '../src/format_reference_contract.dart';
import '../src/format_reference_model.dart';
import '../src/format_reference_validator.dart';

void main() {
  // A validator that rejects a real catalog row, or a catalog with an
  // unresolved structural defect, would make every later projection unsafe.
  test('the complete reference contract is structurally valid', () {
    expect(validateFormatReferenceContract(formatReferenceContract), isEmpty);
  });

  // Adding payload to the empty presentation, or dropping one of the literal
  // token exclusions below, would make a typed renderer advertise a
  // specification that the corresponding brace presentation rejects.
  test('brace type restrictions preserve the exact option-token matrix', () {
    final types = {
      for (final type in formatReferenceContract.brace.types) type.id: type,
    };

    expect(types['brace.none']!.optionIds, isNot(contains('brace.payload')));
    expect(types['brace.string']!.excludedOptionTokens, const {
      'brace.fill_align': ['='],
    });
    expect(types['brace.character']!.excludedOptionTokens, const {
      'brace.fill_align': ['='],
    });
    for (final id in ['brace.binary', 'brace.octal', 'brace.hex']) {
      expect(types[id]!.excludedOptionTokens, const {
        'brace.integer_grouping': [','],
      });
    }
    expect(types['brace.custom_type']!.excludedOptionTokens, const {
      'brace.fill_align': ['='],
    });
  });

  // Reusing one semantic id within a semantic category would make generated
  // anchors and evidence ownership ambiguous.
  test('duplicate semantic ids are rejected', () {
    final contract = fixtureContract(
      rules: const [
        GrammarRule(id: 'same', syntax: 'a', text: LocalizedText('a', 'а')),
        GrammarRule(id: 'same', syntax: 'b', text: LocalizedText('b', 'б')),
      ],
    );
    expect(
      validateFormatReferenceContract(contract),
      contains(contains('duplicate semantic id: same')),
    );
  });

  // Deleting exclusion-option validation would let a typo point outside the
  // options actually exposed by this type and leave consumers unable to
  // resolve the restriction.
  test('unknown token-exclusion option ids are rejected', () {
    final contract = fixtureContract(
      options: [
        _option('known', const ['x']),
      ],
      types: [
        _type(
          'type',
          const ['t'],
          optionIds: const ['known'],
          excludedOptionTokens: const {
            'absent': ['x'],
          },
        ),
      ],
    );

    expect(
      validateFormatReferenceContract(contract),
      contains(contains('unknown exclusion option: absent')),
    );
  });

  // Deleting excluded-token membership validation would allow a restriction
  // that names no token in the referenced option, so it could never affect a
  // generated matrix.
  test('unknown excluded option tokens are rejected', () {
    final contract = fixtureContract(
      options: [
        _option('known', const ['x']),
      ],
      types: [
        _type(
          'type',
          const ['t'],
          optionIds: const ['known'],
          excludedOptionTokens: const {
            'known': ['y'],
          },
        ),
      ],
    );

    expect(
      validateFormatReferenceContract(contract),
      contains(contains('unknown excluded token: y')),
    );
  });

  // Deleting per-exclusion duplicate tracking would let a renderer receive
  // the same subtraction twice and produce duplicate constraint output.
  test('duplicate excluded option tokens are rejected', () {
    final contract = fixtureContract(
      options: [
        _option('known', const ['x']),
      ],
      types: [
        _type(
          'type',
          const ['t'],
          optionIds: const ['known'],
          excludedOptionTokens: const {
            'known': ['x', 'x'],
          },
        ),
      ],
    );

    expect(
      validateFormatReferenceContract(contract),
      contains(contains('duplicate excluded token: x')),
    );
  });

  // Each fixture isolates a distinct invalid graph edge or localized field;
  // omitting any corresponding validator branch would make that row pass.
  test('all structural validation failures are reported', () {
    final outputCase = _outputCase('output');
    final errorCase = _errorCase('error');
    final fixtures = <({FormatReferenceContract contract, String issue})>[
      (
        contract: fixtureContract(
          braceTitle: const LocalizedText('', 'Фигурный'),
        ),
        issue: 'missing translation',
      ),
      (
        contract: fixtureContract(
          rules: const [
            GrammarRule(
              id: 'missing.ru',
              syntax: 'x',
              text: LocalizedText('English', ''),
              evidence: RuleEvidence(
                successCaseIds: [],
                requiresSuccessCase: false,
              ),
            ),
          ],
        ),
        issue: 'missing translation',
      ),
      (
        contract: fixtureContract(
          options: [
            _option('one', const ['x']),
            _option('two', const ['x']),
          ],
        ),
        issue: 'duplicate token',
      ),
      (
        contract: fixtureContract(
          types: [
            _type('one', const ['x']),
            _type('two', const ['x']),
          ],
        ),
        issue: 'duplicate token',
      ),
      (
        contract: fixtureContract(
          types: [
            _type('type', const ['x'], optionIds: const ['absent']),
          ],
        ),
        issue: 'unknown option',
      ),
      (
        contract: fixtureContract(cases: [outputCase, outputCase]),
        issue: 'duplicate conformance id',
      ),
      (
        contract: fixtureContract(
          rules: [
            _ruleWithEvidence(successCaseIds: const ['error']),
          ],
          cases: [errorCase],
        ),
        issue: 'success evidence is not output',
      ),
      (
        contract: fixtureContract(
          rules: [
            _ruleWithEvidence(
              failureCaseIds: const ['output'],
              requiresSuccessCase: false,
              requiresFailureCase: true,
            ),
          ],
          cases: [outputCase],
        ),
        issue: 'failure evidence is not error',
      ),
      (
        contract: fixtureContract(rules: [_ruleWithEvidence()]),
        issue: 'missing success evidence',
      ),
      (
        contract: fixtureContract(
          rules: [
            _ruleWithEvidence(
              requiresSuccessCase: false,
              requiresFailureCase: true,
            ),
          ],
        ),
        issue: 'missing failure evidence',
      ),
      (
        contract: fixtureContract(
          rules: [
            _ruleWithEvidence(successCaseIds: const ['absent']),
          ],
        ),
        issue: 'unknown conformance case',
      ),
    ];

    for (final fixture in fixtures) {
      expect(
        validateFormatReferenceContract(fixture.contract),
        contains(contains(fixture.issue)),
        reason: fixture.issue,
      );
    }
  });
}

FormatReferenceContract fixtureContract({
  LocalizedText braceTitle = const LocalizedText('Brace', 'Фигурный'),
  List<GrammarRule> rules = const [],
  List<OptionContract> options = const [],
  List<TypeContract> types = const [],
  List<ConformanceCase> cases = const [],
}) => FormatReferenceContract(
  brace: DialectContract(
    dialect: ReferenceDialect.brace,
    title: braceTitle,
    grammar: rules,
    options: options,
    types: types,
  ),
  printf: const DialectContract(
    dialect: ReferenceDialect.printf,
    title: LocalizedText('Printf', 'Printf'),
    grammar: [],
    options: [],
    types: [],
  ),
  limits: const [],
  errors: const [],
  cases: cases,
);

OptionContract _option(String id, List<String> tokens) => OptionContract(
  id: id,
  tokens: tokens,
  order: 1,
  meaning: const LocalizedText('Meaning', 'Смысл'),
  defaultValue: const LocalizedText('Default', 'По умолчанию'),
  appliesTo: const [ValueCategory.any],
  evidence: const RuleEvidence(successCaseIds: [], requiresSuccessCase: false),
);

TypeContract _type(
  String id,
  List<String> tokens, {
  List<String> optionIds = const [],
  Map<String, List<String>> excludedOptionTokens = const {},
}) => TypeContract(
  id: id,
  tokens: tokens,
  accepts: const [ValueCategory.any],
  optionIds: optionIds,
  excludedOptionTokens: excludedOptionTokens,
  result: const LocalizedText('Result', 'Результат'),
  defaultPrecision: const LocalizedText('None', 'Нет'),
  evidence: const RuleEvidence(successCaseIds: [], requiresSuccessCase: false),
);

GrammarRule _ruleWithEvidence({
  List<String> successCaseIds = const [],
  List<String> failureCaseIds = const [],
  bool requiresSuccessCase = true,
  bool requiresFailureCase = false,
}) => GrammarRule(
  id: 'rule',
  syntax: 'syntax',
  text: const LocalizedText('Text', 'Текст'),
  evidence: RuleEvidence(
    successCaseIds: successCaseIds,
    failureCaseIds: failureCaseIds,
    requiresSuccessCase: requiresSuccessCase,
    requiresFailureCase: requiresFailureCase,
  ),
);

ConformanceCase _outputCase(String id) => ConformanceCase(
  id: id,
  call: PublicCall.format,
  dartExpression: "format('{}', 1)",
  expected: const OutputOutcome('1'),
);

ConformanceCase _errorCase(String id) => ConformanceCase(
  id: id,
  call: PublicCall.format,
  dartExpression: "format('{}')",
  expected: const ErrorOutcome(FormattingErrorKind.missingArgument),
);
