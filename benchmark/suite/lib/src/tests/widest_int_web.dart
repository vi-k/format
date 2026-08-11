/// Widest integers where an `int` is a JavaScript double: dart2js.
///
/// 2^53-1 rather than 2^63-1, because past it a JS number stops naming
/// integers exactly — the literal does not even compile. See
/// `widest_int.dart`.
library;

const widestInt = 9007199254740991;
const widestIntText = '9007199254740991';
const narrowestInt = -9007199254740991;
const narrowestIntText = '-9007199254740991';

/// Whether these are the web's integers rather than 64-bit ones.
const widestIntIsWeb = true;
