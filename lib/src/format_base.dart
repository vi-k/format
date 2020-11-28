import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:sprintf/sprintf.dart';

import 'string_ext.dart';

/// Отличия от Python:
///
/// Поддеживается автоматическия и ручная нумерация одновременно - когда
/// встречается ручная нумерация, индекс автоматической нумерации сбрасывается
/// на идекс ручной нумерации.
///
/// В альтернативном формате для X выводится 0x, а не 0X.
///
/// Не поддерживается альтернативный формат для b (0b..) и o (0o..), т.к. Дарт
/// не поддерживает такие литералы.
///
/// Пока не поддерживается в именованных аргументах .key и [index].
///

final RegExp _formatSpecRe = RegExp(
    // {   [argId                       ]   :[  [fill ] align   ] [sign ] [#] [0] [width                                   ] [grpo] [   .precision                                 ] [type             ] [template        ]     }
    r'\{\s*(\d*|[_\w][_\w\d]*|\[[^\]]*\])(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\})?([_,])?(?:\.(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\}))?([sbcdoxXn])?(\[(?:[^\]])*\])?)?\s*\}');
// '\\{\\s*(\\d*|[_\\w][_\\w\\d]*|\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?(?:\\.(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?)?([sSnmfaxXcdtDTqp])?(\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")?)?\\s*\\}');
final RegExp _firstGroup3Re = RegExp(r'(.)((?:...)+)$');
final RegExp _firstGroup4Re = RegExp(r'(.)((?:....)+)$');
final RegExp _secondGroup3Re = RegExp('(...)');
final RegExp _secondGroup4Re = RegExp('(....)');

/// Берёт значение в строке [str] внутри кавычек [left] и [right].
///
/// Строкой [left] задаётся список доступных открывающих кавычек. Строкой
/// [right] - список соответствующих закрывающих кавычек. Заменяет двойные
/// вхождения кавычек внутри строки на одинарные.
///
/// Если нет кавычек возвращает null.
String? _getValueInQuotes(String str, String left, String right) {
  if (str.isNotEmpty) {
    final firstChar = str.substring(0, 1);
    final index = left.indexOf(firstChar);
    if (index >= 0) {
      final l = firstChar;
      final r = right[index];
      return str
          .substring(1, str.length - 1)
          .replaceAll('$l$l', l)
          .replaceAll('$r$r', r);
    }
  }

  return null;
}

/// Удаляет в строке [str] кавычки [left] и [right], если они есть.
///
/// Строкой [left] задаётся список доступных открывающих кавычек. Строкой
/// [right] - список соответствующих закрывающих кавычек. Заменяет двойные
/// вхождения кавычек внутри строки на одинарные.
///
/// Если нет кавычек возвращает исходную строку [str] без имзменений.
String _removeQuotesIfNeed(String str, String left, String right) =>
    _getValueInQuotes(str, left, right) ?? str;

extension Let<T extends Object> on T {
  R let<R>(R Function(T it) op) => op(this);
}

