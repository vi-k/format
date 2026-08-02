part of '../format2.dart';

String _format2Cut(String source, int width) {
  if (source.characters.length <= width) return source;

  const ellipsis = '…';
  if (width < ellipsis.characters.length) return '';

  return source.characters
          .take(width - ellipsis.characters.length)
          .toString()
          .trimRight() +
      ellipsis;
}

String _format2Value(_Format2Options options, Object? value) {
  switch (options.specifier) {
    case 's':
      return _format2String(options, value);
    case 'c':
      return _format2Character(options, value);
    case 'b':
      return _format2Integer(options, value, radix: 2, groupSize: 4);
    case 'o':
      return _format2Integer(options, value, radix: 8, groupSize: 4);
    case 'x':
      return _format2Integer(
        options,
        value,
        radix: 16,
        groupSize: 4,
        prefix: options.alt ? '0x' : '',
      );
    case 'X':
      return _format2Integer(
        options,
        value,
        radix: 16,
        groupSize: 4,
        prefix: options.alt ? '0x' : '',
        upper: true,
      );
    case 'd':
      return _format2Integer(options, value, radix: 10);
    case 'f':
      return _format2Double(options, value, conversion: _format2Fixed);
    case 'F':
      return _format2Double(
        options,
        value,
        conversion: _format2Fixed,
        upper: true,
      );
    case 'e':
      return _format2Double(options, value, conversion: _format2Exponential);
    case 'E':
      return _format2Double(
        options,
        value,
        conversion: _format2Exponential,
        upper: true,
      );
    case 'g':
      return _format2Double(options, value, conversion: _format2General);
    case 'G':
      return _format2Double(
        options,
        value,
        conversion: _format2General,
        upper: true,
      );
    default:
      throw _Format2InvalidSpecifierException(options.specifier!);
  }
}

String _format2String(_Format2Options options, Object? value) {
  if (value is! String) {
    throw _Format2UnsupportedFormatValueException(options.specifier!, value);
  }
  if (options.zero) options.fill = '0';

  final precision = options.precision;
  if (precision == null) return value;
  return options.alt
      ? _format2Cut(value, precision)
      : precision > value.characters.length
      ? value
      : value.characters.take(precision).toString();
}

String _format2Character(_Format2Options options, Object? value) {
  final string = switch (value) {
    int() => String.fromCharCode(value),
    List<int>() => String.fromCharCodes(value),
    _ => null,
  };
  if (string == null) {
    throw _Format2UnsupportedFormatValueException(options.specifier!, value);
  }
  return _format2String(options, string);
}

String _format2Integer(
  _Format2Options options,
  Object? value, {
  required int radix,
  int groupSize = 3,
  String prefix = '',
  bool upper = false,
}) {
  if (value is! int && value is! BigInt) {
    throw _Format2UnsupportedFormatValueException(options.specifier!, value);
  }
  _format2CheckIntegerOptions(options, radix);

  if (options.fill != null) options.zero = false;
  options.align ??= '>';

  final negative = switch (value) {
    int value => value.isNegative,
    BigInt value => value.isNegative,
    _ => false,
  };
  var sign = options.sign;
  if (negative) {
    sign = '-';
  } else if (sign == null || sign == '-') {
    sign = '';
  }

  var result = switch (value) {
    int value => value.toRadixString(radix),
    BigInt value => value.toRadixString(radix),
    _ => '',
  };
  if (result.startsWith('-')) result = result.substring(1);
  if (upper) result = result.toUpperCase();

  result = _format2NumberLayout(
    options,
    result,
    sign: sign,
    prefix: prefix,
    groupSize: groupSize,
  );
  return result;
}

void _format2CheckIntegerOptions(_Format2Options options, int radix) {
  if (options.precision != null) {
    throw _Format2InvalidFormatException(
      fragment: options.all ?? '',
      reason: 'Precision is not supported by specifier ${options.specifier}.',
    );
  }
  if (options.alt && (radix == 2 || radix == 8 || radix == 10)) {
    throw _Format2InvalidFormatException(
      fragment: options.all ?? '',
      reason:
          'Alternate form (#) is not supported by specifier '
          '${options.specifier}.',
    );
  }
  if (options.groupOption == ',' && radix != 10) {
    throw _Format2InvalidFormatException(
      fragment: options.all ?? '',
      reason:
          "Group option ',' is not supported by specifier "
          '${options.specifier}.',
    );
  }
}

