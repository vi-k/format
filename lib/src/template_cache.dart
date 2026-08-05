part of 'engine.dart';

const _templateCacheCapacity = 512;

final _braceTemplateCache = <String, _BraceTemplate>{};
final _printfTemplateCache = <String, _PrintfTemplate>{};

_BraceTemplate _cachedBraceTemplate(String template) {
  final cached = _braceTemplateCache[template];
  if (cached != null) return cached;
  final parsed = _parseBraceTemplate(template);
  if (_braceTemplateCache.length >= _templateCacheCapacity) {
    // Evict the oldest insertion instead of clearing wholesale: a burst
    // of one-off templates must not flush the warm working set at once.
    // Hits stay free of bookkeeping; a failed parse above evicts nothing.
    _braceTemplateCache.remove(_braceTemplateCache.keys.first);
  }
  return _braceTemplateCache[template] = parsed;
}

_PrintfTemplate _cachedPrintfTemplate(String template) {
  final cached = _printfTemplateCache[template];
  if (cached != null) return cached;
  final parsed = _parsePrintfTemplate(template);
  if (_printfTemplateCache.length >= _templateCacheCapacity) {
    _printfTemplateCache.remove(_printfTemplateCache.keys.first);
  }
  return _printfTemplateCache[template] = parsed;
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
