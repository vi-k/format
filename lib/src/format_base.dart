import 'package:intl/intl.dart';

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
/// nan и inf не дополняются нулями при флаге zero.
///

final RegExp _formatSpecRe = RegExp(
    // {   [argId                             ]   :[  [fill ] align   ] [sign ] [#] [0] [width                                   ] [grpo] [   .precision                                 ] [specifier  ] [template        ]     }
    r'\{\s*(\d*|[_\p{L}][_\p{L}\d]*|\[[^\]]*\])(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\})?([_,])?(?:\.(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\}))?([sbcdoxXnf])?(\[(?:[^\]])*\])?)?\s*\}',
    unicode: true);
// '\\{\\s*(\\d*|[_\\w][_\\w\\d]*|\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?(?:\\.(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?)?([sSnmfaxXcdtDTqp])?(\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")?)?\\s*\\}');
final RegExp _firstGroup3Re = RegExp(r'(\d)((?:\d{3})+)(\.|$)');
final RegExp _firstGroup4Re = RegExp(r'([^.])((?:[^.]{4})+)(\.|$)');
final RegExp _secondGroup3Re = RegExp(r'(\d{3})');
final RegExp _secondGroup4Re = RegExp('([^.]{4})');

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

  T also(void Function(T it) op) {
    op(this);
    return this;
  }
}

class _Options {
  _Options(this.positionalArgs, this.namedArgs);

  final List<dynamic> positionalArgs;
  final Map<String, dynamic>? namedArgs;
  final intlNumberFormat = NumberFormat();
  int positionalArgsIndex = 0;
  String all = '';
  String? argId;
  dynamic? value;
  String? fill;
  String? align;
  String? sign;
  bool alt = false;
  bool zero = false;
  int? width;
  String? groupOption;
  int? precision;
  String? specifier;
  String? template;

  @override
  String toString() => '''
_Options{
  positionalArgs: ${positionalArgs.length},
  namedArgs: ${namedArgs?.length ?? 'null'},
  positionalArgsIndex: $positionalArgsIndex,
  spec: $all,
  argId: $argId,
  fill: $fill,
  align: $align,
  sign: $sign,
  alt: $alt,
  zero: $zero,
  width: $width,
  precision: $precision,
  type: $specifier,
  template: $template
}''';
}

/// Поиск значения в [positionalArgs] по индексу [index].
dynamic _getValueByIndex(_Options options, int index) {
  if (index >= options.positionalArgs.length) {
    throw ArgumentError(
        '${options.all} Index #$index out of range of positional args.');
  }

  options.positionalArgsIndex = index + 1;
  return options.positionalArgs[index];
}

