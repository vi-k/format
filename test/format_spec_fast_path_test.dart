/// The specification fast path: a hand-rolled scanner that handles the common
/// ASCII specifications without the general, Unicode-aware parser.
///
/// It is an optimization, which makes it dangerous in a specific way — it can
/// only be wrong by disagreeing with the parser it stands in for, and that
/// disagreement is invisible from the outside until some template renders
/// differently than it used to. So the tests come in pairs: what the fast path
/// claims it can handle, and — through
/// `debugSimpleBuiltinFormatSpecMatchesGeneralParser` — that the two agree on
/// every specification it claims.
///
/// The other direction matters just as much. A specification the fast path
/// *declines* costs a little time and nothing else; one it accepts wrongly is a
/// bug. Hence the list of things it must leave alone: anything Unicode,
/// anything with grouping or a precision beside a width, a width too long to
/// scan, and any custom format name.
library;

import 'package:format/format.dart';
// The package URI resolves to the same library instance as the public
// export above; a relative ../lib/src import would duplicate the library.
import 'package:format/src/engine.dart' as engine;
import 'package:test/test.dart';

void main() {
  // The shortest possible specification — one character. `é` is the control:
  // it is a single character too, but not a single *code unit*, and the scanner
  // works in code units. Accepting it would mean scanning half a character.
  test('recognizes single ASCII built-in format specifications', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('d'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('%'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('é'), isFalse);
  });

  // `.Nf` is the single most common double specification, so it gets its own
  // shape in the scanner. The boundaries: a precision of zero is a precision,
  // two digits are allowed, `F` is the same conversion — while a precision with
  // no digits is malformed, and `g` is a different conversion whose layout the
  // fast path does not implement.
  test('recognizes fixed double precision without Unicode tokenization', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.0f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.20F'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.f'), isFalse);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2g'), isFalse);
  });

  // The equivalence table, and the load-bearing test of the file: for each
  // specification the fast path accepts, the seam parses it both ways and
  // compares the results field by field. A scanner that quietly lost a flag
  // would pass a "does it accept this" test and fail here.
  //
  // The list is chosen around the ambiguities rather than around the common
  // cases. A leading `0` is zero padding, unless a fill and an alignment
  // follow, in which case it is the fill — hence `'0d'`, `'00d'`, `'0<5d'`
  // side by side. A digit or a letter can be a fill too (`'1<5d'`, `'s<5s'`),
  // and `'<<'` is a `<` filled with `<`. `'07'` and `'10'` have no conversion
  // at all, and `'100000x'` sits at the width the scanner still handles.
  test('recognizes ASCII flag and width specifications and matches the general '
      'parser', () {
    const sources = [
      '10d',
      '010d',
      '+10d',
      '-10d',
      ' 10d',
      '#x',
      '#o',
      '+#010X',
      'z10d',
      '0d',
      '00d',
      '07',
      '10',
      '100000x',
      '+d',
      '10s',
      '10%',
      '>10s',
      '<10s',
      '^10s',
      '*^10s',
      '=10d',
      '0<5d',
      '1<5d',
      '<5d',
      '>+#010X',
      '<<',
      's<5s',
    ];
    for (final source in sources) {
      expect(
        engine.debugSimpleBuiltinFormatSpecMatchesGeneralParser(source),
        isTrue,
        reason: source,
      );
    }
  });

  // What the fast path must decline. Two reasons appear here: the shape is
  // beyond what it implements (a custom name, width with precision, grouping,
  // a width past its digit limit), or the input stops being ASCII — and a
  // non-ASCII character can turn up in every position, as fill, after a flag,
  // or in place of the conversion, so each position is listed separately.
  // Declining is always safe; accepting any of these would not be.
  test('leaves Unicode, custom and uncommon specifications to the general '
      'parser', () {
    const sources = [
      '10q', // custom format name
      '8.2f', // width with precision
      '10,d', // grouping
      '1234567d', // width beyond the fast path digit limit
      'é<5d', // Unicode fill
      'é^10s', // Unicode fill before caret align
      '#é', // Unicode after a flag
      '10д', // Unicode in place of a type
    ];
    for (final source in sources) {
      expect(
        engine.debugUsesSimpleBuiltinFormatSpec(source),
        isFalse,
        reason: source,
      );
    }
  });

  // The end of the chain: the same specifications through the public `format`,
  // to pin the output and not only the parse. Both signs are present for every
  // padding mode, since zero padding puts the sign before the zeros while space
  // padding puts it after — the one place a fast path is most likely to differ.
  // The last two have no conversion, where the type of the value decides both
  // the layout and the default alignment.
  test('formats fast path specifications like the general parser', () {
    expect(format('{:10d}', 1), '         1');
    expect(format('{:10d}', -1), '        -1');
    expect(format('{:010d}', 42), '0000000042');
    expect(format('{:010d}', -42), '-000000042');
    expect(format('{:+10d}', 42), '       +42');
    expect(format('{: d}', 42), ' 42');
    expect(format('{:#x}', 255), '0xff');
    expect(format('{:#X}', 255), '0XFF');
    expect(format('{:#o}', 8), '0o10');
    expect(format('{:10}', 'ab'), 'ab        ');
    expect(format('{:10}', 42), '        42');
  });
}
