# format

[![CI](https://github.com/vi-k/format/actions/workflows/ci.yaml/badge.svg)](https://github.com/vi-k/format/actions/workflows/ci.yaml)

`format` brings Python-style braces and printf-style mini-languages to Dart
while keeping Dart SDK number conversion as the default. It supports positional
and named values, Unicode-aware alignment, locale-aware numbers, and custom
formatters.

## Usage

```dart
import 'package:format/format.dart';

format('{} {}', 'hello', 'world');
format('{1} {0}', 'hello', 'world');
formatWith('{name}: {value}', named: {'name': 'answer', 'value': 42});
```

The public formatting API consists of:

```dart
format(String template, [Object? value1, ..., Object? value10]);
formatWith(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
});
sprintf(String template, [Object? value1, ..., Object? value10]);
vsprintf(String template, List<Object?> values);
```

Literal width and precision are supported in templates:

```dart
format('{:08d}', 42);       // 00000042
format('{:>10.2f}', 12.34); //      12.34
format('{:*^9s}', 'hello'); // **hello**
```

Use doubled braces to emit literal braces:

```dart
format('{{value}} = {0}', 42); // {value} = 42
```

The same doubling works inside a format specification, but there the two
forms must balance: `{{` requires a later `}}`, because the first unescaped
`}` is what ends the specification. In ordinary text they are independent, so
a lone `{{` is fine there and a lone `{` is not.

## Key differences from 1.6.0

Version 2.0.0 was never published, so upgrading from 1.6.0 takes the 2.0 and
3.0 changes together. The CHANGELOG lists them in full, and
[Format 3.0 migration](#format-30-migration) describes what an upgrade has to
change in calling code.

- **Two mini-languages on one engine.** Braces stay in `format` and
  `formatWith`; the printf dialect arrives as [`sprintf` and
  `vsprintf`](#sprintf), with C-style conversions for text, integers, and
  floating point.
- **Configuration is an object, not a global.** A `Format` instance carries the
  number locale, the text unit, the `double` profile, and the registered
  [custom formatters](#custom-formatters), attribute lookups, and
  representations. Instances are immutable and there is no global registry to
  mutate.
- **The `String` extension is gone.** 1.6.0 formatted through `'{}'.format(x)`
  as well; 3.0 exports top-level functions only.
- **Failures are typed.** Every one of them is a `FormattingException` subclass
  that carries the position in the template — see [Error
  classes](#error-classes). The hierarchy is separate from `dart:core`'s
  `FormatException` and does not extend it, so `on FormatException` catches
  nothing this package throws.
- **`double` conversion follows the Dart SDK by default.** [Double formatting
  profiles](#double-formatting-profiles) switches to the Python/C++ compatible
  profile where its rounding, exponent layout, extended precision, and
  `inf`/`nan` spellings are wanted.
- **`intl` is no longer a dependency.** [Number locales](#number-locales)
  define the separators, digits, and grouping, the C locale is the default, and
  `package:format_intl` supplies an `intl`-backed locale for applications that
  want one. Code that relied on 1.6.0 reading the ambient `intl` locale for `n`
  has to pass a locale explicitly.
- **Width counts what you choose.** [Unicode text units](#unicode-text-units)
  align by grapheme clusters, Unicode scalars, or UTF-16 code units.
- **Templates are compiled and cached.** 1.6.0 parsed the template with regular
  expressions on every call. 3.0 compiles it into a program of typed operations
  and keeps that program in a [template cache](#template-cache) bounded by
  entry count and by memory. This is where most of the difference measured
  below comes from.

### Performance against 1.6.0

Each figure below is a ratio: how many times faster 3.0 formats the same
template and the same values than 1.6.0 does. Both versions run in one process
against the same values, so the machine cancels out of the comparison.

| template | values | Dart VM | dart2js | dart2wasm |
|---|---|---|---|---|
| `{}` | `'hello world'` | 17.8× | 3.0× | 22.5× |
| `{:d}` | `-12345` | 9.3× | 2.0× | 11.5× |
| `{:d}` | the runtime's largest exact integer | 2.5× | 1.2× | 7.5× |
| `{:10d}` | `1` | 10.8× | 3.0× | 9.4× |
| `{:,d}` | `1234567` | 16.1× | 4.1× | 19.4× |
| `{:010,d}` | `1234` | 28.1× | 6.5× | 19.9× |
| `{:.2f}` | `0.1` | 8.8× | 2.7× | 7.9× |
| fifty `{}` fields | `0`…`49` | 11.7× | 2.8× | 25.4× |

Over the whole matrix of thirty-one cases the gain is 2.4× to 28.1× on the VM,
6.5× to 25.4× under dart2wasm, and 1.1× to 6.4× under dart2js. The narrowest
gains are on integers at the platform's exact limit, where writing nineteen or
twenty digits is most of the call and 1.6.0's per-call overhead weighs least;
the widest are on grouped or zero-padded integers and on long templates, where
1.6.0 pays for a regular expression per call and 3.0 pays for nothing it has
already compiled.

The cache is most of that difference, and it is the part a workload can lose.
With it off, the VM keeps 1.7× to 8.9× and dart2wasm 1.5× to 7.6×, but dart2js
falls behind 1.6.0 on twenty-six of the thirty-one cases, between 0.46× and
2.1×: 1.6.0's regular expressions run on the JavaScript engine's own regex
implementation, while the 3.0 scanner is compiled JavaScript. [When to turn it
off](#when-to-turn-it-off) describes the workloads where the cache does not pay
for itself.

`sprintf` has no counterpart here — 1.6.0 had no printf dialect — so the table
has no row for it; the benchmark compares it against `package:sprintf` instead.

Measured on an Apple M3 Max (macOS 26.5.2, Dart 3.13.0, Node v26.5.0) as the
minimum over the measured rounds, against a vendored copy of 1.6.0, from a
clone of the repository rather than the published package:

```console
cd benchmark/suite
dart run tool/run.dart --runtime=vm   -- --full
dart run tool/run.dart --runtime=js   -- --full
dart run tool/run.dart --runtime=wasm -- --full
```

Another machine will print other numbers. What carries over is the ordering
between templates and between runtimes, not the ratios themselves.

<!-- BEGIN GENERATED FORMAT REFERENCE -->
## Format reference

### Brace template grammar

```text
template = (literal | "{{" | "}}" | replacement_field)*
replacement_field = "{" field_name? lookup* conversion? format_spec? "}"
field_name = decimal_index | python_identifier
lookup = "." python_identifier | "[" item_key "]"
automatic xor manual positional numbering
conversion = "!" ("s" | "r" | "a")
format_spec may contain replacement_field at depth 1
```

| Syntax | Meaning |
|---|---|
| `template = (literal \| "{{" \| "}}" \| replacement_field)*` | Doubled braces emit literals. |
| `replacement_field = "{" field_name? lookup* conversion? format_spec? "}"` | Field parts have this order. |
| `field_name = decimal_index \| python_identifier` | Empty is automatic; Python Unicode decimal digits are positional; an identifier is named. |
| `lookup = "." python_identifier \| "[" item_key "]"` | Unicode identifier attributes and non-empty unquoted item chains. |
| `automatic xor manual positional numbering` | Automatic and numeric roots never mix. |
| `conversion = "!" ("s" \| "r" \| "a")` | Conversion precedes the specification. |
| `format_spec may contain replacement_field at depth 1` | One nested level; nested specifications cannot nest again. |

### Brace format specification

```text
[[fill]align][sign]["z"]["#"]["0"][width][grouping]["." (precision [grouping] | grouping)][type | custom_name [":" payload]]
custom_name = ASCII_LETTER (ASCII_LETTER | ASCII_DIGIT | "_")*
```

| Syntax | Meaning |
|---|---|
| `[[fill]align][sign]["z"]["#"]["0"][width][grouping]["." (precision [grouping] \| grouping)][type \| custom_name [":" payload]]` | Exact option order. |
| `custom_name = ASCII_LETTER (ASCII_LETTER \| ASCII_DIGIT \| "_")*` | Built-ins reserved, payload follows colon. |

### Brace options

| Tokens | Meaning | Default | Applies to |
|---|---|---|---|
| `<`, `>`, `^`, `=` | Fill with one text unit and align left, right, center, or after the sign. | Text and custom output align left; numbers align right. Zero implies sign-aware alignment when align is absent. | `String`, `int`, `BigInt`, `double`, custom value |
| `+`, `-`, ` ` | Select the sign for numeric output. | Minus only. | `int`, `BigInt`, `double`, custom value |
| `z` | Remove the minus when rounding produces zero. | Off; clears a sign only after rounding to zero. | `double`, custom value |
| `#` | Request a radix prefix or decimal point. | Off; a radix prefix or forced decimal point, with no visible prefix for decimal integers. | `int`, `BigInt`, `double`, custom value |
| `0` | Request sign-aware numeric zero padding. | Off; numeric sign-aware zero padding, passed through to a custom formatter. | `int`, `BigInt`, `double`, custom value |
| `ASCII_DIGIT+` | Set the minimum field width. | Absent; range 0…100000. | `String`, `int`, `BigInt`, `double`, custom value |
| `,`, `_` | Group integer digits with comma or underscore. | Absent; comma is decimal-only, underscore supports every non-locale radix, and custom formatters receive only this separator. | `int`, `BigInt`, `double`, custom value |
| `.ASCII_DIGIT+` | Truncate text or control numeric precision. | Absent; truncates text, controls numeric digits, and passes an integer value to a custom formatter. | `String`, `double`, custom value |
| `.,`, `._`, `precision suffix ,`, `precision suffix _` | Group fractional digits after rounding. | Absent; accepted syntactically but not exposed to custom formatters. | `double` |
| `built-in letter`, `custom_name` | Select a built-in presentation or custom formatter. | Inferred from the value when empty. | any value |
| `:balanced specification text` | Pass resolved text after the custom formatter name. | Absent differs from empty; nested fields resolve before the callback. | custom value |

### Brace presentation matrix

| Type | Accepts | Allowed option tokens | Result | Default precision |
|---|---|---|---|---|
| *empty* | any value | `<`, `>`, `^` (`String`, `int`, `BigInt`, `double` only); `=` (`int`, `BigInt`, `double` only); `+`, `-`, ` ` (`int`, `BigInt`, `double` only); `z` (`double` only); `#` (`int`, `BigInt`, `double` only); `0` (`int`, `BigInt`, `double` only); `ASCII_DIGIT+` (`String`, `int`, `BigInt`, `double` only); `,`, `_` (`int`, `BigInt`, `double` only); `.ASCII_DIGIT+` (`String`, `double` only); `.,`, `._`, `precision suffix ,`, `precision suffix _` (`double` only); *empty* | Value-default text or one matching custom formatter. | Depends on the value type. |
| `s` | `String` | `<`, `>`, `^`; `ASCII_DIGIT+`; `.ASCII_DIGIT+`; `s` | [Text, optionally truncated.](#text-formatting) | Not specified. |
| `c` | `int`, `BigInt` | `<`, `>`, `^`; `ASCII_DIGIT+`; `c` | [One Unicode scalar.](#character-values) | Not specified. |
| `d` | `int`, `BigInt` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `d` | Exact decimal integer. | Not specified. |
| `b` | `int`, `BigInt` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `#`; `0`; `ASCII_DIGIT+`; `_`; `b` | Exact binary integer. | Not specified. |
| `o` | `int`, `BigInt` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `#`; `0`; `ASCII_DIGIT+`; `_`; `o` | Exact octal integer. | Not specified. |
| `x`, `X` | `int`, `BigInt` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `#`; `0`; `ASCII_DIGIT+`; `_`; `x`, `X` | Exact lower- or uppercase hexadecimal integer. | Not specified. |
| `n` | `int`, `BigInt`, `double` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `z` (`double` only); `#`; `0`; `ASCII_DIGIT+`; `.ASCII_DIGIT+` (`double` only); `n` | [Locale-aware decimal or general number.](#number-locales) | Floating values use the general default. |
| `f`, `F` | `int`, `BigInt`, `double` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `z`; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `.ASCII_DIGIT+`; `.,`, `._`, `precision suffix ,`, `precision suffix _`; `f`, `F` | [Fixed-point number.](#double-formatting-profiles) | 6 fractional digits |
| `e`, `E` | `int`, `BigInt`, `double` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `z`; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `.ASCII_DIGIT+`; `.,`, `._`, `precision suffix ,`, `precision suffix _`; `e`, `E` | [Scientific notation.](#double-formatting-profiles) | SDK shortest exponent or compatible precision 6 |
| `g`, `G` | `int`, `BigInt`, `double` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `z`; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `.ASCII_DIGIT+`; `.,`, `._`, `precision suffix ,`, `precision suffix _`; `g`, `G` | [General decimal notation.](#double-formatting-profiles) | SDK shortest or compatible significant precision 6 |
| `%` | `int`, `BigInt`, `double` | `<`, `>`, `^`, `=`; `+`, `-`, ` `; `z`; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `.ASCII_DIGIT+`; `.,`, `._`, `precision suffix ,`, `precision suffix _`; `%` | [Value multiplied by 100 with a percent suffix.](#double-formatting-profiles) | 6 fractional digits |
| `ASCII name` | custom value | `<`, `>`, `^`; `+`, `-`, ` `; `z`; `#`; `0`; `ASCII_DIGIT+`; `,`, `_`; `.ASCII_DIGIT+`; `ASCII name`; `:balanced specification text` | [Custom callback output with engine-applied layout.](#custom-formatters) | Not specified. |

### Printf grammar and dynamic options

```text
template = (literal | conversion)*
conversion = "%" flags width? precision? type
flags = ("-" | "+" | " " | "#" | "0")*
width = ASCII_DIGIT+ | "*"
precision = "." (ASCII_DIGIT* | "*")
no "$" positions; no h/l/j/z/t/L modifiers
```

| Syntax | Meaning |
|---|---|
| `template = (literal \| conversion)*` | Percent begins every conversion. |
| `conversion = "%" flags width? precision? type` | Fixed order. |
| `flags = ("-" \| "+" \| " " \| "#" \| "0")*` | Repeats collapse; `+` beats space, `-` beats zero. |
| `width = ASCII_DIGIT+ \| "*"` | Dynamic width is consumed before precision and value. |
| `precision = "." (ASCII_DIGIT* \| "*")` | Empty is zero; negative dynamic precision is absent. |
| `no "$" positions; no h/l/j/z/t/L modifiers` | Unsupported C/POSIX syntax is rejected. |

| Tokens | Meaning | Default | Applies to |
|---|---|---|---|
| `ASCII_DIGIT+`, `*` | Set literal or argument-supplied minimum width. | Absent for every value conversion; `%%` forbids it. | any value |
| `.ASCII_DIGIT*`, `.*` | Set literal or argument-supplied precision. | Absent for text, integer, and floating conversions; `%c` and `%%` forbid it. | `String`, `int`, `BigInt`, `double` |

### Printf flag matrix

| Flag | Allowed conversions | Meaning | Default |
|---|---|---|---|
| `-` | `s`, `c`, `d`, `i`, `u`, `o`, `x`, `X`, `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A` | Left-align the converted value. | Right alignment for every value conversion. |
| `+` | `d`, `i`, `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A` | Show a plus sign for a non-negative signed value. | Minus only. |
| ` ` | `d`, `i`, `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A` | Prefix a non-negative signed value with a space. | Off; ignored when `+` exists. |
| `#` | `o`, `x`, `X`, `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A` | Request the conversion's alternate form. | Off. |
| `0` | `d`, `i`, `u`, `o`, `x`, `X`, `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A` | Pad a numeric conversion with zeros. | Off; disabled by `-`, and for integers by precision. |

### Printf conversion matrix

| Type | Accepts | Allowed option tokens | Result | Default precision |
|---|---|---|---|---|
| `s` | any value | `-`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [`toString()` text, optionally truncated.](#unicode-text-units) | Not specified. |
| `c` | `int`, `BigInt` | `-`; `ASCII_DIGIT+`, `*` | [One Unicode scalar.](#character-values) | Not specified. |
| `d`, `i` | `int`, `BigInt` | `-`; `+`; ` `; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Signed decimal integer.](#sprintf) | No leading precision zeros. |
| `u` | non-negative `int`, `BigInt` | `-`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Non-negative decimal integer.](#sprintf) | No leading precision zeros. |
| `o` | non-negative `int`, `BigInt` | `-`; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Non-negative octal integer.](#sprintf) | No leading precision zeros. |
| `x`, `X` | non-negative `int`, `BigInt` | `-`; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Non-negative hexadecimal integer.](#sprintf) | No leading precision zeros. |
| `f`, `F` | `double` | `-`; `+`; ` `; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Fixed-point double.](#double-formatting-profiles) | 6 fractional digits |
| `e`, `E` | `double` | `-`; `+`; ` `; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Scientific double.](#double-formatting-profiles) | SDK exponent spelling when absent, otherwise requested; compatible default 6 |
| `g`, `G` | `double` | `-`; `+`; ` `; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [General decimal double.](#double-formatting-profiles) | SDK `toString` when absent; compatible significant precision 6 |
| `a`, `A` | `double` | `-`; `+`; ` `; `#`; `0`; `ASCII_DIGIT+`, `*`; `.ASCII_DIGIT*`, `.*` | [Exact hexadecimal binary64 notation.](#double-formatting-profiles) | Exact trimmed notation |
| `%` | — | — | [Literal percent; no value consumed.](#sprintf) | Not specified. |

### Limits

| Rule | Contract |
|---|---|
| Safe option size | `brace and printf literal width/precision ≤ 100000` |
| Dynamic width | `printf dynamic width −100000…100000; negative means left alignment` |
| Dynamic precision | `printf dynamic precision ≤ 100000; every negative value means absent` |
| Fill expansion | `width * fill.length ≤ 200000 UTF-16 code units` |
| Field indexes | `brace positional and numeric item index ≤ 9223372036854775807` |
| Nesting depth | `one nested replacement-field level` |
| Dart-profile precision | `` Dart profile: general/empty/`n` 1…21; `f`/`e`/`%` 0…20 `` |
| Compatible-profile precision | `` compatible profile accepts 0…100000; `g` precision 0 behaves as 1 `` |

### Error classes

| Rule | Contract |
|---|---|
| Malformed template | `InvalidFormatException` |
| Inapplicable options | `InvalidSpecifierException` |
| Unsupported value | `UnsupportedFormatValueException` |
| Unsupported brace conversion | `UnsupportedConversionException` |
| Missing argument | `MissingFormatArgumentException` |

<!-- END GENERATED FORMAT REFERENCE -->

## Text formatting

The complete token set for text is in the
[brace presentation matrix](#brace-presentation-matrix).

Fill, alignment, and width apply to whatever the placeholder produced, and
precision truncates text rather than rounding it:

```dart
format('{:>8s}', 'hi');     //       hi
format('{:.3s}', 'abcdef'); // abc
```

Zero padding is a numeric option, so a text specification rejects it instead
of quietly padding with zeros:

```dart
format('{:05s}', 'abc');  // throws InvalidSpecifierException
```

Width and precision are read as ASCII digits. Other Unicode digits are a
specification error, though they remain usable in a field index or key, where
they name an argument rather than a count:

```dart
format('{:٥d}', 1);                        // throws InvalidSpecifierException
formatWith('{٠}', positional: ['first']);  // first
```

## Character values

The exact brace and printf option sets for characters are in the
[brace presentation matrix](#brace-presentation-matrix) and
[printf conversion matrix](#printf-conversion-matrix).

The `c` conversion turns a number into the character it encodes, in both
mini-languages:

```dart
format('{:c}', 0x41);  // A
sprintf('%c', 0x41);   // A
```

The value must be a Unicode scalar. A lone surrogate or a value above
`0x10FFFF` is rejected rather than producing a broken string, and zero padding
is a numeric option here too:

```dart
format('{:c}', 0xD800);    // throws UnsupportedFormatValueException
format('{:c}', 0x110000);  // throws UnsupportedFormatValueException
format('{:05c}', 0x41);    // throws InvalidSpecifierException
```

## Unicode text units

The [brace presentation matrix](#brace-presentation-matrix) and
[printf conversion matrix](#printf-conversion-matrix) link text conversions
back here because these units govern their width, precision, and fill behavior.

Width and precision count Unicode scalar values by default. Configure grapheme
clusters when emoji and combined characters should count as one visible
character each:

```dart
final graphemeFormat = Format(textUnit: TextUnit.graphemeClusters);

format('{:.3s}', '👩‍👩‍👧‍👦ab');              // 👩‍👩  — three scalars
graphemeFormat.format('{:.3s}', '👩‍👩‍👧‍👦ab');  // 👩‍👩‍👧‍👦ab — three clusters
graphemeFormat.format('{:*<5s}', '👩‍👩‍👧‍👦');   // 👩‍👩‍👧‍👦****
```

The unit also decides what counts as a single fill character, so a multi-scalar
fill needs the grapheme mode:

```dart
graphemeFormat.format('{:🇰🇿^13s}', 'Қазақстан');  // 🇰🇿🇰🇿Қазақстан🇰🇿🇰🇿
format('{:🇰🇿^13s}', 'Қазақстан');                // throws InvalidSpecifierException
```

`TextUnitOperations` exposes the same measurement the engine uses, for code
that needs to lay out text alongside it:

```dart
TextUnit.graphemeClusters.length('👩‍👩‍👧‍👦ab');  // 3
TextUnit.unicodeScalars.length('👩‍👩‍👧‍👦ab');    // 9
```

## Double formatting profiles

The numeric rows and their default precisions are collected in the
[brace presentation matrix](#brace-presentation-matrix) and
[printf conversion matrix](#printf-conversion-matrix).

Decimal `double` conversions use the Dart SDK by default. In particular, `f`,
`e`, and `g` delegate to `toStringAsFixed`, `toStringAsExponential`, and
`toStringAsPrecision` when a precision is present. The no-precision `g` and
empty conversions use `toString()`:

```dart
format('{:.0f}', 2.5);          // 3
format('{:e}', 1.0);            // 1e+0
format('{:.3g}', 1.0);          // 1.00
format('{}', double.infinity);  // Infinity
```

SDK precision limits therefore apply: `f`, `e`, and `%` accept 0 through 20,
while `g` and `n` accept 1 through 21. A specification with a precision but no
type counts as `g` here, so `format('{:.0}', 2.0)` is rejected in this mode and
gives `2e+00` in the compatible one. As with `toStringAsFixed`, `f` may use
exponential notation for magnitudes at or above `10^21`.

Select `DoubleFormatMode.compatible` when exact Python brace-formatting and
C++ printf rounding and spelling are required:

```dart
final compatible = Format(
  doubleFormatMode: DoubleFormatMode.compatible,
);

compatible.format('{:.0f}', 2.5);          // 2
compatible.format('{:e}', 1.0);            // 1.000000e+00
compatible.format('{:.3g}', 1.0);          // 1
compatible.format('{}', double.infinity);  // inf
```

Compare both profiles on the current machine with the ANSI-colored benchmark,
from a clone of the [repository](https://github.com/vi-k/format) — the
benchmarks are not part of the published package:

```console
cd benchmark/suite
dart run bin/double_modes_benchmark.dart
```

For finite `double` values in the benchmark scenarios,
`DoubleFormatMode.dartSdk` is faster than compatible mode or falls within the
default 5% equivalence threshold. The report prints both formatted results and
median times; this performance conclusion does not include `NaN` or
`Infinity`, and it is measured on the Dart VM — the benchmark runs there, and
the two modes have not been compared under dart2js. VS Code also provides the
**Benchmark: double modes** launch configuration.

In Dart SDK mode, non-finite values are `NaN` and `Infinity` by default. Their
short spellings can be selected independently; compatible mode always uses
short spellings:

```dart
final shortSpecials = Format(
  doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
);

shortSpecials.format('{}', double.nan);        // nan
shortSpecials.sprintf('%F', double.infinity);  // INF
```

## sprintf

Use `sprintf` for direct arguments and `vsprintf` for a list:

```dart
sprintf('%s: %#08x', 'answer', 42);       // answer: 0x00002a
vsprintf('%*.*f', [8, 2, 1.5]);           //     1.50
```

The complete set of letters, accepted values, and flags is in the
[printf conversion matrix](#printf-conversion-matrix). Width and precision may
be literals or `*` arguments. Decimal floating-point conversions use the
selected double profile: Dart SDK semantics by default, or deterministic
C++23-compatible nearest-even rounding and `inf`/`nan` spelling in compatible
mode. In the default profile `sprintf('%e', 12.5)` returns `1.25e+1`, not the C
`1.250000e+01`: select `DoubleFormatMode.compatible` when C-exact decimal output
is required. Negative unsigned values are rejected instead of wrapped.

This Dart dialect intentionally omits `%n`, `%p`, C length modifiers, POSIX
`$` argument indexing, and C++26 `%b`/`%B`. String width and precision use the
configured Unicode `TextUnit`; `%c` accepts a Unicode scalar; `%s` calls
`toString()` for non-string Dart values; and `int`/`BigInt` are not truncated
to a C machine width. A configured `NumberLocale`, including one supplied by
`format_intl`, may localize signs, separators, and digits beyond the normative
`LC_ALL=C` compatibility profile.

## Number locales

The locale-aware brace and printf rows are indexed in the
[brace presentation matrix](#brace-presentation-matrix) and
[printf conversion matrix](#printf-conversion-matrix).

The `n` presentation type reads a `NumberLocale`. The `,` and `_` grouping
flags do not: they always write the separator they name, exactly as CPython
does, so `'{:,d}'` is `1,234,567` under every locale and only `'{:n}'` follows
the configured one.

The printf dialect answers differently, and deliberately: `%f`, `%e`, `%g` and
`%a` write the locale's decimal separator, because that is what C does with
`LC_NUMERIC`, while the brace dialect keeps `.` because that is what Python
does. Under a locale that separates decimals with a comma, `'{:.2f}'` is
`1234.50` and `'%.2f'` is `1234,50` — each dialect follows the language it
comes from rather than the other one.

The default locale is the C locale, which groups with `,`, separates decimals
with `.`, and leaves `n` ungrouped:

```dart
format('{:,.2f}', 1234567.5);  // 1,234,567.50
format('{:n}', 1234567);       // 1234567
```

Implement `NumberLocale` for a locale of your own, or use the optional
[`format_intl`](https://pub.dev/packages/format_intl) package, which adapts
`intl` locale data without adding `intl` to this package's dependencies:

```dart
import 'package:format_intl/format_intl.dart';

final kazakh = Format(numberLocale: IntlNumberLocale('kk_KZ'));
kazakh.format('{:.8n}', 123456.789);
```

The printf dialect has no `n`, so every numeric conversion reads the locale —
`%d` and `%x` take its digits and signs, `%f` and `%e` its separators too. It
never groups on its own: a template that did not ask for separators does not
get them.

A locale localizes digits, and only digits: `localizeDigits` is handed the
ASCII `0`–`9` of a number and nothing else. In `%x`, `%X` and `%#o` that means
the digits change and the hexadecimal letters do not — under a locale with
Eastern Arabic digits, `sprintf('%x', 0xabc123)` is `abc١٢٣` — and in `%a` the
mantissa digits and exponent are localized while the `0x` prefix and the `p`
that marks the exponent stay as they are. C localizes none of this, and Python
has no such conversions; the mixed script is the price of localizing the digits
of a conversion whose letters are not digits.

A locale may localize signs, separators, and digits beyond what the C locale
core specifies; the compatibility fixtures pin only the C locale behavior.

## Custom formatters

The accepted built-in layout tokens and callback-specific payload token are in
the [brace presentation matrix](#brace-presentation-matrix).

Implement `Formatter<T>`, then provide it to an immutable `Format` instance:

```dart
final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

final jsonFormat = Format(formatters: [JsonFormatter()]);
jsonFormat.format('{:json}', <String, Object?>{'answer': 42});
```

The engine checks a value against the formatter's `T` before any extension
code runs. `canFormat(T value)` returns `true` by default, so an ordinary
formatter only implements `format`. Override the typed predicate only for a
narrower condition within `T`, for example
`bool canFormat(Money value) => value.currency == 'KZT'`.

Custom specifiers must match `[A-Za-z][A-Za-z0-9_]*`. Built-in names are
reserved. For a placeholder without an explicit specifier, built-in types take
priority, followed by a unique matching custom formatter, then `toString()`.
A formatter is therefore never consulted for a value the engine already
renders: one that accepts everything still leaves `{}` on a `String` or an
`int` to the built-in path, and only an explicit `{:name}` reaches such a
value. When two formatters accept the same value and the placeholder names
neither, the engine throws `AmbiguousFormatterException` rather than picking
one.

Automatic selection needs the specification to be *empty*, not merely
nameless: `{:>12}` on a custom value carries options and names nothing, so it
never reaches the registry and is rejected as a specification. Name the
formatter — `{:>12money}` — or leave the specification empty. Options alone do
not select one, because then registering an extension would change what an
unrelated `{:>12}` elsewhere in the program means.

Width, fill, and alignment are applied by the engine after a custom formatter
returns, while `FormatOptions` provides sign, alternate form, zero, grouping,
precision, and the optional additional template. That template is the text
after a second `:`; the formatter reads it from `FormatOptions.payload` and
interprets it however it likes:

```dart
jsonFormat.format('{:json:pretty}', <String, Object?>{'answer': 42});
// JsonFormatter.format receives options.payload == 'pretty'
```

A payload lives inside the specification, so it inherits the balancing rule
above: braces reach it doubled, and a lone one cannot be carried at all.

```dart
jsonFormat.format('{:json:a{{b}}c}', <String, Object?>{'answer': 42});
// options.payload == 'a{b}c'
jsonFormat.format('{:json:a{{b}', <String, Object?>{'answer': 42});
// throws InvalidFormatException — the {{ has no matching }}
```

`FormatOptions` describes the specification, not the engine: a formatter
receives no `NumberLocale`, `TextUnit` or `DoubleFormatMode`. So `grouping` is
the flag as written (`,` or `_`), not the separator to write with — a
formatter that groups digits itself needs the locale, and the application
hands it over the same way it hands it to the engine:

```dart
const locale = MyLocale();
final engine = Format(
  numberLocale: locale,
  formatters: [MoneyFormatter(locale)],
);
```

### Attribute lookup

Dart has no reflection, so `{value.attribute}` resolves only through a
registered `AttributeLookup`. Without one, the engine throws
`FormatLookupException`:

```dart
final class PointLookup extends AttributeLookup<Point> {
  @override
  Object? lookup(Point value, String attribute) => switch (attribute) {
    'x' => value.x,
    _ => throw ArgumentError.value(attribute, 'attribute'),
  };
}

final pointFormat = Format(lookups: [PointLookup()]);
pointFormat.formatWith('{p.x}', named: {'p': const Point(7)});  // 7
```

The same typed default applies to `canLookup`: the engine first checks
`Point`, and the inherited method accepts every `Point`. Override
`bool canLookup(Point value)` only to select a subset of points.

A `Map` is the exception: `{value.name}` on a map is a shorthand for the
string key `'name'`, resolved before any lookup is consulted, so a lookup that
accepts maps is never called for one.

```dart
formatWith('{value.name}', named: {
  'value': {'name': 'Ada'},
});  // Ada
```

An `[item]` key is literal text, as in Python: whatever stands between the
brackets is the key, quotes included. A key that *begins* with a quote is
refused instead, because that is Python's dict syntax written by mistake and
the error says so rather than reporting a key that was never there:

```dart
formatWith("{0[it's]}", positional: [{"it's": 'fine'}]);  // fine
formatWith("{0['key']}", positional: [{"'key'": 1}]);     // throws
```

### Custom representations

Implement `Representation<T>` to give a type its own `!r` and `!a` form.
Built-in representations take priority the same way built-in formatters do,
and `!a` escapes non-ASCII characters in whatever the representation returned:

```dart
final class MoneyRepresentation extends Representation<Money> {
  @override
  String represent(Money value) => '${value.cents}¢';
}

final moneyRepr = Format(representations: [MoneyRepresentation()]);
moneyRepr.format('{!r}', const Money(250));  // 250¢
moneyRepr.format('{!a}', const Money(250));  // 250\xa2
```

`canRepresent(Money value)` likewise returns `true` by default and is needed
only when a representation accepts a subset of `Money` values.

### Failures inside an extension

Anything an extension throws is caught and rethrown as
`FormatExtensionException`, which carries the original `error` and
`stackTrace` along with the template location. The exception to that is a
`FormattingException`: an extension reporting a failure in the engine's own
vocabulary has it passed through unchanged.

A value outside an extension's `T` is an ordinary non-match: the engine does
not call its typed predicate. Errors Dart raises inside extension code are
wrapped the same way; for example, an extension that formats by calling the
engine again on the same value produces a `StackOverflowError`, which arrives
as `FormatExtensionException` rather than escaping the engine raw.

## JavaScript number semantics

dart2js represents an `int` and an integral `double` as the same JavaScript
`number`. Format canonically treats that indistinguishable value as an integer:
empty, integer, `!r`, and container formatting spell both `42` and `42.0` as
`42`. Explicit floating-point specifiers such as `f`, `e`, `g`, and `%` still
select floating-point formatting. So does a specification that carries no type
but does carry a precision, a `z`, or a fraction separator — no integer
specification accepts any of those, so `'{:.3}'` is a floating specification
whatever the runtime believes the value to be, and `format('{:.3}', 2.0)` is
`2.00` in a browser as it is everywhere else. The cost of that is the mirror
case: `format('{:.3}', 2)` also produces `2.00` on the web, where the VM and
CPython reject it. dart2js cannot tell the two values apart, so one of the two
answers has to give; this way the divergence hands back a string rather than an
exception. On the Dart VM, `42` and `42.0` remain distinct and empty formatting
produces `42` and `42.0` respectively. `BigInt` remains a separate value kind on
every platform.

## Representations

The `!r` conversion produces a Dart-oriented representation, while `!a` also
escapes non-ASCII characters. Both are implemented by this package rather than
delegated to the value: there is no Dart equivalent of the Python object
protocol to call.

```dart
format('{0!r} {0!a}', 'строка');
// 'строка' '\u0441\u0442\u0440\u043e\u043a\u0430'
```

Values are spelled with their Dart tokens, and a container keeps the iteration
order of the collection it came from rather than being reordered:

```dart
format('{} {} {}', true, false, null);  // true false null
format('{!r}', {'b': 1, 'a': 2});       // {'b': 1, 'a': 2}
format('{!r}', {'b', 'a'});             // {'b', 'a'}
```

Nested `double` values follow the selected double profile and special-value
spelling. Empty `Map` and `Set` values are both represented as `{}`. This
ambiguity is intentional: non-empty values remain distinguishable by their
entries.

## Template cache

Parsed templates are cached, which is what makes repeated formatting cheap.
How much cheaper depends on the template, and the spread is wide: parsing is
paid per template, while formatting is paid per field, so the denser the
template the smaller the share parsing takes. Measured on the package's own
benchmark, a first call costs this much more than a cached one:

| template | Dart VM | dart2js |
|---|---|---|
| `literal {}` | 4.5× | 14.1× |
| ten `{i:d}` fields | 20.6× | 21.5× |
| five `%d` conversions | 4.3× | 8.1× |
| fifty `%d` conversions | 5.1× | 7.7× |

The two runtimes differ, and not in the direction the table might suggest at a
glance: under dart2js parsing is dearer than on the VM while formatting is
cheaper, so it is the cached call that pulls the quotient up. The cache is
therefore worth more on the web, not less. Figures quoted anywhere in this
README are measured on the Dart VM unless a runtime is named.

The cache is bounded, because templates can come from data and an unbounded
cache would be an unbounded leak.

```dart
templateCacheCapacity;     // 512 entries by default, per mini-language
templateCacheMemoryLimit;  // 8 MiB by default, per mini-language
templateCacheSize;         // how many parsed templates are resident
templateCacheMemory;       // what they are estimated to hold
clearTemplateCache();      // discard them all
```

There are two bounds because a count of entries says nothing about their size.
A workload with a few very large generated templates stays well inside the
capacity while holding hundreds of megabytes, so the second bound is on memory:
whichever binds first evicts.

That figure is an estimate, and it has to be — a Dart program cannot measure
the memory it holds. An entry is priced by a model of what caching it retains:
the template text as the key, the text each literal slices out of it, the code
units prepared for those literals on the VM, and a constant per parse node. The
constants are fitted to measured retention, and the model matters because the
same amount of text costs wildly different amounts depending on its shape —
around 1 byte per character for text with no fields, 4 with a few, 76 for a
template of nothing but `{}` and 120 for one of nothing but `{:d}`, where what
an entry holds is a parse node each rather than text. The default therefore
holds about 2 Mi characters of ordinary text, or 110 Ki of the dense kind: the
budget adapts where a count of characters could not.

An entry priced above the whole budget is formatted but never cached — emptying
the cache for one that still would not fit costs every other template its parse
and gains nothing.

Both bounds are per isolate and shared by every `Format` instance — a parsed
template does not depend on the engine that parsed it. Raise the capacity when
the working set is larger than the default and templates repeat; a set that
cycles past it keeps roughly `capacity / size` of itself resident, because a
full cache evicts at random rather than in order.

Set either to zero when templates are generated and never repeat, so that
caching would only pay to evict:

```dart
templateCacheCapacity = 0;  // discards what is cached, and keeps nothing
```

You do not have to: a cache that misses and evicts many times in a row stops
being consulted by itself, and is consulted again after a while in case the
workload has changed. What it holds is kept rather than discarded, so nothing
is lost when it comes back. Measured on the cold path under dart2js, a call
formatting a template it has never seen went from 600 ns to 250 for a literal
template and from 4230 to 2240 for one of ten fields; on the VM 469 to 311 and
2337 to 2043; under dart2wasm 379 to 237 and 2424 to 1900. Setting the bound to
zero is still the sharper instrument — it says so from the first call rather
than after the misses that establish it, and it frees what is cached.

### When to turn it off

What decides is not how often a template repeats but whether the working set
fits inside both bounds. If it fits, the cache pays for itself almost at once;
if it does not, it never pays at all, at any repetition rate — an entry is
evicted before the workload comes back to it. Measured as cached time over
uncached time, so below 1 means the cache is winning:

| distinct templates | shape | ×1 | ×2 | ×3 | ×5 | ×10 |
|---|---|---|---|---|---|---|
| inside the bounds | ten `{i:>8,d}` fields | 1.16 | **0.66** | 0.50 | 0.36 | 0.26 |
| inside the bounds | ten `{}` fields | 1.47 | **0.93** | 0.69 | 0.54 | 0.45 |
| inside the bounds | one literal, no fields | 5.82 | 1.85 | 1.40 | 1.04 | **0.68** |
| past the bounds | ten `{i:>8,d}` fields | 1.34 | 1.30 | 1.28 | 1.33 | 1.30 |
| past the bounds | ten `{}` fields | 1.75 | 1.58 | 1.57 | 1.52 | 1.48 |
| past the bounds | one literal, no fields | 8.17 | 4.52 | 5.10 | 4.04 | 3.95 |

So a template with fields repays its own caching on the second use, and a
template that is nothing but literal text takes until about the seventh —
there is nothing to parse there, while the cache still charges two table
operations. The rows past the bounds are flat, which is the point: repetition
buys nothing once the set no longer fits.

Those three flat rows are what the cache now steps out of on its own — they
are measured with it consulted throughout, which is what it used to do and
what it still does until the misses add up. Turning it off outright is the
difference between paying that for the first few hundred calls and not paying
it at all.

Before turning the cache off, weigh raising both bounds so that the set does
fit — and size that with `templateCacheMemory` rather than by eye, because
capacity alone will not do it. What an entry holds depends on its shape far
more than on its length:

| shape | per entry | fit in the default 8 MiB |
|---|---|---|
| one literal, no fields | 5 bytes | about 1 750 000 |
| ten `{}` fields | about 1.7 KiB | about 5 000 |
| ten `{i:>8,d}` fields | about 5 KiB | about 1 640 |

A template with no fields is its own output and holds only the key, which is
why it is nearly free to cache and also the one shape least worth caching.
A field-dense template holds a parse node per field, so raising the capacity
to 8192 without raising the memory limit leaves it evicting exactly as before.

Lowering either bound discards entries immediately, rather than at the next
insertion.

`templateCacheSize` tells "the cache is too small for this workload" apart
from "this workload never repeats a template", which otherwise look alike from
the outside. Both it and `templateCacheMemory` are sums across the two
mini-languages, while the two bounds apply to each separately: a program using
braces and printf alike can read 1024 resident templates with the capacity at
512 and nothing be wrong. Read with `templateCacheMemory`, it also tells a
cache full of small templates from one held by a handful of large or
field-dense ones — the two need opposite adjustments. To see the difference
the cache makes on the current machine, the benchmark measures every case with
it on and off — again from a clone of the repository, not from the published
package:

```console
cd benchmark/suite
dart run bin/benchmark.dart             # on the Dart VM
dart run tool/run.dart --runtime=js     # dart2js, under node
dart run tool/run.dart --runtime=wasm   # dart2wasm, under node
```

`tool/run.dart` also takes `--bin=`, one of `comparison`, `template_ir`,
`double_modes`, `list_snapshot`, and compiles into a temporary directory.
The operations per round are calibrated to whichever clock the runtime has:
under dart2js it advances in whole milliseconds, so a count tuned on the VM
would print multiples of 50 ns and nothing between them.

## Format 3.0 migration

Version 2.0.0 was never published to pub.dev, so migrating from the published
1.6.0 means adopting the 2.0 and 3.0 changes together; both are described in
the CHANGELOG. What the two of them add, and how the result measures against
1.6.0, is in [Key differences from 1.6.0](#key-differences-from-160).

Version 3.0 removes `formatNamed` and treats a `List` passed to `format` as one
value. Pass direct values separately, or use `formatWith` for positional and
named collections:

```dart
format('{} {}', 'hello', 'world');
formatWith(
  '{name}: {value}',
  named: {'name': 'answer', 'value': 42},
);
```

Formatting failures use the typed `FormattingException` hierarchy. It is
separate from `dart:core`'s `FormatException` and does not extend it, so
`on FormatException` catches nothing this package throws — catch
`FormattingException`. Configure custom formatters, lookups, representations,
locales, and text units by constructing a `Format` instance instead of mutating
global registries.

Version 3.0 uses Dart SDK decimal `double` conversion by default. Applications
that depend on Python/C++ rounding, exponent layout, precision beyond the Dart
SDK limits, or `inf`/`nan` spellings should construct a `Format` with
`DoubleFormatMode.compatible`. This setting applies consistently to brace
formatting, `sprintf`, and nested `!r`/`!a` representations.