String format(String format, List<dynamic> positionalArgs,
    [Map<String, dynamic>? namedArgs]) {
  var argsIndex = 0;
  String? currentSpec;

  dynamic getValueByIndex(int index) {
    if (index >= positionalArgs.length) {
      throw ArgumentError(
          '$currentSpec Index #$index out of range of positional args.');
    }

    return positionalArgs[index];
  }

  // Поиск значения. Варианты:
  // {} - перебираем параметры в positionalArgs по порядку;
  // {index} - индекс параметра в positionalArgs;
  // {id} или {[id]} - название параметра в namedArgs;
  dynamic getValue(String? rawId) {
    dynamic value;

    if (rawId == null || rawId.isEmpty) {
      // Порядковый параметр.
      value = getValueByIndex(argsIndex++);
    } else {
      final index = int.tryParse(rawId);
      if (index != null) {
        // Нумерованный параметр.
        //
        // В этом месте различия с C++20, который не поддерживает смешение
        // нумерованных и порядковых параметров. В нашем варианте смешение
        // возможно - как только встречается нумерованный параметр, порядковый
        // параметр перемещается на следующий после него.
        value = getValueByIndex(index);
        argsIndex = index + 1;
      } else {
        // Именованный параметр.
        final id = _removeQuotesIfNeed(rawId, '[', ']');

        if (namedArgs == null) {
          throw ArgumentError(
              '$currentSpec Key [$id] is missing: [namedArgs] is null.');
        }

        if (!namedArgs.containsKey(id)) {
          throw ArgumentError('$currentSpec Key [$id] is missing.');
        }

        value = namedArgs[id];
      }
    }

    return value;
  }

  // Вычисление width и precision. Варианты:
  // n - значение задано напрямую;
  // {} - перебираем параметры в positionalArgs по порядку;
  // {index} - индекс параметра в positionalArgs;
  // {id} или {[id]} - название параметра в namedArgs;
  int? getWidth(String? str, String name) {
    int? value;

    if (str != null) {
      value = int.tryParse(str);
      if (value == null) {
        // Значение передано в виде параметра.
        final dynamic v = getValue(_getValueInQuotes(str, '{', '}'));
        if (v is! int) {
          throw ArgumentError(
              '$currentSpec $name must be int, passed ${v.runtimeType}.');
        }

        value = v;
      }
    }

    return value;
  }

  var removeEmptyStrings = false;

  // bBdnoxXaAceEfFgGps
  var result = format.replaceAllMapped(_formatSpecRe, (match) {
    const allGroup = 0;
    const argIdGroup = 1;
    const fillGroup = 2;
    const alignGroup = 3;
    const signGroup = 4;
    const altGroup = 5;
    const zeroGroup = 6;
    const widthGroup = 7;
    const groupOptionGroup = 8;
    const precisionGroup = 9;
    const typeGroup = 10;
    const templateGroup = 11;

    currentSpec = match.group(allGroup)!;

    //return '{spec: $currentSpec, argId: ${match.group(argIdGroup)}, fill: ${match.group(fillGroup)}, align: ${match.group(alignGroup)}, sign: ${match.group(signGroup)}, alt: ${match.group(altGroup)}, zero: ${match.group(zeroGroup)}, width: ${match.group(widthGroup)}, precision: ${match.group(precisionGroup)}, type: ${match.group(typeGroup)}, template: ${match.group(templateGroup)}}';

    var value = getValue(match.group(argIdGroup));
    var align = match.group(alignGroup);

    final width = getWidth(match.group(widthGroup), 'Width');
    final precision = getWidth(match.group(precisionGroup), 'Precision');

    String? result;

    var type = match.group(typeGroup);

    if (type == null) {
      if (value is String) {
        type = 's';
      } else if (value is int) {
        type = 'd';
      } else if (value is double) {
        type = 'g';
      }
    }

    if (type == null) {
      result = value.toString();
    } else {
      switch (type) {
        // Символ
        case 'c':
          if (value is int) {
            result = String.fromCharCode(value);
          } else if (value is List<int>) {
            result = String.fromCharCodes(value);
          } else {
            throw ArgumentError(
                '$currentSpec Expected int or List<int>, passed ${value.runtimeType}.');
          }
          break;

        // Строка
        case 's':
          if (value is! String) {
            throw ArgumentError(
                '$currentSpec Expected String. Received ${value.runtimeType}.');
          }

          result = value;
          if (precision != null) {
            result = match.group(altGroup) == null
                ? result.substring(0, precision)
                : result.cut(precision);
          }
          break;

        // Целое число
        case 'b':
        case 'd':
        case 'o':
        case 'x':
        case 'X':
        case 'n':
          if (value is! int) {
            throw ArgumentError(
                '$currentSpec Expected int. Received ${value.runtimeType}.');
          }

          if (precision != null) {
            throw ArgumentError('$currentSpec Precision not allowed for int.');
          }

          // Знак сохраняем отдельно, работаем с положительным числом
          var sign = match.group(signGroup);
          if (value < 0) {
            value = -value;
            sign = '-';
          } else if (sign == null || sign == '-') {
            sign = '';
          }

          // Преобразуем в строку
          switch (type) {
            case 'b':
              result = value.toRadixString(2);
              break;

            case 'o':
              result = value.toRadixString(8);
              break;

            case 'x':
              result = value.toRadixString(16);
              break;

            case 'X':
              result = value.toRadixString(16).toUpperCase();
              break;

            default:
              result = value.toString();
              break;
          }

          // Дополняем нулями (align и fill в этом случае игнорируются)
          final zero = match.group(zeroGroup);
          if (zero != null && width != null) {
            final w = result.length + sign.length;
            if (w < width) result = '0' * (width - w) + result;
          }

          // Разделяем на группы:
          // 0001234 -> 0,001,234
          // 0x123ABCDEF -> 0x1_23AB_CDEF
          var grpo = match.group(groupOptionGroup);
          if (grpo != null) {
            if (type == 'n' && grpo == ',') {
              grpo = NumberFormat().symbols.GROUP_SEP;
            }

            var re1 = _firstGroup3Re;
            var re2 = _secondGroup3Re;
            if (type != 'd' && type != 'n') {
              if (grpo == ',') {
                throw ArgumentError("$currentSpec Option ',' not allowed here.");
              }
              re1 = _firstGroup4Re;
              re2 = _secondGroup4Re;
            }

            result = result.replaceFirstMapped(
                re1,
                (m) =>
                    m[1]! + m[2]!.replaceAllMapped(re2, (m) => '$grpo${m[1]}'));

            // Если добавляли нули, надо обрезать лишние
            if (zero != null && width != null) {
              final extra = result.substring(0, result.length + sign.length - width);
              result = extra.replaceAll(RegExp('^[0$grpo]*'), '') + result.substring(result.length + sign.length - width);
              if (result[0] == grpo) result = '0$result';
            }
          }

          if (match.group(altGroup) != null) {
            if (type == 'x' || type == 'X') result = '0x$result';
          }

          // Восстанавливаем знак
          result = sign + result;

          align ??= '>'; // Числа по умолчанию прижимаются вправо
          break;

        // case "a": // Для совместимости с FormatStr(), равно "n"
        // case "n": // Точность по умолчанию равна 0, далее значение округляется
        // case "m": // Точность по умолчанию равна 0, оставшаяся часть отбрасывается (floor)
        // case "f": // Точность по умолчанию не определена - значение выводится полностью,
        //           // точность указывает на максимальное значение - конечные нули удаляются
        //   var num = +value;

        //   // Знак сохраняем отдельно, работаем с положительным числом
        //   if (num < 0) {
        //     num = -num;
        //     sign = "-";
        //   }
        //   else if (sign === undefined || sign === "-") sign = "";

        //   if (precision === undefined && type !== "f") precision = 0;
        //   if (type === "m") num = num.floor(precision);

        //   // Преобразуем в строку
        //   result = precision === undefined ? num.toString() : num.toFixed(precision).toString();
        //   if (type === "f") result = result.replace(/(\.[0-9]*?)0*$/, "$1").replace(/\.$/, "");

        //   // Дополняем нулями (align и fill в этом случае игнорируются)
        //   if (zero === "0" && width !== undefined) {
        //     var w = result.length + sign.length;
        //     if (w < width) result = "0".repeat(width - w) + result;
        //   }

        //   if (alt === "#") {
        //     // Разделяем на тройки (0001234.567 -> 0'001'234.567)
        //     result = result.replace(/(\d)((?:\d\d\d)+)(\.|$)/, function (_, pre, res, post) {
        //       res = res.replace(/(\d\d\d)/g, "'$1");
        //       return pre + res + post;
        //     });

        //     // Если добавляли нули, надо обрезать лишние
        //     if (zero === "0" && width !== undefined) {
        //       var extra = result.substr(0, result.length + sign.length - width);
        //       result = extra.replace(/^[0']*/, "") + result.substr(result.length + sign.length - width);
        //       if (result.charAt(0) === "'") result = result.substr(1);
        //     }
        //   }

        //   // Восстанавливаем знак
        //   result = sign + result;

        //   if (align === undefined) align = ">"; // Числа по-умолчанию прижимаются вправо

        //   break;

        //   //
        //   // Шестнадцатиричное число (abcd)
        //   //
        //   case "x":
        //   case "X":
        //     var num = Math.floor(+value);
        //     var pre = sign;

        //     // Знак сохраняем отдельно, работаем с положительным числом
        //     if (num < 0) {
        //       num = -num;
        //       pre = "-";
        //     }
        //     else if (pre === undefined || pre === "-") pre = "";

        //     if (alt === "#") pre += "0x";

        //     // Преобразуем в строку
        //     result = num.toString(16);
        //     if (type === "X") result = result.toUpperCase();

        //     // Дополняем нулями (align и fill в этом случае игнорируются)
        //     if (zero === "0" && width !== undefined) {
        //       var w = result.length + pre.length;
        //       if (w < width) result = "0".repeat(width - w) + result;
        //     }

        //     // Восстанавливаем знак
        //     result = pre + result;

        //     if (align === undefined) align = ">"; // Числа по-умолчанию прижимаются вправо

        //     break;

        //   //
        //   // Дата/время
        //   //
        //   case "d":
        //     result = template === undefined ? Datetime(value).ToDateStr() : Datetime(value).ToStr(template);
        //     break;

        //   case "t":
        //     result = template === undefined ? Datetime(value).ToTimeStr() : Datetime(value).ToStr(template);
        //     break;

        //   case "D":
        //     result = Datetime(value).ToStr("d month y");
        //     break;

        //   case "T":
        //     result = Datetime(value).ToStr();
        //     break;

        //   case "q":
        //     result = Datetime(value).ToSQL();
        //     break;

        //   //
        //   // Период (Январь 2020)
        //   //
        //   case "p":
        //     if (classOf === "Number") {
        //       var n = +value;
        //       var year = Math.floor(n / 12);
        //       var month = n % 12;
        //       if (month === 0) {
        //         month = 12;
        //         year--;
        //       }
        //       result = Datetime.GetMonthName(month, true) + " " + year;
        //     }
        //     else result = Datetime(value).ToStr("Monthname y");
        //     break;

        //   default:
        //     result = "-";//value;
      }
    }

    // // Размещение строк относительно текущего отступа
    // if (align === "|") {
    //   if (result === "") {
    //     result = "{remove}";
    //     removeEmptyStrings = true;
    //   }
    //   else {
    //     var lineStart = src.lastIndexOf("\n", pos - 1) + 1;
    //     var indent = pos - lineStart;

    //     if (width !== undefined) {
    //       var textStart = lineStart;
    //       while (textStart < pos && src.charAt(textStart) === " ") textStart++;
    //       indent = textStart - lineStart + width;
    //     }

    //     if (fill === undefined) fill = " ";
    //     result = result.addIndent(fill.repeat(indent), true);
    //   }
    // }
    // // Ограничение по ширине
    // else if (width !== undefined) {
    //   if (result.length > width) {
    //     // Если не вмещаемся, заполняем '*'
    //     result = "*".repeat(width);
    //   }
    // else
    if (result != null && width != null && result.length < width) {
      // Выравниваем относительно заданной ширины
      final fill = match.group(fillGroup) ?? ' ';
      final n = width - result.length;

      switch (align ?? '<') {
        case '<':
          result += fill * n;
          break;
        case '>':
          result = fill * n + result;
          break;
        case '^':
          {
            final half = n ~/ 2;
            result = fill * half + result + fill * (n - half);
            break;
          }
      }
    }

    if (result != null) return result;

    return '{spec: $currentSpec, argId: ${match.group(argIdGroup)}, fill: ${match.group(fillGroup)}, align: ${match.group(alignGroup)}, sign: ${match.group(signGroup)}, alt: ${match.group(altGroup)}, zero: ${match.group(zeroGroup)}, width: ${match.group(widthGroup)}, precision: ${match.group(precisionGroup)}, type: ${match.group(typeGroup)}, template: ${match.group(templateGroup)}, value: $value}';
  });

  // Удаляем пустые строки для параметра "|"
  // if (removeEmptyStrings) {
  //   result = result
  //     // В случае, когда вокруг пустые строки или удаляемая строка наверху, удаляем также пустые строки снизу
  //     .replace(/(^|(\r?\n *\r?\n)) *{remove}\r?\n( *\r?\n)*/g, "$1")
  //     // В случае, когда удаляемая строка внизу, удаляем также пустые строки сверху
  //     .replace(/( *\r?\n)* *{remove}(\r?\n)?$/g, "")
  //     // В любом другом случае удаляем либо всю строку, если она пустая, либо триммим строку справа
  //     .replace(/(\r?\n)? *{remove}/g, "");
  // }

  return result;
}
