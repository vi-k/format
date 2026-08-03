import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/src/engine.dart' as engine;

void main() {
  test('recognizes only single ASCII built-in format specifications', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('d'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('%'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('10d'), isFalse);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('é'), isFalse);
  });

  test('recognizes fixed double precision without Unicode tokenization', () {
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.0f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2f'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.20F'), isTrue);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.f'), isFalse);
    expect(engine.debugUsesSimpleBuiltinFormatSpec('.2g'), isFalse);
  });
}
