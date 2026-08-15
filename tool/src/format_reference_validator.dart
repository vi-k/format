import 'format_reference_model.dart';

List<String> validateFormatReferenceContract(FormatReferenceContract contract) {
  final issues = <String>[];
  final grammarIds = <String>{};
  final optionIds = <String>{};
  final typeIds = <String>{};
  final limitIds = <String>{};
  final errorIds = <String>{};
  final casesById = <String, ConformanceCase>{};
  final caseIssues = <String>[];

  _checkText(issues, 'brace.title', contract.brace.title);
  _checkText(issues, 'printf.title', contract.printf.title);

  for (final conform in contract.cases) {
    if (!casesById.containsKey(conform.id)) {
      casesById[conform.id] = conform;
    } else {
      caseIssues.add('duplicate conformance id: ${conform.id}');
    }
  }

  void checkId(String id, Set<String> ids) {
    if (!ids.add(id)) {
      issues.add('duplicate semantic id: $id');
    }
  }

  void checkEvidence(String owner, RuleEvidence evidence) {
    if (evidence.requiresSuccessCase && evidence.successCaseIds.isEmpty) {
      issues.add('$owner: missing success evidence');
    }
    if (evidence.requiresFailureCase && evidence.failureCaseIds.isEmpty) {
      issues.add('$owner: missing failure evidence');
    }
    for (final caseId in evidence.successCaseIds) {
      final conform = casesById[caseId];
      if (conform == null) {
        issues.add('$owner: unknown conformance case: $caseId');
      } else if (conform.expected is! OutputOutcome) {
        issues.add('$owner: success evidence is not output: $caseId');
      }
    }
    for (final caseId in evidence.failureCaseIds) {
      final conform = casesById[caseId];
      if (conform == null) {
        issues.add('$owner: unknown conformance case: $caseId');
      } else if (conform.expected is! ErrorOutcome) {
        issues.add('$owner: failure evidence is not error: $caseId');
      }
    }
  }

  void checkRule(GrammarRule rule, Set<String> ids) {
    checkId(rule.id, ids);
    _checkText(issues, rule.id, rule.text);
    checkEvidence(rule.id, rule.evidence);
  }

  void checkDialect(DialectContract dialect) {
    final dialectOptionIds = <String>{};
    final dialectOptionsById = <String, OptionContract>{};
    final optionTokens = <String, String>{};
    final typeTokens = <String, String>{};

    for (final rule in dialect.grammar) {
      checkRule(rule, grammarIds);
    }
    for (final option in dialect.options) {
      checkId(option.id, optionIds);
      dialectOptionIds.add(option.id);
      dialectOptionsById.putIfAbsent(option.id, () => option);
      _checkText(issues, '${option.id}.meaning', option.meaning);
      _checkText(issues, '${option.id}.default', option.defaultValue);
      _checkTokens(issues, option.id, option.tokens, optionTokens);
      checkEvidence(option.id, option.evidence);
    }
    for (final type in dialect.types) {
      checkId(type.id, typeIds);
      _checkText(issues, '${type.id}.result', type.result);
      _checkText(issues, '${type.id}.precision', type.defaultPrecision);
      final deepLink = type.deepLink;
      if (deepLink != null) {
        _checkText(issues, '${type.id}.deepLink', deepLink);
      }
      _checkTokens(issues, type.id, type.tokens, typeTokens);
      for (final optionId in type.optionIds) {
        if (!dialectOptionIds.contains(optionId)) {
          issues.add('${type.id}: unknown option: $optionId');
        }
      }
      for (final exclusion in type.excludedOptionTokens.entries) {
        final option = dialectOptionsById[exclusion.key];
        if (option == null || !type.optionIds.contains(exclusion.key)) {
          issues.add('${type.id}: unknown exclusion option: ${exclusion.key}');
          continue;
        }
        final excludedTokens = <String>{};
        for (final token in exclusion.value) {
          if (!excludedTokens.add(token)) {
            issues.add(
              '${type.id}: duplicate excluded token: $token for '
              '${exclusion.key}',
            );
          }
          if (!option.tokens.contains(token)) {
            issues.add(
              '${type.id}: unknown excluded token: $token for '
              '${exclusion.key}',
            );
          }
        }
      }
      for (final applicability in type.optionAppliesTo.entries) {
        final option = dialectOptionsById[applicability.key];
        if (option == null || !type.optionIds.contains(applicability.key)) {
          issues.add(
            '${type.id}: unknown applicability option: ${applicability.key}',
          );
          continue;
        }
        _checkApplicabilityCategories(
          issues,
          type,
          applicability.key,
          applicability.value,
        );
      }
      final availableTokens = <String>{
        for (final optionId in type.optionIds)
          ...?dialectOptionsById[optionId]?.tokens,
      };
      for (final applicability in type.tokenAppliesTo.entries) {
        if (!availableTokens.contains(applicability.key)) {
          issues.add(
            '${type.id}: unknown applicability token: ${applicability.key}',
          );
          continue;
        }
        _checkApplicabilityCategories(
          issues,
          type,
          applicability.key,
          applicability.value,
        );
      }
      checkEvidence(type.id, type.evidence);
    }
  }

  checkDialect(contract.brace);
  checkDialect(contract.printf);
  for (final rule in contract.limits) {
    checkRule(rule, limitIds);
  }
  for (final rule in contract.errors) {
    checkRule(rule, errorIds);
  }
  issues.addAll(caseIssues);

  return issues;
}

void _checkApplicabilityCategories(
  List<String> issues,
  TypeContract type,
  String owner,
  List<ValueCategory> categories,
) {
  final seen = <ValueCategory>{};
  for (final category in categories) {
    if (!seen.add(category)) {
      issues.add(
        '${type.id}: duplicate applicability category: $category for $owner',
      );
    }
    if (category == ValueCategory.any || category == ValueCategory.none) {
      issues.add(
        '${type.id}: non-concrete applicability category: $category for $owner',
      );
    } else if (!type.accepts.contains(ValueCategory.any) &&
        !type.accepts.contains(category)) {
      issues.add(
        '${type.id}: applicability category is not accepted: '
        '$category for $owner',
      );
    }
  }
}

void _checkText(List<String> issues, String owner, LocalizedText text) {
  if (text.english.trim().isEmpty) {
    issues.add('$owner: missing translation: english');
  }
  if (text.russian.trim().isEmpty) {
    issues.add('$owner: missing translation: russian');
  }
}

void _checkTokens(
  List<String> issues,
  String owner,
  List<String> tokens,
  Map<String, String> ownersByToken,
) {
  for (final token in tokens) {
    final previousOwner = ownersByToken[token];
    if (previousOwner == null) {
      ownersByToken[token] = owner;
    } else {
      issues.add(
        '$owner: duplicate token: $token (already used by $previousOwner)',
      );
    }
  }
}
