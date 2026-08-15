import 'dart:io';

import 'format_reference_contract.dart';
import 'format_reference_model.dart';
import 'format_reference_renderer.dart';
import 'format_reference_validator.dart';

enum FormatReferenceGenerationMode { write, check }

Future<List<String>> generateFormatReferenceArtifacts({
  required Directory root,
  required FormatReferenceGenerationMode mode,
  FormatReferenceContract contract = formatReferenceContract,
  Future<void> Function(File file, String contents)? writeArtifact,
}) async {
  final contractIssues = validateFormatReferenceContract(contract);
  if (contractIssues.isNotEmpty) {
    throw FormatException(
      'invalid format-reference contract:\n${contractIssues.join('\n')}',
    );
  }

  final targets = <String, File>{
    'README.md': File('${root.path}/README.md'),
    'README.ru.md': File('${root.path}/README.ru.md'),
    'test/support/format_reference_cases.dart': File(
      '${root.path}/test/support/format_reference_cases.dart',
    ),
  };
  final current = <String, String>{};
  for (final entry in targets.entries) {
    current[entry.key] =
        entry.value.existsSync() ? entry.value.readAsStringSync() : '';
  }

  final english = renderFormatReference(contract, ReferenceLanguage.english);
  final russian = renderFormatReference(contract, ReferenceLanguage.russian);
  if (!_sameStrings(english.semanticIds, russian.semanticIds)) {
    throw const FormatException(
      'English and Russian format-reference semantic order differs',
    );
  }

  final generated = <String, String>{
    'README.md': replaceFormatReferenceBlock(
      current['README.md']!,
      english.markdown,
    ),
    'README.ru.md': replaceFormatReferenceBlock(
      current['README.ru.md']!,
      russian.markdown,
    ),
    'test/support/format_reference_cases.dart': renderFormatReferenceCases(
      contract,
    ),
  };
  _validateDeepLinks(
    contract.brace.types.followedBy(contract.printf.types),
    ReferenceLanguage.english,
    generated['README.md']!,
  );
  _validateDeepLinks(
    contract.brace.types.followedBy(contract.printf.types),
    ReferenceLanguage.russian,
    generated['README.ru.md']!,
  );

  final stale = <String>[
    for (final path in targets.keys)
      if (current[path] != generated[path]) path,
  ];
  if (mode == FormatReferenceGenerationMode.check) return stale;

  final writer =
      writeArtifact ??
      (File file, String contents) => file.writeAsString(contents);
  for (final path in stale) {
    final file = targets[path]!;
    await file.parent.create(recursive: true);
    await writer(file, generated[path]!);
  }
  return stale;
}

void _validateDeepLinks(
  Iterable<TypeContract> types,
  ReferenceLanguage language,
  String readme,
) {
  final anchors = markdownHeadingAnchors(readme);
  for (final type in types) {
    final link = type.deepLink?.inLanguage(language);
    if (link != null && !anchors.contains(link)) {
      throw FormatException('${type.id}: missing README anchor: $link');
    }
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
