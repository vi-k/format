import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  test('literal-only template compiles to a single literal op', () {
    expect(
      debugCompiledProgramDescription(
        'plain text',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal'],
    );
  });

  test('empty spec compiles to the dynamic value op', () {
    expect(
      debugCompiledProgramDescription(
        '{} {name}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['dynamic', 'literal', 'dynamic'],
    );
  });

  test('fields compile to fallback ops in the skeleton', () {
    // Both fields stay on fallback even after Tasks 4-8: a floating spec
    // and a dynamic nested spec are outside the v1 hot core.
    expect(
      debugCompiledProgramDescription(
        'a{:.2f}b{:{}d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'fallback', 'literal', 'fallback'],
    );
  });

  test('static integer specs compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:10d}|{:x}|{:<5b}|{:#o}|{:+03d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['int:d:w10', 'literal', 'int:x', 'literal', 'int:b:w5', 'literal',
          'int:o', 'literal', 'int:d:w3'],
    );
  });

  test('non-hot integer specs stay on fallback', () {
    // NB: single-code-unit fills (including precomposed 'é') compile hot;
    // only multi-unit fills fall back — that case is covered in Task 6.
    for (final spec in ['{:,d}', '{:n}', '{:.2d}', '{:{}d}']) {
      expect(
        debugCompiledProgramDescription(
          spec,
          printf: false,
          textUnit: TextUnit.unicodeScalars,
        ),
        ['fallback'],
        reason: spec,
      );
    }
  });

  test('static text specs compile to text ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:s}|{:<10s}|{:^7.3s}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['text:s', 'literal', 'text:s:w10', 'literal', 'text:s:w7:p3'],
    );
  });

  test('text specs with numeric options stay on fallback', () {
    // The combining fill (e + U+0301) is written as an explicit escape so
    // it stays two code units regardless of editor/source normalization;
    // a precomposed 'é' is one code unit and would compile hot instead.
    for (final spec in [
      '{:=10s}', '{:+s}', '{:#s}', '{:,s}', '{:e\u0301^10s}',
    ]) {
      expect(
        debugCompiledProgramDescription(
          spec,
          printf: false,
          textUnit: TextUnit.unicodeScalars,
        ),
        ['fallback'],
        reason: spec,
      );
    }
  });

  test('IR path and legacy path agree on a mixed template', () {
    const template = '{} + {} = {answer:>6}';
    final ir = formatWith(template, positional: [2, 3], named: {'answer': 5});
    final legacy = debugFormatBraceWithoutIr(
      template,
      defaultFormat,
      positional: [2, 3],
      named: {'answer': 5},
    );
    expect(ir, legacy);
  });

  test('printf skeleton: literals merge, %% folds into literal', () {
    // %f stays on fallback even after Tasks 7-8 (doubles are out of the
    // v1 hot core), so this expectation survives the whole plan.
    expect(
      debugCompiledProgramDescription(
        'x=%f, done 100%%',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'fallback', 'literal'],
    );
  });

  test('printf IR path agrees with the legacy path', () {
    const template = '%s scored %05.1f%%';
    final ir = sprintf(template, 'Ann', 97.5);
    final legacy = debugFormatPrintfWithoutIr(template, defaultFormat, [
      'Ann',
      97.5,
    ]);
    expect(ir, legacy);
  });
}
