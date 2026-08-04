part of 'engine.dart';

sealed class _BraceNode {
  final int offset;
  final String fragment;

  const _BraceNode(this.offset, this.fragment);
}

final class _BraceTemplate {
  final List<_BraceNode> nodes;

  _BraceTemplate(List<_BraceNode> nodes) : nodes = _sealedInDebug(nodes);
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

  const _LiteralNode(super.offset, super.fragment, this.text);
}

final class _FieldNode extends _BraceNode {
  final _FieldRoot root;
  final List<_FieldAccess> accesses;
  final String? conversion;
  final List<_BraceNode> specification;

  _FieldNode({
    required int offset,
    required String fragment,
    required this.root,
    required List<_FieldAccess> accesses,
    required this.conversion,
    required List<_BraceNode> specification,
  }) : accesses = _sealedInDebug(accesses),
       specification = _sealedInDebug(specification),
       super(offset, fragment);

  // Lazily memoized parse of a static specification, one slot per TextUnit.
  // Nodes are shared through the template cache, so the slots make repeated
  // calls skip parseFormatSpec entirely. Failed parses are never memoized.
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
