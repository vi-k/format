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

## Text formatting

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

The C-style subset supports `%%`, `%c`, `%s`, signed and unsigned integer
conversions, and decimal or hexadecimal floating-point conversions. Width and
precision may be literals or `*` arguments. Decimal floating-point conversions
use the selected double profile: Dart SDK semantics by default, or deterministic
C++23-compatible nearest-even rounding and `inf`/`nan` spelling in compatible
mode. In the default profile `sprintf('%e', 12.5)` returns `1.25e+1`, not the
C `1.250000e+01`: select `DoubleFormatMode.compatible` when C-exact decimal
output is required. Negative unsigned values are rejected instead of wrapped.

This Dart dialect intentionally omits `%n`, `%p`, C length modifiers, POSIX
`$` argument indexing, and C++26 `%b`/`%B`. String width and precision use the
configured Unicode `TextUnit`; `%c` accepts a Unicode scalar; `%s` calls
`toString()` for non-string Dart values; and `int`/`BigInt` are not truncated
to a C machine width. A configured `NumberLocale`, including one supplied by
`format_intl`, may localize signs, separators, and digits beyond the normative
`LC_ALL=C` compatibility profile.

## Number locales

The `n` presentation type and the `,`/`_` grouping flags read a `NumberLocale`.
The default is the C locale, which groups with `,`, separates decimals with
`.`, and leaves `n` ungrouped:

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

A locale may localize signs, separators, and digits beyond what the C locale
core specifies; the compatibility fixtures pin only the C locale behavior.

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
A formatter is therefore never consulted for a value the engine already
renders: one that accepts everything still leaves `{}` on a `String` or an
`int` to the built-in path, and only an explicit `{:name}` reaches such a
value. When two formatters accept the same value and the placeholder names
neither, the engine throws `AmbiguousFormatterException` rather than picking
one.

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

### Attribute lookup

Dart has no reflection, so `{value.attribute}` resolves only through a
registered `AttributeLookup`. Without one, the engine throws
`FormatLookupException`:

```dart
final class PointLookup extends AttributeLookup<Point> {
  @override
  bool canLookup(Object? value) => value is Point;

  @override
  Object? lookup(Point value, String attribute) => switch (attribute) {
    'x' => value.x,
    _ => throw ArgumentError.value(attribute, 'attribute'),
  };
}

final pointFormat = Format(lookups: [PointLookup()]);
pointFormat.formatWith('{p.x}', named: {'p': const Point(7)});  // 7
```

A `Map` is the exception: `{value.name}` on a map is a shorthand for the
string key `'name'`, resolved before any lookup is consulted, so a lookup that
accepts maps is never called for one.

```dart
formatWith('{value.name}', named: {
  'value': {'name': 'Ada'},
});  // Ada
```

### Custom representations

Implement `Representation<T>` to give a type its own `!r` and `!a` form.
Built-in representations take priority the same way built-in formatters do,
and `!a` escapes non-ASCII characters in whatever the representation returned:

```dart
final class MoneyRepresentation extends Representation<Money> {
  @override
  bool canRepresent(Object? value) => value is Money;

  @override
  String represent(Money value) => '${value.cents}¢';
}

final moneyRepr = Format(representations: [MoneyRepresentation()]);
moneyRepr.format('{!r}', const Money(250));  // 250¢
moneyRepr.format('{!a}', const Money(250));  // 250\xa2
```

### Failures inside an extension

Anything an extension throws is caught and rethrown as
`FormatExtensionException`, which carries the original `error` and
`stackTrace` along with the template location. The exception to that is a
`FormattingException`: an extension reporting a failure in the engine's own
vocabulary has it passed through unchanged.

Errors Dart raises on the extension's behalf are wrapped the same way. A
`canFormat` that accepts a value of the wrong type produces a `TypeError` when
the engine calls `format`, and an extension that formats by calling the engine
again on the same value produces a `StackOverflowError` — both arrive as
`FormatExtensionException` rather than escaping the engine raw.

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

Lowering either bound discards entries immediately, rather than at the next
insertion.

`templateCacheSize` tells "the cache is too small for this workload" apart
from "this workload never repeats a template", which otherwise look alike from
the outside. Read with `templateCacheMemory`, it also tells a cache full of
small templates from one held by a handful of large or field-dense ones — the
two need opposite adjustments. To see the difference the cache makes on the
current machine, the benchmark measures every case with it on and off:

```console
cd benchmark/suite
dart run bin/benchmark.dart
```

## Format 3.0 migration

Version 2.0.0 was never published to pub.dev, so migrating from the published
1.6.0 means adopting the 2.0 and 3.0 changes together; both are described in
the CHANGELOG.

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
