/// Widest integers where an `int` is a real 64-bit integer: the Dart VM and
/// dart2wasm. See `widest_int.dart` for why this is a separate file.
library;

const widestInt = 9223372036854775807;
const widestIntText = '9223372036854775807';
const narrowestInt = -9223372036854775808;
const narrowestIntText = '-9223372036854775808';

/// Whether these are the web's integers rather than 64-bit ones.
const widestIntIsWeb = false;
