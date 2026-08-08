part of 'engine.dart';

const _defaultTemplateCacheCapacity = 512;

/// The default character budget, about 5.7 MiB of retained memory.
///
/// A cached entry costs roughly 5.5 bytes per character of its template: the
/// text is reachable from the key, from the node fragments, from the literal
/// nodes and from the compiled literal ops. Ordinary workloads never approach
/// this — 512 templates of a hundred characters is fifty thousand — so the
/// budget only ever binds on the case that motivated it, where a few templates
/// are enormous.
const _defaultTemplateCacheCharacterLimit = 1 << 20;

int _templateCacheCapacity = _defaultTemplateCacheCapacity;

int _templateCacheCharacterLimit = _defaultTemplateCacheCharacterLimit;

final _braceTemplateCache = _TemplateCache<_BraceTemplate>();
final _printfTemplateCache = _TemplateCache<_PrintfTemplate>();

/// How many parsed templates each mini-language keeps, 512 by default.
///
/// Parsing a template costs far more than formatting with one already
/// parsed — around three quarters of a first call — so the cache is what
/// makes repeated formatting cheap. It is bounded because templates can come
/// from data, and an unbounded cache would then be an unbounded leak.
///
/// Raise it when the working set is larger than the default and templates
/// repeat; a set that cycles past the capacity keeps roughly
/// `capacity / size` of itself resident. Set it to zero when templates are
/// generated and never repeat: caching them only pays to evict them.
///
/// This is a bound on entries, not on memory: see
/// [templateCacheCharacterLimit], which bounds the other one. Both apply.
///
/// Lowering it discards entries immediately. The caches are per isolate, and
/// shared by every [Format] instance, which is safe because a parsed template
/// does not depend on the engine that parsed it.
int get templateCacheCapacity => _templateCacheCapacity;

set templateCacheCapacity(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'templateCacheCapacity', 'Must be >= 0.');
  }
  _templateCacheCapacity = value;
  _braceTemplateCache.trim();
  _printfTemplateCache.trim();
}

/// How much template text each mini-language keeps, about a million
/// characters by default.
///
/// A count of entries says nothing about their size, and templates can come
/// from data: a workload with a few very large generated templates stays well
/// inside [templateCacheCapacity] while holding hundreds of megabytes. This is
/// the bound that case runs into. Both bounds apply, and whichever binds first
/// evicts.
///
/// The unit is characters of template text, which is what a caller can see;
/// the memory a cached entry actually holds is around 5.5 times that, since
/// the text is reachable from the key, the fragments, the literal nodes and
/// the compiled literal ops. The default is therefore about 5.7 MiB.
///
/// A template longer than the whole budget is formatted but never cached —
/// evicting the entire cache to hold one entry that cannot fit would be worse
/// than reparsing it. Set the limit to zero to cache nothing, as with
/// [templateCacheCapacity].
///
/// Lowering it discards entries immediately.
int get templateCacheCharacterLimit => _templateCacheCharacterLimit;

set templateCacheCharacterLimit(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'templateCacheCharacterLimit',
      'Must be >= 0.',
    );
  }
  _templateCacheCharacterLimit = value;
  _braceTemplateCache.trim();
  _printfTemplateCache.trim();
}

/// How many parsed templates are resident, across both mini-languages.
///
/// Useful for telling "the cache is too small for this workload" from "this
/// workload never repeats a template", which otherwise look alike from the
/// outside.
int get templateCacheSize =>
    _braceTemplateCache.length + _printfTemplateCache.length;

/// How much template text is resident, across both mini-languages.
///
/// Read with [templateCacheSize], this is what distinguishes a cache full of
/// small templates from one held by a handful of large ones — the two need
/// opposite adjustments, and the entry count alone cannot tell them apart.
int get templateCacheCharacters =>
    _braceTemplateCache.characters + _printfTemplateCache.characters;

/// Discards every parsed template.
///
/// The next use of each template pays for parsing it again.
void clearTemplateCache() {
  _braceTemplateCache.clear();
  _printfTemplateCache.clear();
}

