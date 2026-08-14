/// The engine, and the seam its own tests reach it through. Not an entry
/// point for users of this package.
///
/// `package:format/format.dart` is the supported surface and the only one the
/// version number promises anything about. Everything here — the parts below,
/// the re-exports above, every top-level name they bring with them — may be
/// renamed, resplit or deleted in any release, including a patch one.
///
/// The re-exports exist because the differential tests build engines and
/// compare exceptions through this library alone, and each carries its reason
/// where it stands. They are convenience for those tests, not a second
/// edition of the public API: every symbol among them is also exported by
/// `format.dart`, which is where an application should take it from.
///
/// What is genuinely internal stays private. A function whose signature names
/// a private type would otherwise have to advertise that type here, so the
/// functions are private too — `lib/src/` being private by convention is not
/// a reason to stop at convention.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:characters/characters.dart';

import 'binary64.dart';
import 'double_format.dart';
import 'errors.dart';
import 'extensions.dart';
import 'number_locale.dart';
import 'text_unit.dart';

// DoubleFormatMode and DoubleSpecialValueSpelling are part of the same seam
// surface as TextUnit below: the differential tests build engines in both
// double modes and in both non-finite spellings through this library alone
// (both are also separately exported by the public `format.dart` library).
export 'double_format.dart' show DoubleFormatMode, DoubleSpecialValueSpelling;

// FormattingException and FormatExceptionContext are needed by the
// template-IR differential tests accessed via `package:format/src/engine.dart`:
// the parity helpers compare exception context fields (offset, fragment,
// specifier, conversion, argumentIndex) between the IR and legacy paths, not
// just runtimeType. The concrete subclasses come with them because the
// harness also compares per-type payloads (reason, key, value, ...) through a
// switch that must stay exhaustive over the sealed hierarchy — every leaf has
// to be nameable there (all of them are also separately exported by the
// public `format.dart` library).
export 'errors.dart'
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

// AttributeLookup and Representation are part of the same seam surface: two
// payloads the parity helpers switch over — FormatExtensionException and
// AmbiguousFormatterException — cannot be produced by any engine without
// extensions registered, so the differential tests build one that has them
// (both are also separately exported by the public `format.dart` library).
export 'extensions.dart' show AttributeLookup, Representation;

// NumberLocale is part of the same seam surface: the template-IR
// differential tests build an engine on a deliberately non-default locale to
// prove the hot double ops hand such engines back to the legacy tail. The
// C locale comes with it, because those tests also build an engine on a
// non-const instance of it, which the constructor canonicalizes — the case
// that decides whether `n` and the printf doubles take their hot path (both
// are also separately exported by the public `format.dart` library).
export 'number_locale.dart' show CNumberLocale, NumberLocale;

// TextUnit is part of the internal template-IR test seam surface: seam
// tests reach it via `package:format/src/engine.dart` alone, so it must be
// re-exported here (it is also separately exported by the public
// `format.dart` library).
export 'text_unit.dart' show TextUnit;

part 'api.dart';
part 'format.dart';
part 'printf_ast.dart';
part 'printf_parser.dart';
part 'printf_formatter.dart';
part 'printf_processor.dart';
part 'brace_processor.dart';
part 'dart_double_format.dart';
part 'representation.dart';
part 'brace_ast.dart';
part 'field_resolver.dart';
part 'python_identifier.dart';
part 'brace_parser.dart';
part 'format_spec.dart';
part 'template_cache.dart';
part 'char_sink.dart';
part 'template_ir.dart';
part 'number_format.dart';
part 'value_formatter.dart';
