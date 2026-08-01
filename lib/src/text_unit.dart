import 'package:characters/characters.dart';

enum TextUnit { unicodeScalars, graphemeClusters }

extension TextUnitOperations on TextUnit {
  int length(String value) => switch (this) {
    TextUnit.unicodeScalars => value.runes.length,
    TextUnit.graphemeClusters => value.characters.length,
  };

  String take(String value, int count) {
    if (count <= 0) return '';
    if (count >= length(value)) return value;

    return switch (this) {
      TextUnit.unicodeScalars => String.fromCharCodes(value.runes.take(count)),
      TextUnit.graphemeClusters => value.characters.take(count).toString(),
    };
  }

  List<String> split(String value) => switch (this) {
    TextUnit.unicodeScalars => List.unmodifiable(
      value.runes.map(String.fromCharCode),
    ),
    TextUnit.graphemeClusters => List.unmodifiable(value.characters),
  };
}
