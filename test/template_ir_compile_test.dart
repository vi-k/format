// What each template compiles to — the classifier, not the output.
//
// A parsed template is compiled into a program of ops, and each field ends up
// either on a specialized op (`int`, `double`, `text`, `str`, `dynamic`) or on
// `fallback`, which runs the general path. Both outcomes are correct; the
// difference is speed, and it is invisible from the outside. That is exactly
// why it needs its own tests: a specification that silently stops compiling hot
// keeps producing the right string while the optimization it was written for
// quietly stops applying, and only a benchmark would ever notice.
//
// So `debugCompiledProgramDescription` renders the program as a list of
// op descriptions, and the tests assert those lists exactly. The descriptions
// carry the compiled details too (`int:d:w10:g,3z` — decimal, width 10, comma
// grouping by three, zero padding regrouped with the digits), which means a
// field that compiles hot with the *wrong* parameters is caught here rather
// than as a wrong string somewhere downstream.
//
// The fallback lists matter as much as the hot ones. Each entry is a shape the
// compiler must decline — a dynamic nested specification it cannot see at
// compile time, a multi-code-unit fill, an option combination the hot op does
// not implement, a precision past the safety ceiling — and accepting one of
// them wrongly is a correctness bug, not a performance one.
//
// Two tests here compare the IR against the legacy path directly. They are a
// smoke check; the real comparison happens at scale in `template_ir_diff_test`
// and `template_ir_fuzz_test`.

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  // The degenerate program: no fields, so one literal op and nothing else.
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

  // A field with no specification cannot be classified by type — the value
  // decides at runtime — so it compiles to the `dynamic` op rather than to a
  // fallback: still specialized, just specialized on "anything".
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

  // The integer shapes that compile hot, with their parameters visible: width,
  // radix, alignment and sign all land in the op rather than being re-derived
  // per call. `{:+03d}` compiling to `int:d:w3` is the interesting one — the
  // sign and the zero fill are folded into the op's own padding arithmetic.
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

  // Grouping compiles hot, with the separator and its group size in the op —
  // three for decimal, four for hexadecimal. The three padded variants are the
  // point: they differ only in fill and alignment, and only one of them
  // regroups the padding with the digits.
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

  // `n` is hot even though its layout depends on the locale: the op carries the
  // conversion and checks the locale on each call, delegating only when it is
  // not the canonical C one. The alternative — always falling back — would put
  // every localized number on the slow path forever.
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
    // Three reasons to decline, one per entry: an option the hot op does not
    // implement, an option that is invalid for the conversion (',' outside
    // 'd', which keeps its per-call error rather than being rejected at
    // compile time), and a nested specification unknown until the call.
    //
    // NB: single-code-unit fills (including precomposed 'é') compile hot;
    // only multi-unit fills fall back — see the text and double cases below.
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

  // Text shapes: bare, with a width and alignment, and with both a width and a
  // precision. All three carry their parameters into the op.
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

  // Every double conversion compiles hot, including the two with no conversion
  // letter (`double:-`), where the shortest digits are used but the layout is
  // still known at compile time. Percent is one of them, so its scaling and
  // suffix are part of the op rather than a wrapper around it.
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

  // Grouping is hot for doubles too, and the `z` marker records the same
  // distinction as on the integer side: zero padding is regrouped with the
  // digits only when the fill is the default under an implied `=`, not when an
  // explicit fill and alignment surround them.
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

  // A precision past the safety ceiling is not compiled hot: the refusal lives
  // on the general path, and duplicating it into the op would mean two places
  // that must agree about the limit.
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

  // A smoke comparison against the legacy path on a template that mixes
  // automatic numbering, a named field and an alignment. The exhaustive version
  // of this is `template_ir_diff_test`; this one fails fast if the two paths
  // have diverged at all.
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

  // The printf half of the smoke comparison, on a template combining a string,
  // zero-padded floating layout and an escaped percent.
  test('printf IR path agrees with the legacy path', () {
    const template = '%s scored %05.1f%%';
    final ir = sprintf(template, 'Ann', 97.5);
    final legacy = debugFormatPrintfWithoutIr(template, defaultFormat, [
      'Ann',
      97.5,
    ]);
    expect(ir, legacy);
  });

  // printf strings, including the dynamic forms: a `*` width or precision still
  // compiles hot, with the op recording that the value comes from the argument
  // list (`w*`, `p*`) rather than from the template.
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

  // The printf integer conversions and their flags. Several distinct templates
  // compile to the same op — `%10d`, `%-10d` and `%010d` all become
  // `int:d:w10` — because alignment and fill are layout the op applies from
  // flags it already holds; the description shows what the op is keyed on.
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

  // The printf double conversions, and the one that stays on the general path:
  // `%a` has no hot op. Hexadecimal float layout shares almost nothing with the
  // decimal conversions, so it would be a second implementation of its own
  // rather than a specialization of theirs.
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
