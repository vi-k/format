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

  test('formats alternate integer forms and negative prefixes', () {
    expect(format('{:#b}', 42), '0b101010');
    expect(format('{:#o}', 42), '0o52');
    expect(format('{:#x}', -42), '-0x2a');
    expect(format('{:#X}', -42), '-0X2A');
    expect(format('{:#x}', 0), '0x0');
  });

  test('applies Python integer sign flags', () {
    expect(format('{:+d}', 42), '+42');
    expect(format('{: d}', 42), ' 42');
    expect(format('{:-d}', 42), '42');
    expect(format('{:+d}', -42), '-42');
    expect(format('{:+d}', 0), '+0');
  });

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

  test('groups decimal and non-decimal digits like Python', () {
    expect(format('{:,d}', 1234567), '1,234,567');
    expect(format('{:_d}', -1234567), '-1_234_567');
    expect(format('{:_b}', 0x1234), '1_0010_0011_0100');
    expect(format('{:_o}', 0x12345678), '22_1505_3170');
    expect(format('{:_x}', 0x12345678), '1234_5678');
    expect(format('{:#_X}', 0x12345678), '0X1234_5678');
  });

  test('groups sign-aware zero padding after padding the magnitude', () {
    expect(format('{:08,d}', 1234), '0,001,234');
    expect(format('{:08_d}', 1234), '0_001_234');
    expect(format('{:08_x}', 0x1234), '0000_1234');
    expect(format('{:#010_x}', 0x1234), '0x0000_1234');
  });

  test('formats n through C and custom number locales', () {
    expect(format('{:n}', 1234567), '1234567');
    expect(format('{:+n}', 42), '+42');

    final localized = Format(numberLocale: _LocalizedNumberLocale());
    expect(localized.format('{:n}', 123456789), '١٢.٣٤.٥٦.٧٨٩');
    expect(localized.format('{:+n}', 42), '＋٤٢');
    expect(localized.format('{: n}', -42), '−٤٢');
  });

  test('regroups and localizes n sign-aware zero padding', () {
    final localized = Format(numberLocale: _LocalizedNumberLocale());
    final positive = localized.format('{:08n}', 1234);
    final negative = localized.format('{:08n}', -1234);

    expect(positive, '٠٠.٠١.٢٣٤');
    expect(negative, '−٠.٠١.٢٣٤');
    expect(positive.runes.length, 9);
    expect(negative.runes.length, 9);
  });

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

  test('does not treat bool as an integer', () {
    expect(
      () => format('{:d}', true),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  for (final template in ['{:+}', '{:08}', '{:#}', '{:.1}', '{:=5}']) {
    test('rejects numeric options on bool $template', () {
      expect(
        () => format(template, true),
        throwsA(isA<UnsupportedFormatValueException>()),
      );
    });
  }
}
