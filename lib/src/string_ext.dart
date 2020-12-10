import 'package:characters/characters.dart';

extension StringExt on String {
  /// Обрезает строку и добавляет к ней троеточие [ellipsis], если она больше
  /// заданного размера [width].
  ///
  /// Пробелы в конце строки, появившиеся в результате операции, автоматически
  /// удаляются. Но можно их оставить, установив [trim] = true.
  String cut(int width, {String ellipsis = '…', bool trim = true}) {
    if (characters.length <= width) return this;

    // В заданный размер должно поместиться троеточие
    final ellipsisLength = ellipsis.characters.length;
    if (width < ellipsisLength) return '';

    var result = characters.take(width - ellipsisLength).toString();
    if (trim) result = result.trimRight();

    return result + ellipsis;
  }

  // /// Центрирует текст, добавляя слева и справа [padding]
  // String pad(int width, [String padding = ' ']) => padLeft((width + length) ~/ 2, padding).padRight(width, padding);

  // /// Обрезает строку и добавляет [padding] слева (смещает строку вправо)
  // String cutAndPadLeft(int width, {String ellipsis = '…', bool trim = true, String padding = ' '}) =>
  //     cut(width, ellipsis: ellipsis, trim: trim).padLeft(width, padding);

  // /// Обрезает строку и добавляет [padding] справа (смещает строку влево)
  // String cutAndPadRight(int width, {String ellipsis = '…', bool trim = true, String padding = ' '}) =>
  //     cut(width, ellipsis: ellipsis, trim: trim).padRight(width, padding);

  // /// Обрезает строку и центрирует строку
  // String cutAndPad(int width, {String ellipsis = '…', bool trim = true, String padding = ' '}) =>
  //     cut(width, ellipsis: ellipsis, trim: trim).pad(width, padding);
}
