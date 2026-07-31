import 'dart:core';
import 'dart:core' as core show print;

import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

import 'errors.dart';
import 'formatter.dart';

part 'options.dart';
part 'format.dart';

/// String formatting function like in Python with positional arguments.
String format2(String template, List<Object?> values) =>
    _Processor(template, positionalArgs: values).format(Format._instance);

/// String formatting function like in Python with named arguments.
String format2m(String template, Map<String, Object?> values) =>
    _Processor(template, namedArgs: values).format(Format._instance);

/// Temporary bridge for the legacy engine during the Format 2.0 migration.
void checkForAmbiguousCustomFormatter(Object? value) =>
    Format._instance._automaticFormatterFor(value);

final class _Processor {
  static final RegExp _formatSpecRe = RegExp(
    // begin
    r'(?:\{\{|\{\s*'
    // argId
    r'(\d*|[_\p{L}][_.\p{L}\d]*|'
    "'(?:''|[^'])*'"
    '|"(?:""|[^"])*")'
    //  :[  [fill ] align   ] [sign ] [#] [0]
    '(?::(?:([^}]+)?([<>^|]))?([-+ ])?(#)?(0)?'
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
    r'\s*\})',
    unicode: true,
  );

  final String template;
  final List<Object?>? positionalArgs;
  final Map<Object, Object?>? namedArgs;

  int positionalArgsIndex = 0;

  _Processor(
    this.template, {
    this.positionalArgs,
    this.namedArgs,
  });

  String format(Format settings) {
    final result = template.replaceAllMapped(_formatSpecRe, (match) {
      final all = match.group(0)!;

      if (all == '{{') {
        return '{';
      }

      final options = Options()..all = all;

      final argId = match.group(1);
      final value = _getValue(options, argId);

      options
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

      String? result;

      // Типы форматирования по умолчанию.
      final specifier = options.specifier ??= settings._autoSpecifierFor(value);

      if (specifier == null) {
        result = value.toString();
      } else {
        final formatters = settings._formatters[specifier];
        if (formatters != null) {
          for (final formatter in formatters) {
            final r = formatter.format(options, value);
            if (r != null) {
              result = r;
              break;
            }
          }

          if (result == null) {
            throw ArgumentError(
              '${options.all}'
              ' Formatter for type ${value.runtimeType}'
              ' and specifier $specifier is not registered',
            );
          }
        }

        /// TODO(vi.k): intl вынести в отдельный пакет
        if (result == null) {
          switch (specifier) {
            case 'n':
              result = _intlNumberFormat<num>(
                options,
                value,
                removeTrailingZeros: !options.alt,
                needPoint: options.alt && value is! int,
              );
          }
        }
      }

      final width = options.width;
      if (result != null && width != null) {
        final resultWidth = result.characters.length;
        if (resultWidth < width) {
          // Выравниваем относительно заданной ширины
          final fill = options.fill ?? ' ';
          final n = width - resultWidth;

          switch (options.align ?? '<') {
            case '<':
              result += fill * n;

            case '>':
              result = fill * n + result;

            case '^':
              final half = n ~/ 2;
              result = fill * half + result + fill * (n - half);
          }
        }
      }

      if (result != null) return result;

      return options.toString();
    });

    return result;
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
  /// Если нет кавычек возвращает исходную строку [str] без изменений.
  String _removeQuotesIfNeed(String str, String left, String right) =>
      _getValueInQuotes(str, left, right) ?? str;

  /// Поиск значения в positionalArgs по индексу [index].
  Object? _getValueByIndex(Options options, int index) {
    final positionalArgs = this.positionalArgs;

    if (positionalArgs == null) {
      throw ArgumentError('${options.all} Positional args is missing.');
    }

    if (index >= positionalArgs.length) {
      throw ArgumentError(
        '${options.all} Index #$index out of range of positional args.',
      );
    }

    positionalArgsIndex = index + 1;

    return positionalArgs[index];
  }

  /// Поиск значения.
  ///
  /// Варианты:
  /// `{}` - перебираем параметры в positionalArgs по порядку;
  /// `{index}` - индекс параметра в positionalArgs;
  /// `{id}` или `{[id]}` - название параметра в namedArgs;
  Object? _getValue(Options options, String? rawId) {
    Object? value;

    if (rawId == null || rawId.isEmpty) {
      // Автоматическая нумерация.
      value = _getValueByIndex(options, positionalArgsIndex);
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
        final stringId = _removeQuotesIfNeed(rawId, '\'"', '\'"');

        final namedArgs = this.namedArgs;
        if (namedArgs == null) {
          throw ArgumentError('${options.all} Named args is missing.');
        }

        final id =
            namedArgs is Map<Symbol, Object?> ? Symbol(stringId) : stringId;

        if (!namedArgs.containsKey(id)) {
          throw ArgumentError(
            '${options.all} Key [$id] is missing in named args.',
          );
        }

        value = namedArgs[id];
      }
    }

    return value;
  }

  /// Вычисляет width и precision.
  ///
  /// Варианты:
  /// `n` - значение задано напрямую;
  /// `{}` - перебираем параметры в positionalArgs по порядку;
  /// `{index}` - индекс параметра в positionalArgs;
  /// `{id}` или `{[id]}` - название параметра в namedArgs.
  int? _getWidth(Options options, String? str, String name) {
    int? value;

    if (str != null) {
      value = int.tryParse(str);
      if (value == null) {
        // Значение передано в виде параметра.
        final v = _getValue(options, _getValueInQuotes(str, '{', '}'));
        if (v is! int) {
          throw ArgumentError(
            '${options.all} $name must be int, passed ${v.runtimeType}.',
          );
        }

        value = v;
      }
    }

    return value;
  }

  // ignore: long-method
  String _intlNumberFormat<T extends num>(
    Options options,
    Object? dyn, {
    bool removeTrailingZeros = false,
    bool needPoint = false,
  }) {
    // Проверки.
    if (dyn is! T) {
      throw ArgumentError(
        '${options.all} Expected $T. Passed ${dyn.runtimeType}.',
      );
    }

    final num value = dyn;

    // Если задан fill, игнорируем zero.
    if (options.fill != null) {
      options.zero = false;
    }

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
            '${options.all} '
            'Precision not allowed for int with format specifier '
            "'${options.specifier}'.",
          );
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

      if (options.groupOption != ',') {
        fmt.turnOffGrouping();
      }

      // Из-за того, что форматирование может быть сложным, не добиваем нулями
      // самостоятельно, а формируем отдельную строку с нулями. Длину строки
      // подбираем, исходя из того, чтобы вся дробная часть и точка могут
      // быть откинуты.
      if (options.zero && width != null) {
        final zeroFmt = NumberFormat.decimalPattern()
          ..minimumIntegerDigits = width;
        if (options.groupOption != ',') {
          zeroFmt.turnOffGrouping();
        }
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
        RegExp(r'(?:(\d)|(.))'),
        (m) => m[1] == null ? '\\${m[2]}' : m[1]!,
      );
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
              '(($decimalSepForRe)?$zeroDigitForRe)+(?=$expSymbolForRe|\$)',
            ),
            '',
            decPoint,
          );
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

      if (options.zero &&
          width != null &&
          result.length < width - sign.length) {
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

  String debugToString() => '$_Processor('
      'template: $template'
      ', positionalArgs: $positionalArgs'
      ', namedArgs: $namedArgs'
      ')';
}
