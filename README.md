# format

It is a package for formatting Dart strings. It contains: the `format`
function and the extension methods of the String class: `format` and `print`.

Function `format` similar to [format](https://docs.python.org/3/library/string.html#format-string-syntax)
method in Python, [std::format](https://en.cppreference.com/w/cpp/utility/format/format)
function from C++20, which in turn became the development of the popular
function [sprintf](https://en.cppreference.com/w/c/io/fprintf) from C. Its
essence is that instead of templates enclosed in curly braces `{}`, substitute
the values of the passed arguments, formatting them as required.

```dart
String result = '{...}'.format(...);
```

## Usage example

Hello world:

```dart
format('{}', 'hello world'); // hello world
```

Values as function arguments (max 10 values):

```dart
format('{} {}', 'hello', 'world'); // hello world
```

Values as positional arguments (unlimited number of values):

```dart
format('{} {}', ['hello', 'world']);
```

Manual numbering of positional arguments:

```dart
format('{0} {1}', 'hello', 'world'); // hello world
format('{1} {0}', 'hello', 'world'); // world hello
```

Values as named arguments:

```dart
format('{h} {w}', {'h': 'hello', 'w': 'world'}); // hello world
format('{w} {h}', {#h: 'hello', #w: 'world'}); // world hello
```

Number formatting:

```dart
print('| Name     |    Price |    Count |      Sum |');
print(
  '| {name:8s} | {price:8.2f} | {count:8d} | {sum:8.2f} |'.format({
    #name: 'Apple',
    #price: 1.2,
    #count: 9,
    #sum: 10.8,
  }),
);

// | Name     |    Price |    Count |      Sum |
// | Apple    |     1.20 |        9 |    10.80 |
```

Unicode:

```dart
format('{:🇺🇦^12}', ' No war '); // 🇺🇦🇺🇦 No war 🇺🇦🇺🇦
```

Locale:

```dart
Intl.defaultLocale = 'uk_UA';
format('{:,.8n}', 123456.789); // 123 456,79

Intl.defaultLocale = 'bn';
format('{:,.8n}', 123456.789); // ১,২৩,৪৫৬.৭৯
```

## Differences from Python

- Python supports only one type of argument numbering at a time: either
  automatic numbering (`{} {} {}`) or manual numbering (`{0} {1} {2}`).
  I've added the ability to use both types of numbering at the same time:

  ```dart
  format('{0} {}->1 {}->2 {5} {}->6'); // 0 1 2 5 6
  ```

- Named parameters can be specified in national languages according to the same
  principle as Latin characters: the identifier must start with a letter or an
  underscore and then digits can be added (Unicode is ised). Parameter names
  can be specified in quotes (both single and double). There are no
  restrictions in this case. Quotation marks inside names must be double-quoted
  to avoid being perceived as the end of the identifier.

  ```dart
  format('{가격}', {'가격': 123.45});
  format("{'It''s a name'}", {"It's a name": 'Name'});
  ```

- The alternative format for `X` outputs `0x` instead of `0X` (`0xABCDEF`
  instead of `0XABCDEF`).

  ```dart
  format('{0:#x} {0:#X}', 0xabcdef); // 0xabcdef 0xABCDEF
  ```

- I did not support an alternative format for `b` (`0b...`) and `o` (`0o...`),
  since Dart does not support such literals. Let me know if you need it.

- `nan` and `inf` are not complemented with zeros when the zero flag is set (as
  Python does, but msvc:spintf does not). `sign` does not work for `nan` (`nan`
  cannot become `+nan`) (Python and msvc:sprintf output `+nan`). In short,
  neither `nan` nor `inf` changes in any way. Only the width alignment works.
  And this is done deliberately. Nobody, as I think, needs `+nan`, `000nan` and
  `000inf`.

- In `g` and `n` formats, the default precision is 6.

- To support surrogate pairs and other combinations of Unicode characters,
  `fill` can accept any number of characters, as long as it ends with one of
  the `align` characters (`>`, `<`, `^`).

- Not supported in named arguments .key and index. That's an interesting
  solution. I like it. But I didn't.

- In exponential notation ('e' and 'g') in Python, the exponent is returned
  with at least two digits. I have one.

- In `n` format, `E5` is output instead of `e+05`. This is how NumberFormat
  works by default.

- Does not support `=` in `align`.

- Doesn't support `%`.

- `{}` only supports `width` and `precision`, while Python supports `{}`
  anywhere to form a pattern. But this can easily be replaced with `${}`.
