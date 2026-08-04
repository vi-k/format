part of 'engine.dart';

sealed class _BraceOp {
  const _BraceOp();

  void write(CharSink sink, _BraceProcessor frame);

  String describe();
}

final class _BraceProgram {
  final List<_BraceOp> ops;
  final int estimatedCapacity;
  final bool needsResolver;

  const _BraceProgram(this.ops, this.estimatedCapacity, this.needsResolver);
}

final class _BraceLiteralOp extends _BraceOp {
  final Uint16List units;

  _BraceLiteralOp(String text) : units = Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    sink.writeCodeUnits(units);
  }

  @override
  String describe() => 'literal';
}

final class _BraceFallbackOp extends _BraceOp {
  final _FieldNode field;
  final int automaticBase;

  const _BraceFallbackOp(this.field, this.automaticBase);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final resolver = frame.resolver.._automaticIndex = automaticBase;
    final value = resolver.resolveField(field);
    sink.writeString(frame._formatField(resolver, field, value));
  }

  @override
  String describe() => 'fallback';
}

int _automaticFieldCount(_FieldNode field) {
  var count = field.root is _AutomaticRoot ? 1 : 0;
  for (final node in field.specification) {
    if (node is _FieldNode) count += _automaticFieldCount(node);
  }
  return count;
}

// Consumed by _classifyBraceField once the hot ops land in Tasks 4-6;
// unused until then.
// ignore: unused_element
String? _staticBraceSpecification(_FieldNode field) {
  final specification = field.specification;
  if (specification.isEmpty) return '';
  if (specification case [_LiteralNode(:final text)]) return text;
  return null;
}

// Hot classification lands in Tasks 4-6; the skeleton sends every field
// through the legacy string path.
_BraceOp? _classifyBraceField(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  TextUnit textUnit,
) => null;

_BraceProgram _compileBraceProgram(_BraceTemplate template, TextUnit textUnit) {
  final ops = <_BraceOp>[];
  var automatic = 0;
  var capacity = 0;
  var needsResolver = false;
  for (final node in template.nodes) {
    if (node case _LiteralNode(:final text)) {
      ops.add(_BraceLiteralOp(text));
      capacity += text.length;
      continue;
    }
    final field = node as _FieldNode;
    final automaticBase = automatic;
    automatic += _automaticFieldCount(field);
    capacity += 16;
    final (argumentIndex, argumentName) = switch (field.root) {
      _AutomaticRoot() => (automaticBase, null),
      _PositionalRoot(:final index) => (index, null),
      _NamedRoot(:final name) => (-1, name),
    };
    final op =
        field.conversion == null && field.accesses.isEmpty
            ? _classifyBraceField(field, argumentIndex, argumentName, textUnit)
            : null;
    if (op == null) {
      ops.add(_BraceFallbackOp(field, automaticBase));
      needsResolver = true;
    } else {
      ops.add(op);
    }
  }
  return _BraceProgram(ops, capacity, needsResolver);
}

sealed class _PrintfOp {
  const _PrintfOp();

  void write(CharSink sink, _PrintfProcessor frame);

  String describe();
}

final class _PrintfProgram {
  final List<_PrintfOp> ops;
  final int estimatedCapacity;

  const _PrintfProgram(this.ops, this.estimatedCapacity);
}

final class _PrintfLiteralOp extends _PrintfOp {
  final Uint16List units;

  _PrintfLiteralOp(String text) : units = Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    sink.writeCodeUnits(units);
  }

  @override
  String describe() => 'literal';
}

final class _PrintfFallbackOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int widthArgIndex;
  final int precisionArgIndex;
  final int valueArgIndex;

  const _PrintfFallbackOp(
    this.node,
    this.widthArgIndex,
    this.precisionArgIndex,
    this.valueArgIndex,
  );

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    // Same consumption order as the legacy cursor (width, precision,
    // value) and the same _staticResolved/_staticContext memoization, so
    // static fallback conversions (e.g. %f) keep today's performance.
    var resolved = node._staticResolved;
    if (resolved == null) {
      var flags = node.flags;
      var width = _fallbackOption(frame, node.width, widthArgIndex, 'width');
      var precision = _fallbackOption(
        frame,
        node.precision,
        precisionArgIndex,
        'precision',
      );
      if (width case final value? when value < 0) {
        flags |= _PrintfFlags.left;
        width = -value;
      }
      if (precision case final value? when value < 0) precision = null;
      resolved = _ResolvedPrintfConversion(
        node: node,
        flags: flags,
        width: width,
        precision: precision,
      );
      if (!node.hasDynamicOptions) node._staticResolved = resolved;
    }
    if (node.type == '%') {
      sink.writeCharCode(0x25);
      return;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    var context = node._staticContext;
    if (context == null) {
      context = _printfContext(
        frame.template,
        node,
        argumentIndex: valueArgIndex,
      );
      if (!node.hasDynamicOptions) node._staticContext = context;
    }
    sink.writeString(
      _formatPrintfValue(argument, resolved, frame.engine, context),
    );
  }

  int? _fallbackOption(
    _PrintfProcessor frame,
    _PrintfOption? option,
    int argumentIndex,
    String role,
  ) {
    if (option == null) return null;
    if (option case _LiteralPrintfOption(:final value)) {
      return frame._validateOption(node, value, role);
    }
    final argument = frame._argumentAt(argumentIndex, node, specifier: role);
    if (argument is! int || !_isIntegerValue(argument)) {
      throw UnsupportedFormatValueException(
        _printfContext(
          frame.template,
          node,
          specifier: role,
          argumentIndex: argumentIndex,
        ),
        argument,
      );
    }
    return frame._validateOption(
      node,
      argument,
      role,
      argumentIndex: argumentIndex,
    );
  }

  @override
  String describe() => 'fallback';
}

