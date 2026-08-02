part of 'engine.dart';

enum _PrintfFlag { left, sign, space, alternate, zero }

sealed class _PrintfNode {
  final int offset;
  final String fragment;

  const _PrintfNode(this.offset, this.fragment);
}

final class _PrintfTemplate {
  final List<_PrintfNode> nodes;

  _PrintfTemplate(Iterable<_PrintfNode> nodes)
    : nodes = List.unmodifiable(nodes);
}

final class _PrintfLiteralNode extends _PrintfNode {
  final String text;

  const _PrintfLiteralNode(super.offset, super.fragment, this.text);
}

sealed class _PrintfOption {
  const _PrintfOption();
}

final class _LiteralPrintfOption extends _PrintfOption {
  final int value;

  const _LiteralPrintfOption(this.value);
}

final class _DynamicPrintfOption extends _PrintfOption {
  const _DynamicPrintfOption();
}

final class _PrintfConversionNode extends _PrintfNode {
  final Set<_PrintfFlag> flags;
  final _PrintfOption? width;
  final _PrintfOption? precision;
  final String type;

  _PrintfConversionNode({
    required int offset,
    required String fragment,
    required Iterable<_PrintfFlag> flags,
    required this.width,
    required this.precision,
    required this.type,
  }) : flags = Set.unmodifiable(flags),
       super(offset, fragment);
}
