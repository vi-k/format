part of 'engine.dart';

final class _FieldResolver {
  final String template;
  final List<Object?> positional;
  final Map<String, Object?> named;
  final Format engine;
  var _automaticIndex = 0;

  _FieldResolver({
    required this.template,
    required this.positional,
    required this.named,
    required this.engine,
  });

  Object? resolveField(_FieldNode field) {
    var value = _resolveRoot(field);
    for (final access in field.accesses) {
      value = _resolveAccess(field, access, value);
    }
    return value;
  }

  Object? _resolveRoot(_FieldNode field) {
    final context = _context(field);
    switch (field.root) {
      case _AutomaticRoot():
        final index = _automaticIndex++;
        return _positionalValue(context, index);
      case _PositionalRoot(:final index):
        return _positionalValue(context, index);
      case _NamedRoot(:final name):
        if (!named.containsKey(name)) {
          throw MissingFormatArgumentException(context, name);
        }
        return named[name];
    }
  }

  Object? _positionalValue(FormatExceptionContext context, int index) {
    if (index >= positional.length) {
      throw MissingFormatArgumentException(context, index);
    }
    return positional[index];
  }

  Object? _resolveAccess(_FieldNode field, _FieldAccess access, Object? value) {
    final context = _context(field);
    switch (access) {
      case _IntegerItemAccess(:final index):
        if (value is List<Object?>) {
          if (index >= value.length) {
            throw FormatLookupException(context, index, value);
          }
          return value[index];
        }
        if (value is Map<Object?, Object?> && value.containsKey(index)) {
          return value[index];
        }
        throw FormatLookupException(context, index, value);
      case _StringItemAccess(:final key):
        if (value is Map<Object?, Object?> && value.containsKey(key)) {
          return value[key];
        }
        throw FormatLookupException(context, key, value);
      case _AttributeAccess(:final name):
        if (value is Map<Object?, Object?>) {
          if (value.containsKey(name)) return value[name];
          throw FormatLookupException(context, name, value);
        }
        return _resolveAttribute(context, value, name);
    }
  }

  Object? _resolveAttribute(
    FormatExceptionContext context,
    Object? value,
    String name,
  ) {
    final matches = <AttributeLookup<dynamic>>[];
    for (final lookup in engine.lookups) {
      if (_canLookup(context, lookup, value)) matches.add(lookup);
    }
    if (matches.isEmpty) throw FormatLookupException(context, name, value);
    if (matches.length > 1) {
      throw AmbiguousFormatterException(
        context,
        value,
        matches.map(_extensionName),
      );
    }
    return _lookup(context, matches.single, value, name);
  }

  bool _canLookup(
    FormatExceptionContext context,
    AttributeLookup<dynamic> lookup,
    Object? value,
  ) {
    try {
      return lookup.canLookup(value);
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      throw FormatExtensionException(
        context,
        _extensionName(lookup),
        error,
        stackTrace,
      );
    }
  }

  Object? _lookup(
    FormatExceptionContext context,
    AttributeLookup<dynamic> lookup,
    Object? value,
    String name,
  ) {
    try {
      return lookup.lookup(value, name);
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      throw FormatExtensionException(
        context,
        _extensionName(lookup),
        error,
        stackTrace,
      );
    }
  }

  String _extensionName(AttributeLookup<dynamic> lookup) =>
      lookup.runtimeType.toString();

  FormatExceptionContext _context(_FieldNode field) => FormatExceptionContext(
    template: template,
    offset: field.offset,
    fragment: field.fragment,
  );
}
