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
        output.write(resolver.resolveField(node as _FieldNode));
      }
    }
    return output.toString();
  }
}
