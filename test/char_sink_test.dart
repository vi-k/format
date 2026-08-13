/// [CharSink] — the buffer every formatted string is built in — tested directly
/// rather than through the engine.
///
/// Most of what is pinned here is one invariant: the sink starts in
/// single-string mode, holding a reference to the one string written so far and
/// nothing else, and any second write has to materialize that string into the
/// buffer first. The mode is what makes `format('{}', s)` return `s` itself
/// instead of a copy, and it is also the sink's sharpest edge — a new write
/// method that forgets to materialize loses the pending string silently, and
/// the engine above it would just produce a slightly wrong result somewhere.
///
/// Reached through the engine these paths are hard to aim at: the sink decides
/// its own mode from the write sequence, and only a few templates produce each
/// sequence. Here the sequences are written out directly, including the
/// degenerate ones (empty string first, zero and negative fills).
///
/// [CharSink.writePadded] is here for the same reason: it is the one write
/// that skips the buffer entirely, and the engine only ever calls it for a
/// template that is a single field, so the degenerate cases — no padding at
/// all, a sink that already holds something — are unreachable from above.
///
/// The grouped writes ([CharSink.writeGroupedMagnitude],
/// [CharSink.writeGroupedBody]) are not here — they are covered against the
/// legacy path in `template_ir_diff_test`, where the expected grouping comes
/// from an oracle rather than from a literal.
library;

