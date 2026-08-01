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
    final resolver = _FieldResolver(
      template: template,
      positional: positional,
      named: named,
      engine: engine,
    );
    final output = StringBuffer();
    for (final node in _parseBraceTemplate(template).nodes) {
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

  String _formatField(
    _FieldResolver resolver,
    _FieldNode field,
    Object? value,
  ) {
    final converted = applyConversion(
      field.conversion,
      value,
      engine,
      _context(field, ''),
    );
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
