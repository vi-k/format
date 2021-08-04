# format

*format* is a package for formatting Dart strings. It contains: the `format`
function and the extension methods of the String class: `format` and `print`.

## Usage example

```dart
import 'package:format/format.dart';
import 'package:intl/intl.dart';

void main() {
  print(format('{}', 'hello world')); // "hello world"
  print('{}'.format('hello world')); // "hello world"
  '{}'.print('hello world'); // "hello world"

  '{} {}'.print('hello', 'world'); // "hello world" (max 10 values)
  '{} {}'
      .print(['hello', 'world']); // "hello world" (unlimited number of values)
  '{0} {1}'.print('hello', 'world'); // "hello world"
  '{1} {0}'.print('hello', 'world'); // "world hello"
  '{h} {w}'.print({'h': 'hello', 'w': 'world'}); // "hello world"
  '{"it\'s hello"} {"it\'s world"}'
      .print({"it's hello": 'hello', "it's world": 'world'}); // "hello world"

  '{:d}'.print(123); // "123"
  '{:7d}'.print(123); // "    123"
  '{:<7d}'.print(123); // "123    "
  '{:^7d}'.print(123); // "  123  "
  '{:*^7d}'.print(123); // "**123**"

  '{:07d}'.print(123); // "0000123"
  '{:09,d}'.print(123); // "0,000,123"
  '{:09_d}'.print(123); // "0_000_123"

  '{:0{},d}'.print(123, 9); // "0,000,123"
  '{:0{},d}'.print(123, 11); // "000,000,123"
  '{value:0{width},d}'.print({'value': 123, 'width': 13}); // "0,000,000,123"

  '{:+d}'.print(123); // "+123"
  '{: d}'.print(123); // " 123"

  // Automatic type inference.
  '{}'.print(123); // "123"
  '{}'.print('aaa'); // "aaa"
  '{:7}'.print(123); // "    123"
  '{:7}'.print('aaa'); // "aaa    "

  const n = 123.4567;
  '{:.2f}'.print(n); // 123.46
  '{:10.2f}'.print(n); // '    123.46'
  '{:010.2f}'.print(n); // 0000123.46
  '{:012,.2f}'.print(n); // 0,000,123.46
  '{:012_.2f}'.print(n); // 0_000_123.46

  '{:0{},.{}f}'.print(n, 12, 2); // 0,000,123.46
  '{value:0{width},.{precision}f}'.print({
    'value': n,
    'width': 12,
    'precision': 2,
  }); // 0,000,123.46

  const n1 = 123456.789;
  const n2 = 1234567.89;
  '{:g}'.print(n1); // 123457
  '{:g}'.print(n2); // 1.23457e+6
  '{:.9g}'.print(n1); // 123456.789
  '{:.9g}'.print(n2); // 1234567.89
  '{:.5g}'.print(n1); // 1.2346e+5
  '{:.5g}'.print(n2); // 1.2346e+6

  '{:g}'.print(double.nan); // nan
  '{:g}'.print(double.infinity); // inf
  '{:g}'.print(double.negativeInfinity); // -inf

  const i = 12345678;
  '{:b}'.print(i); // 101111000110000101001110
  '{:d}'.print(i); // 12345678
  '{:x}'.print(i); // bc614e
  '{:X}'.print(i); // BC614E
  '{:#x}'.print(i); // 0xbc614e
  '{:#X}'.print(i); // 0xBC614E

  '{:_b}'.print(i); // 1011_1100_0110_0001_0100_1110
  '{:,d}'.print(i); // 12,345,678
  '{:_d}'.print(i); // 12_345_678
  '{:_x}'.print(i); // bc_614e
  '{:_X}'.print(i); // BC_614E
  '{:#_x}'.print(i); // 0xbc_614e
  '{:#_X}'.print(i); // 0xBC_614E

  '{:c}+{:c}+{:c}+{:c}={:c}'.print(
    0x1F468, // 👨
    0x1F469, // 👩
    0x1F466, // 👦
    0x1F467, // 👧
    [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466, 0x200D, 0x1F467], // 👨‍👩‍👦‍👧
  ); // 👨+👩+👦+👧=👨‍👩‍👦‍👧

  '{:👨>10}'.print('!'); // 👨👨👨👨👨👨👨👨👨!
  '{:👨‍👩‍👦‍👧>10}'.print(
      '!'); // 👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧!
  '{:ä>10}'.print('!'); // äääääääää!

  const m = 12345678.9;
  Intl.defaultLocale = 'ru_RU';
  '{:n}'.print(m); // 1,23457E7
  '{:.9n}'.print(m); // 12345678,9
  '{:012,.9n}'.print(m); // 12 345 678,9
  '{:n}'.print(double.nan); // не число
  '{:n}'.print(double.infinity); // ∞
  '{:n}'.print(double.negativeInfinity); // -∞

  Intl.defaultLocale = 'de_DE';
  '{:n}'.print(m); // 1,23457E7
  '{:.9n}'.print(m); // 12345678,9
  '{:012,.9n}'.print(m); // 12.345.678,9

  Intl.defaultLocale = 'en_IN';
  '{:n}'.print(m); // 1.23457E7
  '{:.9n}'.print(m); // 12345678.9
  '{:012,.9n}'.print(m); // 1,23,45,678.9

  Intl.defaultLocale = 'bn';
  '{:n}'.print(m); // ১.২৩৪৫৭E৭
  '{:.9n}'.print(m); // ১২৩৪৫৬৭৮.৯
  '{:012,.9n}'.print(m); // ১,২৩,৪৫,৬৭৮.৯

  Intl.defaultLocale = 'ar_EG';
  '{:n}'.print(m); // ١٫٢٣٤٥٧اس٧
  '{:.9n}'.print(m); // ١٢٣٤٥٦٧٨٫٩
  '{:012,.9n}'.print(m); // ١٢٬٣٤٥٬٦٧٨٫٩
  '{:n}'.print(double.nan); // ليس رقم

  '{:👨^5}'.print(':'); // 👨👨:👨👨
  '{:👨‍👩‍👦‍👧^5}'
      .print(':'); // 👨‍👩‍👦‍👧👨‍👩‍👦‍👧:👨‍👩‍👦‍👧👨‍👩‍👦‍👧
}
```

