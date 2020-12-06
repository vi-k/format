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
    // {   [argId                             ]   :[  [fill ] align   ] [sign ] [#] [0] [width                                   ] [grpo] [   .precision                                 ] [specifier       ] [template        ]     }
    r'\{\s*(\d*|[_\p{L}][_\p{L}\d]*|\[[^\]]*\])(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\})?([_,])?(?:\.(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\}))?([sbcdoxXnfFeEgG])?(\[(?:[^\]])*\])?)?\s*\}',
    unicode: true);
// '\\{\\s*(\\d*|[_\\w][_\\w\\d]*|\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?(?:\\.(\\d+|\\{(\\d*|[_\\w][_\\w\\d]*)\\})?)?([sSnmfaxXcdtDTqp])?(\'(?:\'\'|[^\'])*\'|"(?:""|[^"])*")?)?\\s*\\}');
final RegExp _triplesRe = RegExp(r'(\d)((?:\d{3})+)$');
final RegExp _quadruplesRe = RegExp(r'([0-9a-fA-F])((?:[0-9a-fA-F]{4})+)$');
final RegExp _tripleRe = RegExp(r'\d{3}');
final RegExp _quadrupleRe = RegExp('[0-9a-fA-F]{4}');
final RegExp _trailingZerosRe = RegExp(r'\.?0+(?=(e[-+]\d+)?$)');
final RegExp _placeForPointRe = RegExp(r'(?=(e[-+]\d+)?$)');

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
int? _getWidth(_Options options, String? str, String name, {int min = 0}) {
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

    if (value < min) {
      throw ArgumentError(
          '${options.all} $name must be >= $min. Passed $value.');
    }
  }

  return value;
}

String _numberFormat<T extends num>(
  _Options options,
  dynamic dyn, {
  bool altAllowed = true,
  bool standartGroupOptionAllowed = true,
  required String Function(T value, int? precision) toStr,
  bool removeTrailingZeros = false,
  bool needPoint = false,
  int groupLength = 3,
  String prefix = '',
}) {
  // Проверки.
  if (dyn is! T) {
    throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.');
  }
  if (options.alt && !altAllowed) {
    throw ArgumentError(
        "${options.all} Alternate form (#) not allowed with format specifier '${options.specifier}'.");
  }
  if (options.groupOption == ',' && !standartGroupOptionAllowed) {
    throw ArgumentError(
        "${options.all} Group option ',' not allowed with format specifier '${options.specifier}'.");
  }

  String result;
  num value = dyn;

  final precision = options.precision;

  // Знак сохраняем отдельно, работаем с положительным числом.
  var sign = options.sign;
  if (value.isNegative) {
    value = -value;
    sign = '-';
  } else if (sign == null || sign == '-') {
    sign = '';
  }

  // Преобразуем в строку.
  if (value.isNaN) {
    result = 'nan';
    options.zero = false;
  } else if (value.isInfinite) {
    result = 'inf';
    options.zero = false;
  } else {
    result = toStr(value as T, precision);
  }

  // Удаляем лишние нули.
  if (removeTrailingZeros && result.contains('.')) {
    result = result.replaceFirst(_trailingZerosRe, '');
  }

  // Ставим обязательную точку.
  if (needPoint && !result.contains('.')) {
    result = result.replaceFirst(_placeForPointRe, '.');
  }

  // Дополняем нулями (align и fill в этом случае игнорируются).
  final minWidth = (options.width ?? 0) - sign.length - prefix.length;
  if (options.zero && result.length < minWidth) {
    result = '0' * (minWidth - result.length) + result;
  }

  // Разделяем на группы.
  final grpo = options.groupOption;
  if (grpo != null) {
    final searchRe = groupLength == 3 ? _triplesRe : _quadruplesRe;
    final changeRe = groupLength == 3 ? _tripleRe : _quadrupleRe;
    var pointIndex = result.indexOf('.');
    if (pointIndex == -1) pointIndex = result.indexOf(RegExp('e[+-]'));
    if (pointIndex == -1) pointIndex = result.length;

    result = result.substring(0, pointIndex).replaceFirstMapped(
            searchRe,
            (m) =>
                m[1]! +
                m[2]!.replaceAllMapped(changeRe, (m) => '$grpo${m[0]}')) +
        result.substring(pointIndex);

    // Если добавляли нули, надо обрезать лишние.
    if (options.zero) {
      final extraWidth = result.length - minWidth;
      final extra = result.substring(0, extraWidth);
      result = extra.replaceFirst(RegExp('^[0$grpo]*'), '') +
          result.substring(extraWidth);
      if (result[0] == grpo) result = '0$result';
    }
  }

  // Восстанавливаем знак, добавляем префикс.
  result = '$sign$prefix$result';

  // Числа по умолчанию прижимаются вправо
  options.align ??= '>';

  return result;
}

