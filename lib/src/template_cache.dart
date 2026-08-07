part of 'engine.dart';

const _defaultTemplateCacheCapacity = 512;

int _templateCacheCapacity = _defaultTemplateCacheCapacity;

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

/// How many parsed templates are resident, across both mini-languages.
///
/// Useful for telling "the cache is too small for this workload" from "this
/// workload never repeats a template", which otherwise look alike from the
/// outside.
int get templateCacheSize =>
    _braceTemplateCache.length + _printfTemplateCache.length;

/// Discards every parsed template.
///
/// The next use of each template pays for parsing it again.
void clearTemplateCache() {
  _braceTemplateCache.clear();
  _printfTemplateCache.clear();
}

/// A bounded template cache that evicts a random entry when it is full.
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

  int get length => _entries.length;

  T? operator [](String template) => _entries[template];

  /// Stores [parsed] under [template], which must not already be cached.
  T store(String template, T parsed) {
    if (_templateCacheCapacity == 0) return parsed;
    while (_entries.length >= _templateCacheCapacity) {
      _evict();
    }
    _keys.add(template);

    return _entries[template] = parsed;
  }

  /// Drops entries until the cache fits a capacity that has just shrunk.
  void trim() {
    while (_entries.length > _templateCacheCapacity) {
      _evict();
    }
  }

  void _evict() {
    final victim = _victims.nextInt(_keys.length);
    _entries.remove(_keys[victim]);
    _keys[victim] = _keys.last;
    _keys.removeLast();
  }

  void clear() {
    _entries.clear();
    _keys.clear();
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

void debugClearTemplateCaches() {
  templateCacheCapacity = _defaultTemplateCacheCapacity;
  clearTemplateCache();
}

Object debugCachedBraceTemplate(String template) =>
    _cachedBraceTemplate(template);

Object debugCachedPrintfTemplate(String template) =>
    _cachedPrintfTemplate(template);
