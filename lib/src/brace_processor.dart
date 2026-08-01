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
        final specification = _literalSpecification(field);
        final context = FormatExceptionContext(
          template: template,
          offset: field.offset,
          fragment: field.fragment,
          specifier: specification,
          conversion: field.conversion,
        );
        output.write(
          formatValue(
            applyConversion(field.conversion, value, engine, context),
            specification,
            engine,
            context,
          ),
        );
      }
    }
    return output.toString();
  }

  String _literalSpecification(_FieldNode field) {
    final output = StringBuffer();
    for (final node in field.specification) {
      if (node case _LiteralNode(:final text)) {
        output.write(text);
      } else {
        throw InvalidSpecifierException(
          FormatExceptionContext(
            template: template,
            offset: field.offset,
            fragment: field.fragment,
          ),
          'Nested format specifications are not supported yet.',
        );
      }
    }
    return output.toString();
  }
}
