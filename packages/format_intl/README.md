# format_intl

`format_intl` adapts the number symbols and grouping rules in
[`intl`](https://pub.dev/packages/intl) for use with
[`format`](https://pub.dev/packages/format). It keeps `format` independent of
`intl` while letting an application opt into locale-aware number formatting.

## Installation

Add both packages to the application that creates the formatting engine:

```yaml
dependencies:
  format: ^4.0.0
  format_intl: ^1.0.0
```

Under Flutter there is one more constraint to satisfy, and it is not this
package's: `flutter_localizations` pins `intl` to a single exact version, so
that pin and the constraint here have to overlap. The `intl` range above spans
both versions Flutter pins — 0.19.0 up to Flutter 3.31.x and 0.20.2 from
3.32.0 — so the two overlap on every Flutter from 3.27.0, which is also the
first one `format` itself installs on.

### Which `intl` your application resolves is visible in the output

This package is an adapter: it reports the symbols the resolved `intl` carries,
and that data is not identical across the range. Of the 119 locales `intl`
ships, four differ:

| Locale | `intl` 0.19.0 | 0.20.2 | 0.20.3 |
| --- | --- | --- | --- |
| `en_ZA` | decimal `.`, group `,` | decimal `,`, group NBSP | same as 0.20.2 |
| `de_CH`, `gsw`, `it_CH` | group `’` | group `’` | group `'` |

Only `en_ZA` changes the decimal separator, so it is the one where a number can
be read wrongly rather than merely look different. Note that three of the four
already move inside a `^0.20.2` constraint: pinning the range up would not have
made the output version-independent, only narrower. Every other locale is
identical across all three versions.

## Usage

Inject an `IntlNumberLocale` when constructing `Format`. The resulting engine
is independent of the package-level default API, so retain whichever method
tear-offs your application needs:

```dart
import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';

void main() {
  final kazakh = Format(
    numberLocale: IntlNumberLocale('kk_KZ'),
  );
  final formatKk = kazakh.format;
  final sprintfKk = kazakh.sprintf;

  print(formatKk('{:n}', 1234567.5));
  print(sprintfKk('%.2f', 12.5));
}
```

`Format` provides four formatting method tear-offs:

- `format` accepts a brace-format template and up to ten positional values.
- `formatWith` accepts a brace-format template plus `positional` and `named`
  collections.
- `sprintf` accepts a printf-style template and up to ten positional values.
- `vsprintf` accepts a printf-style template and a list of values.

The `n` specifier applies the adapter's grouping rule automatically; it does
not need a grouping flag. The printf dialect uses the locale's decimal
separator, signs, exponent separator, and digits.

That exponent separator is worth knowing about before it surprises you: `intl`
spells it `E` for 108 of its 119 locales, so `%e` and `%E` produce the same
text under most of them and stop being distinguishable. Seven locales spell it
as something that is not a letter at all — `×10^` in `sv`, `أس` in `ar_EG` —
and there `%E` has nothing to uppercase either. Brace formatting is
unaffected, because `{:e}` does not read the locale at all; only `{:n}`
does. `IntlNumberLocale` supplies
symbols and grouping only: it does not round values. Precision and rounding
remain the responsibility of `format`. `IntlNumberLocale` does not select or
apply number notation, including compact or scientific notation; notation
remains the responsibility of `format`.

Decimal `double` values use Dart SDK conversion by default. Locale symbols are
applied after that conversion. Select the compatible profile when Python brace
or C++ printf rounding and exponent layout are required:

```dart
final compatibleKazakh = Format(
  numberLocale: IntlNumberLocale('kk_KZ'),
  doubleFormatMode: DoubleFormatMode.compatible,
);
```

`DoubleSpecialValueSpelling.short` selects `nan`/`inf` in Dart SDK mode;
compatible mode always uses those short spellings. These profile settings
belong to `Format`, not `IntlNumberLocale`.

## Default-locale snapshot

Use `IntlNumberLocale.fromDefault()` when the `intl` current locale should be
chosen at construction time:

```dart
final locale = IntlNumberLocale.fromDefault();
final engine = Format(numberLocale: locale);
```

This takes an immutable snapshot of the locale's number symbols and grouping
rules. Changing `Intl.defaultLocale` later does not update an existing
`IntlNumberLocale` or `Format`; construct a new adapter and engine to use the
new default.

## Localized digits are a Dart extension

`IntlNumberLocale` also maps ASCII digits to the locale's `ZERO_DIGIT` symbol.
That applies to both brace and printf formatting. Localized digits and locale
specific signs or exponent symbols are Dart extensions provided by `format`'s
`NumberLocale` interface; they go beyond the C locale behavior that printf
compatibility targets.
