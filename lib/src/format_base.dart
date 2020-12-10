import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

final RegExp _formatSpecRe = RegExp(
    // begin
    r'\{\s*'
    // argId
    r'(\d*|[_\p{L}][_\p{L}\d]*|'
    "'(?:''|[^'])*'"
    '|"(?:""|[^"])*")'
    //  :[  [fill ] align   ] [sign ] [#] [0]
    '(?::(?:([^{}])?([<>^|]))?([-+ ])?(#)?(0)?'
    // width (number or {widthId})
    r'(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\})?'
    // group option
    '([_,])?'
    // .precision (number or {precissionId})
    r'(?:\.(\d+|\{(?:\d*|[_\w][_\w\d]*|\[[^\]]*\])\}))?'
    // specifier
    '([csbodxXfFeEgGn])?'
    // additional template
    "('(?:''|[^'])*'"
    '|"(?:""|[^"])*")?)?'
    // end
    r'\s*\}',
    unicode: true);
final RegExp _triplesRe = RegExp(r'(\d)((?:\d{3})+)$');
final RegExp _quadruplesRe = RegExp(r'([0-9a-fA-F])((?:[0-9a-fA-F]{4})+)$');
final RegExp _tripleRe = RegExp(r'\d{3}');
final RegExp _quadrupleRe = RegExp('[0-9a-fA-F]{4}');
final RegExp _trailingZerosRe = RegExp(r'\.?0+(?=e|$)');
final RegExp _placeForPointRe = RegExp(r'(?=(e[-+]\d+)?$)');