/// Поиск значения.
///
/// Варианты:
/// {} - перебираем параметры в positionalArgs по порядку;
/// {index} - индекс параметра в positionalArgs;
/// {id} или {[id]} - название параметра в namedArgs;
dynamic _getValue(_Options options, String? rawId) {
  dynamic value;

  if (rawId == null || rawId.isEmpty) {
    // Автоматическая нумерация.
    value = _getValueByIndex(options, options.positionalArgsIndex);
  } else {
    final index = int.tryParse(rawId);
    if (index != null) {
      // Параметр по заданному индексу.
      // В этом месте различия с C++20, который не поддерживает смешение
      // нумерованных и порядковых параметров. В нашем варианте смешение
      // возможно - как только встречается нумерованный параметр, индекс
      // перемещается на следующий параметр после него.
      value = _getValueByIndex(options, index);
    } else {
      // Именованный параметр.
      final id = _removeQuotesIfNeed(rawId, '[', ']');

      final namedArgs = options.namedArgs;
      if (namedArgs == null) {
        throw ArgumentError('${options.all} Named args is missing.');
      }

      if (!namedArgs.containsKey(id)) {
        throw ArgumentError(
            '${options.all} Key [$id] is missing in named args.');
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
int? _getWidth(_Options options, String? str, String name) {
  int? value;

  if (str != null) {
    value = int.tryParse(str);
    if (value == null) {
      // Значение передано в виде параметра.
      final dynamic v = _getValue(options, _getValueInQuotes(str, '{', '}'));
      if (v is! int) {
        throw ArgumentError(
            '${options.all} $name must be int, passed ${v.runtimeType}.');
      }

      value = v;
    }
  }

  return value;
}

String _numFormat<T extends num>(
  _Options options,
  dynamic dyn, {
  required String Function(T value, int? precision) toStr,
  int groupLength = 3,
  String? prefix,
}) {
  String result;

  if (dyn is! T) {
    throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.');
  }

  num value = dyn;

  final precision = options.precision;
  if (value is int && precision != null) {
    throw ArgumentError('${options.all} Precision not allowed for int.');
  }

  // Знак сохраняем отдельно, работаем с положительным числом
  var sign = options.sign;
  if (value.isNegative) {
    value = -value;
    sign = '-';
  } else if (sign == null || sign == '-') {
    sign = '';
  }

  // Преобразуем в строку
  if (value.isNaN) {
    result = 'nan';
    options.zero = false;
  } else if (value.isInfinite) {
    result = 'inf';
    options.zero = false;
  } else {
    result = toStr(value as T, precision);
  }

  // Дополняем нулями (align и fill в этом случае игнорируются)
  final width = options.width;
  if (options.zero && width != null) {
    final w = result.length + sign.length;
    if (w < width) result = '0' * (width - w) + result;
  }

  // Разделяем на группы:
  // 0001234 -> 0,001,234
  // 0x123ABCDEF -> 0x1_23AB_CDEF
  final grpo = options.groupOption;
  if (grpo != null) {
    if (grpo == ',' && groupLength == 4) {
      throw ArgumentError(
          "${options.all} Option ',' not allowed with format specifier '${options.specifier}'.");
    }

    final firstRe = groupLength == 3 ? _firstGroup3Re : _firstGroup4Re;
    final secondRe = groupLength == 3 ? _secondGroup3Re : _secondGroup4Re;

    result = result.replaceFirstMapped(
        firstRe,
        (m) =>
            m[1]! +
            m[2]!.replaceAllMapped(secondRe, (m) => '$grpo${m[1]}') +
            m[3]!);

    // Если добавляли нули, надо обрезать лишние
    if (options.zero && width != null) {
      final extra = result.substring(0, result.length + sign.length - width);
      result = extra.replaceAll(RegExp('^[0$grpo]*'), '') +
          result.substring(result.length + sign.length - width);
      if (result[0] == grpo) result = '0$result';
    }
  }

  if (options.alt) {
    if (prefix == null) {
      throw ArgumentError(
          "${options.all} Alternate form (#) not allowed with format specifier '${options.specifier}'.");
    }
    result = '$prefix$result';
  }

  // Восстанавливаем знак
  result = sign + result;

  // Числа по умолчанию прижимаются вправо
  options.align ??= '>';

  return result;
}

String _format(String template, List<dynamic> positionalArgs,
    [Map<String, dynamic>? namedArgs]) {
  final options = _Options(positionalArgs, namedArgs);

  // var removeEmptyStrings = false;

  var result = template.replaceAllMapped(_formatSpecRe, (match) {
    options
      ..all = match.group(0)!
      ..argId = match.group(1)
      ..value = _getValue(options, options.argId)
      ..fill = match.group(2)
      ..align = match.group(3)
      ..sign = match.group(4)
      ..alt = match.group(5) != null
      ..zero = match.group(6) != null
      ..width = _getWidth(options, match.group(7), 'Width')
      ..groupOption = match.group(8)
      ..precision = _getWidth(options, match.group(9), 'Precision')
      ..specifier = match.group(10)
      ..template = match.group(11);

    // var value = getValue(match.group(argIdGroup));
    // var align = match.group(alignGroup);

    // final width = getWidth(match.group(widthGroup), 'Width');
    // final precision = getWidth(match.group(precisionGroup), 'Precision');

    String? result;

    var value = options.value;

    // Типы форматирования по умолчанию.
    if (options.specifier == null) {
      if (value is String) {
        options.specifier = 's';
      } else if (value is int) {
        options.specifier = 'd';
      } else if (value is double) {
        options.specifier = 'g';
      }
    }

    String Function(String result)? post;

    if (options.specifier == 'n') {
      if (value is int) {
        options.specifier = 'd';
      } else if (value is double) {
        options.specifier = 'g';
      } else {
        throw ArgumentError(
            '${options.all} Expected int or double. Passed ${value.runtimeType}.');
      }

      post = (result) => result.replaceAllMapped(RegExp('[.,e+-]'), (match) {
            switch (match.group(0)) {
              case '.':
                return options.intlNumberFormat.symbols.DECIMAL_SEP;
              case ',':
                return options.intlNumberFormat.symbols.GROUP_SEP;
              case 'e':
                return options.intlNumberFormat.symbols.EXP_SYMBOL;
              case '+':
                return options.intlNumberFormat.symbols.PLUS_SIGN;
              case '-':
                return options.intlNumberFormat.symbols.MINUS_SIGN;
            }
            return '';
          });

      // if (options.groupOption == ',') {
      //   options.groupOption = options.intlNumberFormat.symbols.GROUP_SEP;
      // }
    }

    final spec = options.specifier;
    if (spec == null) {
      result = options.value.toString();
    } else {
      switch (spec) {
        // Символ
        case 'c':
          if (value is int) {
            result = String.fromCharCode(value);
          } else if (value is List<int>) {
            result = String.fromCharCodes(value);
          } else {
            throw ArgumentError(
                '${options.all} Expected int or List<int>. Passed ${value.runtimeType}.');
          }
          break;

        // Строка
        case 's':
          if (value is! String) {
            throw ArgumentError(
                '${options.all} Expected String. Passed ${value.runtimeType}.');
          }

          result = options.precision == null
              ? value
              : options.alt
                  ? value.cut(options.precision!)
                  : value.substring(0, options.precision!);
          break;

        // ? число
        // case 'b':
        // case 'o':
        // case 'x':
        // case 'X':
        //   if (value is! int) {
        //     throw ArgumentError(
        //         '${options.spec} Expected int. Passed ${value.runtimeType}.');
        //   }

        //   if (options.precision != null) {
        //     throw ArgumentError(
        //         '${options.spec} Precision not allowed for int.');
        //   }

        //   // Знак сохраняем отдельно, работаем с положительным числом
        //   if (value < 0) {
        //     value = -value;
        //     options.sign = '-';
        //   } else if (options.sign == null || options.sign == '-') {
        //     options.sign = '';
        //   }

        //   // Преобразуем в строку
        //   switch (type) {
        //     case 'b':
        //       result = value.toRadixString(2);
        //       break;

        //     case 'o':
        //       result = value.toRadixString(8);
        //       break;

        //     case 'x':
        //       result = value.toRadixString(16);
        //       break;

        //     case 'X':
        //       result = value.toRadixString(16).toUpperCase();
        //       break;

        //     default:
        //       result = value.toString();
        //       break;
        //   }

        //   // Дополняем нулями (align и fill в этом случае игнорируются)
        //   if (options.zero && options.width != null) {
        //     final w = result.length + options.sign!.length;
        //     if (w < options.width!)
        //       result = '0' * (options.width! - w) + result;
        //   }

        //   // Разделяем на группы:
        //   // 0001234 -> 0,001,234
        //   // 0x123ABCDEF -> 0x1_23AB_CDEF
        //   final grpo = options.groupOption;
        //   if (grpo != null) {
        //     // if (type == 'n' && options.groupOption == ',') {
        //     //   options.groupOption = intlNumberFormat.symbols.GROUP_SEP;
        //     // }

        //     var re1 = _firstGroup3Re;
        //     var re2 = _secondGroup3Re;
        //     if (type != 'd' && type != 'n') {
        //       if (grpo == ',') {
        //         throw ArgumentError(
        //             "${options.spec} Option ',' not allowed here.");
        //       }
        //       re1 = _firstGroup4Re;
        //       re2 = _secondGroup4Re;
        //     }

        //     result = result.replaceFirstMapped(
        //         re1,
        //         (m) =>
        //             m[1]! + m[2]!.replaceAllMapped(re2, (m) => '$grpo${m[1]}'));

        //     // Если добавляли нули, надо обрезать лишние
        //     if (options.zero && options.width != null) {
        //       final extra = result.substring(
        //           0, result.length + options.sign!.length - options.width!);
        //       result = extra.replaceAll(RegExp('^[0$grpo]*'), '') +
        //           result.substring(
        //               result.length + options.sign!.length - options.width!);
        //       if (result[0] == grpo) result = '0$result';
        //     }
        //   }

        //   if (options.alt) {
        //     if (type == 'x' || type == 'X') result = '0x$result';
        //   }

        //   // Восстанавливаем знак
        //   result = options.sign! + result;

        //   options.align ??= '>'; // Числа по умолчанию прижимаются вправо
        //   break;

        // Число
        case 'b':
          result = _numFormat<int>(options, value,
              toStr: (value, precision) => value.toRadixString(2),
              groupLength: 4);
          break;

        case 'o':
          result = _numFormat<int>(options, value,
              toStr: (value, precision) => value.toRadixString(8),
              groupLength: 4);
          break;

        case 'x':
          result = _numFormat<int>(options, value,
              toStr: (value, precision) => value.toRadixString(16),
              groupLength: 4,
              prefix: '0x');
          break;

        case 'X':
          result = _numFormat<int>(options, value,
              toStr: (value, precision) =>
                  value.toRadixString(16).toUpperCase(),
              groupLength: 4,
              prefix: '0x');
          break;

        case 'd':
          result = _numFormat<int>(options, value,
              toStr: (value, _) => value.toString());
          if (post != null) {
            result = post(result);
          }
          break;

        case 'f':
        case 'g':
          result = _numFormat<double>(options, value,
              toStr: (value, precision) =>
                  value.toStringAsFixed(precision ?? 6));
          if (post != null) {
            result = post(result);
          }
          break;

        //   // Знак сохраняем отдельно, работаем с положительным числом
        //   if (value < 0) {
        //     value = -value;
        //     options.sign = '-';
        //   } else if (options.sign == null || options.sign == '-') {
        //     options.sign = '';
        //   }

        //   // Преобразуем в строку
        //   result = value.toStringAsFixed(precision ?? 6);

        //   // Дополняем нулями (align и fill в этом случае игнорируются)
        //   final zero = match.group(zeroGroup);
        //   if (zero != null && width != null) {
        //     final w = result.length + sign.length;
        //     if (w < width) result = '0' * (width - w) + result;
        //   }

        //   // Разделяем на группы:
        //   // 0001234 -> 0,001,234
        //   // 0x123ABCDEF -> 0x1_23AB_CDEF
        //   var grpo = match.group(groupOptionGroup);
        //   if (grpo != null) {
        //     if (type == 'n' && grpo == ',') {
        //       grpo = intlNumberFormat.symbols.GROUP_SEP;
        //     }

        //     var re1 = _firstGroup3Re;
        //     var re2 = _secondGroup3Re;
        //     // if (type != 'd' && type != 'n') {
        //     //   if (grpo == ',') {
        //     //     throw ArgumentError(
        //     //         "$currentSpec Option ',' not allowed here.");
        //     //   }
        //     //   re1 = _firstGroup4Re;
        //     //   re2 = _secondGroup4Re;
        //     // }

        //     result = result.replaceFirstMapped(
        //         re1, (m) => m[1]! + m[2]!.replaceAllMapped(re2, (m) => '$grpo${m[1]}') + m[3]!);

        //     // Если добавляли нули, надо обрезать лишние
        //     if (zero != null && width != null) {
        //       final extra = result.substring(0, result.length + sign.length - width);
        //       result =
        //           extra.replaceAll(RegExp('^[0$grpo]*'), '') + result.substring(result.length + sign.length - width);
        //       if (result[0] == grpo) result = '0$result';
        //     }
        //   }

        //   if (match.group(altGroup) != null) {
        //     if (type == 'x' || type == 'X') result = '0x$result';
        //   }

        //   // Восстанавливаем знак
        //   result = sign + result;

        //   align ??= '>'; // Числа по умолчанию прижимаются вправо
        //   break;

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

    final width = options.width;
    if (result != null && width != null && result.length < width) {
      // Выравниваем относительно заданной ширины
      final fill = options.fill ?? ' ';
      final n = width - result.length;

      switch (options.align ?? '<') {
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

    return options.toString();
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

extension StringFormat on String {
  String format(List<dynamic> positionalArgs,
          [Map<String, dynamic>? namedArgs]) =>
      _format(this, positionalArgs, namedArgs);
}

const format = _format;
