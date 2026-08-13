/// The template cache: that it is transparent, and that its policy holds.
///
/// Parsed templates are kept in a process-wide, bounded cache, which is the
/// single largest reason repeated formatting is fast. Being a cache, the one
/// thing it must never do is change an answer — so half of this file is the
/// boring half: the same call twice, a dynamic width twice with different
/// values, a failing template twice. Each of those is a way a cached node could
/// leak state from one call into the next, and each failure mode is silent and
/// data-dependent, which is exactly the kind that reaches production.
///
/// The other half is the policy, tested through debug seams rather than through
/// timing. Two properties are pinned deliberately: overflow evicts one entry
/// rather than clearing the cache, and the replacement is random rather than
/// FIFO or LRU — with the cyclic-working-set test that explains why, since that
/// is the input on which the obvious policies degrade to a zero hit rate.
///
/// The cache is global state, so every test starts from
/// [engine.debugClearTemplateCaches] and some deliberately move
/// [engine.templateCacheCapacity]. That also makes the import below
/// load-bearing rather than stylistic.
///
/// The engine is imported via its package URI: this is the same canonical
/// library instance the public package:format export resolves to, so the debug
/// seams observe the same static template caches that format() and sprintf()
/// populate. A relative ../lib/src import would create a second library
/// instance with its own independent caches and types.
library;

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

  // A set that does not fit is the one case where the cache cannot win: the
  // entry is gone before the workload returns to it, so every call pays a
  // miss, a parse, a store and an eviction, and receives nothing back. The
  // policy is to notice that and stop paying — measured on the cold path at
  // 600 ns per call down to 250 under dart2js.
  //
  // Observed through identity rather than through the size: while the cache
  // is not consulted, the same template parsed twice gives two objects, and
  // that is exactly what "not cached" means from the outside.
  test('a workload that never repeats stops being cached', () {
    engine.templateCacheCapacity = 64;
    for (var index = 0; index < 200; index++) {
      engine.debugCachedBraceTemplate('never repeated $index {}');
    }

    expect(
      identical(
        engine.debugCachedBraceTemplate('probe {}'),
        engine.debugCachedBraceTemplate('probe {}'),
      ),
      isFalse,
    );
    // What was already parsed stays: nothing is discarded, it is only left
    // alone, so the memory the caller allowed is still accounted for.
    expect(engine.debugBraceTemplateCacheSize(), 64);
  });

  // The shape the memory bound exists for, and the one the policy could not
  // see until 2026-08-13: a few templates each too large to cache at all. Such
  // a call misses, declines to store, and evicts nothing — so a policy counting
  // only evictions never reached its threshold, and kept consulting a cache
  // that could not possibly answer. The miss is not free: it hashes the whole
  // freshly built key, and these keys are the longest there are.
  test('templates too large to cache at all stop being looked up', () {
    engine.templateCacheCapacity = 64;
    engine.templateCacheMemoryLimit = 200;
    for (var index = 0; index < 200; index++) {
      engine.debugCachedBraceTemplate(
        '${'far past the budget ' * 20}$index {}',
      );
    }

    // Nothing was ever stored, and the cache has stopped being asked. The
    // probe is a template with no fields on purpose: it is priced at its key
    // alone, so it fits the budget the oversized ones blew, and its identity
    // therefore says whether the cache is being consulted rather than whether
    // it can afford the answer.
    expect(engine.debugBraceTemplateCacheSize(), 0);
    expect(
      identical(
        engine.debugCachedBraceTemplate('probe'),
        engine.debugCachedBraceTemplate('probe'),
      ),
      isFalse,
    );
  });

  // The trap this pins: an empty cache filling up is all misses too. Counting
  // misses alone would write off every large working set on its first lap,
  // including the cyclic one two tests above, which does hit and does profit.
  // Only a miss that had to evict is evidence, and a fill evicts nothing.
  test('filling the cache is not mistaken for a set that does not fit', () {
    engine.templateCacheCapacity = 64;
    for (var index = 0; index < 64; index++) {
      engine.debugCachedBraceTemplate('fills $index {}');
    }

    expect(
      identical(
        engine.debugCachedBraceTemplate('after the fill {}'),
        engine.debugCachedBraceTemplate('after the fill {}'),
      ),
      isTrue,
    );
  });

  // Stopping has to be revocable, or a burst of one-off templates would cost
  // a program its cache for the rest of the process. The interval is not
  // asserted, only that there is one: the loop runs until the cache answers
  // again, and fails by timing out at a bound far above it.
  test('a workload that turns repetitive is cached again', () {
    engine.templateCacheCapacity = 64;
    for (var index = 0; index < 200; index++) {
      engine.debugCachedBraceTemplate('never repeated $index {}');
    }

    var previous = engine.debugCachedBraceTemplate('now repeating {}');
    var cachedAgain = false;
    for (var index = 0; index < 40000 && !cachedAgain; index++) {
      final current = engine.debugCachedBraceTemplate('now repeating {}');
      cachedAgain = identical(current, previous);
      previous = current;
    }

    expect(cachedAgain, isTrue);
  });

  // Emptying the cache is a caller saying the workload has changed, and the
  // policy has to take that at face value rather than make them wait out the
  // interval.
  test('emptying the cache makes the policy ask again at once', () {
    engine.templateCacheCapacity = 64;
    for (var index = 0; index < 200; index++) {
      engine.debugCachedBraceTemplate('never repeated $index {}');
    }
    engine.clearTemplateCache();

    expect(
      identical(
        engine.debugCachedBraceTemplate('after clearing {}'),
        engine.debugCachedBraceTemplate('after clearing {}'),
      ),
      isTrue,
    );
  });

  // The two mini-languages have their own caches and decide separately: a
  // program generating brace templates from data while formatting printf ones
  // from literals must not lose the cache it is profiting from.
  test('each mini-language decides for itself', () {
    engine.templateCacheCapacity = 64;
    for (var index = 0; index < 200; index++) {
      engine.debugCachedBraceTemplate('never repeated $index {}');
    }

    expect(
      identical(
        engine.debugCachedPrintfTemplate('printf stays cached %d'),
        engine.debugCachedPrintfTemplate('printf stays cached %d'),
      ),
      isTrue,
    );
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

  // The memory budget binds where the entry count cannot: five templates is
  // nothing against a capacity of 512, but a budget of 600 bytes holds only two
  // of these at a time. The resident estimate is what says the budget is
  // tracked rather than merely checked once.
  test('the memory budget evicts before the entry count does', () {
    engine.templateCacheMemoryLimit = 600;
    for (var index = 0; index < 5; index++) {
      engine.format('${'x' * 90} $index {}', 1);
    }

    expect(engine.templateCacheSize, lessThan(3));
    expect(engine.templateCacheMemory, lessThanOrEqualTo(600));
    expect(
      engine.templateCacheCapacity,
      greaterThan(engine.templateCacheSize),
      reason: 'the entry count was never the bound that bound',
    );
  });

  // Why the budget is in bytes and not in characters, which is what the caller
  // can count: the same amount of text costs an order of magnitude more when it
  // is fields, because what an entry then holds is a parse node each. Stated as
  // a ratio, since the constants behind it are fitted estimates and the point
  // is the gap, not their values.
  test('a field-dense template is priced far above the same text', () {
    engine.format('x' * 200);
    final text = engine.templateCacheMemory;
    engine.clearTemplateCache();

    engine.formatWith('{}' * 100, positional: List.filled(100, 1));
    expect(engine.templateCacheMemory, greaterThan(text * 10));
  });

  // A template larger than the whole budget cannot be held at any point, so it
  // is formatted and dropped rather than emptying the cache on the way in.
  // Evicting everything for an entry that still would not fit costs every
  // other template its parse and gains nothing.
  test('a template past the whole budget is formatted but not cached', () {
    engine.templateCacheMemoryLimit = 400;
    engine.format('small {}', 1);
    final resident = engine.templateCacheSize;

    expect(engine.format('${'y' * 500} {}', 2), endsWith(' 2'));
    expect(engine.templateCacheSize, resident, reason: 'nothing was evicted');
    expect(engine.templateCacheMemory, lessThanOrEqualTo(400));
  });

  // The budget exists for templates that come from data. This is the other
  // half of that case, and it was open until 2026-08-13: data arriving in the
  // *values*. A specification with a nested field is resolved per call and
  // remembered on the op, which lives as long as the cache entry — while the
  // price model counts the template's own nodes and nothing else. An
  // unbounded memo therefore let a call retain what the entry was never
  // charged for, measured at 154 MiB held against 190 KiB accounted.
  //
  // Observed through a seam rather than through output: a remembered parse
  // and a fresh one produce the same string, so nothing else distinguishes
  // them.
  test('a long resolved specification is not retained by the cache', () {
    const template = '{0:{1}}';
    final graphemes = engine.Format(textUnit: TextUnit.graphemeClusters);
    // One grapheme cluster of five thousand code units, so the specification
    // is enormous and still valid — the only kind that reaches the memo at
    // all, which is filled only after a parse that did not throw.
    final huge = 'a${'́' * 5000}<8';

    graphemes.formatWith(template, positional: ['x', '>8']);
    expect(
      engine.debugMemoizedSpecificationUnits(
        template,
        TextUnit.graphemeClusters,
      ),
      2,
      reason: 'the short specification is worth remembering',
    );

    expect(
      graphemes.formatWith(template, positional: ['x', huge]).length,
      35008,
    );
    expect(
      engine.debugMemoizedSpecificationUnits(
        template,
        TextUnit.graphemeClusters,
      ),
      2,
      reason: 'the huge one was parsed, used and dropped',
    );
  });

  // A parsed template is shared by every engine, but a compiled program is
  // not: there is a slot per text unit, and each field memoizes its parsed
  // specification per unit too. The entry was priced for one unit when it was
  // stored, so an engine of the other unit reaching it later makes the entry
  // outgrow its price — measured at 26% to 59% of it, depending on shape.
  //
  // Left uncharged, the budget stopped bounding what it names: a process
  // formatting the same templates through engines of both units held about
  // half again what the limit allowed, and nothing reported it.
  test('a second text unit is charged to the entry that grew', () {
    final graphemes = engine.Format(textUnit: TextUnit.graphemeClusters);
    const template = 'grew {0:>8,d} {1:^6s} {2:#x}';
    const values = <Object?>[1, 'x', 255];

    engine.formatWith(template, positional: values);
    final oneUnit = engine.templateCacheMemory;
    expect(engine.templateCacheSize, 1);

    graphemes.formatWith(template, positional: values);
    expect(engine.templateCacheSize, 1, reason: 'still one entry');
    expect(engine.templateCacheMemory, greaterThan(oneUnit));

    // Third and later calls compile nothing, so they must charge nothing.
    final bothUnits = engine.templateCacheMemory;
    graphemes.formatWith(template, positional: values);
    engine.formatWith(template, positional: values);
    expect(engine.templateCacheMemory, bothUnits);
  });

  // The growth is added to what the entry was charged, and eviction has to
  // subtract that same number rather than recompute the original price —
  // otherwise the total drifts by the difference on every evicted entry, in
  // the direction that eventually reports a cache holding less than nothing.
  test('growth survives eviction without drifting the total', () {
    final graphemes = engine.Format(textUnit: TextUnit.graphemeClusters);
    for (var index = 0; index < 12; index++) {
      final template = 'drift $index {0:>8,d} {1:^6s}';
      engine.formatWith(template, positional: const [1, 'x']);
      graphemes.formatWith(template, positional: const [1, 'x']);
    }
    expect(engine.templateCacheSize, 12);

    engine.templateCacheCapacity = 3;
    expect(engine.templateCacheSize, 3);
    expect(engine.templateCacheMemory, greaterThan(0));

    engine.templateCacheCapacity = 0;
    expect(engine.templateCacheMemory, 0, reason: 'no residue, no negative');
  });

  // Same contract as the capacity: a lowered bound takes effect at once, not
  // at the next insertion. A program reducing its budget to free memory would
  // otherwise keep everything until it happened to format something else.
  test('lowering the memory limit discards entries now', () {
    for (var index = 0; index < 20; index++) {
      engine.format('budget $index {}', 1);
    }
    expect(engine.templateCacheSize, 20);
    final before = engine.templateCacheMemory;

    engine.templateCacheMemoryLimit = before ~/ 4;
    expect(engine.templateCacheMemory, lessThanOrEqualTo(before ~/ 4));
    expect(engine.templateCacheSize, lessThan(20));
    expect(() => engine.templateCacheMemoryLimit = -1, throwsArgumentError);
  });

  // Zero means "cache nothing", the same way it does for the capacity — and
  // the two opt-outs must not depend on each other.
  test('a zero memory limit keeps nothing while the capacity is ample', () {
    engine.templateCacheMemoryLimit = 0;

    expect(engine.format('zero {}', 7), 'zero 7');
    expect(engine.sprintf('%d zero', 7), '7 zero');
    expect(engine.templateCacheSize, 0);
    expect(engine.templateCacheMemory, 0);
  });

  // The two counters answer different questions — how many templates, and how
  // much memory — and a workload held by a few large templates looks nothing
  // like one holding many small ones. Both count the two mini-languages
  // together, and clearing resets both.
  test('resident memory tracks both mini-languages and clearing', () {
    engine.format('{:10d}', 1);
    final brace = engine.templateCacheMemory;
    engine.sprintf('%10d', 1);

    expect(engine.templateCacheSize, 2);
    expect(
      engine.templateCacheMemory,
      greaterThan(brace),
      reason: 'the printf entry was counted too',
    );
    expect(engine.templateCacheMemory, greaterThan('{:10d}%10d'.length));

    engine.clearTemplateCache();
    expect(engine.templateCacheMemory, 0);
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
    // Back to the first width. What is remembered between calls is the last
    // resolved specification and its parse, so this is the direction that
    // catches a memo which answers from the wrong entry rather than one that
    // never answers at all.
    expect(engine.format('{:{}d}', 42, 6), '    42');
    // A resolution that does not parse has to throw every time it is
    // resolved, and must not displace what the memo holds: the call after it
    // is the one that would silently format at the wrong width.
    expect(
      () => engine.format('{:{}d}', 42, 'wide'),
      throwsA(isA<FormattingException>()),
    );
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
