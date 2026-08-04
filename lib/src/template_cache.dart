part of 'engine.dart';

const _templateCacheCapacity = 512;

final _braceTemplateCache = <String, _BraceTemplate>{};
final _printfTemplateCache = <String, _PrintfTemplate>{};

_BraceTemplate _cachedBraceTemplate(String template) {
  final cached = _braceTemplateCache[template];
  if (cached != null) return cached;
  if (_braceTemplateCache.length >= _templateCacheCapacity) {
    _braceTemplateCache.clear();
  }
  return _braceTemplateCache[template] = _parseBraceTemplate(template);
}

_PrintfTemplate _cachedPrintfTemplate(String template) {
  final cached = _printfTemplateCache[template];
  if (cached != null) return cached;
  if (_printfTemplateCache.length >= _templateCacheCapacity) {
    _printfTemplateCache.clear();
  }
  return _printfTemplateCache[template] = _parsePrintfTemplate(template);
}

/// Test seams for the template cache. They are deliberately not exported by
/// `format.dart`.
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
