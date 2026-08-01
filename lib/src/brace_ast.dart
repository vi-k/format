part of 'engine.dart';

sealed class _BraceNode {
  final int offset;
  final String fragment;

  const _BraceNode(this.offset, this.fragment);
}

final class _BraceTemplate {
  final List<_BraceNode> nodes;

  _BraceTemplate(Iterable<_BraceNode> nodes) : nodes = List.unmodifiable(nodes);
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
    required Iterable<_FieldAccess> accesses,
    required this.conversion,
    required Iterable<_BraceNode> specification,
  }) : accesses = List.unmodifiable(accesses),
       specification = List.unmodifiable(specification),
       super(offset, fragment);
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
