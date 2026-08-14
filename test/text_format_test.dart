/// The two text conversions, `s` and `c`, and the option sets they accept.
///
/// Text formatting is where the configured [TextUnit] becomes visible: width
/// and precision count units, not code units, so the same template gives
/// different answers under `unicodeScalars` and `graphemeClusters`. Both modes
/// are exercised on values where they genuinely disagree — a combining
/// sequence, a ZWJ emoji — because on ASCII they never differ and any mode
/// confusion would go unnoticed.
///
/// The other half is rejection. `s` and `c` take a small subset of the numeric
/// option grammar, and the options they *don't* take are listed one per test:
/// silently ignoring `{:+s}` or `{:04c}` would let a template that means
/// nothing look like it worked.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  // Truncation is where the unit choice changes the *content*, not the width:
  // `'e' + U+0301` is two scalars and one cluster, so a precision of 1 either
  // strips the accent or keeps it. The default is scalars, matching Python.
  test('uses Unicode scalars by default and graphemes when configured', () {
    expect(format('{:.1s}', 'e\u0301'), 'e');

    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    expect(graphemes.format('{:.1s}', 'e\u0301'), 'e\u0301');
  });

  // All four alignments on a value whose code-unit length and scalar length
  // differ, so padding computed in the wrong unit is one character off in the
  // output. The last case is the check that the count is not code units at
  // all: the ZWJ value is four scalars, already at width 4, so it must come
  // back unpadded even though it is seven code units long.
  test('aligns text using selected Unicode text units', () {
    expect(format('{:4s}', 'é'), 'é   ');
    expect(format('{:>4s}', 'é'), '   é');
    expect(format('{:^4s}', 'é'), ' é  ');
    expect(format('{:*^4s}', 'é'), '*é**');
    expect(format('{:>4s}', 'a👩‍🔬'), 'a👩‍🔬');
  });

  // The fill character is one text unit, in whatever unit the instance counts
  // in — so a ZWJ cluster is a legal fill under `graphemeClusters` and not a
  // single anything under `unicodeScalars`. Accepting it in scalar mode would
  // mean padding by a fraction of a fill per step and a field of the wrong
  // width; rejecting it is the only consistent answer.
  test('uses grapheme fill only in grapheme mode', () {
    final graphemes = Format(textUnit: TextUnit.graphemeClusters);

    expect(
      () => format('{:👩‍🔬>3s}', 'x'),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(graphemes.format('{:👩‍🔬>3s}', 'x'), '👩‍🔬👩‍🔬x');
  });

  // The width counts units, and that bounds the result only while a unit is
  // bounded. A grapheme cluster is not: the ceiling of 100 000 units, which
  // reports itself as "too large to format safely", let a cluster fill write
  // that many copies of itself — five hundred million characters from a
  // seven-character template, and `OutOfMemoryError` one cluster larger, which
  // is not a `FormattingException` and so takes the isolate with it.
  //
  // The bound is on the specification rather than on the call, so a width that
  // is safe is safe for every value. Its size is what `unicodeScalars` could
  // already produce at the maximum width, which is why the two cases below it
  // still format.
  test('a fill of many code units bounds the width it may pad to', () {
    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    // One cluster: a letter and five thousand combining marks.
    final cluster = 'a${'́' * 5000}';

    expect(
      () => graphemes.format('{:$cluster<40s}', 'x'),
      throwsA(isA<InvalidSpecifierException>()),
    );
    // Small enough to stay inside the bound, and still padded with the cluster.
    expect(graphemes.format('{:$cluster<10s}', 'x').length, 45010);
    // What the bound is measured against: the widest scalar fill at the widest
    // width, which formatted before the bound existed and formats after it.
    expect(format('{:\u{1F600}<100000s}', 'x').length, 199999);
    expect(format('{:*<100000s}', 'x').length, 100000);
  });

  // A fill can be almost any character, which makes `{{` inside a
  // specification ambiguous: an escaped brace used as fill, or the start of a
  // nested field. The template grammar wins and the whole template is rejected
  // — this is an `InvalidFormatException`, not an invalid specifier.
  test('rejects escaped braces as literal text fill', () {
    expect(
      () => format('{:{{<5s}', 'x'),
      throwsA(isA<InvalidFormatException>()),
    );
  });

  // Zero is a precision, not a missing one: it truncates to nothing. The
  // tempting reading — treat 0 as unset and print the whole string — is the
  // bug this pins against.
  test('accepts precision zero for text', () {
    expect(format('{:.0s}', 'text'), '');
  });

  // A conversion produces text, and the specification then applies to that
  // text rather than to the original value: `null` becomes `'null'` and is then
  // truncated like any string. The stages must run in that order, and the
  // second must not notice that the value used to be null.
  test('formats converted null text with the requested precision', () {
    expect(format('{!s:.2s}', null), 'nu');
  });

  // Options that belong to numbers and mean nothing for text: a sign, the
  // alternate form, zero padding. Then three that are malformed rather than
  // inapplicable — a fill with no alignment after it, two fill characters, and
  // an alignment in the wrong position. All are rejected rather than ignored,
  // so a template written with the wrong conversion in mind fails loudly.
  for (final template in [
    '{:+s}',
    '{:#.4s}',
    '{:04s}',
    '{:.1c}',
    '{:|4s}',
    '{:ab>4s}',
    '{:4.1>}',
  ]) {
    test('rejects invalid text spec $template', () {
      expect(
        () => format(template, 'x'),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }

  // `c` turns a code point into the character it denotes, across the whole
  // range: the null character at one end, the last plane at the other (a
  // surrogate pair in the output), and a `BigInt` in place of an `int`, since
  // on the web an integer can arrive as either. Alignment still applies — the
  // result is text, and one character wide even when it is two code units.
  test('formats Unicode scalar values with c', () {
    for (final scalar in [0, 0xd7ff, 0xe000, 0x10ffff]) {
      expect(format('{:c}', scalar), String.fromCharCode(scalar));
    }
    for (final scalar in [
      BigInt.zero,
      BigInt.from(0xd7ff),
      BigInt.from(0xe000),
      BigInt.from(0x10ffff),
    ]) {
      expect(format('{:c}', scalar), String.fromCharCode(scalar.toInt()));
    }
    expect(format('{:4c}', 65), '   A');
    expect(format('{:<4c}', 65), 'A   ');
  });

  // `c` takes an integer but produces a character, so it inherits neither
  // option set: nothing numeric applies (sign, alternate form, zero padding,
  // grouping, `=` alignment) and neither does precision, which for text would
  // truncate a single character to nothing.
  for (final template in [
    '{:+c}',
    '{:zc}',
    '{:#c}',
    '{:04c}',
    '{:,c}',
    '{:.1c}',
    '{:=4c}',
  ]) {
    test('rejects unsupported c option $template', () {
      expect(
        () => format(template, 65),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }

  // The values `c` cannot turn into a character: below the range, above it,
  // and — the one that would otherwise slip through — a lone surrogate, which
  // is a valid code unit but not a valid scalar. `BigInt` is walked through the
  // same boundaries because it takes a different path to the same check, and a
  // non-integer stands for the wrong type entirely.
  //
  // Each must fail as `UnsupportedFormatValueException` with the location
  // filled in: this is a complaint about the value, and it has to say which
  // field produced it.
  for (final value in [
    -1,
    0x110000,
    0xd800,
    0xdfff,
    BigInt.from(-1),
    BigInt.from(0x110000),
    BigInt.from(0xd800),
    BigInt.from(0xdfff),
    const <int>[65],
    // A string is the wrong type a caller is most likely to pass, and the one
    // place where `c` visibly departs from "brace decides from the value's
    // type": every other specification would answer `InvalidSpecifierException`
    // here. `c` asks for a code point instead, so it answers about the value —
    // the same class `sprintf('%c', 'a')` raises.
    'a',
  ]) {
    test('rejects unsupported c value $value with a typed error', () {
      expect(
        () => format('{:c}', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', '{:c}')
              .having((error) => error.context.fragment, 'fragment', '{:c}')
              .having((error) => error.context.specifier, 'specifier', 'c'),
        ),
      );
    });
  }
}
