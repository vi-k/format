part of 'engine.dart';

final class _PrintfProcessor {
  static const _maximumSafeOption = 100000;

  final String template;
  final List<Object?> values;
  final Format engine;
  late final _PrintfArgumentCursor _arguments = _PrintfArgumentCursor(
    template,
    values,
  );

  _PrintfProcessor(this.template, this.values, this.engine);

  String format() {
    final parsed = _cachedPrintfTemplate(template);
    final output = StringBuffer();
    for (final node in parsed.nodes) {
      if (node case _PrintfLiteralNode(:final text)) {
        output.write(text);
        continue;
      }

      final conversion = node as _PrintfConversionNode;
      final resolved = _resolve(conversion);
      if (conversion.type == '%') {
        output.write('%');
        continue;
      }

      final argument = _arguments.take(conversion);
      final context = _printfContext(
        template,
        conversion,
        argumentIndex: argument.index,
      );
      final formatted = _formatPrintfValue(
        argument.value,
        resolved,
        engine,
        context,
      );
      output.write(formatted);
    }
    return output.toString();
  }

  _ResolvedPrintfConversion _resolve(_PrintfConversionNode node) {
    var flags = node.flags;
    var width = _resolveOption(node, node.width, 'width');
    var precision = _resolveOption(node, node.precision, 'precision');
    if (width case final value? when value < 0) {
      flags |= _PrintfFlags.left;
      width = -value;
    }
    if (precision case final value? when value < 0) precision = null;
    return _ResolvedPrintfConversion(
      node: node,
      flags: flags,
      width: width,
      precision: precision,
    );
  }

  int? _resolveOption(
    _PrintfConversionNode node,
    _PrintfOption? option,
    String role,
  ) {
    if (option == null) return null;
    if (option case _LiteralPrintfOption(:final value)) {
      return _validateOption(node, value, role);
    }

    final argument = _arguments.take(node, specifier: role);
    final value = argument.value;
    if (value is! int || !_isIntegerValue(value)) {
      throw UnsupportedFormatValueException(
        _printfContext(
          template,
          node,
          specifier: role,
          argumentIndex: argument.index,
        ),
        value,
      );
    }
    return _validateOption(node, value, role, argumentIndex: argument.index);
  }

  int _validateOption(
    _PrintfConversionNode node,
    int value,
    String role, {
    int? argumentIndex,
  }) {
    final unsafe =
        role == 'width'
            ? value < -_maximumSafeOption || value > _maximumSafeOption
            : value > _maximumSafeOption;
    if (unsafe) {
      throw InvalidSpecifierException(
        _printfContext(
          template,
          node,
          specifier: role,
          argumentIndex: argumentIndex,
        ),
        'The resolved printf $role is too large to format safely.',
      );
    }
    return value;
  }
}

final class _PrintfArgumentCursor {
  final String template;
  final List<Object?> values;
  var _index = 0;

  _PrintfArgumentCursor(this.template, this.values);

  ({Object? value, int index}) take(
    _PrintfConversionNode node, {
    String? specifier,
  }) {
    final index = _index;
    if (index == values.length) {
      throw MissingFormatArgumentException(
        _printfContext(
          template,
          node,
          specifier: specifier,
          argumentIndex: index,
        ),
        index,
      );
    }
    _index++;
    return (value: values[index], index: index);
  }
}

FormatExceptionContext _printfContext(
  String template,
  _PrintfConversionNode node, {
  String? specifier,
  int? argumentIndex,
}) => FormatExceptionContext(
  template: template,
  offset: node.offset,
  fragment: node.fragment,
  specifier: specifier ?? node.type,
  conversion: node.type,
  argumentIndex: argumentIndex,
);
