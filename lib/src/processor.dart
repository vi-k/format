import 'dart:core';
import 'dart:core' as core show print;

import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

import 'errors.dart';
import 'formatter.dart';

part 'options.dart';
part 'format.dart';

/// Formats [values] referenced by positional placeholders in [template].
String format(String template, List<Object?> values) =>
    _Processor(template, positionalArgs: values).format(Format._instance);

/// Formats [values] referenced by named placeholders in [template].
String formatNamed(String template, Map<String, Object?> values) =>
    _Processor(template, namedArgs: values).format(Format._instance);

final class _Processor {
  static final RegExp _formatSpecRe = RegExp(
    // begin
    r'(?:\{\{|\}\}|\{\s*'
    // argId
    r'(\d*|[_\p{L}][_.\p{L}\d]*|'
    "'(?:''|[^'])*'"
    '|"(?:""|[^"])*")'
    //  :[  [fill ] align   ] [sign ] [#] [0]
    '(?::(?:([^}]+)?([<>^|]))?([-+ ])?(#)?(0)?'
    // literal width
    r'(\d+)?'
    // group option
    '([_,])?'
    // literal precision
    r'(?:\.(\d+))?'
    // specifier
    '([A-Za-z][A-Za-z0-9_]*)?'
    // additional template
    "('(?:''|[^'])*'"
    '|"(?:""|[^"])*")?)?'
    // end
    r'\s*\})',
    unicode: true,
  );

  final String template;
  final List<Object?>? positionalArgs;
  final Map<String, Object?>? namedArgs;

  int positionalArgsIndex = 0;

  _Processor(this.template, {this.positionalArgs, this.namedArgs});

  String format(Format settings) {
    final options = Options();
    var previousEnd = 0;
    final result = template.replaceAllMapped(_formatSpecRe, (match) {
      _validateLiteral(previousEnd, match.start);
      previousEnd = match.end;
      return _formatMatch(settings, match, options);
    });
    _validateLiteral(previousEnd, template.length);

    return result;
  }

  void _validateLiteral(int start, int end) {
    for (var index = start; index < end; index++) {
      final codeUnit = template.codeUnitAt(index);
      if (codeUnit == 0x7b || codeUnit == 0x7d) {
        final fragmentEnd = template.indexOf('}', index + 1);
        throw InvalidFormatException(
          fragment: template.substring(
            index,
            fragmentEnd == -1 ? end : fragmentEnd + 1,
          ),
          reason: 'Expected an escaped brace or a valid placeholder.',
        );
      }
    }
  }