import 'dart:typed_data';

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  // The same string written twice: the second write has to leave
  // single-string mode and produce a concatenation, not silently keep holding
  // one reference and report it once.
  test('a repeated literal accumulates past single-string mode', () {
    final sink =
        CharSink(1)
          ..writeString('lit')
          ..writeString('lit');
    expect(sink.toString(), 'litlit');
    expect(sink.length, 6);
  });

  // All four write kinds in one sequence, starting from a capacity of 1 so
  // that the buffer has to grow underneath them. The trailing empty string is
  // there on purpose: it must change neither the length nor the contents.
  test('writes strings, chars and fill with growth', () {
    final sink =
        CharSink(1)
          ..writeString('ab')
          ..writeCharCode(0x2d)
          ..fill(0x30, 3)
          ..writeString('');
    expect(sink.length, 6);
    expect(sink.toString(), 'ab-000');
  });

  // Callers compute padding as `width - content`, which goes zero or negative
  // whenever the content already fills the field. `fill` absorbs that instead
  // of making every call site guard, so a negative count must write nothing
  // rather than loop, throw or corrupt the length.
  test('fill ignores non-positive counts', () {
    final sink =
        CharSink(4)
          ..fill(0x30, 0)
          ..fill(0x30, -2);
    expect(sink.toString(), isEmpty);
  });

  // `digitCount` is how the integer paths size a field before writing a single
  // digit, so it has to agree exactly with what `writeMagnitude` will produce —
  // one too few and the padding is wrong, one too many and it is off by a
  // space. `toRadixString` of the absolute value is the reference; the cases
  // walk the radix boundaries (9/10, 99) and both signs, since the count is of
  // the magnitude and must ignore the minus.
  test('digitCount matches toString length across radixes', () {
    for (final value in [0, 1, 7, 9, 10, 99, 12345, -1, -12345]) {
      for (final radix in [2, 8, 10, 16]) {
        expect(
          CharSink.digitCount(value, radix),
          value.abs().toRadixString(radix).length,
          reason: '$value radix $radix',
        );
      }
    }
  });

  // `writeMagnitude` writes digits backwards into space it reserved, so the
  // three things that can go wrong are all pinned at once: the sign must be
  // dropped (`-48879` prints as `BEEF`), case must apply only to the letters
  // of the requested write, and zero must still produce one digit rather than
  // none. The separator between the two hex writes is what would expose digits
  // landing at the wrong offset.
  test('writeMagnitude writes |value| digits in place', () {
    final sink =
        CharSink(4)
          ..writeMagnitude(-48879, 16, uppercase: true)
          ..writeCharCode(0x7c)
          ..writeMagnitude(255, 16)
          ..writeMagnitude(0, 10);
    expect(sink.toString(), 'BEEF|ff0');
  });

  // The sink works in UTF-16 code units and knows nothing about characters.
  // That is fine as long as it never splits a pair: a capacity of 2 forces the
  // emoji's two units across a growth boundary, and they must come back out
  // adjacent and in order.
  test('surrogate pairs survive as code units', () {
    final sink = CharSink(2)..writeString('a\u{1F600}b');
    expect(sink.toString(), 'a\u{1F600}b');
  });

  // Growth is where a copy can go wrong, and the sink has a minimum capacity
  // that hides small mistakes. This sequence crosses it several times and mixes
  // the write kinds across the boundaries, so a reallocation that copied too
  // little or wrote at the pre-growth offset shows up in the contents rather
  // than only in the length.
  test('buffer reallocation handles growth past 16-unit minimum', () {
    final sink =
        CharSink(1)
          ..writeString('start')
          ..fill(0x30, 20)
          ..writeCharCode(0x2d)
          ..fill(0x31, 15);
    expect(sink.length, 41);
    expect(sink.toString(), 'start${'0' * 20}-${'1' * 15}');
  });

  // The payoff of single-string mode, and the only test that states it as an
  // identity rather than an equality: one write in, the same object out, not a
  // unit copied either way. This is what makes `format('{}', s)`, `'{:s}'` on
  // an already-fitting string, and a template with no fields at all cost
  // nothing.
  test('a single writeString is returned by reference', () {
    const text = 'hello world';
    final sink = CharSink(1)..writeString(text);
    expect(sink.length, text.length);
    expect(identical(sink.toString(), text), isTrue);
  });

  // The capacity a program that writes one string asks for: none, because it
  // accumulates nothing. The minimum still has to hold for the sink that then
  // does accumulate after all, which is what the second half writes past.
  test('a sink asked for no capacity returns and accumulates alike', () {
    const text = 'hello world';
    expect(
      identical((CharSink(0)..writeString(text)).toString(), text),
      isTrue,
    );
    final sink =
        CharSink(0)
          ..writeString(text)
          ..writeCharCode(0x21)
          ..fill(0x2e, 20);
    expect(sink.length, text.length + 21);
    expect(sink.toString(), '$text!${'.' * 20}');
  });

  test('a non-positive fill after writeString keeps single-string mode', () {
    // e.g. `{:<10s}` when content.length >= width: padding is 0 or
    // negative, so this fill call must stay a true no-op and not force the
    // pending single string into the buffer.
    const text = 'hello world';
    final sink =
        CharSink(1)
          ..writeString(text)
          ..fill(0x20, 0)
          ..fill(0x20, -3);
    expect(sink.length, text.length);
    expect(identical(sink.toString(), text), isTrue);
  });

  // Leaving single-string mode through each of the other write kinds in turn,
  // interleaved: the pending string is materialized once, at the right moment,
  // and every later write lands after it.
  test('writeString followed by other writes materializes correctly', () {
    final sink =
        CharSink(1)
          ..writeString('hello')
          ..writeCharCode(0x2d)
          ..writeString('world')
          ..fill(0x21, 2);
    expect(sink.length, 13);
    expect(sink.toString(), 'hello-world!!');
  });

  // An empty first write leaves the sink in a state that is ambiguous by
  // length alone — nothing written, but a pending string is held. The next
  // write must not treat the empty pending string as absent and must not
  // concatenate it as content; either way the result is just `'x'`, and it must
  // still be reachable by reference rather than through a materialized buffer.
  test('empty first string then another string keeps single-string mode '
      'consistent', () {
    final sink =
        CharSink(1)
          ..writeString('')
          ..writeString('x');
    expect(sink.length, 1);
    expect(sink.toString(), 'x');
  });

  // The padded write, which a program that is one op uses to assemble its
  // whole result without the accumulator: the fill has to land on the side
  // asked for, in the amount asked for, and the sink has to stay in
  // single-string mode while it does.
  test('writePadded assembles the layout as one string', () {
    expect(
      (CharSink(0, soleOp: true)..writePadded('ab', 0x2e, 3, 0)).toString(),
      '...ab',
    );
    expect(
      (CharSink(0, soleOp: true)..writePadded('ab', 0x2e, 0, 3)).toString(),
      'ab...',
    );
    final centred = CharSink(0, soleOp: true)..writePadded('ab', 0x2e, 2, 3);
    expect(centred.toString(), '..ab...');
    expect(centred.length, 7);
  });

  // Nothing to pad — `{:>5s}` of a string already five units wide — so the
  // text has to come back the way writeString would have returned it, by
  // reference rather than through a copy that happens to compare equal.
  test('writePadded without padding keeps the text by reference', () {
    const text = 'hello';
    final sink = CharSink(0, soleOp: true)..writePadded(text, 0x20, 0, -2);
    expect(sink.length, text.length);
    expect(identical(sink.toString(), text), isTrue);
  });

  // The emptiness check inside writePadded is a guard, not the condition:
  // callers reach it only for a sole op, so a sink that already holds
  // something is not supposed to arrive here at all. If one ever did, what it
  // held must survive — the failure this guards against is silent, because
  // replacing the pending string still produces a plausible result.
  test('writePadded after another write accumulates instead of replacing', () {
    final sink =
        CharSink(0, soleOp: true)
          ..writeString('x=')
          ..writePadded('ab', 0x2e, 3, 1);
    expect(sink.toString(), 'x=...ab.');
  });

  // Prepared code units are compiled on the VM only, so on the web this method
  // had no caller and no branch of its own: it grew the accumulator the web
  // does not use, having first spun forever trying to double a buffer of
  // length zero. Both halves are pinned here, and this file runs on all three
  // runtimes, which is the only way the web half is ever executed.
  test('writeCodeUnits appends on every runtime', () {
    final sink =
        CharSink(0)
          ..writeString('a=')
          ..writeCodeUnits(Uint16List.fromList('bc'.codeUnits))
          ..writeString('!');

    expect(sink.toString(), 'a=bc!');
    expect(sink.length, 5);
  });

  // The same write as the sole one, where the pending string has to be
  // materialized before the units land: forgetting that is exactly the silent
  // loss the file's header describes.
  test('writeCodeUnits materializes a pending single string', () {
    final sink =
        CharSink(0, soleOp: true)
          ..writeString('head')
          ..writeCodeUnits(Uint16List.fromList([0x2d, 0x74, 0x61, 0x69, 0x6c]));

    expect(sink.toString(), 'head-tail');
  });

  test('a second writeString materializes the first before appending', () {
    // Both writes carry real content and both go through writeString, so
    // this pins the materialize-then-copy order directly: a copy-then-
    // materialize bug (or one that drops/reorders the pending string)
    // would produce something other than the straight concatenation.
    final sink =
        CharSink(1)
          ..writeString('hello')
          ..writeString('world');
    expect(sink.length, 10);
    expect(sink.toString(), 'helloworld');
  });
}