String _intlNumberFormat<T extends num>(
  _Options options,
  dynamic dyn, {
  bool needPoint = false,
}) {
  // Проверки.
  if (dyn is! T) {
    throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.');
  }

  String result;
  num value = dyn;

  final fmt = NumberFormat.decimalPattern();
  final zeroDigitForRe = fmt.symbols.ZERO_DIGIT
      .replaceFirstMapped(RegExp(r'(?:(\d)|(.))'), (m) => m[1] == null ? '\\${m[2]}' : m[1]!);
  final expSymbolForRe = fmt.symbols.EXP_SYMBOL
      .replaceFirstMapped(RegExp('.'), (m) => '\\${m[0]}');
  final decimalSepForRe = fmt.symbols.DECIMAL_SEP
      .replaceFirstMapped(RegExp('.'), (m) => '\\${m[0]}');
  final groupSepForRe =
      fmt.symbols.GROUP_SEP.replaceFirstMapped(RegExp('.'), (m) => '\\${m[0]}');

  final precision = options.precision ?? (value is int ? 0 : 6);

  // Знак сохраняем отдельно, работаем с положительным числом.
  var sign = options.sign;
  if (value.isNegative) {
    value = -value;
    sign = fmt.symbols.MINUS_SIGN;
  } else if (sign == null || sign == '-') {
    sign = '';
  } else if (sign == '+') {
    sign = fmt.symbols.PLUS_SIGN;
  }

  // Преобразуем в строку.
  if (value.isNaN) {
    result = fmt.symbols.NAN;
    options.zero = false;
  } else if (value.isInfinite) {
    result = fmt.symbols.INFINITY;
    options.zero = false;
  } else {
    fmt
      ..minimumFractionDigits = fmt.maximumFractionDigits = precision
      ..minimumIntegerDigits = options.zero ? options.width ?? 1 : 1;
    if (options.groupOption != ',') fmt.turnOffGrouping();

    result = fmt.format(value);
  }

  // Удаляем лишние нули в конце.
  final pointIndex = result.indexOf(fmt.symbols.DECIMAL_SEP);
  if (pointIndex != -1) {
    result = result.replaceFirst(
        RegExp('(($decimalSepForRe)?$zeroDigitForRe)+(?=$expSymbolForRe|\$)'),
        '',
        pointIndex);
  }

  // Ставим обязательную точку.
  if (needPoint && !result.contains('.')) {
    result = result.replaceFirst(_placeForPointRe, '.');
  }

  // Удаляем лишние нули в начале.
  if (options.zero) {
    final extraWidth = result.length - (fmt.minimumIntegerDigits - sign.length);
    final extra = result.substring(0, extraWidth);
    result =
        extra.replaceFirst(RegExp('^($zeroDigitForRe|$groupSepForRe)*'), '') +
            result.substring(extraWidth);
    if (result.startsWith(fmt.symbols.GROUP_SEP)) {
      result = '${fmt.symbols.ZERO_DIGIT}$result';
    }
  }

  // // Дополняем нулями (align и fill в этом случае игнорируются).
  // final minWidth = (options.width ?? 0) - sign.length;
  // if (options.zero && result.length < minWidth) {
  //   result = zeroDigit * (minWidth - result.length) + result;
  // }

  // // Разделяем на группы.
  // final grpo = options.groupOption;
  // if (grpo != null) {
  //   final searchRe = groupLength == 3 ? _triplesRe : _quadruplesRe;
  //   final changeRe = groupLength == 3 ? _tripleRe : _quadrupleRe;
  //   var pointIndex = result.indexOf('.');
  //   if (pointIndex == -1) pointIndex = result.indexOf(RegExp('e[+-]'));
  //   if (pointIndex == -1) pointIndex = result.length;

  //   result = result.substring(0, pointIndex).replaceFirstMapped(
  //           searchRe,
  //           (m) =>
  //               m[1]! +
  //               m[2]!.replaceAllMapped(changeRe, (m) => '$grpo${m[0]}')) +
  //       result.substring(pointIndex);

  //   // Если добавляли нули, надо обрезать лишние.
  //   if (options.zero) {
  //     final extraWidth = result.length - minWidth;
  //     final extra = result.substring(0, extraWidth);
  //     result = extra.replaceAll(RegExp('^[0$grpo]*'), '') +
  //         result.substring(extraWidth);
  //     if (result[0] == grpo) result = '0$result';
  //   }
  // }

  // Восстанавливаем знак, добавляем префикс.
  result = '$sign$result';

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
      ..specifier = match.group(10)
      ..template = match.group(11);

    String? result;

    final value = options.value;

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

    final spec = options.specifier;

    options.precision = _getWidth(options, match.group(9), 'Precision',
        min: spec == 'g' || spec == 'G' ? 1 : 0);
    if (value is int && options.precision != null) {
      throw ArgumentError('${options.all} Precision not allowed for int.');
    }

    if (spec == null) {
      result = value.toString();
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

        // Число
        case 'b':
          result = _numberFormat<int>(
            options,
            value,
            altAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(2),
            groupLength: 4,
          );
          break;

        case 'o':
          result = _numberFormat<int>(
            options,
            value,
            altAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(8),
            groupLength: 4,
          );
          break;

        case 'x':
          result = _numberFormat<int>(
            options,
            value,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(16),
            groupLength: 4,
            prefix: options.alt ? '0x' : '',
          );
          break;

        case 'X':
          result = _numberFormat<int>(
            options,
            value,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(16).toUpperCase(),
            groupLength: 4,
            prefix: options.alt ? '0x' : '',
          );
          break;

        case 'd':
          result = _numberFormat<int>(
            options,
            value,
            altAllowed: false,
            toStr: (value, _) => value.toString(),
          );
          break;

        case 'f':
        case 'F':
          result = _numberFormat<double>(
            options,
            value,
            toStr: (value, precision) => value.toStringAsFixed(precision ?? 6),
            needPoint: options.alt,
          );
          if (spec == 'F') result = result.toUpperCase();
          break;

        case 'e':
        case 'E':
          result = _numberFormat<double>(
            options,
            value,
            toStr: (value, precision) =>
                value.toStringAsExponential(precision ?? 6),
            needPoint: options.alt,
          );
          if (spec == 'E') result = result.toUpperCase();
          break;

        case 'g':
        case 'G':
          result = _numberFormat<double>(
            options,
            value,
            toStr: (value, precision) =>
                value.toStringAsPrecision(precision ?? 6),
            removeTrailingZeros: true,
            needPoint: options.alt,
          );
          if (spec == 'G') result = result.toUpperCase();
          break;

        case 'n':
          if (value is! num) {
            throw ArgumentError(
                '${options.all} Expected int or double. Passed ${value.runtimeType}.');
          }

          result =
              _intlNumberFormat<num>(options, value, needPoint: options.alt);

          // final precision = options.precision ?? (value is int ? 0 : 6);
          // final fmt = NumberFormat.decimalPattern();
          // fmt.minimumFractionDigits = fmt.maximumFractionDigits = precision;
          // fmt.minimumIntegerDigits = options.zero ? options.width ?? 1 : 1;
          // if (options.groupOption != ',') fmt.turnOffGrouping();

          // result = fmt.format(value);

          // if (options.zero) {
          //   final extraWidth = result.length - fmt.minimumIntegerDigits;
          //   final extra = result.substring(0, extraWidth);
          //   final grpo = fmt.symbols.GROUP_SEP;
          //   result = extra.replaceAll(
          //           RegExp(
          //               '^(${fmt.symbols.MINUS_SIGN})?(${fmt.symbols.ZERO_DIGIT}|$grpo)*'),
          //           '') +
          //       result.substring(extraWidth);
          //   if (result[0] == grpo) result = '${fmt.symbols.ZERO_DIGIT}$result';
          // }

          options.align ??= '>';

          break;

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
