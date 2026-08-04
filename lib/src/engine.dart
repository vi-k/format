import 'dart:typed_data';
import 'binary64.dart';
import 'double_format.dart';
import 'errors.dart';
import 'extensions.dart';
import 'number_locale.dart';
import 'text_unit.dart';

// FormattingException and FormatExceptionContext are needed by the
// template-IR differential tests accessed via `package:format/src/engine.dart`:
// the parity helpers compare exception context fields (offset, fragment,
// specifier, conversion, argumentIndex) between the IR and legacy paths, not
// just runtimeType.
export 'errors.dart' show FormatExceptionContext, FormattingException;

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
