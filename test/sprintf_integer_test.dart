// Integer conversions in the printf dialect, where C's rules differ from
// Python's — this is not the brace behaviour with another syntax.
//
// Three differences carry the file. Integers have a *precision* here, meaning a
// minimum number of digits, and a precision of zero prints an empty string for
// the value zero. The alternate prefix follows C: `%#o` is `052`, not `0o52`.
// And the unsigned conversions are genuinely unsigned — a negative value is
// rejected rather than reinterpreted, because printing `-1` as
// `18446744073709551615` is exactly the C behaviour that hides bugs, and this
// dialect has no fixed width to wrap to in the first place.
//
// The int/`BigInt` boundary and the minimum int are walked again here, since
// printf reaches the digits through its own conversions rather than the brace
// path's.
//
// VM-only, and annotated as such: the 64-bit literals below do not survive
// dart2js. The web side of these paths is covered in `template_ir_diff_test`.

@TestOn('vm')
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  // All six integer conversions, including `%i` — C's synonym for `%d`, which
  // exists so that format strings can be moved between languages unchanged.
  // The `BigInt` is one past the last exactly representable double, catching a
  // path that converted through one.
  test('formats signed and unsigned integer conversions', () {
    expect(sprintf('%d', -42), '-42');
    expect(sprintf('%i', BigInt.parse('9007199254740993')), '9007199254740993');
    expect(sprintf('%u', 42), '42');
    expect(sprintf('%o', 42), '52');
    expect(sprintf('%x', 0x2af), '2af');
    expect(sprintf('%X', 0x2af), '2AF');
  });

  // The int boundaries and the values one step past them, on the printf side.
  // "Exactly one sign" is the property at risk: the minimum int has no
  // representable magnitude, so an implementation that negates before writing
  // digits can end up emitting the sign twice — a bug that exists in the wild,
  // in the `sprintf` package the benchmark suite compares against.
  test('formats signed decimal boundaries with exactly one sign', () {
    const minInt = -9223372036854775808;
    const maxInt = 9223372036854775807;
    final aboveInt = BigInt.parse('9223372036854775808');
    final belowInt = BigInt.parse('-9223372036854775809');

    expect(sprintf('%d', minInt), '-9223372036854775808');
    expect(sprintf('%d', maxInt), '9223372036854775807');
    expect(sprintf('%d', 0), '0');
    expect(sprintf('%d', aboveInt), '9223372036854775808');
    expect(sprintf('%d', belowInt), '-9223372036854775809');
  });

  // Integer precision, which the brace dialect does not have: `%.5d` pads with
  // zeros to five digits, and `%.0d` of zero is the empty string — C's rule,
  // and the one everybody finds surprising. The alternate form interacts with
  // it: `%#.0o` of zero still prints `0`, because the prefix *is* the digit in
  // octal, while `%#.0x` of zero prints nothing at all since `0x` alone would
  // be a prefix with no number. `%#x` of a plain zero gets no prefix either.
  test('formats C integer precision and alternate prefixes', () {
    expect(sprintf('%.5d', 42), '00042');
    expect(sprintf('%.0d', 0), '');
    expect(sprintf('%#.0o', 0), '0');
    expect(sprintf('%#o', 42), '052');
    expect(sprintf('%#x', 42), '0x2a');
    expect(sprintf('%#X', 42), '0X2A');
    expect(sprintf('%#.0x', 0), '');
    expect(sprintf('%#x', 0), '0');
  });

  // Flag precedence, which is where printf implementations quietly disagree.
  // `+` beats the space flag when both are given; `-` beats `0`, so
  // `%-05d` pads on the right with spaces rather than zeros; and a precision
  // beats `0` as well — `%08.3d` zero-pads to three digits and then space-pads
  // to eight. Each of these is a rule about which flag wins, not about layout.
  test('applies printf sign width and flag precedence', () {
    expect(sprintf('% +d', 42), '+42');
    expect(sprintf('% 5d', 42), '   42');
    expect(sprintf('%08d', -42), '-0000042');
    expect(sprintf('%#08x', 42), '0x00002a');
    expect(sprintf('%-05d', 42), '42   ');
    expect(sprintf('%08.3d', 42), '     042');
  });

  // Dynamic options on the integer conversions, with the two sign conventions
  // repeated here because they are handled by this processor rather than the
  // text one: a negative width left-aligns, a negative precision means none.
  test('consumes dynamic integer options before the value', () {
    expect(vsprintf('%*d', [-5, 42]), '42   ');
    expect(vsprintf('%.*d', [-1, 42]), '42');
    expect(vsprintf('%*.*x', [8, 4, 42]), '    002a');
  });

  // The deliberate divergence from C, in all four unsigned conversions. C
  // reinterprets the bits and prints a huge positive number; here there is no
  // fixed width to reinterpret against — an `int` is 64-bit on the VM and a
  // double on the web, and `BigInt` is unbounded — so any wrapping would be a
  // fiction. The value is rejected instead. `template_ir_vm_test` relies on
  // this: it is why the minimum int throws on `%x` and `%o`.
  test('rejects negative unsigned values without wrapping', () {
    for (final template in ['%u', '%o', '%x', '%X']) {
      expect(
        () => sprintf(template, -1),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', template)
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  // The three near-misses: a numeric string, a boolean, and a double that is
  // not integral. None is coerced. In C the first two would compile to
  // something and the third is undefined behaviour; here each is a typed
  // failure naming the position, so a shifted argument list is found at once
  // rather than printed.
  test('integer conversions require int or BigInt', () {
    for (final value in ['42', true, 42.5]) {
      expect(
        () => sprintf('%d', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.fragment, 'fragment', '%d')
              .having((error) => error.context.specifier, 'specifier', 'd')
              .having((error) => error.context.conversion, 'conversion', 'd')
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  // The failure is at the *second* conversion, so this pins that the reported
  // offset, fragment and index track the cursor as the template is consumed
  // rather than describing the template as a whole. Pointing at `%d` here would
  // send the reader to the one conversion that worked.
  test('reports a missing integer argument with full context', () {
    expect(
      () => vsprintf('%d %s', const [1]),
      throwsA(
        isA<MissingFormatArgumentException>()
            .having((error) => error.key, 'key', 1)
            .having((error) => error.context.template, 'template', '%d %s')
            .having((error) => error.context.offset, 'offset', 3)
            .having((error) => error.context.fragment, 'fragment', '%s')
            .having((error) => error.context.conversion, 'conversion', 's')
            .having((error) => error.context.argumentIndex, 'argument', 1),
      ),
    );
  });
}
