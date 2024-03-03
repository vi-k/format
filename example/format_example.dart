import 'package:format/format.dart';
import 'package:intl/intl.dart';

// ignore: long-method
void main() {
  print(format('{}', 'hello world')); // "hello world"
  print('{}'.format('hello world')); // "hello world"
  '{}'.print('hello world'); // "hello world"

  print(format('{} {}', 'hello', 'world')); // "hello world" (max 10 arguments)
  print(
    format('{} {}', ['hello', 'world']),
  ); // "hello world" (unlimited number of arguments)
  print(format('{0} {1}', 'hello', 'world')); // "hello world"
  print(format('{1} {0}', 'hello', 'world')); // "world hello"
  print(format('{h} {w}', {'h': 'hello', 'w': 'world'})); // "hello world"
  print(format('{w} {h}', {#h: 'hello', #w: 'world'})); // "hello world"
  print(
    format(
      '{"it\'s hello"} {"it\'s world"}',
      {"it's hello": 'hello', "it's world": 'world'},
    ),
  ); // "hello world"

  print(format('{:d}', 123)); // "123"
  print(format('{:7d}', 123)); // "    123"
  print(format('{:<7d}', 123)); // "123    "
  print(format('{:^7d}', 123)); // "  123  "
  print(format('{:*^7d}', 123)); // "**123**"

  print(format('{:07d}', 123)); // "0000123"
  print(format('{:09,d}', 123)); // "0,000,123"
  print(format('{:09_d}', 123)); // "0_000_123"

  print(format('{:0{},d}', 123, 9)); // "0,000,123"
  print(format('{:0{},d}', 123, 11)); // "000,000,123"
  print(
    format('{value:0{width},d}', {'value': 123, 'width': 13}),
  ); // "0,000,000,123"

  print(format('{:+d}', 123)); // "+123"
  print(format('{: d}', 123)); // " 123"

  // Automatic type inference.
  print(format('{}', 123)); // "123"
  print(format('{}', 'aaa')); // "aaa"
  print(format('{:7}', 123)); // "    123"
  print(format('{:7}', 'aaa')); // "aaa    "

  const n = 123.4567;
  print(format('{:.2f}', n)); // 123.46
  print(format('{:10.2f}', n)); // '    123.46'
  print(format('{:010.2f}', n)); // 0000123.46
  print(format('{:012,.2f}', n)); // 0,000,123.46
  print(format('{:012_.2f}', n)); // 0_000_123.46

  print(format('{:0{},.{}f}', n, 12, 2)); // 0,000,123.46
  print(
    format('{value:0{width},.{precision}f}', {
      'value': n,
      'width': 12,
      'precision': 2,
    }),
  ); // 0,000,123.46

  const n1 = 123456.789;
  const n2 = 1234567.89;
  print(format('{:g}', n1)); // 123457
  print(format('{:g}', n2)); // 1.23457e+6
  print(format('{:.9g}', n1)); // 123456.789
  print(format('{:.9g}', n2)); // 1234567.89
  print(format('{:.5g}', n1)); // 1.2346e+5
  print(format('{:.5g}', n2)); // 1.2346e+6

  print(format('{:g}', double.nan)); // nan
  print(format('{:g}', double.infinity)); // inf
  print(format('{:g}', double.negativeInfinity)); // -inf

  const i = 12345678;
  print(format('{:b}', i)); // 101111000110000101001110
  print(format('{:d}', i)); // 12345678
  print(format('{:x}', i)); // bc614e
  print(format('{:X}', i)); // BC614E
  print(format('{:#x}', i)); // 0xbc614e
  print(format('{:#X}', i)); // 0xBC614E

  print(format('{:_b}', i)); // 1011_1100_0110_0001_0100_1110
  print(format('{:,d}', i)); // 12,345,678
  print(format('{:_d}', i)); // 12_345_678
  print(format('{:_x}', i)); // bc_614e
  print(format('{:_X}', i)); // BC_614E
  print(format('{:#_x}', i)); // 0xbc_614e
  print(format('{:#_X}', i)); // 0xBC_614E

  // Surrogate pairs
  print(
    format(
      '{:c}+{:c}+{:c}+{:c}={:c}',
      0x1F468, // 👨
      0x1F469, // 👩
      0x1F467, // 👧
      0x1F466, // 👦
      [
        0x1F468, // 👨
        0x200D,
        0x1F469, // 👩
        0x200D,
        0x1F467, // 👧
        0x200D,
        0x1F466, // 👦
      ], // 👨‍👩‍👧‍👦
    ),
  ); // 👨+👩+👧+👦=👨‍👩‍👧‍👦

  print(format('{:🇺🇦^10}', 'No war')); // 🇺🇦🇺🇦No war🇺🇦🇺🇦

  const m = 12345678.9;
  Intl.defaultLocale = 'en_US';
  print(format('{:n}', m)); // 1.23457E7
  print(format('{:.9n}', m)); // 12345678.9
  print(format('{:012,.9n}', m)); // 1,23,45,678.9
  print(format('{:n}', double.nan)); // NaN
  print(format('{:n}', double.infinity)); // ∞
  print(format('{:n}', double.negativeInfinity)); // -∞

  Intl.defaultLocale = 'uk_UA';
  print(format('{:n}', m)); // 1,23457E7
  print(format('{:.9n}', m)); // 12345678,9
  print(format('{:012,.9n}', m)); // 12 345 678,9
  print(format('{:n}', double.nan)); // NaN

  Intl.defaultLocale = 'ru_RU';
  print(format('{:n}', m)); // 1,23457E7
  print(format('{:.9n}', m)); // 12345678,9
  print(format('{:012,.9n}', m)); // 12 345 678,9
  print(format('{:n}', double.nan)); // не число

  Intl.defaultLocale = 'de_DE';
  print(format('{:n}', m)); // 1,23457E7
  print(format('{:.9n}', m)); // 12345678,9
  print(format('{:012,.9n}', m)); // 12.345.678,9

  Intl.defaultLocale = 'bn';
  print(format('{:n}', m)); // ১.২৩৪৫৭E৭
  print(format('{:.9n}', m)); // ১২৩৪৫৬৭৮.৯
  print(format('{:012,.9n}', m)); // ১,২৩,৪৫,৬৭৮.৯

  Intl.defaultLocale = 'ar_EG';
  print(format('{:n}', m)); // ١٫٢٣٤٥٧اس٧
  print(format('{:.9n}', m)); // ١٢٣٤٥٦٧٨٫٩
  print(format('{:012,.9n}', m)); // ١٢٬٣٤٥٬٦٧٨٫٩
  print(format('{:n}', double.nan)); // ليس رقم
}
