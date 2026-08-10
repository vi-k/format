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

final class _PrintfTemplate implements _PricedTemplate {
  final List<_PrintfNode> nodes;

  _PrintfTemplate(List<_PrintfNode> nodes) : nodes = _sealedInDebug(nodes);

  /// Priced on demand; see [_BraceTemplate.retainedBytes].
  @override
  late final int retainedBytes = _printfRetainedBytes(nodes);

  // Lazily memoized IR programs, one slot per TextUnit. Shared through the
  // template cache; compilation is total and never throws, so a slot is
  // written at most once per unit.
  _PrintfProgram? _scalarProgram;
  _PrintfProgram? _graphemeProgram;

  _PrintfProgram programFor(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars =>
      _scalarProgram ??= _compilePrintfProgram(this, textUnit),
    TextUnit.graphemeClusters =>
      _graphemeProgram ??= _compilePrintfProgram(this, textUnit),
  };
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

  _PrintfConversionNode({
    required int offset,
    required String fragment,
    required this.flags,
    required this.width,
    required this.precision,
    required this.type,
  }) : super(offset, fragment);

  // Lazily memoized resolution and error context for conversions without
  // dynamic `*` options. Nodes are shared through the template cache, and
  // for a static conversion both values are deterministic per node (the
  // argument index only depends on the template), so repeated calls skip
  // the per-call allocations. Dynamic conversions are never memoized.
  _ResolvedPrintfConversion? _staticResolved;
  FormatExceptionContext? _staticContext;

  bool get hasDynamicOptions =>
      width is _DynamicPrintfOption || precision is _DynamicPrintfOption;
}
