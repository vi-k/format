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

Formatting width uses Unicode scalar values by default. Configure grapheme
clusters when emoji and combined characters should align as one visible
character:

```dart
final graphemeFormat = Format(textUnit: TextUnit.graphemeClusters);
graphemeFormat.format('{:🇰🇿^13s}', 'Қазақстан');
```

The optional [`format_intl`](https://pub.dev/packages/format_intl) package
adapts `intl` locale data without adding `intl` to this package's dependencies:

```dart
import 'package:format_intl/format_intl.dart';

final kazakh = Format(numberLocale: IntlNumberLocale('kk_KZ'));
kazakh.format('{:.8n}', 123456.789);
```

## Double formatting profiles

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
while `g` and `n` accept 1 through 21. As with `toStringAsFixed`, `f` may use
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

Compare both profiles on the current machine with the ANSI-colored benchmark:

```console
cd benchmark/suite
dart run bin/double_modes_benchmark.dart
```

For finite `double` values in the benchmark scenarios,
`DoubleFormatMode.dartSdk` is faster than compatible mode or falls within the
default 5% equivalence threshold. The report prints both formatted results and
median times; this performance conclusion does not include `NaN` or
`Infinity`. VS Code also provides the **Benchmark: double modes** launch
configuration.

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

The C-style subset supports `%%`, `%c`, `%s`, signed and unsigned integer
conversions, and decimal or hexadecimal floating-point conversions. Width and
precision may be literals or `*` arguments. Decimal floating-point conversions
use the selected double profile: Dart SDK semantics by default, or deterministic
C++23-compatible nearest-even rounding and `inf`/`nan` spelling in compatible
mode. Negative unsigned values are rejected instead of wrapped.

This Dart dialect intentionally omits `%n`, `%p`, C length modifiers, POSIX
`$` argument indexing, and C++26 `%b`/`%B`. String width and precision use the
configured Unicode `TextUnit`; `%c` accepts a Unicode scalar; `%s` calls
`toString()` for non-string Dart values; and `int`/`BigInt` are not truncated
to a C machine width. A configured `NumberLocale`, including one supplied by
`format_intl`, may localize signs, separators, and digits beyond the normative
`LC_ALL=C` compatibility profile.

## Custom formatters

Implement `Formatter<T>`, then provide it to an immutable `Format` instance:

```dart
final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is Map<String, Object?>;

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

final jsonFormat = Format(formatters: [JsonFormatter()]);
jsonFormat.format('{:json}', <String, Object?>{'answer': 42});
```

Custom specifiers must match `[A-Za-z][A-Za-z0-9_]*`. Built-in names are
reserved. For a placeholder without an explicit specifier, built-in types take
priority, followed by a unique matching custom formatter, then `toString()`.
Multiple custom matches throw `AmbiguousFormatterException`.

Width, fill, and alignment are applied by the engine after a custom formatter
returns, while `FormatOptions` provides sign, alternate form, zero, grouping,
precision, and the optional additional template.

## JavaScript number semantics

dart2js represents an `int` and an integral `double` as the same JavaScript
`number`. Format canonically treats that indistinguishable value as an integer:
empty, integer, `!r`, and container formatting spell both `42` and `42.0` as
`42`. Explicit floating-point specifiers such as `f`, `e`, `g`, and `%` still
select floating-point formatting. On the Dart VM, `42` and `42.0` remain
distinct and empty formatting produces `42` and `42.0` respectively. `BigInt`
remains a separate value kind on every platform.

## Representations

The `!r` conversion produces a Dart-oriented representation, while `!a` also
escapes non-ASCII characters. Nested `double` values follow the selected double
profile and special-value spelling. Empty `Map` and `Set` values are both
represented as `{}`. This ambiguity is intentional: non-empty values remain
distinguishable by their entries.

## Format 3.0 migration

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

Formatting failures use the typed `FormattingException` hierarchy. Configure
custom formatters, lookups, representations, locales, and text units by
constructing a `Format` instance instead of mutating global registries.

Version 3.0 uses Dart SDK decimal `double` conversion by default. Applications
that depend on Python/C++ rounding, exponent layout, precision beyond the Dart
SDK limits, or `inf`/`nan` spellings should construct a `Format` with
`DoubleFormatMode.compatible`. This setting applies consistently to brace
formatting, `sprintf`, and nested `!r`/`!a` representations.