// Hot classification lands in Tasks 7-8; the skeleton sends every
// conversion through the legacy string path.
_PrintfOp? _classifyPrintfConversion(
  _PrintfConversionNode node,
  int widthArgIndex,
  int precisionArgIndex,
  int valueArgIndex,
  TextUnit textUnit,
) => null;

_PrintfProgram _compilePrintfProgram(
  _PrintfTemplate template,
  TextUnit textUnit,
) {
  final ops = <_PrintfOp>[];
  final literal = StringBuffer();
  var argument = 0;
  var capacity = 0;

  void flushLiteral() {
    if (literal.isEmpty) return;
    final text = literal.toString();
    ops.add(_PrintfLiteralOp(text));
    capacity += text.length;
    literal.clear();
  }

  for (final node in template.nodes) {
    if (node case _PrintfLiteralNode(:final text)) {
      literal.write(text);
      continue;
    }
    final conversion = node as _PrintfConversionNode;
    final widthArgIndex =
        conversion.width is _DynamicPrintfOption ? argument++ : -1;
    final precisionArgIndex =
        conversion.precision is _DynamicPrintfOption ? argument++ : -1;
    final valueArgIndex = conversion.type == '%' ? -1 : argument++;
    if (conversion.type == '%' && !conversion.hasDynamicOptions) {
      literal.write('%');
      continue;
    }
    flushLiteral();
    capacity += 16;
    final op = _classifyPrintfConversion(
      conversion,
      widthArgIndex,
      precisionArgIndex,
      valueArgIndex,
      textUnit,
    );
    ops.add(
      op ??
          _PrintfFallbackOp(
            conversion,
            widthArgIndex,
            precisionArgIndex,
            valueArgIndex,
          ),
    );
  }
  flushLiteral();
  return _PrintfProgram(ops, capacity);
}

// General width/precision resolver for the hot ops landing in Tasks 7-8,
// which compile width/precision down to plain ints instead of keeping
// _PrintfOption nodes around. Sentinels: staticValue -1 means "the option
// was absent" when argumentIndex is also -1 ("static"/no dynamic lookup);
// when argumentIndex is not -1 the option is dynamic and staticValue is
// unused. Unused until Tasks 7-8 wire it up.
// ignore: unused_element
int? _resolveIrPrintfOption(
  _PrintfProcessor frame,
  _PrintfConversionNode node,
  int staticValue,
  int argumentIndex,
  String role,
) {
  if (argumentIndex == -1) {
    return staticValue == -1 ? null : staticValue;
  }
  final argument = frame._argumentAt(argumentIndex, node, specifier: role);
  if (argument is! int || !_isIntegerValue(argument)) {
    throw UnsupportedFormatValueException(
      _printfContext(
        frame.template,
        node,
        specifier: role,
        argumentIndex: argumentIndex,
      ),
      argument,
    );
  }
  return frame._validateOption(
    node,
    argument,
    role,
    argumentIndex: argumentIndex,
  );
}

/// Test seams. Deliberately not exported by `format.dart`.
List<String> debugCompiledProgramDescription(
  String template, {
  required bool printf,
  required TextUnit textUnit,
}) =>
    printf
        ? [
          for (final op
              in _cachedPrintfTemplate(template).programFor(textUnit).ops)
            op.describe(),
        ]
        : [
          for (final op
              in _cachedBraceTemplate(template).programFor(textUnit).ops)
            op.describe(),
        ];

String debugFormatBraceWithoutIr(
  String template,
  Format engine, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) =>
    _BraceProcessor(
      template,
      positional: positional,
      named: named,
      engine: engine,
    ).formatWithoutIr();

String debugFormatPrintfWithoutIr(
  String template,
  Format engine,
  List<Object?> values,
) =>
    _PrintfProcessor(
      template,
      List<Object?>.unmodifiable(values),
      engine,
    ).formatWithoutIr();
