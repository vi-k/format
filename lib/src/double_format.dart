/// Selects how decimal [double] values are converted to text.
enum DoubleFormatMode {
  /// Uses the conversion methods provided by the Dart SDK.
  dartSdk,

  /// Preserves the Python-compatible brace and C++-compatible printf rules.
  compatible,
}

/// Selects the base spelling of non-finite [double] values.
enum DoubleSpecialValueSpelling {
  /// Uses `NaN` and `Infinity`.
  dartSdk,

  /// Uses `nan` and `inf` (or uppercase variants when requested).
  short,
}
