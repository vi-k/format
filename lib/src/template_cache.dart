part of 'engine.dart';

const _defaultTemplateCacheCapacity = 512;

/// The default memory budget, eight mebibytes of parsed templates per
/// mini-language.
///
/// Chosen against the shapes measured for [templateCacheMemoryLimit]: it holds
/// about 2 Mi characters of ordinary text with a few fields, 110 Ki characters
/// of a template that is nothing but `{}`, and 70 Ki of one that is nothing but
/// `{:d}` — the budget adapts where a count of characters could not. Ordinary
/// workloads
/// never approach it — 512 templates of a hundred characters is under a
/// hundred kibibytes — so it only ever binds on the case that motivated it,
/// where templates come from data and a few of them are enormous.
const _defaultTemplateCacheMemoryLimit = 8 << 20;

int _templateCacheCapacity = _defaultTemplateCacheCapacity;

int _templateCacheMemoryLimit = _defaultTemplateCacheMemoryLimit;

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
/// [templateCacheMemoryLimit], which bounds the other one. Both apply.
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

/// How much memory the parsed templates of each mini-language may hold, eight
/// mebibytes by default.
///
/// A count of entries says nothing about their size, and templates can come
/// from data: a workload with a few very large generated templates stays well
/// inside [templateCacheCapacity] while holding hundreds of megabytes. This is
/// the bound that case runs into. Both bounds apply, and whichever binds first
/// evicts.
///
/// The unit is bytes, and the figure is an **estimate**: memory a Dart program
/// holds cannot be measured from inside it, so an entry is priced by a model of
/// what caching it retains — the template text as the key, the text each
/// literal node slices out of it, the code units prepared for those literals on
/// the VM, and a constant per parse node. The constants are fitted to measured
/// retention (RSS, three hundred to a thousand cached templates of a hundred
/// thousand characters each):
///
/// | template shape | measured | priced |
/// |---|---|---|
/// | text, no fields | 1.4 B/char | 1.0 |
/// | text with a few fields | 4.6 | 4.0 |
/// | `{}` repeated | 74.6 | 76.0 |
/// | `a{}` repeated | 98.0 | 100.0 |
/// | `{:d}` repeated | 118.5 | 120.3 |
/// | printf text, no conversions | 1.4 | 1.0 |
/// | `%d` repeated | 142.0 | 141.0 |
/// | `a%d` repeated | 151.0 | 154.0 |
///
/// The first and sixth rows are the floor of the whole scheme — a template with
/// no field is priced at its key and nothing else, which is exactly what it
/// retains; the 0.4 above it is the slack of measuring by resident set size.
///
/// Two things the price cannot see, both of which make it read low: a template
/// formatted under more than one [TextUnit] compiles a program per unit, and
/// the platform the constants are fitted on is the VM — a web target keeps
/// strings instead of code units and pays differently. Treat the number as a
/// budget with a factor of safety, not as an accounting of the heap.
///
/// An entry priced above the whole budget is formatted but never cached —
/// evicting everything to hold one entry that still cannot fit would be worse
/// than reparsing it. Set the limit to zero to cache nothing, as with
/// [templateCacheCapacity].
///
/// Lowering it discards entries immediately.
int get templateCacheMemoryLimit => _templateCacheMemoryLimit;

set templateCacheMemoryLimit(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'templateCacheMemoryLimit',
      'Must be >= 0.',
    );
  }
  _templateCacheMemoryLimit = value;
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

/// The estimated memory resident templates hold, across both mini-languages,
/// in the same units as [templateCacheMemoryLimit].
///
/// Read with [templateCacheSize], this is what distinguishes a cache full of
/// small templates from one held by a handful of large or field-dense ones —
/// the two need opposite adjustments, and the entry count alone cannot tell
/// them apart.
int get templateCacheMemory =>
    _braceTemplateCache.memory + _printfTemplateCache.memory;

/// Discards every parsed template.
///
/// The next use of each template pays for parsing it again.
void clearTemplateCache() {
  _braceTemplateCache.clear();
  _printfTemplateCache.clear();
}

/// A parsed template that can price what caching it retains.
abstract interface class _PricedTemplate {
  /// Estimated bytes held by caching this template, not counting the key: the
  /// cache adds the key's own length, which it alone knows.
  ///
  /// See [templateCacheMemoryLimit] for the model and what it is fitted to.
  int get retainedBytes;

