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
    final output = CharSink(program.estimatedCapacity);
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
    Object? value,
  ) {
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
        spec = parseFormatSpec(staticSpecification, engine.textUnit, context);
        field.memoizeSpec(engine.textUnit, spec);
      }
      return formatParsedValue(converted, spec, engine, context);
    }
    final specification = _resolveSpecification(resolver, field);
    final context = _context(field, specification);
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
