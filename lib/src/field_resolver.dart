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
    switch (field.root) {
      case _AutomaticRoot():
        final index = _automaticIndex++;
        return _positionalValue(field, index);
      case _PositionalRoot(:final index):
        return _positionalValue(field, index);
      case _NamedRoot(:final name):
        if (!named.containsKey(name)) {
          throw MissingFormatArgumentException(_context(field), name);
        }
        return named[name];
    }
  }

  Object? _positionalValue(_FieldNode field, int index) {
    if (index >= positional.length) {
      throw MissingFormatArgumentException(_context(field), index);
    }
    return positional[index];
  }

  Object? _resolveAccess(_FieldNode field, _FieldAccess access, Object? value) {
    switch (access) {
      case _IntegerItemAccess(:final index):
        if (value is List<Object?>) {
          if (index >= value.length) {
            throw FormatLookupException(_context(field), index, value);
          }
          return value[index];
        }
        if (value is Map<Object?, Object?> && value.containsKey(index)) {
          return value[index];
        }
        throw FormatLookupException(_context(field), index, value);
      case _StringItemAccess(:final key):
        if (value is Map<Object?, Object?> && value.containsKey(key)) {
          return value[key];
        }
        throw FormatLookupException(_context(field), key, value);
      case _AttributeAccess(:final name):
        if (value is Map<Object?, Object?>) {
          if (value.containsKey(name)) return value[name];
          throw FormatLookupException(_context(field), name, value);
        }
        return _resolveAttribute(field, value, name);
    }
  }

  Object? _resolveAttribute(_FieldNode field, Object? value, String name) {
    // The success path must not allocate: the list only materializes once a
    // second lookup accepts the value, which is the ambiguity error itself.
    AttributeLookup<dynamic>? match;
    List<AttributeLookup<dynamic>>? ambiguous;
    for (final lookup in engine.lookups) {
      if (!_canLookup(field, lookup, value)) continue;
      if (match == null) {
        match = lookup;
      } else {
        (ambiguous ??= <AttributeLookup<dynamic>>[match]).add(lookup);
      }
    }
    if (match == null) {
      throw FormatLookupException(_context(field), name, value);
    }
    if (ambiguous != null) {
      throw AmbiguousFormatterException(
        _context(field),
        value,
        ambiguous.map(_extensionName),
      );
    }
    return _lookup(field, match, value, name);
  }

  bool _canLookup(
    _FieldNode field,
    AttributeLookup<dynamic> lookup,
    Object? value,
  ) {
    try {
      return attributeLookupAccepts(lookup, value);
    } on FormattingException {
      rethrow;
    } catch (error, stackTrace) {
      throw FormatExtensionException(
        _context(field),
        _extensionName(lookup),
        error,
        stackTrace,
      );
    }
  }

  Object? _lookup(
    _FieldNode field,
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
        _context(field),
        _extensionName(lookup),
        error,
        stackTrace,
      );
    }
  }

  String _extensionName(AttributeLookup<dynamic> lookup) =>
      lookup.runtimeType.toString();

  // Built at the throw site, never ahead of one: a field that resolves
  // cleanly is the common case, and `{0.a[b].c}` used to pay for four of
  // these before anything could go wrong.
  FormatExceptionContext _context(_FieldNode field) => FormatExceptionContext(
    template: template,
    offset: field.offset,
    fragment: field.fragment,
  );
}
