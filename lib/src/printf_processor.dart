part of 'engine.dart';

final class _PrintfProcessor {
  final String template;
  final List<Object?> values;
  final Format engine;
  late final _PrintfArgumentCursor _arguments = _PrintfArgumentCursor(
    template,
    values,
  );

  _PrintfProcessor(this.template, this.values, this.engine);

  String format() {
    final program = _cachedPrintfTemplate(template).programFor(engine.textUnit);
    final output = CharSink(program.estimatedCapacity, soleOp: program.soleOp);
    for (final op in program.ops) {
      op.write(output, this);
    }
    return output.toString();
  }

  /// Legacy string-assembly path. Kept as the baseline for differential
  /// tests and the IR A/B benchmark; reachable via
  /// debugFormatPrintfWithoutIr.
  String formatWithoutIr() {
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
      var context = conversion._staticContext;
      if (context == null) {
        context = _printfContext(
          template,
          conversion,
          argumentIndex: argument.index,
        );
        if (!conversion.hasDynamicOptions) {
          conversion._staticContext = context;
        }
      }
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
    final memoized = node._staticResolved;
    if (memoized != null) return memoized;
    var flags = node.flags;
    var width = _resolveOption(node, node.width, 'width');
    var precision = _resolveOption(node, node.precision, 'precision');
    if (width case final value? when value < 0) {
      flags |= _PrintfFlags.left;
      width = -value;
    }
    if (precision case final value? when value < 0) precision = null;
    final resolved = _ResolvedPrintfConversion(
      node: node,
      flags: flags,
      width: width,
      precision: precision,
    );
    if (!node.hasDynamicOptions) node._staticResolved = resolved;
    return resolved;
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
            ? value < -_maximumSafeFormatOption ||
                value > _maximumSafeFormatOption
            : value > _maximumSafeFormatOption;
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

  Object? _argumentAt(
    int index,
    _PrintfConversionNode node, {
    String? specifier,
  }) {
    if (index >= values.length) {
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
    return values[index];
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
