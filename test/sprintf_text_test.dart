/// The printf text conversions, `%s` and `%c`, and the dialect's own invention:
/// options taken from the argument list.
///
/// `%*.*s` is where printf differs structurally from the brace dialect. A
/// single conversion can consume three values, in a fixed order — width, then
/// precision, then the value — and each of them can be missing, of the wrong
/// type, or absurdly large. So the interesting property is not the layout,
/// which mirrors `text_format_test.dart`, but the *consumption order* and how a
/// failure at each position is reported: by argument index, since a printf
/// template gives the reader no names to go by.
///
/// A dynamic width also carries a meaning static syntax cannot: a negative
/// width means left alignment, and a negative precision means none at all.
/// Those are C's rules, and they make the sign of an argument change the layout
/// rather than being rejected.
///
/// The size ceiling is here rather than with the layout tests because a
/// template is untrusted input: a single conversion must not be able to demand
/// an arbitrarily large allocation, whether the number came from the template
/// or from the arguments.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  // The order, and the two sign conventions. `%*.*s` reads width, precision,
  // value — in that order and from one list, so a transposition would be
  // invisible in the code and obvious in the output. A negative width is C's
  // way of writing left alignment, and a negative precision means "no
  // precision" rather than an error or a truncation to nothing.
  test('consumes dynamic width then precision then value', () {
    expect(vsprintf('%*.*s', [6, 3, 'abcdef']), '   abc');
    expect(vsprintf('%*s', [-5, 'x']), 'x    ');
    expect(vsprintf('%.*s', [-1, 'abcdef']), 'abcdef');
  });

  // Truncating the argument list one value at a time, so each of the three
  // positions is the one that fails. The report has to name which *role* was
  // missing — `width`, `precision`, or the conversion itself — because all
  // three come from the same fragment and an index alone would leave the caller
  // counting asterisks.
  test('reports missing arguments in dynamic consumption order', () {
    for (final entry in [
      (values: const <Object?>[], index: 0, specifier: 'width'),
      (values: const <Object?>[6], index: 1, specifier: 'precision'),
      (values: const <Object?>[6, 3], index: 2, specifier: 's'),
    ]) {
      expect(
        () => vsprintf('%*.*s', entry.values),
        throwsA(
          isA<MissingFormatArgumentException>()
              .having((error) => error.key, 'key', entry.index)
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.index,
              )
              .having((error) => error.context.fragment, 'fragment', '%*.*s')
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's'),
        ),
      );
    }
  });

  // A dynamic option must be an `int`. A numeric string is not coerced — that
  // is how a shifted argument list turns into a plausible-looking wrong width
  // instead of an error — and a `BigInt` is refused too, since no width worth
  // having needs one. Both roles are covered, each naming its own position.
  test('dynamic options require int values', () {
    for (final entry in [
      (values: const <Object?>['6', 3, 'abcdef'], index: 0, specifier: 'width'),
      (
        values: <Object?>[6, BigInt.one, 'abcdef'],
        index: 1,
        specifier: 'precision',
      ),
    ]) {
      expect(
        () => vsprintf('%*.*s', entry.values),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.fragment, 'fragment', '%*.*s')
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.index,
              )
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's'),
        ),
      );
    }
  });

  // The safety ceiling, from both sources. A width of 100 001 written into the
  // template and the same number arriving as an argument must both be refused —
  // one conversion cannot be allowed to demand a hundred kilobytes of padding,
  // whether the number came from a config file or from data. The negative case
  // is there because a dynamic width's magnitude is what allocates, so the
  // check cannot be a simple upper bound on the signed value.
  //
  // The reports differ in one field on purpose: a value from the template has
  // no argument index, a value from the list does.
  test('rejects unsafe static and dynamic option sizes as typed errors', () {
    for (final entry in [
      (
        template: '%100001s',
        values: const <Object?>['x'],
        specifier: 'width',
        argument: null,
      ),
      (
        template: '%.100001s',
        values: const <Object?>['x'],
        specifier: 'precision',
        argument: null,
      ),
      (
        template: '%*s',
        values: const <Object?>[100001, 'x'],
        specifier: 'width',
        argument: 0,
      ),
      (
        template: '%*s',
        values: const <Object?>[-100001, 'x'],
        specifier: 'width',
        argument: 0,
      ),
      (
        template: '%.*s',
        values: const <Object?>[100001, 'x'],
        specifier: 'precision',
        argument: 0,
      ),
    ]) {
      expect(
        () => vsprintf(entry.template, entry.values),
        throwsA(
          isA<InvalidSpecifierException>()
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's')
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.argument,
              ),
        ),
      );
    }
  });

  // The configured text unit governs this dialect too — it is a property of the
  // engine, not of the syntax. Same combining sequence and same ZWJ cluster as
  // in the brace tests, so the two dialects can be compared directly.
  test('uses TextUnit for printf strings and width', () {
    expect(sprintf('%.1s', 'e\u0301'), 'e');
    expect(sprintf('%4s', 'é'), '   é');
    expect(sprintf('%-4s', 'é'), 'é   ');

    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    expect(graphemes.sprintf('%.1s', 'e\u0301'), 'e\u0301');
    expect(graphemes.sprintf('%3s', '👩‍🔬'), '  👩‍🔬');
  });

  // `%c` is a code point, not a byte as in C: an astral scalar produces a
  // surrogate pair that still counts as one character for width. `BigInt` is
  // accepted for the same reason as elsewhere — on the web an integer can
  // arrive as either type.
  test('formats Unicode scalar values with c', () {
    expect(sprintf('%c', 0x1f44b), '👋');
    expect(sprintf('%c', BigInt.from(65)), 'A');
    expect(sprintf('%4c', 0x1f44b), '   👋');
    expect(sprintf('%-4c', 65), 'A   ');
  });

  // The same four rejections as the brace `{:c}` — below the range, above it, a
  // lone surrogate, and a non-integer — checked separately because printf
  // reaches the conversion through its own parser and processor. A character
  // literal is included as the wrong type, since in C it would have been the
  // right one.
  test('rejects invalid Unicode scalar values with typed context', () {
    for (final value in [-1, 0x110000, 0xd800, 'A']) {
      expect(
        () => sprintf('%c', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', '%c')
              .having((error) => error.context.offset, 'offset', 0)
              .having((error) => error.context.fragment, 'fragment', '%c')
              .having((error) => error.context.specifier, 'specifier', 'c')
              .having((error) => error.context.conversion, 'conversion', 'c')
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  // Unconsumed values are fine, including when the template consumes none at
  // all: `%%` is an escaped percent, not a conversion, and must not advance the
  // argument cursor or complain about the value nobody asked for.
  test('ignores values beyond the final conversion', () {
    expect(vsprintf('%s', const ['used', 'ignored']), 'used');
    expect(vsprintf('%%', const ['ignored']), '%');
  });
}
