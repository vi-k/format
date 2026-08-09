import 'package:characters/characters.dart';

/// The unit in which widths, precisions, and fills measure text.
enum TextUnit {
  /// Unicode code points: a surrogate pair counts as one unit, a combining
  /// sequence or an emoji built from several code points counts as several.
  unicodeScalars,

  /// Grapheme clusters: emoji and combined characters count as one visible
  /// character each.
  graphemeClusters,
}

/// Text measurement in terms of a [TextUnit].
extension TextUnitOperations on TextUnit {
  /// The number of units in [value].
  int length(String value) => switch (this) {
    TextUnit.unicodeScalars => _scalarLength(value),
    TextUnit.graphemeClusters => value.characters.length,
  };

  /// The first [count] units of [value].
  String take(String value, int count) {
    if (count <= 0) return '';
    // Code units are an upper bound on both units of measure, so a string no
    // longer than the count cannot need truncating. This is the ordinary case
    // — a precision wider than the text — and measuring it was the whole cost
    // of finding that out.
    if (value.length <= count) return value;
    if (count >= length(value)) return value;

    return switch (this) {
      TextUnit.unicodeScalars => String.fromCharCodes(value.runes.take(count)),
      TextUnit.graphemeClusters => value.characters.take(count).toString(),
    };
  }

  /// [value] split into single units.
  List<String> split(String value) => switch (this) {
    TextUnit.unicodeScalars => List.unmodifiable(
      value.runes.map(String.fromCharCode),
    ),
    TextUnit.graphemeClusters => List.unmodifiable(value.characters),
  };
}

/// The number of Unicode scalars in [value], without materializing runes.
///
/// Equivalent to `value.runes.length` and deliberately so, including for
/// malformed UTF-16: an unpaired surrogate is one scalar to `runes` and one
/// here, because only a complete pair is counted as joined. Scanning code
/// units instead of running an iterator matters because this is on the width
/// and precision paths — measuring a 1024-character string cost 2.5 us
/// through `runes`.
int _scalarLength(String value) {
  final length = value.length;
  var pairs = 0;
  for (var index = 0; index < length - 1; index++) {
    final unit = value.codeUnitAt(index);
    if (unit < 0xd800 || unit > 0xdbff) continue;
    final next = value.codeUnitAt(index + 1);
    if (next >= 0xdc00 && next <= 0xdfff) {
      pairs++;
      index++;
    }
  }

  return length - pairs;
}
