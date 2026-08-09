/// The printf grammar, checked at the parser rather than through output — the
/// counterpart of `parser_test.dart` for the other dialect.
///
/// A printf conversion is a fixed sequence: flags, width, precision, type. What
/// makes it worth testing at this level is that the sequence is *almost*
/// unambiguous. Flags may repeat and collide, a width may be a literal or an
/// asterisk, and the type is a single letter — so a template that means nothing
/// still looks like a conversion, and the parser has to decide which of three
/// answers it gives: accept it, reject it as bad grammar
/// (`InvalidFormatException`), or reject it as an option that does not apply to
/// this conversion (`InvalidSpecifierException`). Those two rejections are
/// different complaints and are kept apart deliberately: `%q` is not a
/// conversion at all, while `%+u` is a real conversion with an option that
/// cannot mean anything for it.
///
/// The three tables are the core of the file: every option each conversion
/// accepts, every combination that parses but is inapplicable, and every shape
/// that is not printf at all — length modifiers (`%llx`), positional arguments
/// (`%2$d`), conversions from other languages (`%b`, `%n`, `%p`), non-ASCII
/// digits.
///
/// The rest is the location contract. printf templates are frequently built at
/// runtime, so an offset that is off by one — or a fragment that stops before
/// the conversion letter — makes a failure much harder to place. Several cases
/// put astral characters before and inside the fragment, since offsets are in
/// UTF-16 code units and a surrogate pair is where a naive count drifts.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  // The full conversion shape in one token: four flags, a dynamic width, a
  // dynamic precision and a type. Each part is asserted separately, so a parse
  // that folded the width and precision together — or lost a flag — is visible
  // as a missing node rather than as an equivalent-looking whole.
  test('parses flags and dynamic options in consumption order', () {
    final debug = debugParsePrintfTemplate('%-+#0*.*f');

    expect(debug, contains('flags=-+#0'));
    expect(debug, contains('width=dynamic'));
    expect(debug, contains('precision=dynamic'));
    expect(debug, contains('type=f'));
  });

  // The complete conversion alphabet, in one template, including `%%`. This is
  // the inventory: a letter dropped from the parser stops being a conversion
  // and silently becomes literal text, which no output test would notice
  // because the literal often looks similar.
  test('parses every supported conversion type and case', () {
    final debug = debugParsePrintfTemplate(
      '%c %s %d %i %u %o %x %X %a %A %e %E %f %F %g %G %%',
    );

    for (final type in [
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
    ]) {
      expect(debug, contains('type=$type'));
    }
  });

  // Offsets are UTF-16 code units, so the emoji before the first conversion
  // moves every later offset by two rather than one — the number a
  // rune-counting parser would get. Adjacent literal text is coalesced into one
  // node, but `%%` still breaks the run, so the node list here is
  // literal / conversion / literal / conversion with exact offsets for each.
  test('preserves UTF-16 offsets fragments and coalesced literals', () {
    final debug = debugParsePrintfTemplate('\ud83d\ude00a%%b%d');

    expect(
      debug,
      contains('literal(offset=0,fragment=\ud83d\ude00a,text=\ud83d\ude00a)'),
    );
    expect(debug, contains('conversion(offset=3,fragment=%%'));
    expect(debug, contains('literal(offset=5,fragment=b,text=b)'));
    expect(debug, contains('conversion(offset=6,fragment=%d'));
  });

  // A precision with no digits is zero, not absent — `%.f` prints no fractional
  // digits at all. Treating it as unset would give six, which is C's default
  // and the opposite of what was written.
  test('parses static and empty precision as literal options', () {
    final debug = debugParsePrintfTemplate('%12.34f %.f');

    expect(debug, contains('width=12'));
    expect(debug, contains('precision=34'));
    expect(debug, contains('precision=0'));
  });

  // Flags are a set, not a sequence: repeats collapse and the order they were
  // written in is not preserved, which is what lets the layout resolve
  // precedence by rule. The trailing `d` after the type is literal text — the
  // conversion ends at its letter.
  test('collapses repeated legal flags', () {
    final debug = debugParsePrintfTemplate('%000---++dd');

    expect(debug, contains('flags=-+0'));
    expect(debug, contains('type=d'));
  });

  // A parsed template is shared through the cache, so anything reachable from
  // it has to be unmodifiable: one caller mutating a node list would change
  // every later call on that template, anywhere in the program.
  //
  // Conversion flags are an immutable int bitmask by construction, so only
  // the node list needs a mutation seam.
  test('keeps AST collections immutable', () {
    expect(
      () => debugClearPrintfTemplateNodes('%--d'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  // The acceptance table: for each conversion, every option it is allowed to
  // carry, written as one maximal template. One test per line so that a
  // conversion which stops accepting an option names itself. Read together with
  // the rejection table below — the two are complementary, and a change to
  // either without the other is a gap.
  group('accepts the exact conversion option table', () {
    for (final template in [
      '%-5c',
      '%-5.2s',
      '%-+ 05.2d',
      '%-05.2i',
      '%-05.2u',
      '%-#05.2o',
      '%-#05.2x',
      '%-#05.2X',
      '%-+ #05.2a',
      '%-+ #05.2A',
      '%-+ #05.2e',
      '%-+ #05.2E',
      '%-+ #05.2f',
      '%-+ #05.2F',
      '%-+ #05.2g',
      '%-+ #05.2G',
      '%%',
    ]) {
      test(
        template,
        () => expect(debugParsePrintfTemplate(template), isNotEmpty),
      );
    }
  });

  // Well-formed conversions carrying an option that cannot mean anything for
  // them: a sign on a character or an unsigned value, a precision on `%c`, the
  // alternate form on a string or a decimal, zero padding on a string, and any
  // option at all on `%%`, which is not a conversion of a value. These are
  // *specifier* failures — the template is grammatical, the combination is not
  // — and reporting them as grammar errors would point the reader at the wrong
  // thing to fix.
  group('rejects syntactically valid but inapplicable options', () {
    for (final template in [
      '%+c',
      '%.1c',
      '%#s',
      '%#d',
      '%+u',
      '% u',
      '%#u',
      '%+x',
      '%1%',
      '%05s',
      '%.*c',
      '%*%',
    ]) {
      test(template, () {
        expect(
          () => debugParsePrintfTemplate(template),
          throwsA(isA<InvalidSpecifierException>()),
        );
      });
    }
  });

  // Shapes that are not this dialect. Length modifiers (`%llx`) and positional
  // arguments (`%2$d`) come from C and are refused rather than ignored, since
  // ignoring them would change which argument each conversion consumes. `%n`
  // writes through a pointer and has no meaning here at all; `%p`, `%b` and
  // `%B` belong to other languages. The rest are incomplete conversions and
  // non-ASCII digits, which are digits to a Unicode-aware reader and not to
  // this grammar.
  group('rejects invalid printf grammar', () {
    for (final template in [
      '%',
      '%q',
      '%n',
      '%p',
      '%llx',
      r'%2$d',
      '%b',
      '%B',
      '%-+5',
      '%.',
      r'%-5$d',
      '%١d',
      '%１２d',
    ]) {
      test(template, () {
        expect(
          () => debugParsePrintfTemplate(template),
          throwsA(isA<InvalidFormatException>()),
        );
      });
    }
  });

  // A grammar failure inside a larger template: the offset points at the `%`,
  // not at the start of the string, and the fragment runs to the terminal
  // letter so the reader sees the whole broken conversion. The specifier names
  // what went wrong (`l`) while the conversion names what it was trying to be.
  test('reports complete typed context for invalid grammar', () {
    try {
      debugParsePrintfTemplate('x%llx');
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, 'x%llx');
      expect(error.context.offset, 1);
      expect(error.context.fragment, '%llx');
      expect(error.context.specifier, 'l');
      expect(error.context.conversion, 'x');
    }
  });

  // The same location contract for the other rejection kind, where the
  // specifier and the conversion are the same letter — the conversion is
  // known, it is the option that does not belong to it.
  test('reports complete typed context for invalid specifiers', () {
    try {
      debugParsePrintfTemplate('x%+u');
      fail('Expected InvalidSpecifierException.');
    } on InvalidSpecifierException catch (error) {
      expect(error.context.template, 'x%+u');
      expect(error.context.offset, 1);
      expect(error.context.fragment, '%+u');
      expect(error.context.specifier, 'u');
      expect(error.context.conversion, 'u');
    }
  });

  // Where a too-large option is refused, and why it is not the parser. See the
  // note in the body: the platforms cannot agree at parse time, so the decision
  // moves to formatting, where all three sources of an oversized option — a
  // long literal, a value past the ceiling, and a dynamic `%*d` — meet the same
  // refusal with the same context.
  test('defers overflowing numeric options to the same refusal', () {
    // An option too long to be an int is not a different failure from one
    // merely past the safety ceiling, and on the web it cannot be told
    // apart: an int is a double there, so the parse rounds instead of
    // failing. The parser therefore accepts the grammar and the formatter
    // refuses the option — which is what `%100001d` already did on both
    // platforms, and what a `%*d` resolved to the same size does.
    final enormous = '9' * 2000;
    for (final entry in [
      (template: '%${enormous}d', role: 'width'),
      (template: '%.${enormous}d', role: 'precision'),
    ]) {
      expect(
        () => debugParsePrintfTemplate(entry.template),
        returnsNormally,
        reason: entry.template,
      );
      expect(
        () => sprintf(entry.template, 1),
        throwsA(
          isA<InvalidSpecifierException>()
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.role,
              )
              .having((error) => error.context.conversion, 'conversion', 'd')
              .having(
                (error) => error.context.template,
                'template',
                entry.template,
              ),
        ),
        reason: entry.template,
      );
    }
  });

  // The location table, and the hardest part of the contract: the fragment has
  // to run to the terminal letter even when the parser gave up long before it,
  // and the conversion has to be named even though the template was rejected.
  // Otherwise the message describes a prefix, and the reader has to find the
  // rest of the conversion themselves.
  //
  // Astral characters appear before the conversion, inside it, and after the
  // positional marker, because offsets are counted in UTF-16 code units and
  // each position is a separate chance for a surrogate pair to shift the
  // arithmetic. The `%` alone at the end is the case with no letter to name.
  test('reports full invalid fragments and known terminal conversions', () {
    for (final entry in [
      (
        template: r'x%2$d',
        offset: 1,
        fragment: r'%2$d',
        specifier: r'$',
        conversion: 'd',
      ),
      (
        template: 'x%q',
        offset: 1,
        fragment: '%q',
        specifier: 'q',
        conversion: 'q',
      ),
      (
        template: 'x%',
        offset: 1,
        fragment: '%',
        specifier: null,
        conversion: null,
      ),
      (
        template: '\ud83d\ude00%llx',
        offset: 2,
        fragment: '%llx',
        specifier: 'l',
        conversion: 'x',
      ),
      (
        template: '%l\ud83d\ude00d',
        offset: 0,
        fragment: '%l\ud83d\ude00d',
        specifier: 'l',
        conversion: 'd',
      ),
      (
        template:
            r'%2$'
            '\ud83d\ude00d',
        offset: 0,
        fragment:
            r'%2$'
            '\ud83d\ude00d',
        specifier: r'$',
        conversion: 'd',
      ),
    ]) {
      try {
        debugParsePrintfTemplate(entry.template);
        fail('Expected InvalidFormatException for ${entry.template}.');
      } on InvalidFormatException catch (error) {
        expect(error.context.template, entry.template);
        expect(error.context.offset, entry.offset);
        expect(error.context.fragment, entry.fragment);
        expect(error.context.specifier, entry.specifier);
        expect(error.context.conversion, entry.conversion);
      }
    }
  });
}