## Description

Function `format` similar to [format](https://docs.python.org/3/library/string.html#format-string-syntax)
method in Python, [std::format](https://en.cppreference.com/w/cpp/utility/format/format)
function from C++20, which in turn became the development of the popular
function [sprintf](https://en.cppreference.com/w/c/io/fprintf) from C. Its
essence is that instead of templates enclosed in curly braces `{}`, substitute
the values of the passed arguments, formatting them as required.

```dart
String result = '{...}'.format(...);
```

### Template description

```text
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

```text
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

If `align` is specified, then the `fill` line can be anything a combination of
characters, while only one character is allowed in Python. This is made in order
to be able to use symbols consisting of several Unicode characters (accented
characters, surrogate pairs, etc.), and at the same time do not engage in
unnecessary analysis.

Python imposes only one constraint on the fill character - not allowed use curly
braces `{}` because they are used to insert values inside the template. In Dart,
there is no need for such a function, since he has built into the language is
excellent [string interpolation](https://dart.dev/guides/language/language-tour#strings).

Possible `align` values:

| Value    | Description
| :------: | :-------
|    '<'   | Left justification (this is the default for strings and characters).
|    '>'   | Right justification (this is the default for numbers).
|    '^'   | Center alignment.

Of course, `align` only matters when a minimum width is given the field is
`width`, and it is larger than the actual width of the field. In this case, the
result is is complemented to the specified one from the corresponding side.

Python also includes the '=' value, through which you can insert any character
instead of leading zeros between the number sign ('+' or '-') and the first
significant digits ('+ 123', '- 42'). '0' before width acts the same principle.
I didn’t take this opportunity. First, because I am not I can understand the
reasons why this is necessary. If the task was to replace leading zeros any
character, then this is not entirely true, because the option of arranging
separators thousand (',') is not included if a character other than '0' is
specified. Those. Python distinguishes zeros from other characters in this
function. Secondly, because of this features all these strange '00000nan',
'-0000inf' appear. Although not it is clear why exactly in these cases no
exception was made for zeros.

#### `sign`

With this function, you can specify how to handle the sign of a number.

| Value  | Description
| :---:  | :---
|  '-'   | The sign is placed only for negative numbers (this is the default value).
|  '+'   | Positive numbers also have a sign (zero also comes with a plus).
|  ''    | Positive numbers have a space character instead of '+'. This can be useful for aligning positive and negative numbers with each other.

...to be continued
