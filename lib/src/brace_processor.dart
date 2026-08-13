part of 'engine.dart';

final class _BraceProcessor {
  final String template;
  final List<Object?> positional;
  final Map<String, Object?> named;
  final Format engine;

  _BraceProcessor(
    this.template, {
    required this.positional,
    required this.named,
    required this.engine,
  });

  String format() {
    final program = _cachedBraceTemplate(template).programFor(engine.textUnit);
    final output = CharSink(program.estimatedCapacity, soleOp: program.soleOp);
    for (final op in program.ops) {
      op.write(output, this);
    }
    return output.toString();
  }

  /// Legacy string-assembly path. Kept as the baseline for differential
  /// tests and the IR A/B benchmark; reachable via debugFormatBraceWithoutIr.
  String formatWithoutIr() {
    final resolver = _FieldResolver(
      template: template,
      positional: positional,
      named: named,
      engine: engine,
    );
    final output = StringBuffer();
    for (final node in _cachedBraceTemplate(template).nodes) {
      if (node case _LiteralNode(:final text)) {
        output.write(text);
      } else {
        final field = node as _FieldNode;
        final value = resolver.resolveField(field);
        output.write(_formatField(resolver, field, value));
      }
    }
    return output.toString();
  }

  _FieldResolver? _lazyResolver;

  _FieldResolver get resolver =>
      _lazyResolver ??= _FieldResolver(
        template: template,
        positional: positional,
        named: named,
        engine: engine,
      );

  Object? _argument(int index, String? name, _FieldNode field) {
    if (name != null) {
      if (!named.containsKey(name)) {
        throw MissingFormatArgumentException(_resolveContext(field), name);
      }
      return named[name];
    }
    if (index >= positional.length) {
      throw MissingFormatArgumentException(_resolveContext(field), index);
    }
    return positional[index];
  }

  FormatExceptionContext _resolveContext(_FieldNode field) =>
      FormatExceptionContext(
        template: template,
        offset: field.offset,
        fragment: field.fragment,
      );

  String _formatField(
    _FieldResolver resolver,
    _FieldNode field,
    Object? value, {
    _DynamicSpecMemo? memo,
  }) {
    final converted =
        field.conversion == null
            ? value
            : applyConversion(
              field.conversion,
              value,
              engine,
              _context(field, ''),
            );
    final staticSpecification = _staticBraceSpecification(field);
    if (staticSpecification != null) {
      final context = _context(field, staticSpecification);
      var spec = field.memoizedSpec(engine.textUnit);
      if (spec == null) {
        spec = _parseFormatSpec(staticSpecification, engine.textUnit, context);
        field.memoizeSpec(engine.textUnit, spec);
      }
      return _formatParsedValue(converted, spec, engine, context);
    }
    final specification = _resolveSpecification(resolver, field);
    final context = _context(field, specification);
    // A specification with a nested field is unknown until the call that
    // resolves it, so it cannot be memoized on the node the way a static one
    // is. It can be memoized on the op, which is where [memo] comes from:
    // the resolved text is almost always the same text again — `{:{width}}`
    // is written to be given one width — and parsing it is what the whole
    // call costs.
    if (memo != null) {
      if (memo.text == specification) {
        return _formatParsedValue(converted, memo.spec!, engine, context);
      }
      final spec = _parseFormatSpec(specification, engine.textUnit, context);
      // Assigned after the parse, so a specification that throws leaves the
      // memo holding the last one that did not.
      memo
        ..text = specification
        ..spec = spec;
      return _formatParsedValue(converted, spec, engine, context);
    }
    return formatValue(converted, specification, engine, context);
  }

  String _resolveSpecification(_FieldResolver resolver, _FieldNode field) {
    final output = StringBuffer();
    for (final node in field.specification) {
      if (node case _LiteralNode(:final text)) {
        output.write(text);
      } else {
        final nested = node as _FieldNode;
        final value = resolver.resolveField(nested);
        output.write(_formatField(resolver, nested, value));
      }
    }
    return output.toString();
  }

  FormatExceptionContext _context(_FieldNode field, String specification) =>
      FormatExceptionContext(
        template: template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specification,
        conversion: field.conversion,
      );
}

/// One resolved specification and the parse it produced.
///
/// A single entry rather than a map: a template asks the same question with
/// the same answer call after call, and a map would charge a hash of the text
/// to find out. A miss costs one string comparison and the parse that was
/// going to happen anyway.
final class _DynamicSpecMemo {
  String? text;
  _FormatSpec? spec;
}
