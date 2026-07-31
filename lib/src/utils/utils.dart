import 'package:characters/characters.dart';

/// Обрезает строку [src] до необходимой ширины [width], вставляет
/// при необходимости [ellipsis].
///
/// Пробелы после обрезки в конце полученной строки можно убрать, установив
/// флаг [trim].
String cut(String src, int width, {String ellipsis = '…', bool trim = true}) {
  if (src.characters.length <= width) return src;

  // В заданный размер должно поместиться троеточие
  final ellipsisLength = ellipsis.characters.length;
  if (width < ellipsisLength) return '';

  var result = src.characters.take(width - ellipsisLength).toString();
  if (trim) result = result.trimRight();

  return result + ellipsis;
}
