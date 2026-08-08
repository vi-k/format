import 'package:format/format.dart';
import 'package:format16_baseline/format16.dart' as format16;
import 'package:sprintf/sprintf.dart' as sprintf70;

import 'my_benchmark_base.dart';

/// The engine settings the matrix measures format 3.0 under; grapheme
/// clusters, because that is the more expensive text unit and the one the
/// comparators have no equivalent for.
final _format3 = Format(textUnit: TextUnit.graphemeClusters);

/// One formatter the matrix measures, and how to call it.
final class BenchmarkEngine {
  final String name;

  /// Whether this engine reads the printf mini-language rather than braces.
  final bool isSprintf;

  final bool isFormat16;
  final bool isSprintf70;

  /// Whether this engine keeps parsed templates, and so has something to
  /// measure with that turned off.
  final bool hasTemplateCache;

  final String Function(String template, List<Object?> values) format;

  const BenchmarkEngine({
    required this.name,
    required this.isSprintf,
    required this.format,
    this.isFormat16 = false,
    this.isSprintf70 = false,
    this.hasTemplateCache = false,
  });
}

final benchmarkEngines = <BenchmarkEngine>[
  BenchmarkEngine(
    name: 'sprintf 7.0 → sprintf',
    isSprintf: true,
    isSprintf70: true,
    format: sprintf70.sprintf.call,
  ),
  BenchmarkEngine(
    name: 'format 1.6 → format',
    isSprintf: false,
    isFormat16: true,
    format: format16.format,
  ),
  BenchmarkEngine(
    name: 'format 3.0 → format',
    isSprintf: false,
    hasTemplateCache: true,
    format:
        (template, values) => _format3.formatWith(template, positional: values),
  ),
  BenchmarkEngine(
    name: 'format 3.0 → sprintf',
    isSprintf: true,
    hasTemplateCache: true,
    format: _format3.vsprintf,
  ),
];

/// A measurement: one engine, with the template cache on or off.
///
/// Both modes are the same class so that the matrix can run them in any
/// order. Each measurement sets the cache mode it needs and puts back
/// whatever it found, rather than assuming what came before it or what comes
/// after — the capacity is global, so anything else would make the result
/// depend on the order the list happened to be in.
final class FormatterBenchmark extends MyBenchmarkBase {
  final BenchmarkEngine engine;

  /// False to measure with the template cache switched off, so every call
  /// parses the template again — the same work a template never seen before
  /// costs, which is what an engine without a cache does every time.
  final bool cached;

  int? _restoreCapacity;

  FormatterBenchmark(this.engine, {this.cached = true})
    : super(name: cached ? engine.name : '${engine.name} (no cache)');

  @override
  bool get isSprintf => engine.isSprintf;

  @override
  bool get isFormat16 => engine.isFormat16;

  @override
  bool get isSprintf70 => engine.isSprintf70;

  @override
  void setup() {
    _restoreCapacity = templateCacheCapacity;
    // Zero discards what is cached and keeps nothing; the default puts a
    // cache back in play for a warm measurement. Set either way, so a
    // measurement never inherits the mode another one left behind.
    templateCacheCapacity = cached ? _defaultCapacity : 0;
  }

  @override
  void teardown() {
    templateCacheCapacity = _restoreCapacity!;
  }

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = engine.format(template, values);
    }
  }
}

/// The package's own default, restated here because the benchmark sets the
/// capacity explicitly and needs a value to set it back to.
const int _defaultCapacity = 512;
