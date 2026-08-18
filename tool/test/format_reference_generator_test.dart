/// Verifies the generated format-reference projections and their transactional
/// filesystem boundary independently of the formatter implementation.
///
/// These tests keep malformed marker layouts, localization drift, stale
/// check-mode writes, broken manual links, and invalid generated Dart from
/// becoming committed documentation.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../src/format_reference_contract.dart';
import '../src/format_reference_generator.dart';
import '../src/format_reference_model.dart';
import '../src/format_reference_renderer.dart';

void main() {
  // Losing either side of a generated block would overwrite hand-written
  // documentation outside the generator's ownership boundary.
  test('replacement preserves manual prefix and suffix', () {
    const source =
        'before\n$formatReferenceStartMarker\nold\n'
        '$formatReferenceEndMarker\nafter\n';

    expect(
      replaceFormatReferenceBlock(source, 'new\n'),
      'before\n$formatReferenceStartMarker\nnew\n'
      '$formatReferenceEndMarker\nafter\n',
    );
  });

  // Accepting an absent, repeated, or reversed marker would make ownership of
  // the surrounding manual text ambiguous.
  test('replacement rejects every malformed marker layout', () {
    const repeatedStart =
        '$formatReferenceStartMarker\na\n$formatReferenceStartMarker\n'
        '$formatReferenceEndMarker\n';
    final malformed = [
      'manual only\n',
      repeatedStart,
      '$formatReferenceEndMarker\n$formatReferenceStartMarker\n',
    ];

    for (final source in malformed) {
      expect(
        () => replaceFormatReferenceBlock(source, 'new\n'),
        throwsFormatException,
        reason: source,
      );
    }
  });

  // Visiting either localization through a differently ordered branch would
  // let the translated README describe a different semantic matrix.
  test('both languages render the same semantic ids in the same order', () {
    final english = renderFormatReference(
      formatReferenceContract,
      ReferenceLanguage.english,
    );
    final russian = renderFormatReference(
      formatReferenceContract,
      ReferenceLanguage.russian,
    );

    expect(russian.semanticIds, english.semanticIds);
  });

  // Ignoring per-type exclusions would advertise sign-aware alignment for
  // strings and comma grouping for non-decimal integer presentations.
  test('presentation rows subtract excluded option tokens', () {
    final markdown =
        renderFormatReference(
          formatReferenceContract,
          ReferenceLanguage.english,
        ).markdown;
    final stringRow = markdown
        .split('\n')
        .firstWhere((line) => line.startsWith('| `s` |'));
    final binaryRow = markdown
        .split('\n')
        .singleWhere((line) => line.startsWith('| `b` |'));

    expect(stringRow, contains('`<`, `>`, `^`'));
    expect(stringRow, isNot(contains('`=`')));
    expect(binaryRow, contains('`_`'));
    expect(binaryRow, isNot(contains('`,`')));
  });

  // A presentation shared by several value categories must not advertise a
  // union of their options as though every accepted value supported it.
  test('mixed-category rows qualify value-dependent option tokens', () {
    final markdown =
        renderFormatReference(
          formatReferenceContract,
          ReferenceLanguage.english,
        ).markdown;
    final emptyRow = markdown
        .split('\n')
        .singleWhere((line) => line.startsWith('| *empty* |'));
    final localeRow = markdown
        .split('\n')
        .singleWhere((line) => line.startsWith('| `n` |'));
    final fixedRow = markdown
        .split('\n')
        .firstWhere((line) => line.startsWith('| `f`, `F` |'));
    final printfStringRow =
        markdown.split('\n').where((line) => line.startsWith('| `s` |')).last;

    expect(
      emptyRow,
      contains('`+`, `-`, ` ` (`int`, `BigInt`, `double` only)'),
    );
    expect(emptyRow, contains('`=` (`int`, `BigInt`, `double` only)'));
    expect(emptyRow, isNot(contains('custom value only')));
    expect(localeRow, contains('`z` (`double` only)'));
    expect(localeRow, contains('`.ASCII_DIGIT+` (`double` only)'));
    expect(fixedRow, isNot(contains(' only)')));
    expect(printfStringRow, isNot(contains(' only)')));
  });

  // Markdown anchors are the external behavior consumed by catalog deep
  // links; punctuation and fenced pseudo-headings must not alter the set.
  test('manual heading anchors preserve Unicode and ignore fenced code', () {
    const markdown = '''
## Double formatting profiles
## Собственные форматтеры
```text
## Not a heading
```
''';

    expect(markdownHeadingAnchors(markdown), {
      '#double-formatting-profiles',
      '#собственные-форматтеры',
    });
  });

  // Omitting either documented Unicode anchor would leave text-unit behavior
  // without a generated route to its retained manual explanation.
  test('the rendered matrices include both Unicode deep links', () {
    expect(
      renderFormatReference(
        formatReferenceContract,
        ReferenceLanguage.english,
      ).markdown,
      contains('(#unicode-text-units)'),
    );
    expect(
      renderFormatReference(
        formatReferenceContract,
        ReferenceLanguage.russian,
      ).markdown,
      contains('(#единицы-измерения-текста-в-unicode)'),
    );
  });

  // These iteration orders are part of the generated bridge surface consumed
  // by the parser-inventory conformance test in the next task.
  test('generated bridge inventories keep their specified stable order', () {
    final generated = renderFormatReferenceCases(formatReferenceContract);

    expect(_dartCollectionKeys(generated, 'formatReferenceBraceTypes'), [
      'b',
      'c',
      'd',
      'e',
      'E',
      'f',
      'F',
      'g',
      'G',
      'n',
      'o',
      's',
      'x',
      'X',
      '%',
    ]);
    expect(_dartCollectionKeys(generated, 'formatReferencePrintfFlags'), [
      'c',
      's',
      'd',
      'i',
      'u',
      'o',
      'x',
      'X',
      'a',
      'A',
      'e',
      'E',
      'f',
      'F',
      'g',
      'G',
      '%',
    ]);
  });

  // A catalog syntax containing inline backticks must use a longer Markdown
  // delimiter, or the generated limit cell stops being one code span.
  test('table code spans remain balanced around catalog backticks', () {
    final markdown =
        renderFormatReference(
          formatReferenceContract,
          ReferenceLanguage.english,
        ).markdown;

    expect(
      markdown,
      contains(
        '| Dart-profile precision | '
        '`` Dart profile: general/empty/`n` 1…21; `f`/`e`/`%` 0…20 `` |',
      ),
    );
  });

  group('artifact generation', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('format-reference-test-');
      await _writeFixture(root);
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    // Check mode must report the whole repair set in deterministic order and
    // remain safe to run against a dirty checkout.
    test('check returns every stale path and writes nothing', () async {
      final before = await _readTargets(root);

      expect(
        await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.check,
        ),
        [
          'README.md',
          'README.ru.md',
          'test/support/format_reference_cases.dart',
        ],
      );
      expect(await _readTargets(root), before);
    });

    // Validation must finish for every target before the first write, or a
    // broken Russian marker could leave only the English README updated.
    test('a malformed second README prevents the first write', () async {
      final english = File('${root.path}/README.md');
      final before = await english.readAsString();
      await File('${root.path}/README.ru.md').writeAsString('manual only\n');

      await expectLater(
        generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.write,
        ),
        throwsFormatException,
      );
      expect(await english.readAsString(), before);
    });

    // A typo in catalog-owned navigation must fail before publishing a block
    // whose link cannot be followed in the complete README.
    test('a deep link to a missing manual anchor is rejected', () async {
      await expectLater(
        generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.write,
          contract: _withPrintfStringLink(
            const LocalizedText('#absent', '#отсутствует'),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('#absent'),
          ),
        ),
      );
    });

    // A repeated write must be a fixed point so generated-artifact checks do
    // not dirty a clean tree.
    test('write is idempotent', () async {
      await generateFormatReferenceArtifacts(
        root: root,
        mode: FormatReferenceGenerationMode.write,
      );
      final once = await _readTargets(root);

      await generateFormatReferenceArtifacts(
        root: root,
        mode: FormatReferenceGenerationMode.write,
      );

      expect(await _readTargets(root), once);
      expect(
        await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.check,
        ),
        isEmpty,
      );
    });

    // A generated README changed by hand must be reported by both check
    // entry points without overwriting any artifact that the developer needs
    // to inspect before deciding whether to regenerate it.
    test(
      'check and the common verifier report a stale English README',
      () async {
        await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.write,
        );
        final english = File('${root.path}/README.md');
        final russian = File('${root.path}/README.ru.md');
        final cases = File(
          '${root.path}/test/support/format_reference_cases.dart',
        );
        await english.writeAsString(
          (await english.readAsString()).replaceFirst(
            '## Brace template grammar',
            '## stale',
          ),
        );
        final englishBeforeCheck = await english.readAsString();
        final russianBeforeCheck = await russian.readAsString();
        final casesBeforeCheck = await cases.readAsString();

        final stale = await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.check,
        );

        expect(stale, contains('README.md'));
        expect(await english.readAsString(), englishBeforeCheck);
        expect(await russian.readAsString(), russianBeforeCheck);
        expect(await cases.readAsString(), casesBeforeCheck);

        final verifier =
            File('tool/verify_generated_artifacts.dart').absolute.path;
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          verifier,
        ], workingDirectory: root.path);
        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}${result.stderr}',
          contains(
            'README.md is out of date: run '
            '`dart run tool/generate_format_reference.dart --write`.',
          ),
        );
      },
    );

    // The Dart bridge reaches package-archive tests, so a stale projection
    // needs its own repair report even when both README files still match.
    test('check reports a stale conformance projection', () async {
      await generateFormatReferenceArtifacts(
        root: root,
        mode: FormatReferenceGenerationMode.write,
      );
      final cases = File(
        '${root.path}/test/support/format_reference_cases.dart',
      );
      await cases.writeAsString('stale\n');

      expect(
        await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.check,
        ),
        contains('test/support/format_reference_cases.dart'),
      );
    });

    // Generator escaping is only valid if the Dart formatter parses the
    // complete emitted bridge and leaves its bytes unchanged.
    test('generated Dart is already formatter-stable', () async {
      await generateFormatReferenceArtifacts(
        root: root,
        mode: FormatReferenceGenerationMode.write,
      );
      final generated = File(
        '${root.path}/test/support/format_reference_cases.dart',
      );
      final before = await generated.readAsString();

      // Same language version the repository is formatted with, which is not
      // the one the pubspec declares: the floor is 3.6.0 so older SDKs can
      // install the package, while the sources stay in the 3.7 style. Without
      // the flag this run reformats the artifact into the pre-3.7 style and
      // the comparison below fails on a difference the generator did not make.
      final result = await Process.run(Platform.resolvedExecutable, [
        'format',
        '--language-version=3.7',
        generated.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(await generated.readAsString(), before);
    });

    // The optional writer models a real mid-transaction filesystem failure:
    // the original error must escape, and a normal retry must repair all
    // artifacts rather than treating the partial write as authoritative.
    test(
      'a writer failure propagates and a later write repairs all targets',
      () async {
        var calls = 0;
        const failure = FileSystemException('second artifact failed');

        await expectLater(
          generateFormatReferenceArtifacts(
            root: root,
            mode: FormatReferenceGenerationMode.write,
            writeArtifact: (file, contents) async {
              calls++;
              if (calls == 2) throw failure;
              await file.writeAsString(contents);
            },
          ),
          throwsA(same(failure)),
        );

        await generateFormatReferenceArtifacts(
          root: root,
          mode: FormatReferenceGenerationMode.write,
        );
        expect(
          await generateFormatReferenceArtifacts(
            root: root,
            mode: FormatReferenceGenerationMode.check,
          ),
          isEmpty,
        );
      },
    );
  });
}

