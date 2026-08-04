// The engine is imported via its package URI: this is the same canonical
// library instance the public package:format export resolves to, so the
// debug seams observe the same static template caches that format() and
// sprintf() populate. A relative ../lib/src import would create a second
// library instance with its own independent caches and types.
import 'package:format/format.dart' show FormattingException, TextUnit;
import 'package:format/src/engine.dart' as engine;
import 'package:test/test.dart';

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

  test('memoizes static specifications per text unit', () {
    final graphemes = engine.Format(textUnit: TextUnit.graphemeClusters);
    final scalars = engine.Format(); // default: TextUnit.unicodeScalars
    // 'e' + combining U+0301: one grapheme cluster but two scalars, so the
    // specification is valid with grapheme fill and invalid with scalars.
    // A precomposed U+00E9 literal would be valid in both modes and could
    // not tell the two memo slots apart.
    const template = '{:e\u0301^6s}';

    expect(graphemes.format(template, 'ab'), 'e\u0301e\u0301abe\u0301e\u0301');
    expect(
      () => scalars.format(template, 'ab'),
      throwsA(isA<FormattingException>()),
    );
    expect(graphemes.format(template, 'ab'), 'e\u0301e\u0301abe\u0301e\u0301');
    expect(
      () => scalars.format(template, 'ab'),
      throwsA(isA<FormattingException>()),
    );
  });

  test('resolves dynamic specifications on every call', () {
    expect(engine.format('{:{}d}', 42, 6), '    42');
    expect(engine.format('{:{}d}', 42, 8), '      42');
  });

  test('printf reuses static conversions across calls', () {
    expect(engine.sprintf('%+08.2f|%s', 3.5, 'x'), '+0003.50|x');
    expect(engine.sprintf('%+08.2f|%s', -3.5, 'y'), '-0003.50|y');
  });

  test('printf dynamic options resolve on every call', () {
    expect(engine.sprintf('%*d', 6, 42), '    42');
    expect(engine.sprintf('%*d', 8, 42), '      42');
    // A negative dynamic width turns on left alignment for THIS call only;
    // the flag must not stick to the shared cached node.
    expect(engine.sprintf('%*d', -6, 42), '42    ');
    expect(engine.sprintf('%*d', 6, 42), '    42');
  });

  test('invalid printf values throw on every call', () {
    expect(
      () => engine.sprintf('%d', 'oops'),
      throwsA(isA<FormattingException>()),
    );
    expect(
      () => engine.sprintf('%d', 'oops'),
      throwsA(isA<FormattingException>()),
    );
  });

  test('invalid static specification throws on every call', () {
    expect(
      () => engine.format('{:.d}', 1),
      throwsA(isA<FormattingException>()),
    );
    expect(
      () => engine.format('{:.d}', 1),
      throwsA(isA<FormattingException>()),
    );
  });
}
