import 'package:format/format.dart';
import 'package:intl/intl.dart';
// ignore: import_of_legacy_library_into_null_safe
// import 'package:sprintf/sprintf.dart';

void main() {
  // print(format('{} {} {} {0} {} {}', [1, 2, 3]));
  // print(format('{a} {[a]} {[+]}', [], {'a': 'a', '+': '+'}));
  // // print(format('{a:*<+#0{width}.{precision}n[z]}', [],
  // //     {'a': 123, 'width': 22, 'precision': 33}));
  // // print(format('{a:*<+#0{width}.{[precision]}n[z]}', [],
  // //     {'a': 123, 'width': 22, 'precision': 33}));

  // print(format('{:c}+{:c}+{:c}+{:c}={:c}', [
  //   0x1F468, // 👨
  //   0x1F469, // 👩
  //   0x1F466, // 👦
  //   0x1F467, // 👧
  //   [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466, 0x200D, 0x1F467], // 👨‍👩‍👦‍👧
  // ]));

  // print(format('[{:^#6.2s}]', ['hello']));
  // print(format('[{:6d}]', [123]));
  // print(format('[{:-}] [{:+}] [{: }]', [123, 123, 123]));
  // print(format('[{:-}] [{:+}] [{: }]', [-123, -123, -123]));
  // print(format('[{:06}] [{:06}]', [123, -123]));
  // print(format('[{0:b}] [{0:o}] [{0:d}] [{0:x}] [{0:X}]', [255]));
  // print(format('[{0:#b}] [{0:#o}] [{0:#d}] [{0:#x}] [{0:#X}] [0x{0:X}]', [255]));
  // print(format('[{0:#b}] [{0:#o}] [{0:#d}] [{0:#x}] [{0:#X}]', [-255]));
  // print(format('[{:_}] [{:_}] [{:_}] [{:_}] [{:_}] [{:_}] [{:_}]', [-1, -12, -123, -1234, -12345, -123456, -1234567]));
  // print(format('[{:,}] [{:,}] [{:,}] [{:,}] [{:,}] [{:,}] [{:,}]', [-1, -12, -123, -1234, -12345, -123456, -1234567]));
  // print(format('[{:_b}] [{:_b}] [{:_b}] [{:_b}] [{:_b}] [{:_b}] [{:_b}] [{:_b}] [{:_b}]', [-0x1, -0x2, -0x5, -0xA, -0x15, -0x2A, -0x55, -0xAA, -0x155]));
  // print(format('[{:_X}] [{:_X}] [{:_X}] [{:_X}] [{:_X}] [{:_X}] [{:_X}] [{:_X}] [{:_X}]', [-0x1, -0x12, -0x123, -0x123A, -0x123AB, -0x123ABC, -0x123ABCD, -0x123ABCDE, -0x123ABCDEF]));
  // // print(format('[{:,b}]', [-0x1]));
  // // print(format('[{:,X}]', [-0x1]));
  // print(format('[{:011b}] [{:011b}] [{:011b}] [{:011b}] [{:011b}] [{:011b}] [{:011b}] [{:011b}] [{:011b}]', [-0x1, -0x2, -0x5, -0xA, -0x15, -0x2A, -0x55, -0xAA, -0x155]));

  // print('');
  // print(format('[{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}]', [1, 12, 123, 1234, 12345, 123456, 1234567]));
  // print(format('[{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}] [{:010,}]', [-1, -12, -123, -1234, -12345, -123456, -1234567]));
  // print(format('[{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}]', [1, 12, 123, 1234, 12345, 123456, 1234567]));
  // print(format('[{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}] [{:09,}]', [-1, -12, -123, -1234, -12345, -123456, -1234567]));

  // print('');
  // print(format('[{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}]', [0x1, 0x2, 0x5, 0xA, 0x15, 0x2A, 0x55, 0xAA, 0x155]));
  // print(format('[{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}] [{:012_b}]', [-0x1, -0x2, -0x5, -0xA, -0x15, -0x2A, -0x55, -0xAA, -0x155]));
  // print(format('[{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}]', [0x1, 0x2, 0x5, 0xA, 0x15, 0x2A, 0x55, 0xAA, 0x155]));
  // print(format('[{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}] [{:011_b}]', [-0x1, -0x2, -0x5, -0xA, -0x15, -0x2A, -0x55, -0xAA, -0x155]));

  // print('');
  // print(format('[{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}]', [0x1, 0x12, 0x123, 0x123A, 0x123AB, 0x123ABC, 0x123ABCD, 0x123ABCDE, 0x123ABCDEF]));
  // print(format('[{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}] [{:012_X}]', [-0x1, -0x12, -0x123, -0x123A, -0x123AB, -0x123ABC, -0x123ABCD, -0x123ABCDE, -0x123ABCDEF]));
  // print(format('[{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}]', [0x1, 0x12, 0x123, 0x123A, 0x123AB, 0x123ABC, 0x123ABCD, 0x123ABCDE, 0x123ABCDEF]));
  // print(format('[{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}] [{:011_X}]', [-0x1, -0x12, -0x123, -0x123A, -0x123AB, -0x123ABC, -0x123ABCD, -0x123ABCDE, -0x123ABCDEF]));

  // print('');
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'en_US';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'ru_RU';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'fr';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'pt_BR';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'es';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'ln';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");
  // Intl.defaultLocale = 'de_DE';
  // print("${Intl.defaultLocale}: ${format('[{:12,n}]', [-1234567])} [${Numberformat().symbols.GROUP_SEP}${Numberformat().symbols.DECIMAL_SEP}]");

  Intl.defaultLocale = 'ru_RU';
  // print(format('[{:09,n}] [{:09,n}] [{:09,n}] [{:09,n}] [{:09,n}] [{:09,n}] [{:09,n}]', [-1, -12, -123, -1234, -12345, -123456, -1234567]));

  print('{:012,.6f}'.format([-123.6]));
  print('{:012,d}'.format([-123]));
  print('{:012,n}'.format([-123]));
  print('{:012,.6n}'.format([-123.0]));
  print('\u043d\u0435\u00a0\u0447\u0438\u0441\u043b\u043e {:011,x}'
      .format([-0x123ABCDEF]));

  // gu,hi DECIMAL_PATTERN

  // print(sprintf('%*<+#02.3f', [123.4]));
  // print(sprintf('%+#02.3f', [123.4]));
  // print(sprintf('%s', [123.4]));
}
