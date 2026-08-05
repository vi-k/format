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
    TextUnit.unicodeScalars => value.runes.length,
    TextUnit.graphemeClusters => value.characters.length,
  };

  /// The first [count] units of [value].
  String take(String value, int count) {
    if (count <= 0) return '';
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
