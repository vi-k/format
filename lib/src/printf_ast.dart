part of 'engine.dart';

/// Printf flag bits. A conversion's flags travel as one immutable int so the
/// hot path allocates no sets and tests membership with a mask.
abstract final class _PrintfFlags {
  static const int left = 1 << 0;
  static const int sign = 1 << 1;
  static const int space = 1 << 2;
  static const int alternate = 1 << 3;
  static const int zero = 1 << 4;
}

bool _hasPrintfFlag(int flags, int flag) => (flags & flag) != 0;

sealed class _PrintfNode {
  final int offset;
  final String fragment;

  const _PrintfNode(this.offset, this.fragment);
}

final class _PrintfTemplate {
  final List<_PrintfNode> nodes;

  _PrintfTemplate(List<_PrintfNode> nodes) : nodes = _sealedInDebug(nodes);
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
  final int flags;
  final _PrintfOption? width;
  final _PrintfOption? precision;
  final String type;

  const _PrintfConversionNode({
    required int offset,
    required String fragment,
    required this.flags,
    required this.width,
    required this.precision,
    required this.type,
  }) : super(offset, fragment);
}
