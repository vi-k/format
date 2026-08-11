/// The widest integer the compilation target actually has, and its digits.
///
/// The scenarios that use these mean "the widest integer this platform can
/// hold", not one particular number — but the number has to be written as a
/// literal, and `9223372036854775807` is not a literal dart2js will compile at
/// all. So the two spellings live in separate files and the target picks one.
///
/// The condition is `dart.library.js`, not `dart.library.js_interop`: dart2js
/// and dart2wasm both have the latter, and only the former distinguishes them.
/// dart2wasm has real 64-bit integers and belongs on the native side; sending
/// it to the web side would silently narrow what it measures. If a future SDK
/// drops `dart:js` from dart2js, this falls back to the native file and
/// dart2js stops compiling on the literal — loud, which is the failure to
/// prefer. [checkWidestInt] covers the quieter direction.
library;

export 'widest_int_native.dart' if (dart.library.js) 'widest_int_web.dart';
