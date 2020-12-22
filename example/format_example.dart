import 'package:format/format.dart';
import 'package:intl/intl.dart';

void main() {
  print('hello {}'.format(['world'])); // hello world
  print('{} {}'.format(['hello', 'world'])); // hello world
  print('{1} {0}'.format(['hello', 'world'])); // world hello
  print('{} {} {0} {}'.format(['hello', 'world'])); // hello world hello world
  print('{a} {b}'.format([], {'a': 'hello', 'b': 'world'})); // hello world

  print('{a} {"a"} {"+"} {"hello world"}'.format([], {'a': 1, '+': 2, 'hello world': 3})); // 1 1 2 3
  print("{a} {'a'} {'+'} {'hello world'}".format([], {'a': 1, '+': 2, 'hello world': 3})); // 1 1 2 3

  const n = 123.4567;
  print('{:.2f}'.format([n])); // 123.46

  print('{:10.2f}'.format([n])); // '    123.46'
  print('{:<10.2f}'.format([n])); // '123.46    '
  print('{:^10.2f}'.format([n])); // '  123.46  '
  print('{:>10.2f}'.format([n])); // '    123.46'

  print('{:*<10.2f}'.format([n])); // 123.46****
  print('{:*^10.2f}'.format([n])); // **123.46**
  print('{:*>10.2f}'.format([n])); // ****123.46

  print('{:010.2f}'.format([n])); // 0000123.46
  print('{:012,.2f}'.format([n])); // 0,000,123.46
  print('{:012_.2f}'.format([n])); // 0_000_123.46

  print('{:0{},.{}f}'.format([n, 12, 2])); // 0,000,123.46
  print('{value:0{width},.{precision}f}'.format([], {'value': n, 'width': 12, 'precision': 2})); // 0,000,123.46

  const n1 = 123456.789;
  const n2 = 1234567.89;
  print('{:g}'.format([n1])); // 123457
  print('{:g}'.format([n2])); // 1.23457e+6
  print('{:.9g}'.format([n1])); // 123456.789
  print('{:.9g}'.format([n2])); // 1234567.89
  print('{:.5g}'.format([n1])); // 1.2346e+5
  print('{:.5g}'.format([n2])); // 1.2346e+6

  print('{:g}'.format([double.nan])); // nan
  print('{:g}'.format([double.infinity])); // inf
  print('{:g}'.format([double.negativeInfinity])); // -inf

  const i = 12345678;
  print('{:b}'.format([i])); // 101111000110000101001110
  print('{:d}'.format([i])); // 12345678
  print('{:x}'.format([i])); // bc614e
  print('{:X}'.format([i])); // BC614E
  print('{:#x}'.format([i])); // 0xbc614e
  print('{:#X}'.format([i])); // 0xBC614E

  print('{:_b}'.format([i])); // 1011_1100_0110_0001_0100_1110
  print('{:,d}'.format([i])); // 12,345,678
  print('{:_d}'.format([i])); // 12_345_678
  print('{:_x}'.format([i])); // bc_614e
  print('{:_X}'.format([i])); // BC_614E
  print('{:#_x}'.format([i])); // 0xbc_614e
  print('{:#_X}'.format([i])); // 0xBC_614E

  print('{:c}+{:c}+{:c}+{:c}={:c}'.format([
    0x1F468, // 👨
    0x1F469, // 👩
    0x1F466, // 👦
    0x1F467, // 👧
    [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466, 0x200D, 0x1F467], // 👨‍👩‍👦‍👧
  ]));

  const m = 12345678.9;
  Intl.defaultLocale = 'ru_RU';
  print('{:n}'.format([m])); // 1,23457E7
  print('{:.9n}'.format([m])); // 12345678,9
  print('{:012,.9n}'.format([m])); // 12 345 678,9
  print('{:n}'.format([double.nan])); // не число
  print('{:n}'.format([double.infinity])); // ∞
  print('{:n}'.format([double.negativeInfinity])); // -∞

  Intl.defaultLocale = 'de_DE';
  print('{:n}'.format([m])); // 1,23457E7
  print('{:.9n}'.format([m])); // 12345678,9
  print('{:012,.9n}'.format([m])); // 12.345.678,9

  Intl.defaultLocale = 'en_IN';
  print('{:n}'.format([m])); // 1.23457E7
  print('{:.9n}'.format([m])); // 12345678.9
  print('{:012,.9n}'.format([m])); // 1,23,45,678.9

  Intl.defaultLocale = 'bn';
  print('{:n}'.format([m])); // ১.২৩৪৫৭E৭
  print('{:.9n}'.format([m])); // ১২৩৪৫৬৭৮.৯
  print('{:012,.9n}'.format([m])); // ১,২৩,৪৫,৬৭৮.৯

  Intl.defaultLocale = 'ar_EG';
  print('{:n}'.format([m])); // ١٫٢٣٤٥٧اس٧
  print('{:.9n}'.format([m])); // ١٢٣٤٥٦٧٨٫٩
  print('{:012,.9n}'.format([m])); // ١٢٬٣٤٥٬٦٧٨٫٩
  print('{:n}'.format([double.nan])); // ليس رقم

  print('{:👨>10}'.format([1]));
  print('{:👨‍👩‍👦‍👧>10}'.format([1]));
}
