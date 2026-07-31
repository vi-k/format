# Format 2.0 Design

## Goal

Replace the legacy formatter and the experimental `format2` implementation
with one extensible formatting engine that preserves supported output behavior,
provides a type-safe public API, and does not regress multi-placeholder
performance.

## Public API

Version 2.0 exposes only top-level formatting functions:

```dart
String format(String template, List<Object?> values);

String formatNamed(
  String template,
  Map<String, Object?> values,
);
```

The following APIs are removed:

- `format2` and `format2m`;
- `String.format` and `String.print` extensions;
- the legacy `format` overload with positional arguments `v2` through `v10`;
- `Map<Symbol, Object?>` named arguments;
- dynamic width and precision read from positional or named arguments.

Literal width and precision remain part of the template syntax.

## Template Syntax

Built-in specifiers keep their existing one-character names. Custom
specifiers use ASCII identifiers matching:

```text
[A-Za-z][A-Za-z0-9_]*
```

Both opening and closing braces are escaped by doubling them:

```text
{{ -> {
}} -> }
```

Width and precision accept decimal integer literals only. Forms such as
`{:{}}`, `{:.{}}`, `{:{width}}`, and `{:.{precision}}` are invalid in 2.0.

## Engine Architecture

There is one processor implementation behind both public functions. The
processor parses the template, resolves each value, selects a formatter,
formats the value, and finally applies common padding.

Built-in specifiers use a direct dispatch path rather than the custom formatter
registry. This avoids a map lookup and formatter-list iteration for every
placeholder. Custom specifiers use a global registry owned by `Format.instance`.

The implementation must not maintain separate legacy and experimental
formatting paths.

## Formatter API

The public extension point is generic:

```dart
abstract base class Formatter<T> {
  String get specifier;

  bool canFormat(Object? value);

  String format(T value, FormatOptions options);
}
```

`FormatOptions` is immutable. It exposes the parsed options needed by a value
formatter:

- sign;
- alternate form;
- zero flag;
- grouping option;
- precision;
- additional template.

Width, fill, and alignment are handled by the processor after the formatter
returns its unpadded string. This guarantees consistent Unicode-aware padding
for built-in and custom formatters.

One formatter owns one specifier. The specifier is read from the formatter
object, so registration cannot receive a mismatched name and formatter.

## Global Formatter Registry

Custom formatters are registered globally within the current Dart isolate:

```dart
Format.instance.registerFormatter(formatter);
final removed = Format.instance.unregisterFormatter('json');
```

Built-in specifier names are reserved. Registering or unregistering a built-in
specifier is an error. Registering an already registered custom specifier is
also an error.

`unregisterFormatter` returns `true` when it removes a custom formatter and
`false` when no custom formatter has that name. Removing a formatter also
removes it from automatic selection.

## Automatic Formatter Selection

For a placeholder without an explicit specifier, formatter selection follows
this order:

1. Built-in types have unconditional priority:
   - `String` uses `s`;
   - `int` and `BigInt` use `d`;
   - `double` uses `g`.
2. Every registered custom formatter is queried through `canFormat`.
3. One custom match is selected.
4. Multiple custom matches throw `AmbiguousFormatterException`.
5. No match falls back to `value.toString()`.

An explicitly named custom specifier selects its registered formatter without
running automatic selection.

## Errors

Formatting errors use a typed hierarchy rooted at `FormattingException`:

- `InvalidFormatException` for invalid template syntax or options;
- `InvalidSpecifierException` for a custom specifier that is not a valid ASCII
  identifier;
- `FormatterAlreadyRegisteredException` for duplicate registration;
- `BuiltInSpecifierException` for attempts to register or unregister a
  built-in specifier;
- `AmbiguousFormatterException` when automatic selection finds multiple custom
  formatters;
- `UnsupportedFormatValueException` when an explicitly selected formatter
  cannot accept the supplied value.

Exceptions expose structured context such as the specifier, template fragment,
and offending value when applicable. Tests assert exception types and fields,
not complete human-readable messages.

## Correctness Requirements

The new engine preserves all supported output behavior from the legacy
formatter except the explicitly removed APIs and dynamic width/precision.

The implementation must correct the known defects found during review:

- closing-brace escaping must handle `}}`;
- invalid literal width and precision must produce typed formatting errors;
- `n` precision must be validated before calling Dart number APIs;
- zero padding combined with grouping must not access strings out of range;
- custom formatter registration must be usable through
  `package:format/format.dart` without importing `src` files.

## Performance Requirements

The performance baseline covers both JIT and AOT execution. The benchmark suite
must include:

- integer and floating-point formatting;
- strings and Unicode grapheme clusters;
- named arguments;
- locale-aware `n` formatting;
- custom formatters;
- templates containing 1, 5, 10, and 50 placeholders.

Each reported comparison uses equivalent input and output, performs warmup,
runs long enough to reduce timer noise, and reports the ratio between the old
and new engines. The new engine must not show a repeatable slowdown on
multi-placeholder templates beyond measurement noise. The existing simple-case
performance improvement should be retained where practical.

Template precompilation and caching are outside this implementation. They can
be designed as a separate feature after the 2.0 engine is complete.

## Testing Strategy

Development follows red-green-refactor. Tests are added before each behavior
change and observed failing for the expected reason.

The test suite includes:

- migrated legacy output-contract tests using `format` and `formatNamed`;
- syntax and brace-escaping tests;
- fixed literal width and precision tests;
- tests proving dynamic width and precision are rejected;
- zero-padding and grouping edge cases for positive, negative, prefixed, `int`,
  and `BigInt` values;
- registration, duplicate registration, removal, reserved built-in names, and
  invalid custom names;
- explicit custom formatting;
- automatic matching, built-in priority, fallback to `toString`, and ambiguity;
- public-import tests that implement a custom `Formatter` without importing
  internal source files;
- JIT and AOT performance comparisons.

## Migration

Because this is a major release, removed APIs do not require deprecated aliases
inside the 2.0 implementation. The changelog and README must show the new
`format` and `formatNamed` calls and list the removed extension methods,
`Map<Symbol, Object?>`, positional convenience arguments, and dynamic
width/precision.
