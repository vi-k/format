part of 'engine.dart';

final class _BraceProcessor {
  final String template;
  final List<Object?> positional;
  final Map<String, Object?> named;

  _BraceProcessor(
    this.template, {
    required this.positional,
    required this.named,
  });

  String format() {
    final output = StringBuffer();
    var automaticIndex = 0;
    var index = 0;

    while (index < template.length) {
      final character = template[index];
      if (character == '{') {
        final closeIndex = template.indexOf('}', index + 1);
        if (closeIndex == -1) throw _invalidFormat(index);

        final field = template.substring(index + 1, closeIndex);
        final value = _valueFor(field, automaticIndex);
        if (field.isEmpty) automaticIndex++;
        output.write(value);
        index = closeIndex + 1;
      } else {
        output.write(character);
        index++;
      }
    }

    return output.toString();
  }

  Object? _valueFor(String field, int automaticIndex) {
    if (field.isEmpty) return _positionalValue(automaticIndex);

    final positionalIndex = int.tryParse(field);
    if (positionalIndex != null) return _positionalValue(positionalIndex);

    if (!named.containsKey(field)) {
      throw MissingFormatArgumentException(_context(index: null), field);
    }
    return named[field];
  }

  Object? _positionalValue(int index) {
    if (index >= positional.length) {
      throw MissingFormatArgumentException(_context(index: index), index);
    }
    return positional[index];
  }

  InvalidFormatException _invalidFormat(int offset) => InvalidFormatException(
    _context(index: offset),
    'Expected a closing brace for a simple placeholder.',
  );

  FormatExceptionContext _context({required int? index}) =>
      FormatExceptionContext(template: template, offset: index);
}