  /// What the cache last charged for this template, or null while it is not
  /// resident.
  ///
  /// Stored rather than recomputed on eviction because the price can grow
  /// after the entry is stored: compiling a program for a second text unit
  /// adds to it. Recomputing would subtract a number that was never added.
  int? chargedBytes;
}

// The fitted constants. Each stands for one node's worth of objects — the node
// itself, the op compiled from it, the slots both take in their lists, and
// whatever the first call memoizes on it — so they are per node and not per
// character. See the table on templateCacheMemoryLimit.
const _braceLiteralNodeBytes = 144;
const _braceFieldNodeBytes = 150;
const _braceSpecificationBytes = 180;
const _printfLiteralNodeBytes = 176;
const _printfConversionNodeBytes = 280;

/// What a literal's own text costs beyond the key it was sliced from: its
/// string on both platforms, and on the VM the code units prepared next to it.
const _literalTextBytesPerCharacter = _isWeb ? 1 : 3;

/// What a second [TextUnit] adds to an entry already priced, as a percentage
/// of that first price.
///
/// A parsed template is shared by every engine, but a compiled program is not:
/// there is a slot per text unit, and each field memoizes its parsed
/// specification per unit as well. An entry first reached by a scalar engine
/// and later by a grapheme one therefore holds two programs and two specs per
/// field while the constants above priced one of each — the price is fixed
/// when the entry is stored, and the second unit arrives afterwards.
///
/// Measured as the difference between filling a cache under one unit and under
/// both, RSS per entry, minimum of three runs at 60 000 to 300 000 entries:
///
/// | shape | one unit | both | second unit, of priced |
/// |---|---|---|---|
/// | 3 literals, 2 fields, no specifications | 1083 | 1308 | 26% |
/// | 5 literals, 5 fields, no specifications | 1601 | 2252 | 43% |
/// | the same with short specifications | 3104 | 4973 | 59% |
/// | the same with longer specifications | 3281 | 5095 | 56% |
/// | 10 fields, 8 specifications, nested width | 4385 | 6696 | 38% |
///
/// One share rather than a constant per node: an additive fit taken from the
/// five-field shapes predicted 3254 for the dense one against 2311 measured,
/// so the per-node form is not supported by what can be measured here. The
/// share is set at the top of the range instead of its middle because a budget
/// that undercounts is the defect this exists to remove — the same reasoning
/// that prices `%%` as a conversion below.
const _secondTextUnitPercent = 60;

int _secondTextUnitBytes(int firstUnitBytes) =>
    firstUnitBytes * _secondTextUnitPercent ~/ 100;

int _braceRetainedBytes(List<_BraceNode> nodes) {
  // The one shape that slices nothing: a template that is a single literal is
  // its own output, so the node holds the key itself and no units are prepared
  // for it (see _BraceSoleLiteralOp). Everything else is then already paid for
  // by the key.
  //
  // Only the template's own nodes qualify. A specification that is a single
  // literal — the `d` of `{:d}` — is a slice like any other, and pricing it at
  // nothing read a field with a specification thirty per cent low.
  if (nodes case [_LiteralNode()]) return 0;
  return _braceNodesBytes(nodes);
}

int _braceNodesBytes(List<_BraceNode> nodes) {
  var bytes = 0;
  for (final node in nodes) {
    if (node case _LiteralNode(:final text)) {
      bytes +=
          _braceLiteralNodeBytes + text.length * _literalTextBytesPerCharacter;
      continue;
    }
    final field = node as _FieldNode;
    bytes += _braceFieldNodeBytes;
    // A specification is parsed into nodes of its own and its parse is
    // memoized on the field at the first call, which is the larger half of it.
    if (field.specification.isNotEmpty) {
      bytes += _braceSpecificationBytes + _braceNodesBytes(field.specification);
    }
  }
  return bytes;
}

int _printfRetainedBytes(List<_PrintfNode> nodes) {
  if (nodes case [_PrintfLiteralNode()]) return 0;

  var bytes = 0;
  for (final node in nodes) {
    // A `%%` is priced as a conversion although it folds into the literal
    // beside it and memoizes nothing, so the estimate reads high on a template
    // full of escaped percents. That is the safe direction for a budget.
    bytes +=
        node is _PrintfLiteralNode
            ? _printfLiteralNodeBytes +
                node.text.length * _literalTextBytesPerCharacter
            : _printfConversionNodeBytes;
  }
  return bytes;
}

