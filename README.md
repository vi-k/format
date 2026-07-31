# format

`format` is a Dart package for Python-style string formatting with positional
and named values, Unicode-aware alignment, locale-aware numbers, and custom
formatters.

## Usage

```dart
import 'package:format/format.dart';

format('{} {}', ['hello', 'world']);
format('{1} {0}', ['hello', 'world']);
formatNamed('{name}: {value}', {'name': 'answer', 'value': 42});
```

The public formatting API consists of:

```dart
String format(String template, List<Object?> values);
String formatNamed(String template, Map<String, Object?> values);
```

Literal width and precision are supported in templates:

```dart
format('{:08d}', [42]);       // 00000042
format('{:>10.2f}', [12.34]); //      12.34
format('{:*^9s}', ['hello']); // **hello**
```

Use doubled braces to emit literal braces:

```dart
format('{{value}} = {0}', [42]); // {value} = 42
```

Formatting width is measured in Unicode grapheme clusters, so emoji and
combined characters align as one visible character:

```dart
format('{:🇺🇦^10s}', ['peace']);
```

The `n` specifier uses the current `intl` locale:

```dart
Intl.defaultLocale = 'uk_UA';
format('{:,.8n}', [123456.789]);
```

## Custom formatters

Implement `Formatter<T>`, then register it globally for the current isolate:

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

Format.registerFormatter(JsonFormatter());
format('{:json}', [<String, Object?>{'answer': 42}]);
Format.unregisterFormatter('json');
```

Custom specifiers must match `[A-Za-z][A-Za-z0-9_]*`. Built-in names are
reserved. For a placeholder without an explicit specifier, built-in types take
priority, followed by a unique matching custom formatter, then `toString()`.
Multiple custom matches throw `AmbiguousFormatterException`.

Width, fill, and alignment are applied by the engine after a custom formatter
returns, while `FormatOptions` provides sign, alternate form, zero, grouping,
precision, and the optional additional template.

## Format 2.0 migration

Version 2.0 removes the old String extensions, `format2`/`format2m`, positional
convenience arguments, `Map<Symbol, Object?>`, and dynamic width or precision.
Replace them as follows:

```dart
format('{} {}', ['hello', 'world']);
formatNamed('{name}: {value}', {'name': 'answer', 'value': 42});
```

Forms such as `{:{}}`, `{:.{}}`, and `{:{width}}` are invalid. Use decimal
literals directly in the template. Formatting failures use the typed
`FormattingException` hierarchy.
