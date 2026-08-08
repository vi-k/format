// The template cache: that it is transparent, and that its policy holds.
//
// Parsed templates are kept in a process-wide, bounded cache, which is the
// single largest reason repeated formatting is fast. Being a cache, the one
// thing it must never do is change an answer — so half of this file is the
// boring half: the same call twice, a dynamic width twice with different
// values, a failing template twice. Each of those is a way a cached node could
// leak state from one call into the next, and each failure mode is silent and
// data-dependent, which is exactly the kind that reaches production.
//
// The other half is the policy, tested through debug seams rather than through
// timing. Two properties are pinned deliberately: overflow evicts one entry
// rather than clearing the cache, and the replacement is random rather than
// FIFO or LRU — with the cyclic-working-set test that explains why, since that
// is the input on which the obvious policies degrade to a zero hit rate.
//
// The cache is global state, so every test starts from
// `debugClearTemplateCaches` and some deliberately move
// `templateCacheCapacity`. That also makes the import below load-bearing rather
// than stylistic.
//
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

  // The cache exists at all, in both dialects, and it is keyed by the template
  // text: the same string twice yields the same object, and the size confirms
  // one entry rather than two identical ones.
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

  // What overflow costs. Filling to capacity and adding one more must leave the
  // cache full — the earlier implementation cleared it wholesale, which meant a
  // single unusual template threw away every warm entry an application had.
  // Both dialects have their own cache and their own overflow path.
  test('overflowing the capacity evicts exactly one entry at a time', () {
    final capacity = engine.debugTemplateCacheCapacity();
    for (var index = 0; index < capacity; index++) {
      engine.debugCachedBraceTemplate('unique $index {}');
      engine.debugCachedPrintfTemplate('unique $index %d');
    }
    expect(engine.debugBraceTemplateCacheSize(), capacity);
    expect(engine.debugPrintfTemplateCacheSize(), capacity);

    engine.debugCachedBraceTemplate('overflow {}');
    engine.debugCachedPrintfTemplate('overflow %d');

    // The cache stays full rather than being flushed wholesale: a burst of
    // one-off templates costs one warm entry each, not the whole set.
    expect(engine.debugBraceTemplateCacheSize(), capacity);
    expect(engine.debugPrintfTemplateCacheSize(), capacity);
  });

  test('a working set just past the capacity keeps most of its entries', () {
    // The regression this pins: under FIFO (or LRU) a cyclic working set one
    // template larger than the cache evicts precisely the entry needed next,
    // so every single call reparses. Random replacement must not do that.
    final capacity = engine.debugTemplateCacheCapacity();
    final templates = [
      for (var index = 0; index <= capacity; index++) 'cyclic $index {}',
    ];
    // The first lap fills the cache; an entry that survives a later lap
    // comes back as the same instance, an evicted one comes back reparsed.
    final previous = {
      for (final template in templates)
        template: engine.debugCachedBraceTemplate(template),
    };

    var hits = 0;
    var lookups = 0;
    for (var lap = 0; lap < 4; lap++) {
      for (final template in templates) {
        final current = engine.debugCachedBraceTemplate(template);
        lookups++;
        if (identical(current, previous[template])) hits++;
        previous[template] = current;
      }
    }

    // FIFO scores exactly zero here. The bar is deliberately far below what
    // random replacement actually achieves, so the test pins the policy
    // rather than a particular random stream.
    expect(hits, greaterThan(lookups ~/ 2));
  });

  // The capacity is a knob an application can turn, so lowering it has to take
  // effect immediately rather than at the next eviction — otherwise a program
  // reducing it to bound its memory would keep the old entries indefinitely on
  // an idle cache. The negative value is rejected outright: there is no reading
  // of "capacity −1" that makes sense, and clamping it silently would hide the
  // caller's bug.
  test('the capacity is public, and lowering it discards entries now', () {
    for (var index = 0; index < 40; index++) {
      engine.format('sized $index {}', 1);
    }
    expect(engine.templateCacheSize, 40);

    engine.templateCacheCapacity = 10;
    expect(engine.templateCacheCapacity, 10);
    expect(
      engine.templateCacheSize,
      10,
      reason: 'a smaller capacity has to take effect before the next call',
    );

    engine.format('sized fresh {}', 1);
    expect(engine.templateCacheSize, 10, reason: 'and has to hold');
    expect(() => engine.templateCacheCapacity = -1, throwsArgumentError);
  });

  test('a zero capacity formats without keeping anything', () {
    engine.templateCacheCapacity = 0;

    // Templates that never repeat only pay to be evicted, so a workload made
    // of them must be able to opt out rather than churn the cache.
    expect(engine.format('zero {}', 7), 'zero 7');
    expect(engine.sprintf('%d zero', 7), '7 zero');
    expect(engine.format('zero {}', 8), 'zero 8');
    expect(engine.templateCacheSize, 0);
  });

  // `templateCacheSize` counts both dialects together and `clearTemplateCache`
  // empties both — one number and one call, because the split between them is
  // an implementation detail an application should not have to know about.
  // Formatting after a clear still works, which is the part that would break if
  // clearing left a stale index behind.
  test('clearing is public and counted across both mini-languages', () {
    engine.format('counted {}', 1);
    engine.sprintf('%d counted', 1);
    expect(engine.templateCacheSize, 2);

    engine.clearTemplateCache();
    expect(engine.templateCacheSize, 0);
    expect(engine.format('counted {}', 1), 'counted 1');
    expect(engine.templateCacheSize, 1);
  });

  // A template that does not parse produces nothing to cache, and must not
  // occupy an entry: a program logging with a broken format string in a loop
  // would otherwise evict its whole working set to store failures. It also has
  // to fail identically the second time, rather than hit a poisoned entry.
  test('does not cache templates that fail to parse', () {
    expect(() => engine.format('{:d', 1), throwsA(isA<FormattingException>()));
    expect(() => engine.format('{:d', 1), throwsA(isA<FormattingException>()));
    expect(engine.debugBraceTemplateCacheSize(), 0);
  });

  // The public entry points populate the same caches the seams observe — the
  // cache is not something only the debug path reaches — and the second call
  // through a warm entry produces the same string as the first.
  test('formats through the cache on repeated calls', () {
    expect(engine.format('{:10d}', 1), '         1');
    expect(engine.format('{:10d}', 1), '         1');
    expect(engine.debugBraceTemplateCacheSize(), 1);
    expect(engine.sprintf('%10d', 1), '         1');
    expect(engine.sprintf('%10d', 1), '         1');
    expect(engine.debugPrintfTemplateCacheSize(), 1);
  });

  // The subtle one. A parsed specification is memoized inside the shared cached
  // node, but its meaning depends on the `Format` that uses it — so the memo
  // has to be per text unit, not one slot for the template. Two differently
  // configured instances use the same template here, alternating, and each must
  // keep getting its own answer: valid for graphemes, rejected for scalars.
  // One shared slot would make the result depend on which instance formatted
  // first.
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

  // A nested width is part of the *values*, not of the template, so it cannot
  // be memoized into the shared node. Two calls with different widths through
  // one cached template: caching the first resolution would silently format
  // every later call at the wrong width.
  test('resolves dynamic specifications on every call', () {
    expect(engine.format('{:{}d}', 42, 6), '    42');
    expect(engine.format('{:{}d}', 42, 8), '      42');
  });

  // The printf side of the same question. Everything in `%+08.2f` is static and
  // may be memoized — but the sign is not: the second call passes a negative
  // value through the same cached conversion and must get `-`, not the `+`
  // computed the first time.
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

  // The template here is perfectly valid and does get cached; it is the value
  // that is wrong. So the failure has to be re-derived on every call rather
  // than remembered against the entry — and, symmetrically, a bad value must
  // not poison a template that will be used correctly a moment later.
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

  // `{:.d}` parses as a template and fails when the specification is
  // interpreted, which is the one failure that happens *inside* a cacheable
  // node. It still has to be raised on every call: memoizing "this was fine"
  // after a throw, or short-circuiting to a half-built specification, would
  // make the second call disagree with the first.
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
