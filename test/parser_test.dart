/// The brace template grammar, checked at the parser rather than through the
/// formatted output.
///
/// A template is untrusted input — it can come from a config file, a log format
/// string, a translation catalogue — so what the parser accepts and rejects is
/// a contract in itself, and the rejections matter as much as the acceptances.
/// Going through [format] would only show that a bad template failed somehow;
/// [debugParseBraceTemplate] shows the parse tree, which is how a template that
/// parses into the *wrong* structure gets caught rather than a template that
/// happens to render the same anyway.
///
/// The interesting territory is where braces nest: a specification can contain
/// fields, and both escapes and nested fields are spelled with braces, so the
/// grammar has to stay decidable in cases like `'{0:{{{width}}}}'`.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  // Every part of the field grammar in one field, so that the parts are shown
  // to compose: a root name, an attribute step, an item step, a conversion and
  // a nested specification. Each is checked as its own node — a parse that
  // swallowed `items[0]` into the root name would still render correctly for
  // some values and be wrong here.
  test('parses nested fields and lookup chains', () {
    final debug = debugParseBraceTemplate('{user.items[0].name!r:{width}}');

    expect(debug, contains('root=user'));
    expect(debug, contains('attribute=items'));
    expect(debug, contains('item=0'));
    expect(debug, contains('conversion=r'));
    expect(debug, contains('nested=width'));
  });

  // An index is parsed as an int, which gives it a ceiling the grammar itself
  // does not have. The two sides of that ceiling must fail differently: a
  // representable index that no value was passed for is a *missing argument*,
  // while an index that cannot be an int at all is a *malformed template* — the
  // first is the caller's data, the second is the caller's template.
  test('accepts a padded index and rejects one past the 64-bit range', () {
    expect(formatWith('{0000000005}', positional: [0, 1, 2, 3, 4, 5]), '5');
    // 9223372036854775807 is the last index that fits; the next one, and
    // any longer run of digits, must be rejected.
    expect(
      () => formatWith('{9223372036854775807}'),
      throwsA(isA<MissingFormatArgumentException>()),
    );
    for (final index in ['9223372036854775808', '12345678901234567890']) {
      expect(
        () => formatWith('{$index}'),
        throwsA(isA<InvalidFormatException>()),
        reason: index,
      );
    }
  });

  // Indexes up to fifteen digits are computed by arithmetic and wider ones
  // through BigInt, because the short path is three allocations cheaper and
  // fifteen digits still fit a JavaScript double exactly. That split is an
  // implementation detail and must stay one: the values either side of it are
  // reported identically, and a template does not get to notice where the
  // parser changed its mind. Checked through `key`, which carries the parsed
  // number rather than the digits it came from.
  test('reads the same index either side of the arithmetic cutoff', () {
    for (final crossing
        in const {
          '999999999999999': 999999999999999, // fifteen digits
          '1000000000000000': 1000000000000000, // sixteen, the wide path
          '0000000000000000005': 5, // nineteen digits, all but one a zero
        }.entries) {
      final digits = crossing.key;
      final value = crossing.value;
      try {
        formatWith('{$digits}');
        fail('expected a missing argument for $digits');
      } on MissingFormatArgumentException catch (error) {
        expect(error.key, value, reason: digits);
        expect(error.context.fragment, '{$digits}', reason: digits);
      }
    }
  });

  test('rejects an unbounded digit run without parsing it as a number', () {
    // A template is untrusted input, so the cost of rejecting it must not
    // scale with the size of the number it spells.
    for (final length in [1000, 100000]) {
      expect(
        () => formatWith('{${'9' * length}}'),
        throwsA(isA<InvalidFormatException>()),
        reason: '$length digits',
      );
      expect(
        () => formatWith('{0[${'9' * length}]}', positional: const [<int>[]]),
        throwsA(isA<InvalidFormatException>()),
        reason: '$length digits in an item key',
      );
    }
  });

  // An unknown conversion letter is well-formed grammar with no meaning, so
  // the parser keeps it instead of rejecting it: the complaint belongs to the
  // stage that knows which conversions exist, and it can then name the letter.
  // Rejecting here would turn a precise processing error into a parse error.
  test('preserves an unknown conversion for typed processing errors', () {
    final debug = debugParseBraceTemplate('{value!q}');

    expect(debug, contains('conversion=q'));
  });

  // Names are Unicode identifiers, not ASCII: Cyrillic and Greek roots,
  // attributes and item keys all parse. The escaped braces wrapped around them
  // are there to keep the two brace meanings apart in the same template.
  test('parses escaped braces and Unicode names', () {
    final debug = debugParseBraceTemplate(
      '{{{\u0438\u043c\u044f.\u03b4[\u043a\u043b\u044e\u0447]}}}',
    );

    expect(debug, contains('literal={'));
    expect(debug, contains('root=\u0438\u043c\u044f'));
    expect(debug, contains('attribute=\u03b4'));
    expect(debug, contains('item=\u043a\u043b\u044e\u0447'));
    expect(debug, contains('literal=}'));
  });

  // Python's identifier rules admit any Unicode decimal digit, and normalize
  // it: Arabic-Indic `١٢٣` is the name `123`. This is the one place the
  // generated identifier tables are visible from the outside, and it is why
  // they are generated rather than hand-written — see `tool/`.
  test('accepts decimal digits from the Python identifier tables', () {
    final debug = debugParseBraceTemplate('{\u0661\u0662\u0663[\u0664]}');

    expect(debug, contains('root=123'));
    expect(debug, contains('item=4'));
  });

  // Inside `[...]` the grammar stops applying identifier rules: the key runs to
  // the closing bracket, spaces and all, because a map key is data and not a
  // name. Quoting it would be the mistake — `'any key'` would then include the
  // quotes.
  test('allows arbitrary unquoted item keys and named nested fields', () {
    final debug = debugParseBraceTemplate(
      '{record[any key]:{width}.{precision}}',
    );

    expect(debug, contains('root=record'));
    expect(debug, contains('item=any key'));
    expect(debug, contains('nested=width'));
    expect(debug, contains('nested=precision'));
  });

  // Nesting is one level deep, so the parser does not have to count braces: the
  // first `}` after a nested field closes it. `'{0:{1:}}'` is the case that
  // makes this visible — the inner field carries a colon of its own, and the
  // parse must still end up with `1` nested inside `0`.
  test('uses the first closing brace to close a nested specification', () {
    final debug = debugParseBraceTemplate('{0:{1:}}');

    expect(debug, contains('root=0'));
    expect(debug, contains('nested=1'));
  });

  // Escapes work inside a specification too, and there they are ambiguous with
  // the nested-field syntax: `'{0:{{}}}'` is a fill of literal `{}`, not a
  // nested field. The two are told apart by doubling, not by position.
  test('parses escaped braces in a specification', () {
    final debug = debugParseBraceTemplate('{0:{{}}}');

    expect(debug, contains('root=0'));
    expect(debug, contains('literal={}'));
  });

  // The hardest case in the grammar: five closing braces in a row, of which
  // one closes the field, two are an escape and two more are the nested field
  // and the outer field. Getting the split wrong here still yields a template
  // that parses — into something else — which is why the parts are asserted
  // separately rather than as a rendered string.
  test('parses escaped braces beside a nested specification', () {
    final debug = debugParseBraceTemplate('{0:{{{width}}}}');

    expect(debug, contains('literal={'));
    expect(debug, contains('nested=width'));
    expect(debug, contains('literal=}'));
  });

  // A rejection is only useful if it says where. The exception carries the
  // whole template, the offset of the field and the fragment that failed, so a
  // bad format string in a config file can be pointed at rather than described.
  test('reports each parser failure with template offset and fragment', () {
    try {
      debugParseBraceTemplate('{ name }');
      fail('expected invalid format');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, '{ name }');
      expect(error.context.offset, 1);
      expect(error.context.fragment, ' name ');
    }
  });

  // The conversion character was the one place in the parser that read a
  // UTF-16 code unit instead of a scalar, so an astral conversion was split
  // down the middle of its own surrogate pair: the rejection then named an
  // offset inside a character and carried half of one as its fragment. A
  // diagnostic that cannot even be printed is worse than the error it
  // describes, so both properties are pinned rather than the exact wording.
  test('reads an astral conversion as one scalar, not half a pair', () {
    const template = '{!\u{1F600}}';

    // Parsed like any other unknown conversion, per the test above: the
    // grammar is well-formed, so the complaint belongs to the stage that
    // knows which conversions exist.
    expect(debugParseBraceTemplate(template), contains('conversion=\u{1F600}'));

    try {
      format(template, 1);
      fail('expected an unsupported conversion');
    } on UnsupportedConversionException catch (error) {
      expect(error.context.conversion, '\u{1F600}');
      expect(
        _hasLoneSurrogate(error.context.fragment ?? ''),
        isFalse,
        reason: 'фрагмент диагностики обязан быть валидным UTF-16',
      );
    }
  });

  // Mixing numbering styles is rejected by the two templates below, and the
  // rejection used to carry an empty fragment: both call sites reported a
  // zero-width span. An empty fragment is the one thing a diagnostic must not
  // be — it turns "here is what failed" into "something failed" — so the span
  // now runs from the opening brace through the character that revealed the
  // style, which is the closing brace in both of these.
  for (final (template, fragment) in [('{}{0}', '{0}'), ('{0}{}', '{}')]) {
    test('names the field that switched numbering: $template', () {
      try {
        debugParseBraceTemplate(template);
        fail('expected invalid format');
      } on InvalidFormatException catch (error) {
        expect(error.context.fragment, fragment);
        expect(error.context.template, template);
      }
    });
  }

  // Escapes behave differently on the two sides of a `:`, and the difference
  // is a documented rule rather than an accident: what ends a specification
  // is the first unescaped `}`, so inside one the parser has to know whether
  // a `}}` closes an escape or is the end plus a stray brace. Ordinary text
  // has no boundary to find, so there the two forms are independent.
  test('balances escaped braces inside a specification, not outside', () {
    expect(format('{{', 1), '{');
    expect(format('}}', 1), '}');

    final debug = debugParseBraceTemplate('{0:a{{b}}c}');
    expect(debug, contains('root=0'));
    expect(debug, contains('literal=a{b}c'));
  });

  // The price of that rule, and the reason it is in the README: a payload
  // cannot carry a lone brace in any spelling. Each template below fails for
  // its own reason — an escape left open, a specification ended early by the
  // first `}`, a `{` starting a nested field — which is why they are listed
  // rather than folded into one case.
  for (final template in ['{0:a{{b}', '{0:a}}b}', '{0:a{b}', '{0:a}b}']) {
    test('refuses an unbalanced brace in a specification: $template', () {
      expect(
        () => debugParseBraceTemplate(template),
        throwsA(isA<InvalidFormatException>()),
      );
    });
  }

  // The rejection table, one test per template so a newly accepted one names
  // itself in the failure. Each line is a different way to be invalid: mixing
  // automatic and manual numbering (which would otherwise silently renumber the
  // rest of the template), nesting deeper than one level, quoting a name,
  // doubling or omitting a separator, an empty item key, an unbalanced escape,
  // a conversion with no letter or two, and a brace left open or closed alone.
  for (final template in [
    '{0} {}',
    '{} {1}',
    '{:{0}}',
    '{:{:{}}}',
    '{ name }',
    "{'name'}",
    '{user["name"]}',
    '{user..name}',
    '{0[]}',
    '{0:{{}',
    '{0:}}x}',
    '{user[missing}',
    '{user!}',
    '{user!qq}',
    '{user',
    'user}',
  ]) {
    test('rejects invalid field grammar: $template', () {
      expect(
        () => debugParseBraceTemplate(template),
        throwsA(isA<InvalidFormatException>()),
      );
    });
  }
}

/// Whether [text] contains a surrogate that is not part of a valid pair.
///
/// Lives here rather than in the engine because it is the property a
/// diagnostic must have, not one the formatter produces: a fragment sliced
/// out of a template can only be printed or logged if its UTF-16 is
/// well-formed.
bool _hasLoneSurrogate(String text) {
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    final isHigh = unit >= 0xd800 && unit <= 0xdbff;
    final isLow = unit >= 0xdc00 && unit <= 0xdfff;
    if (!isHigh && !isLow) continue;
    if (isLow || index + 1 >= text.length) return true;
    final next = text.codeUnitAt(index + 1);
    if (next < 0xdc00 || next > 0xdfff) return true;
    index++;
  }
  return false;
}
