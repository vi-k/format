import 'package:test/test.dart';

// The engine is imported ONLY via this relative URI: mixing it with
// package:format imports would create two library instances with two
// independent template caches, and the seams would observe the wrong one.
// ignore: avoid_relative_lib_imports
import '../lib/src/engine.dart' as engine;
// ignore: avoid_relative_lib_imports
import '../lib/src/errors.dart';

void main() {
  setUp(engine.debugClearTemplateCaches);

  test('returns identical ASTs for repeated templates', () {
    final brace1 = engine.debugCachedBraceTemplate('{:10d} x');
    final brace2 = engine.debugCachedBraceTemplate('{:10d} x');
    expect(identical(brace1, brace2), isTrue);

    final printf1 = engine.debugCachedPrintfTemplate('%10d x');
    final printf2 = engine.debugCachedPrintfTemplate('%10d x');
    expect(identical(printf1, printf2), isTrue);

    expect(engine.debugBraceTemplateCacheSize(), 1);
    expect(engine.debugPrintfTemplateCacheSize(), 1);
  });

  test('clears the cache when capacity overflows', () {
    for (var index = 0; index < 512; index++) {
      engine.debugCachedBraceTemplate('unique $index {}');
    }
    expect(engine.debugBraceTemplateCacheSize(), 512);
    engine.debugCachedBraceTemplate('overflow {}');
    expect(engine.debugBraceTemplateCacheSize(), 1);
  });

  test('does not cache templates that fail to parse', () {
    expect(
      () => engine.format('{:d', 1),
      throwsA(isA<FormattingException>()),
    );
    expect(
      () => engine.format('{:d', 1),
      throwsA(isA<FormattingException>()),
    );
    expect(engine.debugBraceTemplateCacheSize(), 0);
  });

  test('formats through the cache on repeated calls', () {
    expect(engine.format('{:10d}', 1), '         1');
    expect(engine.format('{:10d}', 1), '         1');
    expect(engine.debugBraceTemplateCacheSize(), 1);
    expect(engine.sprintf('%10d', 1), '         1');
    expect(engine.sprintf('%10d', 1), '         1');
    expect(engine.debugPrintfTemplateCacheSize(), 1);
  });
}
