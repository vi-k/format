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

  test('dynamic nested specs stay on fallback', () {
    // The floating spec became hot with the double ops; a dynamic nested
    // spec stays on fallback because it cannot be classified at compile
    // time.
    expect(
      debugCompiledProgramDescription(
        'a{:.2f}b{:{}d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'double:f:p2', 'literal', 'fallback'],
    );
  });

  test('static integer specs compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:10d}|{:x}|{:<5b}|{:#o}|{:+03d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'int:d:w10',
        'literal',
        'int:x',
        'literal',
        'int:b:w5',
        'literal',
        'int:o',
        'literal',
        'int:d:w3',
      ],
    );
  });

  test('grouped integer specs compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:,d}|{:_x}|{:010,d}|{:0>10,d}|{:=12,d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'int:d:g,3',
        'literal',
        'int:x:g_4',
        'literal',
        // Zero padding is regrouped with the digits only under '=' with a
        // '0' fill: '0>' fills around them, '=' with the default fill pads
        // between the sign and them.
        'int:d:w10:g,3z',
        'literal',
        'int:d:w10:g,3',
        'literal',
        'int:d:w12:g,3',
      ],
    );
  });

  test('n compiles to the int op, which checks the locale per call', () {
    expect(
      debugCompiledProgramDescription(
        '{:n}|{:12n}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['int:n', 'literal', 'int:n:w12'],
    );
  });

  test('non-hot integer specs stay on fallback', () {
    // NB: single-code-unit fills (including precomposed 'é') compile hot;
    // only multi-unit fills fall back — that case is covered in Task 6.
    // ',' is rejected outside 'd', so it keeps its per-call error.
    for (final spec in ['{:,x}', '{:.2d}', '{:{}d}']) {
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
      '{:=10s}',
      '{:+s}',
      '{:#s}',
      '{:,s}',
      '{:e\u0301^10s}',
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

  test('static double specs compile to double ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:.2f}|{:e}|{:10.3G}|{:.1%}|{:.3}|{:10}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'double:f:p2',
        'literal',
        'double:e',
        'literal',
        'double:G:w10:p3',
        'literal',
        'double:%:p1',
        'literal',
        'double:-:p3',
        'literal',
        'double:-:w10',
      ],
    );
  });

  test('grouped double specs compile to double ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:,.2f}|{:012,.2f}|{:0>12,.2f}|{:,e}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'double:f:p2:g,',
        'literal',
        'double:f:w12:p2:g,z',
        'literal',
        'double:f:w12:p2:g,',
        'literal',
        'double:e:g,',
      ],
    );
  });

  test('non-hot double specs stay on fallback', () {
    // The combining fill (e + U+0301) is written as an explicit escape so
    // it stays two code units regardless of editor/source normalization:
    // the parser rejects it under unicodeScalars and it is a multi-unit
    // fill under graphemeClusters, so it never compiles hot. A precomposed
    // single-code-unit fill would compile hot instead.
    for (final spec in ['{:.2_f}', '{:.2n}', '{:e\u0301^10.2f}']) {
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

  test('oversized double precision stays on fallback', () {
    expect(
      debugCompiledProgramDescription(
        '{:.100001f}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['fallback'],
    );
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
    // The point of this case is the literal merging around a conversion and
    // the %% fold, not what %f classifies as: %f became a hot double op with
    // the printf double ops.
    expect(
      debugCompiledProgramDescription(
        'x=%f, done 100%%',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'double:f', 'literal'],
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

  test('%s compiles to the string op, static and dynamic', () {
    expect(
      debugCompiledProgramDescription(
        '%s|%10s|%-10s|%.3s|%*s|%.*s',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'str',
        'literal',
        'str:w10',
        'literal',
        'str:w10',
        'literal',
        'str:p3',
        'literal',
        'str:w*',
        'literal',
        'str:p*',
      ],
    );
  });

  test('printf integers compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '%d|%10d|%-10d|%010d|%+d|% d|%#x|%#o|%.3d|%*d|%u|%X',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'int:d',
        'literal',
        'int:d:w10',
        'literal',
        'int:d:w10',
        'literal',
        'int:d:w10',
        'literal',
        'int:d',
        'literal',
        'int:d',
        'literal',
        'int:x',
        'literal',
        'int:o',
        'literal',
        'int:d:p3',
        'literal',
        'int:d:w*',
        'literal',
        'int:u',
        'literal',
        'int:X',
      ],
    );
  });

  test('printf doubles compile to double ops, %a stays fallback', () {
    expect(
      debugCompiledProgramDescription(
        '%f|%.2f|%-10.2f|%010.2f|%e|%.3G|%*.*f|%a',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      [
        'double:f',
        'literal',
        'double:f:p2',
        'literal',
        'double:f:w10:p2',
        'literal',
        'double:f:w10:p2',
        'literal',
        'double:e',
        'literal',
        'double:G:p3',
        'literal',
        'double:f:w*:p*',
        'literal',
        'fallback',
      ],
    );
  });
}