String _format2Fixed(double value, int? precision) =>
    value.toStringAsFixed(precision ?? 6);

String _format2Exponential(double value, int? precision) =>
    value.toStringAsExponential(precision ?? 6);

String _format2General(double value, int? precision) =>
    value.toStringAsPrecision(precision ?? 6);

String _format2Double(
  _Format2Options options,
  Object? value, {
  required String Function(double value, int? precision) conversion,
  bool upper = false,
}) {
  if (value is! double) {
    throw _Format2UnsupportedFormatValueException(options.specifier!, value);
  }

  final precision = options.precision;
  final isGeneral = options.specifier == 'g' || options.specifier == 'G';
  if (precision != null &&
      (precision < (isGeneral ? 1 : 0) || precision > (isGeneral ? 21 : 20))) {
    throw _Format2InvalidFormatException(
      fragment: options.all ?? '',
      reason:
          'Precision must be between ${isGeneral ? 1 : 0} and '
          '${isGeneral ? 21 : 20}. Passed $precision.',
    );
  }

  if (options.fill != null) options.zero = false;
  options.align ??= '>';

  var sign = options.sign;
  if (value.isNegative) {
    sign = '-';
  } else if (sign == null || sign == '-') {
    sign = '';
  }
  if (value.isNaN) return upper ? 'NAN' : 'nan';
  if (value.isInfinite) return upper ? '${sign}INF' : '${sign}inf';

  var result = conversion(value, precision);
  if (result.startsWith('-')) result = result.substring(1);
  if (isGeneral && !options.alt && result.contains('.')) {
    result = result.replaceFirst(RegExp(r'\.?0+(?=e|$)'), '');
  }
  if (options.alt && !result.contains('.')) {
    result = result.replaceFirst(RegExp(r'(?=(e[-+]\d+)?$)'), '.');
  }

  result = _format2NumberLayout(options, result, sign: sign);
  return upper ? result.toUpperCase() : result;
}

String _format2NumberLayout(
  _Format2Options options,
  String result, {
  required String sign,
  String prefix = '',
  int groupSize = 3,
}) {
  final minWidth = (options.width ?? 0) - sign.length - prefix.length;
  final zeroPaddingAdded = options.zero && result.length < minWidth;
  if (zeroPaddingAdded) result = '0' * (minWidth - result.length) + result;

  final grouping = options.groupOption;
  if (grouping != null) {
    final chunkSize = groupSize == 3 ? 3 : 4;
    final boundary = result.indexOf(RegExp(r'[.e]'));
    final integerEnd = boundary == -1 ? result.length : boundary;
    final integer = result.substring(0, integerEnd);
    final firstLength = integer.length % chunkSize;
    final chunks = <String>[];
    if (firstLength != 0) chunks.add(integer.substring(0, firstLength));
    for (var index = firstLength; index < integer.length; index += chunkSize) {
      chunks.add(integer.substring(index, index + chunkSize));
    }
    result = chunks.join(grouping) + result.substring(integerEnd);
    if (zeroPaddingAdded) {
      final extraWidth = result.length - minWidth;
      final extra = result.substring(0, extraWidth);
      result =
          extra.replaceFirst(RegExp('^[0$grouping]*'), '') +
          result.substring(extraWidth);
      if (result.startsWith(grouping)) result = '0$result';
    }
  }

  return '$sign$prefix$result';
}

sealed class _Format2FormattingException implements Exception {
  const _Format2FormattingException();
}

final class _Format2InvalidFormatException extends _Format2FormattingException {
  final String fragment;
  final String reason;

  const _Format2InvalidFormatException({
    required this.fragment,
    required this.reason,
  });
}

final class _Format2InvalidSpecifierException
    extends _Format2FormattingException {
  final String specifier;

  const _Format2InvalidSpecifierException(this.specifier);
}

final class _Format2UnsupportedFormatValueException
    extends _Format2FormattingException {
  final String specifier;
  final Object? value;

  const _Format2UnsupportedFormatValueException(this.specifier, this.value);
}
