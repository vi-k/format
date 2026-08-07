part of 'engine.dart';

const _templateCacheCapacity = 512;

final _braceTemplateCache = _TemplateCache<_BraceTemplate>();
final _printfTemplateCache = _TemplateCache<_PrintfTemplate>();

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
    if (_entries.length >= _templateCacheCapacity) {
      final victim = _victims.nextInt(_keys.length);
      _entries.remove(_keys[victim]);
      _keys[victim] = _keys.last;
      _keys.removeLast();
    }
    _keys.add(template);

    return _entries[template] = parsed;
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
/// `format.dart`.
int debugTemplateCacheCapacity() => _templateCacheCapacity;

int debugBraceTemplateCacheSize() => _braceTemplateCache.length;

int debugPrintfTemplateCacheSize() => _printfTemplateCache.length;

void debugClearTemplateCaches() {
  _braceTemplateCache.clear();
  _printfTemplateCache.clear();
}

Object debugCachedBraceTemplate(String template) =>
    _cachedBraceTemplate(template);

Object debugCachedPrintfTemplate(String template) =>
    _cachedPrintfTemplate(template);
