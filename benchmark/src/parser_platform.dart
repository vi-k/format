export 'parser_platform_stub.dart'
    if (dart.library.io) 'parser_platform_io.dart'
    if (dart.library.js_interop) 'parser_platform_js.dart';
