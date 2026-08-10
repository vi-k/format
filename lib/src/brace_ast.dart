part of 'engine.dart';

sealed class _BraceNode {
  const _BraceNode();
}

final class _BraceTemplate implements _PricedTemplate {
  final List<_BraceNode> nodes;

  _BraceTemplate(List<_BraceNode> nodes) : nodes = _sealedInDebug(nodes);

  /// Priced on demand rather than at parse time: with the cache switched off
  /// every call parses, and none of those parses is ever priced.
  @override
  late final int retainedBytes = _braceRetainedBytes(nodes);

  // Lazily memoized IR programs, one slot per TextUnit. Shared through the
  // template cache; compilation is total and never throws, so a slot is
  // written at most once per unit.
  _BraceProgram? _scalarProgram;
  _BraceProgram? _graphemeProgram;

  _BraceProgram programFor(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars =>
      _scalarProgram ??= _compileBraceProgram(this, textUnit),
    TextUnit.graphemeClusters =>
      _graphemeProgram ??= _compileBraceProgram(this, textUnit),
  };
}

/// Returns [list] as-is in production; under asserts it is replaced with an
/// unmodifiable copy so tests can pin that AST collections never mutate.
/// Parsers are the only producers and always hand over freshly built lists,
/// so skipping the per-call defensive copy on the hot path is safe.
List<T> _sealedInDebug<T>(List<T> list) {
  var sealed = list;
  assert(() {
    sealed = List.unmodifiable(list);
    return true;
  }());
  return sealed;
}

final class _LiteralNode extends _BraceNode {
  final String text;

  const _LiteralNode(this.text);
}

final class _FieldNode extends _BraceNode {
  // Only a field ever reports a position: an error names the field it came
  // from, never the literal text around it, so carrying an offset and a
  // fragment on a literal meant slicing the template for nobody to read.
  final int offset;

  /// The template this field was parsed from, kept so that [fragment] can be
  /// sliced when something fails rather than for every field that parses.
  final String _template;
  final int _end;

  /// The field's own text, as it appears in the template.
  String get fragment => _template.substring(offset, _end);

  final _FieldRoot root;
  final List<_FieldAccess> accesses;
  final String? conversion;
  final List<_BraceNode> specification;

  _FieldNode({
    required this.offset,
    required String template,
    required int end,
    required this.root,
    required List<_FieldAccess> accesses,
    required this.conversion,
    required List<_BraceNode> specification,
  }) : _template = template,
       _end = end,
       accesses = _sealedInDebug(accesses),
       specification = _sealedInDebug(specification);

  // Lazily memoized parse of a static specification, one slot per TextUnit.
  // Nodes are shared through the template cache, so the slots make repeated
  // calls skip _parseFormatSpec entirely. Failed parses are never memoized.
  _FormatSpec? _scalarSpec;
  _FormatSpec? _graphemeSpec;

  _FormatSpec? memoizedSpec(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars => _scalarSpec,
    TextUnit.graphemeClusters => _graphemeSpec,
  };

  void memoizeSpec(TextUnit textUnit, _FormatSpec spec) {
    switch (textUnit) {
      case TextUnit.unicodeScalars:
        _scalarSpec = spec;
      case TextUnit.graphemeClusters:
        _graphemeSpec = spec;
    }
  }
}

sealed class _FieldRoot {
  const _FieldRoot();
}

final class _AutomaticRoot extends _FieldRoot {
  const _AutomaticRoot();
}

final class _PositionalRoot extends _FieldRoot {
  final int index;

  const _PositionalRoot(this.index);
}

final class _NamedRoot extends _FieldRoot {
  final String name;

  const _NamedRoot(this.name);
}

sealed class _FieldAccess {
  const _FieldAccess();
}

final class _AttributeAccess extends _FieldAccess {
  final String name;

  const _AttributeAccess(this.name);
}

final class _IntegerItemAccess extends _FieldAccess {
  final int index;

  const _IntegerItemAccess(this.index);
}

final class _StringItemAccess extends _FieldAccess {
  final String key;

  const _StringItemAccess(this.key);
}