/// A template cache bounded by entries and by memory, evicting a random entry
/// when either bound is reached.
///
/// Random replacement is deliberate. The pathological input for this cache
/// is a working set slightly larger than the capacity, cycled in order: FIFO
/// and LRU both evict precisely the entry needed next and settle at a zero
/// hit rate, so one template past the capacity costs every later call a full
/// reparse. Random replacement keeps roughly capacity/size of such a set
/// resident instead, and it needs no bookkeeping on a hit — which is what
/// keeps a hit cheap.
final class _TemplateCache<T extends _PricedTemplate> {
  final _entries = <String, T>{};

  /// The insertion keys, in no meaningful order: it exists only so that a
  /// victim can be drawn and removed in constant time.
  final _keys = <String>[];

  /// Seeded on purpose: eviction has nothing to hide, and a fixed stream
  /// makes the policy reproducible in tests.
  final _victims = math.Random(0x5eed);

  /// The summed price of every cached entry, maintained on insertion and
  /// eviction rather than recomputed: the alternative is walking the entries on
  /// every store, which is the one place this cache cannot afford to be
  /// linear.
  int _memory = 0;

  int get length => _entries.length;

  int get memory => _memory;

  T? operator [](String template) => _entries[template];

  /// What caching [parsed] under [template] would hold: its own estimate plus
  /// the key, which the entry keeps alive for as long as it is resident.
  static int _price(String template, _PricedTemplate parsed) =>
      template.length + parsed.retainedBytes;

  /// Stores [parsed] under [template], which must not already be cached.
  T store(String template, T parsed) {
    if (_templateCacheCapacity == 0 || _templateCacheMemoryLimit == 0) {
      return parsed;
    }
    final price = _price(template, parsed);
    // An entry that cannot fit even in an empty cache is not cached at all:
    // emptying the cache for one that still exceeds the budget costs every
    // other template its parse and gains nothing.
    if (price > _templateCacheMemoryLimit) return parsed;

    while (_entries.length >= _templateCacheCapacity ||
        _memory + price > _templateCacheMemoryLimit) {
      _evict();
    }
    _keys.add(template);
    _memory += price;
    parsed.chargedBytes = price;

    return _entries[template] = parsed;
  }

  /// Charges [delta] more for [parsed], which has grown since it was stored.
  ///
  /// A no-op for a template the cache does not hold: one evicted while a call
  /// still had it in hand, or one never stored because the caches are off.
  /// Trimming afterwards is what keeps the bound meaningful — the growth can
  /// push the total past the limit, and nothing else would notice.
  void grew(T parsed, int delta) {
    final charged = parsed.chargedBytes;
    if (charged == null || delta == 0) return;
    parsed.chargedBytes = charged + delta;
    _memory += delta;
    trim();
  }

  /// Drops entries until the cache fits bounds that have just shrunk.
  void trim() {
    while (_entries.isNotEmpty &&
        (_entries.length > _templateCacheCapacity ||
            _memory > _templateCacheMemoryLimit)) {
      _evict();
    }
  }

  void _evict() {
    final victim = _victims.nextInt(_keys.length);
    final key = _keys[victim];
    final parsed = _entries.remove(key);
    if (parsed != null) {
      _memory -= parsed.chargedBytes ?? _price(key, parsed);
      parsed.chargedBytes = null;
    }
    _keys[victim] = _keys.last;
    _keys.removeLast();
  }

  void clear() {
    // The entries outlive the cache whenever a call still holds one, and a
    // template that remembers a charge would take the next growth out of a
    // total it is no longer part of.
    for (final parsed in _entries.values) {
      parsed.chargedBytes = null;
    }
    _entries.clear();
    _keys.clear();
    _memory = 0;
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

int debugTemplateCacheMemoryLimit() => _templateCacheMemoryLimit;

int debugBraceTemplateCacheMemory() => _braceTemplateCache.memory;

void debugClearTemplateCaches() {
  templateCacheCapacity = _defaultTemplateCacheCapacity;
  templateCacheMemoryLimit = _defaultTemplateCacheMemoryLimit;
  clearTemplateCache();
}

Object debugCachedBraceTemplate(String template) =>
    _cachedBraceTemplate(template);

Object debugCachedPrintfTemplate(String template) =>
    _cachedPrintfTemplate(template);
