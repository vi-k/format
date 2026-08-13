/// String formatting in two mini-languages over one engine: Python-style
/// braces and printf-style conversions.
///
/// ```dart
/// format('{:>8s} {:,d}', 'total', 1234567);  //    total 1,234,567
/// sprintf('%-8s %.2f', 'total', 12.5);       // total    12.50
/// ```
///
/// [format] and [formatWith] read `{...}` placeholders, [sprintf] and
/// [vsprintf] read `%...` conversions, and both dialects share the number
/// formatting underneath. Every failure is a [FormattingException] carrying
/// where in the template it happened; this hierarchy is separate from
/// `dart:core`'s `FormatException`.
///
/// The top-level functions use [defaultFormat]. Configure anything — a
/// [NumberLocale], a [TextUnit] for what width counts, a [DoubleFormatMode]
/// for how `double` is rendered, or custom [Formatter]s, [AttributeLookup]s
/// and [Representation]s — by constructing a [Format] and calling the same
/// methods on it, rather than by mutating global state.
///
/// Parsed templates are cached per isolate; [templateCacheCapacity] and
/// [templateCacheMemoryLimit] bound that cache, and [templateCacheSize] with
/// [templateCacheMemory] report it.
library;

// Imported as well as exported so that the doc comment above can link to these
// names: a doc reference resolves in the library's own scope, and a facade that
// only exports has none. `engine.dart` re-exports the rest of them, which is
// why importing it alone is enough — and why importing the others as well is
// flagged as unnecessary.
import 'src/engine.dart';
import 'src/extensions.dart';

export 'src/double_format.dart'
    show DoubleFormatMode, DoubleSpecialValueSpelling;
export 'src/engine.dart'
    show
        Format,
        clearTemplateCache,
        defaultFormat,
        format,
        formatWith,
        sprintf,
        templateCacheCapacity,
        templateCacheMemory,
        templateCacheMemoryLimit,
        templateCacheSize,
        vsprintf;
export 'src/errors.dart'
    show
        AmbiguousFormatterException,
        FormatConfigurationException,
        FormatExceptionContext,
        FormatExtensionException,
        FormatLookupException,
        FormattingException,
        InvalidFormatException,
        InvalidSpecifierException,
        MissingFormatArgumentException,
        UnsupportedConversionException,
        UnsupportedFormatValueException;
export 'src/extensions.dart'
    show AttributeLookup, FormatOptions, Formatter, Representation;
export 'src/number_locale.dart' show CNumberLocale, NumberLocale;
export 'src/text_unit.dart' show TextUnit, TextUnitOperations;
