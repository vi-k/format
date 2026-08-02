part of '../format2.dart';

final class _Format2Processor {
  static final RegExp _formatSpecRe = RegExp(
    r'(?:\{\{|\}\}|\{\s*'
    r'(\d*|[_\p{L}][_.\p{L}\d]*|'
    "'(?:''|[^'])*'"
    '|"(?:""|[^"])*")'
    '(?::(?:([^}]+)?([<>^|]))?([-+ ])?(#)?(0)?'
    r'(\d+)?'
    '([_,])?'
    r'(?:\.(\d+))?'
    '([A-Za-z][A-Za-z0-9_]*)?'
    "('(?:''|[^'])*'"
    '|"(?:""|[^"])*")?)?'
    r'\s*\})',
    unicode: true,
  );

  final String template;
  final List<Object?> values;
  var _valueIndex = 0;

  _Format2Processor(this.template, this.values);

  String format() {
    final options = _Format2Options();
    var previousEnd = 0;
    final result = template.replaceAllMapped(_formatSpecRe, (match) {
      _validateLiteral(previousEnd, match.start);
      previousEnd = match.end;
      return _formatMatch(match, options);
    });
    _validateLiteral(previousEnd, template.length);
    return result;
  }

  void _validateLiteral(int start, int end) {
    for (var index = start; index < end; index++) {
      final codeUnit = template.codeUnitAt(index);
      if (codeUnit == 0x7b || codeUnit == 0x7d) {
        final fragmentEnd = template.indexOf('}', index + 1);
        throw _Format2InvalidFormatException(
          fragment: template.substring(
            index,
            fragmentEnd == -1 ? end : fragmentEnd + 1,
          ),
          reason: 'Expected an escaped brace or a valid placeholder.',
        );
      }
    }
  }

  String _formatMatch(Match match, _Format2Options options) {
    final all = match.group(0)!;
    if (all == '{{' || all == '}}') return all[0];

    options
      ..all = all
      ..fill = match.group(2)
      ..align = match.group(3)
      ..sign = match.group(4)
      ..alt = match.group(5) != null
      ..zero = match.group(6) != null
      ..width = _parseIntOption(match.group(7), all)
      ..groupOption = match.group(8)
      ..precision = _parseIntOption(match.group(9), all)
      ..specifier = match.group(10);

    final value = _getValue(match.group(1), options);
    var specifier = options.specifier;
    if (specifier == null) {
      if (value is String) {
        specifier = 's';
      } else if (value is int || value is BigInt) {
        specifier = 'd';
      } else if (value is double) {
        specifier = 'g';
      } else {
        return value.toString();
      }
      options.specifier = specifier;
    }

    var result = _format2Value(options, value);
    final width = options.width;
    if (width != null) {
      final resultWidth = result.characters.length;
      if (resultWidth < width) {
        final fill = options.fill ?? ' ';
        final remaining = width - resultWidth;
        switch (options.align ?? '<') {
          case '<':
            result += fill * remaining;
          case '>':
            result = fill * remaining + result;
          case '^':
            final half = remaining ~/ 2;
            result = fill * half + result + fill * (remaining - half);
        }
      }
    }
    return result;
  }

  Object? _getValue(String? rawId, _Format2Options options) {
    if (rawId == null || rawId.isEmpty)
      return _getValueByIndex(_valueIndex++, options);
    final index = int.tryParse(rawId);
    if (index == null) {
      throw _Format2InvalidFormatException(
        fragment: options.all ?? '',
        reason: 'Named values are missing.',
      );
    }
    _valueIndex = index + 1;
    return _getValueByIndex(index, options);
  }

  Object? _getValueByIndex(int index, _Format2Options options) {
    if (index >= values.length) {
      throw _Format2InvalidFormatException(
        fragment: options.all ?? '',
        reason: 'Positional index $index is out of range.',
      );
    }
    return values[index];
  }

  int? _parseIntOption(String? value, String fragment) {
    if (value == null) return null;
    final result = int.tryParse(value);
    if (result == null) {
      throw _Format2InvalidFormatException(
        fragment: fragment,
        reason: 'Integer literal is outside the supported range.',
      );
    }
    return result;
  }
}