  String _formatMatch(Format settings, Match match, Options options) {
    final all = match.group(0)!;

    if (all == '{{' || all == '}}') {
      return all[0];
    }

    options.all = all;

    final argId = match.group(1);
    final value = _getValue(options, argId);

    options
      ..fill = match.group(2)
      ..align = match.group(3)
      ..sign = match.group(4)
      ..alt = match.group(5) != null
      ..zero = match.group(6) != null
      ..width = _parseIntOption(match.group(7), all)
      ..groupOption = match.group(8)
      ..precision = _parseIntOption(match.group(9), all)
      ..specifier = match.group(10)
      ..template = match.group(11);

    String? result;

    // Типы форматирования по умолчанию используют прямой built-in dispatch.
    var specifier = options.specifier;
    if (specifier == null) {
      if (value is String) {
        specifier = 's';
      } else if (value is int || value is BigInt) {
        specifier = 'd';
      } else if (value is double) {
        specifier = 'g';
      }
      options.specifier = specifier;
    }

    if (specifier == null) {
      final formatter = settings._automaticFormatterFor(value);
      result =
          formatter == null
              ? value.toString()
              : _formatCustom(formatter, value, options);
    } else {
      switch (specifier) {
        case 'c':
          result = _formatBuiltIn(BuiltInFormatters.character, value, options);
        case 's':
          result = _formatBuiltIn(BuiltInFormatters.string, value, options);
        case 'b':
          result = _formatBuiltIn(BuiltInFormatters.binary, value, options);
        case 'o':
          result = _formatBuiltIn(BuiltInFormatters.octal, value, options);
        case 'x':
          result = _formatBuiltIn(
            BuiltInFormatters.hexadecimal,
            value,
            options,
          );
        case 'X':
          result = _formatBuiltIn(
            BuiltInFormatters.upperHexadecimal,
            value,
            options,
          );
        case 'd':
          result = _formatBuiltIn(BuiltInFormatters.decimal, value, options);
        case 'f':
          result = _formatBuiltIn(BuiltInFormatters.fixed, value, options);
        case 'F':
          result = _formatBuiltIn(BuiltInFormatters.upperFixed, value, options);
        case 'e':
          result = _formatBuiltIn(
            BuiltInFormatters.exponential,
            value,
            options,
          );
        case 'E':
          result = _formatBuiltIn(
            BuiltInFormatters.upperExponential,
            value,
            options,
          );
        case 'g':
          result = _formatBuiltIn(BuiltInFormatters.general, value, options);
        case 'G':
          result = _formatBuiltIn(
            BuiltInFormatters.upperGeneral,
            value,
            options,
          );
        case 'n':
          result = _intlNumberFormat<num>(
            options,
            value,
            removeTrailingZeros: !options.alt,
            needPoint: options.alt && value is! int,
          );
        default:
          final formatter = settings._formatterFor(specifier);
          if (formatter == null) {
            throw InvalidSpecifierException(specifier);
          }
          result = _formatCustom(formatter, value, options);
      }
    }

    final width = options.width;
    if (width != null) {
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

    return result;
  }

  String _formatBuiltIn(
    List<BuiltInFormatter> formatters,
    Object? value,
    Options options,
  ) {
    for (final formatter in formatters) {
      final result = formatter.format(options, value);
      if (result != null) {
        return result;
      }
    }
    throw UnsupportedFormatValueException(options.specifier!, value);
  }

  String _formatCustom(
    Formatter<dynamic> formatter,
    Object? value,
    Options options,
  ) {
    if (!formatter.canFormat(value)) {
      throw UnsupportedFormatValueException(formatter.specifier, value);
    }
    return formatter.format(
      value,
      FormatOptions(
        sign: options.sign,
        alternate: options.alt,
        zero: options.zero,
        grouping: options.groupOption,
        precision: options.precision,
        template: options.template,
      ),
    );
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
      throw InvalidFormatException(
        fragment: options.all ?? '',
        reason: 'Positional values are missing.',
      );
    }

    if (index >= positionalArgs.length) {
      throw InvalidFormatException(
        fragment: options.all ?? '',
        reason: 'Positional index $index is out of range.',
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
          throw InvalidFormatException(
            fragment: options.all ?? '',
            reason: 'Named values are missing.',
          );
        }

        final id = stringId;

        if (!namedArgs.containsKey(id)) {
          throw InvalidFormatException(
            fragment: options.all ?? '',
            reason: 'Named value "$id" is missing.',
          );
        }

        value = namedArgs[id];
      }
    }

    return value;
  }

  int? _parseIntOption(String? value, String fragment) {
    if (value == null) return null;

    final result = int.tryParse(value);
    if (result == null) {
      throw InvalidFormatException(
        fragment: fragment,
        reason: 'Integer literal is outside the supported range.',
      );
    }
    return result;
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
      throw UnsupportedFormatValueException(options.specifier!, dyn);
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

    if (precision != null) {
      if (precision < 1) {
        throw InvalidFormatException(
          fragment: options.all ?? '',
          reason: 'Precision must be >= 1. Passed $precision.',
        );
      }
      if (precision > 21) {
        throw InvalidFormatException(
          fragment: options.all ?? '',
          reason: 'Precision must be <= 21. Passed $precision.',
        );
      }
    }

    if (value.isNaN || value.isInfinite) {
      fmt = NumberFormat.decimalPattern();
    } else {
      if (value is int) {
        if (precision != null) {
          throw InvalidFormatException(
            fragment: options.all ?? '',
            reason:
                'Precision is not supported for integer values with '
                'specifier ${options.specifier}.',
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
        final zeroFmt =
            NumberFormat.decimalPattern()..minimumIntegerDigits = width;
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
      final expSymbolForRe = fmt.symbols.EXP_SYMBOL.replaceFirstMapped(
        RegExp('.'),
        (m) => '\\${m[0]}',
      );
      final decimalSepForRe = fmt.symbols.DECIMAL_SEP.replaceFirstMapped(
        RegExp('.'),
        (m) => '\\${m[0]}',
      );

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
          result =
              '${result.substring(0, index)}'
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

  String debugToString() =>
      '$_Processor('
      'template: $template'
      ', positionalArgs: $positionalArgs'
      ', namedArgs: $namedArgs'
      ')';
}
