# format

*format* is a package for formatting Dart strings. 
Now it has only one function, actually format ().

## Content
- [format()](#stringformat)
    - [Usage example](#usage-example)

## String.format()


Function-extension of the class [String](https://api.dart.dev/stable/dart-core/String-class.html),
similar to method [format](https://docs.python.org/3/library/string.html#format-string-syntax)
in Python, function [std::format](https://en.cppreference.com/w/cpp/utility/format/format)
from C++20, which in turn became the development of the popular function [sprintf](https://en.cppreference.com/w/c/io/fprintf)
from C. Its essence is that instead of templates enclosed in curly braces `{}`,
substitute the values of the passed arguments, formatting them as required.

```dart
String result = '{...}'.format(...);
```

### Template description

```
template            ::=  '{' [argId] [':' formatSpec] '}'
argId               ::=  index | identifier | doubleQuotedString | singleQuotedString
index               ::=  digit+
identifier          ::=  idStart idContinue*
idStart             ::=  '_' | letter
idContinue          ::=  '_' | letter | digit
letter              ::=  <any letter of any language> (\ p {Letter})
doubleQuotedString  ::=  '"' <any characters, with replacement" for ""> "'"
singleQuotedString  ::=  "'" <any characters, replacing' with '>' "'
arg_name            ::=  [identifier | digit+]
attribute_name      ::=  identifier
formatSpec          ::=  <in the next section>
```

### Format string syntax

```
formatSpec      ::=  [[fill]align][sign][#][0][width][grouping_option][.precision][type]
fill            ::=  <any characters>
align           ::=  '<' | '>' | '^'
sign            ::=  '+' | '-' | ' '
width           ::=  digit+ | '{' argId '}'
groupingOption  ::=  '_' | ','
precision       ::=  digit+ | '{' argId '}'
type            ::=  'b' | 'c' | 'd' | 'e' | 'E' | 'f' | 'F' | 'g' | 'G' | 'n' | 'o' | 's' | 'x' | 'X'
```

#### `fill` и `align`

If `align` is specified, then the` fill` line can be anything
a combination of characters, while only one character is allowed in Python. This is
made in order to be able to use symbols consisting of several
Unicode characters (accented characters, surrogate pairs, etc.),
and at the same time do not engage in unnecessary analysis.

Python imposes only one constraint on the fill character - not allowed
use curly braces `{}` because they are used to insert values
inside the template. In Dart, there is no need for such a function, since he has
built into the language is excellent [string interpolation](https://dart.dev/guides/language/language-tour#strings).

Possible `align` values:

| Value    | Description
| :------: | :-------
|    '<'   | Left justification (this is the default for strings and characters).
|    '>'   | Right justification (this is the default for numbers).
|    '^'   | Center alignment.

Of course, `align` only matters when a minimum width is given
the field is `width`, and it is larger than the actual width of the field. In this case, the result is
is complemented to the specified one from the corresponding side.

Python also includes the '=' value, through which you can insert any
character instead of leading zeros between the number sign ('+' or '-') and the first
significant digits ('+ 123', '- 42'). '0' before width acts the same
principle. I didn’t take this opportunity. First, because I am not
I can understand the reasons why this is necessary. If the task was to replace leading zeros
any character, then this is not entirely true, because the option of arranging separators
thousand (',') is not included if a character other than '0' is specified. Those. Python
distinguishes zeros from other characters in this function. Secondly, because of this
features all these strange '00000nan', '-0000inf' appear. Although not
it is clear why exactly in these cases no exception was made for zeros.

#### `sign`

With this function, you can specify how to handle the sign of a number.

| Value  | Description
| :---:  | :---
|  '-'   | The sign is placed only for negative numbers (this is the default value).
|  '+'   | Positive numbers also have a sign (zero also comes with a plus).
|  ''    | Positive numbers have a space character instead of '+'. This can be useful for aligning positive and negative numbers with each other.

### Usage example

```dart
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

  print('{:👨>10}'.format([1]));
  print('{:👨‍👩‍👦‍👧>10}'.format([1]));
  print('{:ä>10}'.format([1]));

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
}
```