/// A template cache bounded by entries and by characters, evicting a random
/// entry when either bound is reached.
///
/// Random replacement is deliberate. The pathological input for this cache
/// is a working set slightly larger than the capacity, cycled in order: FIFO
/// and LRU both evict precisely the entry needed next and settle at a zero
/// hit rate, so one template past the capacity costs every later call a full
/// reparse. Random replacement keeps roughly capacity/size of such a set
/// resident instead, and it needs no bookkeeping on a hit — which is what
/// keeps a hit cheap.
final class _TemplateCache<T extends Object> {
  final _entries = <String, T>{};

  /// The insertion keys, in no meaningful order: it exists only so that a
  /// victim can be drawn and removed in constant time.
  final _keys = <String>[];

  /// Seeded on purpose: eviction has nothing to hide, and a fixed stream
  /// makes the policy reproducible in tests.
  final _victims = math.Random(0x5eed);

  /// The summed length of every cached template, maintained on insertion and
  /// eviction rather than recomputed: the alternative is walking the keys on
  /// every store, which is the one place this cache cannot afford to be
  /// linear.
  int _characters = 0;

  int get length => _entries.length;

  int get characters => _characters;

  T? operator [](String template) => _entries[template];

  /// Stores [parsed] under [template], which must not already be cached.
  T store(String template, T parsed) {
    if (_templateCacheCapacity == 0 || _templateCacheCharacterLimit == 0) {
      return parsed;
    }
    // A template that cannot fit even in an empty cache is not cached at all:
    // emptying the cache for one entry that still exceeds the budget costs
    // every other template its parse and gains nothing.
    if (template.length > _templateCacheCharacterLimit) return parsed;

    while (_entries.length >= _templateCacheCapacity ||
        _characters + template.length > _templateCacheCharacterLimit) {
      _evict();
    }
    _keys.add(template);
    _characters += template.length;

    return _entries[template] = parsed;
  }

  /// Drops entries until the cache fits bounds that have just shrunk.
  void trim() {
    while (_entries.isNotEmpty &&
        (_entries.length > _templateCacheCapacity ||
            _characters > _templateCacheCharacterLimit)) {
      _evict();
    }
  }

  void _evict() {
    final victim = _victims.nextInt(_keys.length);
    final key = _keys[victim];
    _entries.remove(key);
    _characters -= key.length;
    _keys[victim] = _keys.last;
    _keys.removeLast();
  }

  void clear() {
    _entries.clear();
    _keys.clear();
    _characters = 0;
  }
}

_BraceTemplate _cachedBraceTemplate(String template) {
  final cached = _braceTemplateCache[template];
  if (cached != null) return cached;

  // A failed parse below never reaches the store, so it evicts nothing.
  return _braceTemplateCache.store(template, _parseBraceTemplate(template));
}

_PrintfTemplate _cachedPrintfTemplate(String template) {
  final cached = _printfTemplateCache[template];
  if (cached != null) return cached;

  return _printfTemplateCache.store(template, _parsePrintfTemplate(template));
}

/// Test seams for the template cache. They are deliberately not exported by
/// `format.dart`; the capacity, total size, and clearing are public API.
int debugTemplateCacheCapacity() => _templateCacheCapacity;

int debugBraceTemplateCacheSize() => _braceTemplateCache.length;

int debugPrintfTemplateCacheSize() => _printfTemplateCache.length;

int debugTemplateCacheCharacterLimit() => _templateCacheCharacterLimit;

int debugBraceTemplateCacheCharacters() => _braceTemplateCache.characters;

void debugClearTemplateCaches() {
  templateCacheCapacity = _defaultTemplateCacheCapacity;
  templateCacheCharacterLimit = _defaultTemplateCacheCharacterLimit;
  clearTemplateCache();
}

Object debugCachedBraceTemplate(String template) =>
    _cachedBraceTemplate(template);

Object debugCachedPrintfTemplate(String template) =>
    _cachedPrintfTemplate(template);
