/// Integer layout in the brace dialect: the four bases, the sign and alternate
/// forms, width and alignment, digit grouping, and the locale-aware `n`.
///
/// Most of these rules are Python's, and Python's are not obvious, so the
/// expectations are literals taken from its behaviour rather than derived from
/// ours. Two areas carry nearly all the risk. Grouping interacts with zero
/// padding in a way that surprises everyone who meets it — `{:08,d}` of 1234 is
/// `0,001,234`, nine characters, because the padding is fitted to the *grouped*
/// length rather than added to the raw digits — and each combination of width,
/// group size, sign and alternate prefix reaches that arithmetic differently.
/// And `n` hands parts of the layout to a [NumberLocale], which is caller code:
/// it can group irregularly, replace the digits themselves, and throw.
///
/// The values are chosen at the edges: zero, the int boundaries in both
/// directions, [BigInt] values just past them, and the minimum int — the one
/// value with no positive counterpart, which every sign-then-magnitude
/// implementation has to special-case.
///
/// VM-only, and annotated as such: the 64-bit literals below do not survive
/// dart2js, where an int is a double. The IR is exercised against these same
/// paths on the web in `template_ir_diff_test.dart`.
@TestOn('vm')
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _LocalizedNumberLocale implements NumberLocale {
  @override
  String get decimalSeparator => ',';

  @override
  String get exponentSeparator => 'e';

  @override
  String get groupSeparator => '.';

  @override
  List<int> get grouping => [3, 2];

  @override
  bool get groupingEnabled => true;

  @override
  String get minusSign => '−';

  @override
  String get plusSign => '＋';

  @override
  String localizeDigits(String asciiDigits) => asciiDigits
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');
}

final class _ThrowingNumberLocale implements NumberLocale {
  @override
  String get decimalSeparator => '.';

  @override
  String get exponentSeparator => 'e';

  @override
  String get groupSeparator => throw StateError('group separator failed');

  @override
  List<int> get grouping => const [3];

  @override
  bool get groupingEnabled => true;

  @override
  String get minusSign => '-';

  @override
  String get plusSign => '+';

  @override
  String localizeDigits(String asciiDigits) => asciiDigits;
}

