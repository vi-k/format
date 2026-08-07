import 'dart:math' as math;
import 'dart:typed_data';

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

// NumberLocale is part of the same seam surface: the template-IR
// differential tests build an engine on a deliberately non-default locale to
// prove the hot double ops hand such engines back to the legacy tail (it is
// also separately exported by the public `format.dart` library).
export 'number_locale.dart' show NumberLocale;

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
