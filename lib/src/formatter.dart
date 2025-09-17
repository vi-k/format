import 'package:characters/characters.dart';

import 'processor.dart';
import 'utils/utils.dart';

// ignore: one_member_abstracts
abstract base class Formatter {
  String get name;
  String? format(Options options, Object? value);
}

final class StringFormatter extends Formatter {
  @override
  String get name => 'Standart String formatter';

  @override
  String? format(Options options, Object? value) {
    if (value is! String) {
      return null;
    }

    if (options.zero) {
      options.fill = '0';
    }

    final precision = options.precision;
    return precision == null
        ? value
        : options.alt
            ? cut(value, precision)
            : precision > value.characters.length
                ? value
                : value.characters.take(precision).toString();
  }
}

final class CharFormatter extends StringFormatter {
  @override
  String get name => 'Standart char formatter';

  @override
  String? format(Options options, Object? value) {
    if (value is int) {
      value = String.fromCharCode(value);
    } else if (value is List<int>) {
      value = String.fromCharCodes(value);
    } else {
      return null;
    }

    return super.format(options, value);
  }
}

abstract base class NumberFormatter<T> extends Formatter {
  static final RegExp _triplesRe = RegExp(r'(\d)((?:\d{3})+)$');
  static final RegExp _quadruplesRe =
      RegExp(r'([0-9a-fA-F])((?:[0-9a-fA-F]{4})+)$');
  static final RegExp _tripleRe = RegExp(r'\d{3}');
  static final RegExp _quadrupleRe = RegExp('[0-9a-fA-F]{4}');
  static final RegExp _trailingZerosRe = RegExp(r'\.?0+(?=e|$)');
  static final RegExp _placeForPointRe = RegExp(r'(?=(e[-+]\d+)?$)');

  final bool precisionSupported;
  final int minPrecision;
  final bool altSupported;
  final bool standartGroupOptionSupported;
  final bool Function(Options options)? removeTrailingZeros;
  final bool Function(Options options)? needPoint;
  final int groupSize;
  final String Function(Options options)? prefix;
  final String Function(T value, int? precision) convertValue;
  final String Function(String result)? convertResult;

  NumberFormatter({
    required this.convertValue,
    this.precisionSupported = true,
    int? minPrecision,
    this.altSupported = true,
    this.standartGroupOptionSupported = true,
    this.removeTrailingZeros,
    this.needPoint,
    this.groupSize = 3,
    this.prefix,
    this.convertResult,
  }) : minPrecision = minPrecision ?? 0;

  bool isNegative(T value);

  bool isNaN(T value);

  bool isInfinite(T value);

  @override
  String? format(Options options, Object? value) {
    // Проверки.
    if (value is! T) {
      return null;
    }

    final precision = options.precision;
    if (precision != null) {
      if (!precisionSupported) {
        throw ArgumentError(
          '${options.all}'
          ' Precision is not supported by specifier'
          ' ${options.specifier}',
        );
      }

      if (precision < minPrecision) {
        throw ArgumentError(
          '${options.all} Precision must be >= $minPrecision.'
          ' Passed $precision',
        );
      }
    }

    if (options.alt && !altSupported) {
      throw ArgumentError(
        '${options.all}'
        ' Alternate form (#) is not supported by specifier'
        ' ${options.specifier}',
      );
    }

    if (options.groupOption == ',' && !standartGroupOptionSupported) {
      throw ArgumentError(
        '${options.all}'
        " Group option ',' is not supported by specifier"
        ' ${options.specifier}',
      );
    }

    String result;

    // Если задан fill, игнорируем zero.
    if (options.fill != null) {
      options.zero = false;
    }

    // Числа по умолчанию прижимаются вправо.
    options.align ??= '>';

    // Сохраняем знак.
    var sign = options.sign;
    if (isNegative(value)) {
      sign = '-';
    } else if (sign == null || sign == '-') {
      sign = '';
    }

    // Преобразуем в строку.
    if (isNaN(value)) {
      return convertResult?.call('nan') ?? 'nan';
    }

    if (isInfinite(value)) {
      return convertResult?.call('${sign}inf') ?? '${sign}inf';
    }

    result = convertValue(value, options.precision);

    // Убираем минус, вернём его в конце.
    if (result.isNotEmpty && result[0] == '-') result = result.substring(1);

    // Удаляем лишние нули.
    final removeTrailingZeros =
        this.removeTrailingZeros?.call(options) ?? false;
    if (removeTrailingZeros && result.contains('.')) {
      result = result.replaceFirst(_trailingZerosRe, '');
    }

    // Ставим обязательную точку.
    final needPoint = this.needPoint?.call(options) ?? false;
    if (needPoint && !result.contains('.')) {
      result = result.replaceFirst(_placeForPointRe, '.');
    }

    // Дополняем нулями (align и fill в этом случае игнорируются).
    final prefix = this.prefix?.call(options) ?? '';
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
                    m[2]!.replaceAllMapped(changeRe, (m) => '$grpo${m[0]}'),
              ) +
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

    return convertResult?.call(result) ?? result;
  }
}

final class IntFormatter extends NumberFormatter<int> {
  IntFormatter({
    required super.convertValue,
    super.precisionSupported = true,
    super.altSupported = true,
    super.standartGroupOptionSupported = true,
    super.removeTrailingZeros,
    super.needPoint,
    super.groupSize = 3,
    super.prefix,
    super.convertResult,
  });

  @override
  String get name => 'Standart int formatter';

  @override
  bool isNegative(int value) => value.isNegative;

  @override
  bool isNaN(int value) => false;

  @override
  bool isInfinite(int value) => false;
}

final class NumFormatter<T extends num> extends NumberFormatter<T> {
  NumFormatter({
    required super.convertValue,
    super.precisionSupported = true,
    super.minPrecision,
    super.altSupported = true,
    super.standartGroupOptionSupported = true,
    super.removeTrailingZeros,
    super.needPoint,
    super.groupSize = 3,
    super.prefix,
    super.convertResult,
  });

  @override
  String get name => 'Standart num formatter';

  @override
  bool isNegative(T value) => value.isNegative;

  @override
  bool isNaN(T value) => value.isNaN;

  @override
  bool isInfinite(T value) => value.isInfinite;
}

final class BigIntFormatter extends NumberFormatter<BigInt> {
  BigIntFormatter({
    required super.convertValue,
    super.precisionSupported = true,
    super.minPrecision,
    super.altSupported = true,
    super.standartGroupOptionSupported = true,
    super.removeTrailingZeros,
    super.needPoint,
    super.groupSize = 3,
    super.prefix,
    super.convertResult,
  });

  @override
  String get name => 'Standart BigInt formatter';

  @override
  bool isNegative(BigInt value) => value.isNegative;

  @override
  bool isNaN(BigInt value) => false;

  @override
  bool isInfinite(BigInt value) => false;
}