void main() {
  // The four bases, in both integer types, with zero at the end of each. `int`
  // and `BigInt` take different routes to the same digits — one has a native
  // radix conversion, the other does not — so every base is walked twice, and
  // `X` is present to pin that case applies to the digits and not to the
  // conversion letter.
  test('formats int and BigInt magnitudes in every integer base', () {
    final giant = BigInt.parse('123456789012345678901234567890');

    expect(format('{:d}', 42), '42');
    expect(format('{:d}', giant), '123456789012345678901234567890');
    expect(format('{:b}', 42), '101010');
    expect(format('{:o}', 42), '52');
    expect(format('{:x}', 0x2af), '2af');
    expect(format('{:X}', 0x2af), '2AF');
    expect(format('{:d}', 0), '0');
    expect(format('{:x}', BigInt.zero), '0');
  });

  // The seam between the two integer types, crossed in both directions: the
  // largest and smallest `int`, and the `BigInt` values one step beyond each.
  // A path that converted through `int` to save an allocation would round or
  // wrap here, and the digits are written out in full so that a wrong one is
  // visible rather than plausible.
  test('preserves decimal int boundaries and out-of-range BigInt values', () {
    final aboveInt = BigInt.parse('9223372036854775808');
    final belowInt = BigInt.parse('-9223372036854775809');

    expect(format('{:d}', 9223372036854775807), '9223372036854775807');
    expect(format('{:d}', -9223372036854775808), '-9223372036854775808');
    expect(format('{:d}', aboveInt), '9223372036854775808');
    expect(format('{:d}', belowInt), '-9223372036854775809');
    expect(format('{:+,d}', 9223372036854775807), '+9,223,372,036,854,775,807');
  });

  // The minimum int through every conversion. Layout works by taking a
  // magnitude and writing a sign in front, and this is the one value whose
  // magnitude is not representable — so `-value` overflows back to itself and
  // each conversion has to reach the digits another way. Seven conversions,
  // including the alternate hex form where the prefix, the sign and the zero
  // padding all have to be ordered around it.
  test('formats the minimum int through every direct integer presentation', () {
    const minInt = -9223372036854775808;

    expect(
      format('{:b}', minInt),
      '-1000000000000000000000000000000000000000000000000000000000000000',
    );
    expect(format('{:o}', minInt), '-1000000000000000000000');
    expect(format('{:d}', minInt), '-9223372036854775808');
    expect(format('{:n}', minInt), '-9223372036854775808');
    expect(format('{:x}', minInt), '-8000000000000000');
    expect(format('{:X}', minInt), '-8000000000000000');
    expect(format('{:#020x}', minInt), '-0x08000000000000000');
  });

  // `#` adds a base prefix, and the question it raises is where the sign goes:
  // `-0x2a`, not `0x-2a`. The prefix follows the case of the conversion letter,
  // and zero still gets one — `0x0` — since the prefix describes the notation,
  // not the value.
  test('formats alternate integer forms and negative prefixes', () {
    expect(format('{:#b}', 42), '0b101010');
    expect(format('{:#o}', 42), '0o52');
    expect(format('{:#x}', -42), '-0x2a');
    expect(format('{:#X}', -42), '-0X2A');
    expect(format('{:#x}', 0), '0x0');
  });

  // All three sign flags on both signs, plus the case that decides what "zero
  // is positive" means: `{:+d}` of 0 is `+0`. Signs are a property of the flag
  // and the value's sign bit, not of its magnitude.
  test('applies Python integer sign flags', () {
    expect(format('{:+d}', 42), '+42');
    expect(format('{: d}', 42), ' 42');
    expect(format('{:-d}', 42), '42');
    expect(format('{:+d}', -42), '-42');
    expect(format('{:+d}', 0), '+0');
  });

  // Width and the alignments, with `=` — the numeric one — as the point of the
  // exercise: it puts the padding *between* the sign and the digits, so
  // `{:=+8d}` is `+     42` while `{:0=+8d}` is `+0000042`. Zero padding is `=`
  // with a zero fill, which is why `{:08d}` of −42 keeps the sign in front but
  // `{:<08d}` and `{:0>8d}` — where an explicit alignment overrides it — do
  // something else entirely.
  //
  // The last line ties this to the text unit: the fill is one unit, and under
  // graphemes a ZWJ cluster counts as one.
  test('applies numeric width and alignment with selected text units', () {
    expect(format('{:6d}', 42), '    42');
    expect(format('{:<6d}', 42), '42    ');
    expect(format('{:^7d}', 42), '  42   ');
    expect(format('{:*>6d}', 42), '****42');
    expect(format('{:=+8d}', 42), '+     42');
    expect(format('{:0=+8d}', 42), '+0000042');
    expect(format('{:08d}', -42), '-0000042');
    expect(format('{:<08d}', 42), '42000000');
    expect(format('{:0>8d}', 42), '00000042');
    expect(format('{:0=+#10x}', 42), '+0x000002a');

    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    expect(graphemes.format('{:👩‍🔬>4d}', 42), '👩‍🔬👩‍🔬42');
  });

  // The two separators have different group sizes, and the size depends on the
  // base rather than on the separator: `_` groups decimal digits by three and
  // binary, octal and hexadecimal by four, because four digits is one nibble
  // boundary that a reader of a hex number actually uses. `,` is decimal-only
  // (its rejection elsewhere in this file), and grouping composes with the
  // alternate prefix without the prefix being grouped.
  test('groups decimal and non-decimal digits like Python', () {
    expect(format('{:,d}', 1234567), '1,234,567');
    expect(format('{:_d}', -1234567), '-1_234_567');
    expect(format('{:_b}', 0x1234), '1_0010_0011_0100');
    expect(format('{:_o}', 0x12345678), '22_1505_3170');
    expect(format('{:_x}', 0x12345678), '1234_5678');
    expect(format('{:#_X}', 0x12345678), '0X1234_5678');
  });

  // The hardest arithmetic in the file, and the one most likely to be
  // "simplified" into a bug. Zero padding under grouping does not pad to the
  // width — it finds the smallest number of digits whose *grouped* length
  // reaches the width, and then groups those. So `{:08,d}` of 1234 is
  // `0,001,234`: nine characters, one more than asked for, because eight is not
  // a length a grouped number can have. Subtracting one width from another
  // overshoots by a separator.
  //
  // The eleven cases walk that boundary from every side: both separators, all
  // four group sizes, a negative value and an explicit sign (which consume
  // width before the digits), the alternate prefix (which does not group), a
  // width that lands exactly on a group boundary, and a value already wider
  // than the field. The engine computes this analytically
  // (`_fittedGroupedDigitCount`); the legacy path finds it by bisection, and
  // the two are compared at scale in the parity suite.
  test('fits sign-aware zero padding to the width after grouping', () {
    expect(format('{:08,d}', 1234), '0,001,234');
    expect(format('{:08_d}', 1234), '0_001_234');
    expect(format('{:08_x}', 0x1234), '000_1234');
    expect(format('{:#010_x}', 0x1234), '0x000_1234');
    expect(format('{:010,d}', 1234), '00,001,234');
    expect(format('{:015,d}', 123456), '000,000,123,456');
    expect(format('{:06,d}', -5), '-0,005');
    expect(format('{:+09,d}', 1234), '+0,001,234');
    expect(format('{:#014_x}', 0xabc), '0x00_0000_0abc');
    expect(format('{:016_b}', 5), '0_0000_0000_0101');
    expect(format('{:08,d}', 12345678), '12,345,678');
  });

  // `n` is `d` with the layout handed to a `NumberLocale`. Under the default C
  // locale it must be indistinguishable from `d` — no grouping at all — and
  // under a custom one it takes everything from the locale: irregular group
  // sizes (`[3, 2]`, as in the Indian system, so the groups differ within one
  // number), a non-ASCII group separator, non-ASCII digits, and its own plus
  // and minus signs, which are not the ASCII ones here precisely so that a path
  // writing `'-'` directly is caught.
  test('formats n through C and custom number locales', () {
    expect(format('{:n}', 1234567), '1234567');
    expect(format('{:+n}', 42), '+42');

    final localized = Format(numberLocale: _LocalizedNumberLocale());
    expect(localized.format('{:n}', 123456789), '١٢.٣٤.٥٦.٧٨٩');
    expect(localized.format('{:+n}', 42), '＋٤٢');
    expect(localized.format('{: n}', -42), '−٤٢');
  });

  // The two hard problems together: fitted grouped padding, under a locale
  // whose groups are irregular and whose digits are not ASCII. The lengths are
  // asserted in runes rather than code units — the width was requested in text
  // units, and a localized digit is still one of them. The negative case is one
  // rune longer, because the sign is added to a field already fitted.
  test('regroups and localizes n sign-aware zero padding', () {
    final localized = Format(numberLocale: _LocalizedNumberLocale());
    final positive = localized.format('{:08n}', 1234);
    final negative = localized.format('{:08n}', -1234);

    expect(positive, '٠.٠١.٢٣٤');
    expect(negative, '−٠.٠١.٢٣٤');
    expect(positive.runes.length, 8);
    expect(negative.runes.length, 9);
  });

  // A `NumberLocale` is caller code like any other extension, so a throw from
  // one of its getters is wrapped and located rather than escaping as a bare
  // `StateError` from inside the number layout.
  test('wraps locale failures with the original error and format context', () {
    final configured = Format(numberLocale: _ThrowingNumberLocale());

    expect(
      () => configured.format('{:n}', 42),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.error, 'original error', isA<StateError>())
            .having((error) => error.context.template, 'template', '{:n}')
            .having((error) => error.context.specifier, 'specifier', 'n'),
      ),
    );
  });

  // Option combinations that parse but mean nothing, one test each so a
  // newly accepted one names itself. Three rules are encoded here: `,` is a
  // decimal separator and does not apply to the other bases; `n` takes its
  // grouping from the locale, so an explicit separator would contradict it;
  // and integers have no precision, so `.1` is not a rounding request but a
  // mistake. The `c` entries repeat the character conversion's rejections from
  // this side, since `c` also takes an integer and the two option sets are
  // easy to confuse.
  for (final template in [
    '{:,b}',
    '{:,o}',
    '{:,x}',
    '{:,X}',
    '{:,n}',
    '{:_n}',
    '{:.1d}',
    '{:zd}',
    '{:.1_d}',
    '{:+c}',
    '{:0c}',
    '{:=4c}',
    '{:.1c}',
  ]) {
    test('rejects incompatible integer options $template', () {
      expect(
        () => format(template, 42),
        throwsA(isA<InvalidSpecifierException>()),
      );
    });
  }

  // C and Python both let a boolean be formatted as a number. This package
  // does not: `{:d}` of `true` is a rejected value rather than 1, because the
  // reading a Dart caller expects is `'true'` and a silent 1 is the kind of
  // wrong output nobody looks for.
  test('does not treat bool as an integer', () {
    expect(
      () => format('{:d}', true),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  // The same refusal without a conversion letter. These specifications have no
  // `d`, so nothing in them says "number" except the options themselves — and
  // each one is numeric, so applying it to a boolean would mean inferring a
  // numeric interpretation from the option. That inference is what is refused.
  for (final template in ['{:+}', '{:08}', '{:#}', '{:.1}', '{:=5}']) {
    test('rejects numeric options on bool $template', () {
      expect(
        () => format(template, true),
        throwsA(isA<UnsupportedFormatValueException>()),
      );
    });
  }
}