/// Обрезает строку [src] до необходимой ширины [width], вставляет
/// при необходимости [ellipsis].
///
/// Пробелы после обрезки в конце полученной строки можно убрать, установив
/// флаг [trim].
String _cut(String src, int width, {String ellipsis = '…', bool trim = true}) {
  if (src.characters.length <= width) return src;

  // В заданный размер должно поместиться троеточие
  final ellipsisLength = ellipsis.characters.length;
  if (width < ellipsisLength) return '';

  var result = src.characters.take(width - ellipsisLength).toString();
  if (trim) result = result.trimRight();

  return result + ellipsis;
}

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
      final id = _removeQuotesIfNeed(rawId, '\'"', '\'"');

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
// {id} или {[id]} - название параметра в namedArgs.
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
  bool precisionAllowed = true,
  bool altAllowed = true,
  bool standartGroupOptionAllowed = true,
  required String Function(T value, int? precision) toStr,
  bool removeTrailingZeros = false,
  bool needPoint = false,
  int groupSize = 3,
  String prefix = '',
}) {
  // Проверки.
  if (dyn is! T) {
    throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.');
  }
  if (options.precision != null && !precisionAllowed) {
    throw ArgumentError(
        "${options.all} Precision not allowed with format specifier '${options.specifier}'.");
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
  final num value = dyn;

  // Числа по умолчанию прижимаются вправо
  options.align ??= '>';

  // Сохраняем знак.
  var sign = options.sign;
  if (value.isNegative) {
    sign = '-';
  } else if (sign == null || sign == '-') {
    sign = '';
  }

  // Преобразуем в строку.
  if (value.isNaN) return 'nan';
  if (value.isInfinite) return '${sign}inf';

  result = toStr(value as T, options.precision);

  // Убираем минус, вернём его в конце.
  if (result.isNotEmpty && result[0] == '-') result = result.substring(1);

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
    final searchRe = groupSize == 3 ? _triplesRe : _quadruplesRe;
    final changeRe = groupSize == 3 ? _tripleRe : _quadrupleRe;
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
  return '$sign$prefix$result';
}

String _intlNumberFormat<T extends num>(
  _Options options,
  dynamic dyn, {
  bool removeTrailingZeros = false,
  bool needPoint = false,
}) {
  // Проверки.
  if (dyn is! T) {
    throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.');
  }

  final num value = dyn;

  // Числа по умолчанию прижимаются вправо
  options.align ??= '>';

  NumberFormat fmt;
  var hasExp = false;
  String? zeros;
  final precision = options.precision;
  final width = options.width;

  if (value.isNaN || value.isInfinite) {
    fmt = NumberFormat.decimalPattern();
  } else {
    if (value is int) {
      if (precision != null) {
        throw ArgumentError(
            "${options.all} Precision not allowed for int with format specifier '${options.specifier}'.");
      }

      fmt = NumberFormat.decimalPattern();
    } else {
      final tmp = value.toStringAsPrecision(precision ?? 6);
      final start = tmp[0] == '-' ? 1 : 0;
      final decPoint = tmp.indexOf('.');
      var end = tmp.indexOf('e');
      if (end != -1) {
        hasExp = true;
        fmt = NumberFormat.scientificPattern();
      } else {
        fmt = NumberFormat.decimalPattern();
        end = tmp.length;
      }
      if (decPoint == -1) {
        fmt
          ..minimumFractionDigits = fmt.maximumFractionDigits = 0
          ..minimumIntegerDigits = end - start;
      } else {
        fmt
          ..minimumFractionDigits =
              fmt.maximumFractionDigits = end - decPoint - 1
          ..minimumIntegerDigits = decPoint - start;
      }
    }

    if (options.groupOption != ',') fmt.turnOffGrouping();

    // Из-за того, что форматирование может быть сложным, не добиваем нулями
    // самостоятельно, а формируем отдельную строку с нулями. Длину строки
    // подбираем, исходя из того, чтобы вся дробная часть и точка могут
    // быть откинуты.
    if (options.zero && width != null) {
      final zeroFmt = NumberFormat.decimalPattern()
        ..minimumIntegerDigits = width;
      if (options.groupOption != ',') zeroFmt.turnOffGrouping();
      zeros = zeroFmt.format(0);
    }
  }

  // Сохраняем знак.
  var sign = options.sign;
  if (value.isNegative) {
    sign = fmt.symbols.MINUS_SIGN;
  } else if (sign == null || sign == '-') {
    sign = '';
  } else if (sign == '+') {
    sign = fmt.symbols.PLUS_SIGN;
  }

  var result = fmt.format(value);

  // Убираем минус, вернём его в конце.
  if (result.isNotEmpty && result.startsWith(fmt.symbols.MINUS_SIGN)) {
    result = result.substring(fmt.symbols.MINUS_SIGN.length);
  }

  if (!value.isNaN && !value.isInfinite) {
    final zeroDigitForRe = fmt.symbols.ZERO_DIGIT.replaceFirstMapped(
        RegExp(r'(?:(\d)|(.))'), (m) => m[1] == null ? '\\${m[2]}' : m[1]!);
    final expSymbolForRe = fmt.symbols.EXP_SYMBOL
        .replaceFirstMapped(RegExp('.'), (m) => '\\${m[0]}');
    final decimalSepForRe = fmt.symbols.DECIMAL_SEP
        .replaceFirstMapped(RegExp('.'), (m) => '\\${m[0]}');

    // Удаляем лишние нули в конце.
    if (removeTrailingZeros) {
      final decPoint = result.indexOf(fmt.symbols.DECIMAL_SEP);
      if (decPoint != -1) {
        result = result.replaceFirst(
            RegExp(
                '(($decimalSepForRe)?$zeroDigitForRe)+(?=$expSymbolForRe|\$)'),
            '',
            decPoint);
      }
    }

    // Ставим обязательную точку.
    if (needPoint && !result.contains(fmt.symbols.DECIMAL_SEP)) {
      if (hasExp) {
        final index = result.indexOf(fmt.symbols.EXP_SYMBOL);
        assert(index != -1);
        result = '${result.substring(0, index)}'
            '${fmt.symbols.DECIMAL_SEP}'
            '${result.substring(index)}';
      } else {
        result = '$result${fmt.symbols.DECIMAL_SEP}';
      }
    }

    if (options.zero && width != null && result.length < width - sign.length) {
      var integersCount = result.indexOf(fmt.symbols.DECIMAL_SEP);
      if (integersCount == -1) {
        integersCount =
            hasExp ? result.indexOf(fmt.symbols.EXP_SYMBOL) : result.length;
      }
      final end = zeros!.length - integersCount;
      final start = end - (width - sign.length - result.length);
      final addZeros = zeros.substring(start, end);
      result = '$addZeros$result';
      if (result.startsWith(fmt.symbols.GROUP_SEP)) {
        result = '${fmt.symbols.ZERO_DIGIT}$result';
      }
    }
  }

  // Восстанавливаем знак.
  return '$sign$result';
}

String _format(String template, List<dynamic> positionalArgs,
    [Map<String, dynamic>? namedArgs]) {
  final options = _Options(positionalArgs, namedArgs);

  // var removeEmptyStrings = false;

  final result = template.replaceAllMapped(_formatSpecRe, (match) {
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
        min: spec == 'g' || spec == 'G' || spec == 'n' ? 1 : 0);

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

          final precision = options.precision;
          result = precision == null
              ? value
              : options.alt
                  ? _cut(value, precision)
                  : precision > value.characters.length
                      ? value
                      : value.characters.take(precision).toString();
          break;

        // Число
        case 'b':
          result = _numberFormat<int>(
            options,
            value,
            precisionAllowed: false,
            altAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(2),
            groupSize: 4,
          );
          break;

        case 'o':
          result = _numberFormat<int>(
            options,
            value,
            precisionAllowed: false,
            altAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(8),
            groupSize: 4,
          );
          break;

        case 'x':
          result = _numberFormat<int>(
            options,
            value,
            precisionAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(16),
            groupSize: 4,
            prefix: options.alt ? '0x' : '',
          );
          break;

        case 'X':
          result = _numberFormat<int>(
            options,
            value,
            precisionAllowed: false,
            standartGroupOptionAllowed: false,
            toStr: (value, precision) => value.toRadixString(16).toUpperCase(),
            groupSize: 4,
            prefix: options.alt ? '0x' : '',
          );
          break;

        case 'd':
          result = _numberFormat<int>(
            options,
            value,
            precisionAllowed: false,
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
            removeTrailingZeros: !options.alt,
            needPoint: options.alt,
          );
          if (spec == 'G') result = result.toUpperCase();
          break;

        case 'n':
          result = _intlNumberFormat<num>(
            options,
            value,
            removeTrailingZeros: !options.alt,
            needPoint: options.alt && value is! int,
          );
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

/// Функция форматирования строк как в Python'е.
/// https://docs.python.org/3/library/string.html#format-specification-mini-language
///
/// Отличия от Python:
///
/// - Поддерживается автоматическия и ручная нумерация одновременно - когда
///   встречается ручная нумерация, индекс автоматической нумерации сбрасывается
///   на индекс ручной нумерации.
///
/// - В альтернативном формате для X выводится 0x, а не 0X.
///
/// - Не поддерживается альтернативный формат для b (0b..) и o (0o..), т.к. Дарт
///   не поддерживает такие литералы.
///
/// - Пока не поддерживается в именованных аргументах .key и [index].
///
/// - nan и inf не дополняются нулями при флаге zero (так делает msvc:spintf).
///   sign не действует для nan (nan не может стать +nan) (msvc:sprintf выводит
///   +nan, но это его проблемы). Короче говоря ни nan, ни inf никак
///   не меняются. Работает только выравнивание.
///
/// - В форматах 'g' и 'n' точность по-умолчанию 6.
extension StringFormat on String {
  String format(List<dynamic> positionalArgs,
          [Map<String, dynamic>? namedArgs]) =>
      _format(this, positionalArgs, namedArgs);
}