const _englishReadme = '''
# Fixture

$formatReferenceStartMarker
stale
$formatReferenceEndMarker

## Text formatting
## Character values
## Unicode text units
## Double formatting profiles
## sprintf
## Number locales
## Custom formatters
''';

const _russianReadme = '''
# Фикстура

$formatReferenceStartMarker
устарело
$formatReferenceEndMarker

## Форматирование текста
## Символьные значения
## Единицы измерения текста в Unicode
## Профили форматирования double
## sprintf
## Числовые локали
## Собственные форматтеры
''';

Future<void> _writeFixture(Directory root) async {
  await Directory('${root.path}/test/support').create(recursive: true);
  await File('${root.path}/README.md').writeAsString(_englishReadme);
  await File('${root.path}/README.ru.md').writeAsString(_russianReadme);
  await File(
    '${root.path}/test/support/format_reference_cases.dart',
  ).writeAsString('stale\n');
}

Future<Map<String, String>> _readTargets(Directory root) async {
  final result = <String, String>{};
  for (final path in [
    'README.md',
    'README.ru.md',
    'test/support/format_reference_cases.dart',
  ]) {
    result[path] = await File('${root.path}/$path').readAsString();
  }
  return result;
}

FormatReferenceContract _withPrintfStringLink(LocalizedText deepLink) {
  final original = formatReferenceContract.printf.types.first;
  final replacement = TypeContract(
    id: original.id,
    tokens: original.tokens,
    accepts: original.accepts,
    optionIds: original.optionIds,
    excludedOptionTokens: original.excludedOptionTokens,
    optionAppliesTo: original.optionAppliesTo,
    tokenAppliesTo: original.tokenAppliesTo,
    result: original.result,
    defaultPrecision: original.defaultPrecision,
    deepLink: deepLink,
    evidence: original.evidence,
  );
  return FormatReferenceContract(
    brace: formatReferenceContract.brace,
    printf: DialectContract(
      dialect: formatReferenceContract.printf.dialect,
      title: formatReferenceContract.printf.title,
      grammar: formatReferenceContract.printf.grammar,
      options: formatReferenceContract.printf.options,
      types: [replacement, ...formatReferenceContract.printf.types.skip(1)],
    ),
    limits: formatReferenceContract.limits,
    errors: formatReferenceContract.errors,
    cases: formatReferenceContract.cases,
  );
}

List<String> _dartCollectionKeys(String generated, String declaration) {
  final body =
      RegExp(
        '$declaration = .*?\\{(.*?)\\n\\};',
        dotAll: true,
      ).firstMatch(generated)!.group(1)!;
  return RegExp(
    "^  '([^']+)'(?::|,)",
    multiLine: true,
  ).allMatches(body).map((match) => match.group(1)!).toList(growable: false);
}
