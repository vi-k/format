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
}
