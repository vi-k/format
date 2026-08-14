enum ReferenceLanguage { english, russian }

enum ReferenceDialect { brace, printf }

enum ValueCategory {
  any,
  text,
  integer,
  nonNegativeInteger,
  floating,
  custom,
  none,
}

enum PublicCall { format, formatWith, sprintf, vsprintf, configuredFormat }

enum FormattingErrorKind {
  invalidFormat,
  invalidSpecifier,
  missingArgument,
  unsupportedConversion,
  unsupportedValue,
}

final class LocalizedText {
  final String english;
  final String russian;

  const LocalizedText(this.english, this.russian);

  String inLanguage(ReferenceLanguage language) => switch (language) {
    ReferenceLanguage.english => english,
    ReferenceLanguage.russian => russian,
  };
}

final class RuleEvidence {
  final List<String> successCaseIds;
  final List<String> failureCaseIds;
  final bool requiresSuccessCase;
  final bool requiresFailureCase;

  const RuleEvidence({
    required this.successCaseIds,
    this.failureCaseIds = const [],
    this.requiresSuccessCase = true,
    this.requiresFailureCase = false,
  });
}

final class GrammarRule {
  final String id;
  final String syntax;
  final LocalizedText text;
  final RuleEvidence evidence;

  const GrammarRule({
    required this.id,
    required this.syntax,
    required this.text,
    this.evidence = const RuleEvidence(successCaseIds: []),
  });
}

final class OptionContract {
  final String id;
  final List<String> tokens;
  final int order;
  final LocalizedText meaning;
  final LocalizedText defaultValue;
  final List<ValueCategory> appliesTo;
  final RuleEvidence evidence;

  const OptionContract({
    required this.id,
    required this.tokens,
    required this.order,
    required this.meaning,
    required this.defaultValue,
    required this.appliesTo,
    required this.evidence,
  });
}

final class TypeContract {
  final String id;
  final List<String> tokens;
  final List<ValueCategory> accepts;
  final List<String> optionIds;
  final LocalizedText result;
  final LocalizedText defaultPrecision;
  final LocalizedText? deepLink;
  final RuleEvidence evidence;

  const TypeContract({
    required this.id,
    required this.tokens,
    required this.accepts,
    required this.optionIds,
    required this.result,
    required this.defaultPrecision,
    required this.evidence,
    this.deepLink,
  });
}

sealed class ExpectedOutcome {
  const ExpectedOutcome();
}

final class OutputOutcome extends ExpectedOutcome {
  final String value;

  const OutputOutcome(this.value);
}

final class ErrorOutcome extends ExpectedOutcome {
  final FormattingErrorKind kind;

  const ErrorOutcome(this.kind);
}

final class ConformanceCase {
  final String id;
  final PublicCall call;
  final String dartExpression;
  final ExpectedOutcome expected;

  const ConformanceCase({
    required this.id,
    required this.call,
    required this.dartExpression,
    required this.expected,
  });
}

final class DialectContract {
  final ReferenceDialect dialect;
  final LocalizedText title;
  final List<GrammarRule> grammar;
  final List<OptionContract> options;
  final List<TypeContract> types;

  const DialectContract({
    required this.dialect,
    required this.title,
    required this.grammar,
    required this.options,
    required this.types,
  });
}

final class FormatReferenceContract {
  final DialectContract brace;
  final DialectContract printf;
  final List<GrammarRule> limits;
  final List<GrammarRule> errors;
  final List<ConformanceCase> cases;

  const FormatReferenceContract({
    required this.brace,
    required this.printf,
    required this.limits,
    required this.errors,
    required this.cases,
  });
}
