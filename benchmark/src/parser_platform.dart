/// Picks the platform adapter for the target being compiled.
///
/// The order matters and the conditions are not interchangeable.
/// `dart.library.js` is true under dart2js and false under dart2wasm, while
/// `dart.library.js_interop` is true under both — so asking about `js_interop`
/// first would hand dart2wasm the dart2js adapter, and every wasm report would
/// arrive labelled `js`. A gate cannot notice that: the numbers would be
/// plausible and the runtime would be a lie.
library;

export 'parser_platform_stub.dart'
    if (dart.library.io) 'parser_platform_io.dart'
    if (dart.library.js) 'parser_platform_js.dart'
    if (dart.library.js_interop) 'parser_platform_wasm.dart';
