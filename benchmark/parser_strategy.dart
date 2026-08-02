import 'dart:convert';
import 'dart:math';

import 'src/parser_platform.dart';

const parserCorpus = <String>[
  'literal only',
  '%d',
  '%+08.3f',
  '%-*.*s',
  '%#x %d %s %.17g',
  r'%% %1$d %llx %b %',
];

typedef ParserToken = ({
  int offset,
  String fragment,
  String flags,
  String? width,
  String? precision,
  String type,
});

enum ParseErrorCategory { invalidConversion }

typedef ParserOutcome = ({List<ParserToken> tokens, ParseErrorCategory? error});

typedef ParserCandidate = ParserOutcome Function(String format);

// regexp-source-start
final _regexpConversion = RegExp(
  r'%(?:(\d+)\$)?([+\-#0 ]*)(\d+|\*)?(?:\.(\d+|\*))?([diouxXfFeEgGs%])',
);

ParserOutcome parseRegexp(String format) {
  final tokens = <ParserToken>[];
  var offset = 0;
  while (offset < format.length) {
    if (format.codeUnitAt(offset) != 0x25) {
      offset++;
      continue;
    }
    final match = _regexpConversion.matchAsPrefix(format, offset);
    if (match == null) {
      return _invalidOutcome;
    }
    if (match.group(5) == '%' &&
        (match.group(1) != null ||
            match.group(2)!.isNotEmpty ||
            match.group(3) != null ||
            match.group(4) != null)) {
      return _invalidOutcome;
    }
    tokens.add((
      offset: offset,
      fragment: match.group(0)!,
      flags: match.group(2)!,
      width: match.group(3),
      precision: match.group(4),
      type: match.group(5)!,
    ));
    offset = match.end;
  }
  return (tokens: List.unmodifiable(tokens), error: null);
}
// regexp-source-end

// scanner-source-start
ParserOutcome parseScanner(String format) {
  final tokens = <ParserToken>[];
  var offset = 0;
  while (offset < format.length) {
    if (format.codeUnitAt(offset) != 0x25) {
      offset++;
      continue;
    }
    final start = offset++;
    if (offset == format.length) {
      return _invalidOutcome;
    }

    var hasParameter = false;
    final digitsStart = offset;
    while (offset < format.length && _isDigit(format.codeUnitAt(offset))) {
      offset++;
    }
    if (offset > digitsStart &&
        offset < format.length &&
        format.codeUnitAt(offset) == 0x24) {
      hasParameter = true;
      offset++;
    } else {
      offset = digitsStart;
    }

    final flagsStart = offset;
    while (offset < format.length && _isFlag(format.codeUnitAt(offset))) {
      offset++;
    }
    final flags = format.substring(flagsStart, offset);

    String? width;
    if (offset < format.length && format.codeUnitAt(offset) == 0x2a) {
      width = '*';
      offset++;
    } else {
      final widthStart = offset;
      while (offset < format.length && _isDigit(format.codeUnitAt(offset))) {
        offset++;
      }
      if (offset > widthStart) {
        width = format.substring(widthStart, offset);
      }
    }

    String? precision;
    if (offset < format.length && format.codeUnitAt(offset) == 0x2e) {
      offset++;
      if (offset < format.length && format.codeUnitAt(offset) == 0x2a) {
        precision = '*';
        offset++;
      } else {
        final precisionStart = offset;
        while (offset < format.length && _isDigit(format.codeUnitAt(offset))) {
          offset++;
        }
        if (offset == precisionStart) {
          return _invalidOutcome;
        }
        precision = format.substring(precisionStart, offset);
      }
    }

    if (offset == format.length || !_isType(format.codeUnitAt(offset))) {
      return _invalidOutcome;
    }
    final type = format[offset++];
    if (type == '%' &&
        (hasParameter ||
            flags.isNotEmpty ||
            width != null ||
            precision != null)) {
      return _invalidOutcome;
    }
    tokens.add((
      offset: start,
      fragment: format.substring(start, offset),
      flags: flags,
      width: width,
      precision: precision,
      type: type,
    ));
  }
  return (tokens: List.unmodifiable(tokens), error: null);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

bool _isFlag(int codeUnit) =>
    codeUnit == 0x2b ||
    codeUnit == 0x2d ||
    codeUnit == 0x23 ||
    codeUnit == 0x30 ||
    codeUnit == 0x20;

bool _isType(int codeUnit) =>
    codeUnit == 0x64 ||
    codeUnit == 0x69 ||
    codeUnit == 0x6f ||
    codeUnit == 0x75 ||
    codeUnit == 0x78 ||
    codeUnit == 0x58 ||
    codeUnit == 0x66 ||
    codeUnit == 0x46 ||
    codeUnit == 0x65 ||
    codeUnit == 0x45 ||
    codeUnit == 0x67 ||
    codeUnit == 0x47 ||
    codeUnit == 0x73 ||
    codeUnit == 0x25;
// scanner-source-end

// hybrid-source-start
final _hybridConversion = RegExp(
  r'%(?:(\d+)\$)?([+\-#0 ]*)(\d+|\*)?(?:\.(\d+|\*))?([diouxXfFeEgGs%])',
);

ParserOutcome parseHybrid(String format) {
  final tokens = <ParserToken>[];
  var offset = 0;
  while (true) {
    offset = format.indexOf('%', offset);
    if (offset < 0) {
      return (tokens: List.unmodifiable(tokens), error: null);
    }
    final match = _hybridConversion.matchAsPrefix(format, offset);
    if (match == null) {
      return _invalidOutcome;
    }
    if (match.group(5) == '%' &&
        (match.group(1) != null ||
            match.group(2)!.isNotEmpty ||
            match.group(3) != null ||
            match.group(4) != null)) {
      return _invalidOutcome;
    }
    tokens.add((
      offset: offset,
      fragment: match.group(0)!,
      flags: match.group(2)!,
      width: match.group(3),
      precision: match.group(4),
      type: match.group(5)!,
    ));
    offset = match.end;
  }
}
// hybrid-source-end

const _invalidOutcome = (
  tokens: <ParserToken>[],
  error: ParseErrorCategory.invalidConversion,
);

Map<String, Object?> mergeRuntimeResults(
  List<Map<String, Object?>> runtimeResults,
  Map<String, int> sourceSizes,
) {
  runtimeResults.forEach(validateRuntimeResult);
  final byRuntime = <String, Map<String, Object?>>{
    for (final result in runtimeResults) result['runtime']! as String: result,
  };
  if (runtimeResults.length != 3 ||
      byRuntime.length != 3 ||
      !_sameNames(byRuntime.keys, const {'jit', 'aot', 'js'})) {
    throw const FormatException('Expected jit, aot, and js exactly once');
  }
  if (!_sameNames(sourceSizes.keys, _candidateNames) ||
      sourceSizes.values.any((size) => size <= 0)) {
    throw const FormatException('Invalid candidate source sizes');
  }
  final referenceConfig = byRuntime['jit']!['config']!;
  for (final runtime in const ['aot', 'js']) {
    if (!_jsonValuesEqual(referenceConfig, byRuntime[runtime]!['config'])) {
      throw FormatException('Incomparable workload configuration for $runtime');
    }
  }
  final referenceScenarios =
      byRuntime['jit']!['scenarios']! as Map<String, Object?>;
  for (final runtime in const ['aot', 'js']) {
    final scenarios = byRuntime[runtime]!['scenarios']! as Map<String, Object?>;
    for (final scenario in const ['cold', 'hot']) {
      final referenceMeasurements =
          referenceScenarios[scenario]! as Map<String, Object?>;
      final measurements = scenarios[scenario]! as Map<String, Object?>;
      for (final name in _candidateNames) {
        final referenceChecksum =
            (referenceMeasurements[name]! as Map<String, Object?>)['checksum'];
        final checksum =
            (measurements[name]! as Map<String, Object?>)['checksum'];
        if (checksum != referenceChecksum) {
          throw FormatException(
            'Cross-runtime checksum mismatch for $runtime/$scenario/$name',
          );
        }
      }
    }
  }

  final medians = <String, Object?>{};
  final normalized = <String, Object?>{};
  final logSums = <String, double>{for (final name in _candidateNames) name: 0};
  var ratioCount = 0;
  for (final runtime in const ['jit', 'aot', 'js']) {
    final result = byRuntime[runtime]!;
    final scenarios = result['scenarios']! as Map<String, Object?>;
    final runtimeMedians = <String, Object?>{};
    final runtimeNormalized = <String, Object?>{};
    for (final scenario in const ['cold', 'hot']) {
      final measurements = scenarios[scenario]! as Map<String, Object?>;
      final scenarioMedians = <String, num>{
        for (final name in _candidateNames)
          name:
              (measurements[name]! as Map<String, Object?>)['medianMicros']!
                  as num,
      };
      final best = scenarioMedians.values.reduce(min);
      final ratios = <String, double>{
        for (final name in _candidateNames)
          name: scenarioMedians[name]!.toDouble() / best,
      };
      for (final name in _candidateNames) {
        logSums[name] = logSums[name]! + log(ratios[name]!);
      }
      ratioCount++;
      runtimeMedians[scenario] = scenarioMedians;
      runtimeNormalized[scenario] = ratios;
    }
    medians[runtime] = runtimeMedians;
    normalized[runtime] = runtimeNormalized;
  }
  final scores = <String, double>{
    for (final name in _candidateNames) name: exp(logSums[name]! / ratioCount),
  };
  final selected = chooseWinner(scores, sourceSizes);

  return <String, Object?>{
    'schemaVersion': 1,
    'kind': 'parser-strategy-merge',
    'runtimes': <String, Object?>{
      for (final runtime in const ['jit', 'aot', 'js'])
        runtime: byRuntime[runtime],
    },
    'mediansMicros': medians,
    'normalized': normalized,
    'scores': scores,
    'sourceSizeBytes': sourceSizes,
    'selectionRule':
        'lowest geometric score; within 1% smaller source; then scanner',
    'selected': selected,
  };
}

String chooseWinner(Map<String, num> scores, Map<String, int> sourceSizes) {
  if (!_sameNames(scores.keys, _candidateNames) ||
      !_sameNames(sourceSizes.keys, _candidateNames)) {
    throw const FormatException('Missing candidate score or source size');
  }
  final bestScore = scores.values.map((score) => score.toDouble()).reduce(min);
  final contenders = _candidateNames
      .where((name) => scores[name]!.toDouble() <= bestScore * 1.01)
      .toList(growable: false);
  final smallestSource = contenders
      .map((name) => sourceSizes[name]!)
      .reduce(min);
  final sourceTies = contenders
      .where((name) => sourceSizes[name] == smallestSource)
      .toList(growable: false);
  if (sourceTies.contains('scanner')) {
    return 'scanner';
  }
  sourceTies.sort();
  return sourceTies.first;
}

void validateRuntimeResult(Map<String, Object?> result) {
  if (result['schemaVersion'] != 1 ||
      result['kind'] != 'parser-strategy-runtime') {
    throw const FormatException('Unknown runtime result schema');
  }
  final runtime = result['runtime'];
  if (runtime is! String || !const {'jit', 'aot', 'js'}.contains(runtime)) {
    throw const FormatException('Invalid runtime');
  }
  final environment = _objectMap(result['environment'], 'environment');
  for (final field in const ['dartVersion', 'os', 'cpu']) {
    final value = environment[field];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid environment.$field');
    }
  }
  final config = _objectMap(result['config'], 'config');
  final samplesPerScenario = config['samplesPerScenario'];
  if (samplesPerScenario is! int || samplesPerScenario < 7) {
    throw const FormatException('At least 7 samples are required');
  }
  for (final field in const ['coldInputs', 'hotParsesPerSample']) {
    final value = config[field];
    if (value is! int || value <= 0) {
      throw FormatException('Invalid config.$field');
    }
  }
  final candidateOrder = config['candidateOrder'];
  final corpus = config['corpus'];
  if (candidateOrder is! List<Object?> ||
      !_jsonValuesEqual(candidateOrder, _candidateOrder) ||
      corpus is! List<Object?> ||
      !_jsonValuesEqual(corpus, parserCorpus) ||
      config['scenarioOrder'] != 'alternates cold/hot by round' ||
      config['warmup'] != 'one complete cold and hot workload per candidate' ||
      config['coldBatchPolicy'] != 'disjoint precreated batch per sample') {
    throw const FormatException('Invalid workload metadata');
  }
  final scenarios = _objectMap(result['scenarios'], 'scenarios');
  if (!_sameNames(scenarios.keys, const {'cold', 'hot'})) {
    throw const FormatException('Expected cold and hot scenarios');
  }
  for (final scenario in const ['cold', 'hot']) {
    final measurements = _objectMap(scenarios[scenario], scenario);
    if (!_sameNames(measurements.keys, _candidateNames)) {
      throw FormatException('Missing candidate in $scenario');
    }
    int? expectedChecksum;
    for (final name in _candidateNames) {
      final measurement = _objectMap(measurements[name], '$scenario.$name');
      final rawSamples = measurement['samplesMicros'];
      if (rawSamples is! List<Object?> ||
          rawSamples.length != samplesPerScenario ||
          rawSamples.any((sample) => sample is! int || sample <= 0)) {
        throw FormatException('Invalid samples for $scenario.$name');
      }
      final samples = rawSamples.cast<int>();
      final recordedMedian = measurement['medianMicros'];
      if (recordedMedian is! num ||
          recordedMedian.toDouble() != _median(samples)) {
        throw FormatException('Invalid median for $scenario.$name');
      }
      final checksum = measurement['checksum'];
      if (checksum is! int) {
        throw FormatException('Invalid checksum for $scenario.$name');
      }
      expectedChecksum ??= checksum;
      if (checksum != expectedChecksum) {
        throw FormatException('Candidate checksum mismatch in $scenario');
      }
    }
  }
}

const _candidateNames = {'regexp', 'scanner', 'hybrid'};

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected object at $field');
  }
  return value;
}

bool _sameNames(Iterable<String> actual, Set<String> expected) {
  final names = actual.toSet();
  return names.length == expected.length && names.containsAll(expected);
}

bool _jsonValuesEqual(Object? left, Object? right) {
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_jsonValuesEqual(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    if (!_sameNames(left.keys, right.keys.toSet())) {
      return false;
    }
    for (final key in left.keys) {
      if (!_jsonValuesEqual(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

double _median(List<int> samples) {
  final sorted = List<int>.of(samples)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle].toDouble();
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

void main(List<String> mainArguments) {
  final arguments = effectiveArguments(mainArguments);
  if (arguments.length == 1 && arguments.single == '--self-test') {
    _runSelfTest();
    return;
  }
  final options = _parseArguments(arguments);
  final output = options['output'];
  if (output == null || output.isEmpty) {
    throw ArgumentError('Expected --output=<path>');
  }
  final merge = options['merge'];
  if (merge != null) {
    final paths = merge.split(',');
    if (paths.length != 3 || paths.any((path) => path.isEmpty)) {
      throw ArgumentError('--merge requires three comma-separated JSON files');
    }
    final runtimeResults = paths
        .map((path) => _decodeObject(readTextFile(path), path))
        .toList(growable: false);
    final sourceSizes = _candidateSourceSizes(
      readTextFile('benchmark/parser_strategy.dart'),
    );
    final merged = mergeRuntimeResults(runtimeResults, sourceSizes);
    _writeJson(output, merged);
    print('selected: ${merged['selected']}');
    return;
  }
  final runtime = options['runtime'];
  if (runtime == null || !const {'jit', 'aot', 'js'}.contains(runtime)) {
    throw ArgumentError('Expected --runtime=jit|aot|js');
  }
  final result = _runMeasurement(runtime);
  validateRuntimeResult(result);
  _writeJson(output, result);
  print('parser_strategy $runtime: PASS');
}

const _sampleCount = 9;
const _coldInputCount = 60000;
const _hotParsesPerSample = 60000;
const _candidateOrder = ['regexp', 'scanner', 'hybrid'];

var _benchmarkSink = 0;

List<List<List<String>>> _buildColdBatches({
  required int rounds,
  required int candidates,
  required int inputCount,
  required int seed,
}) => List<List<List<String>>>.generate(
  rounds,
  (round) => List<List<String>>.generate(
    candidates,
    (candidate) => _buildColdInputs(
      inputCount,
      seed + ((round * candidates + candidate) * inputCount),
    ),
    growable: false,
  ),
  growable: false,
);

List<String> _buildColdInputs(int inputCount, int seed) =>
    List<String>.generate(
      inputCount,
      (index) =>
          '${parserCorpus[index % parserCorpus.length]} '
          'cold-${(seed + index).toRadixString(36).padLeft(8, '0')}',
      growable: false,
    );

Map<String, String?> _parseArguments(List<String> arguments) {
  final options = <String, String?>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw ArgumentError('Unknown argument: $argument');
    }
    final separator = argument.indexOf('=');
    final name = argument.substring(2, separator);
    if (!const {'runtime', 'merge', 'output'}.contains(name) ||
        options.containsKey(name)) {
      throw ArgumentError('Unknown or duplicate argument: $argument');
    }
    options[name] = argument.substring(separator + 1);
  }
  if (options.containsKey('runtime') == options.containsKey('merge')) {
    throw ArgumentError('Specify exactly one of --runtime or --merge');
  }
  return options;
}

Map<String, Object?> _runMeasurement(String runtime) {
  final candidates = <String, ParserCandidate>{
    'regexp': parseRegexp,
    'scanner': parseScanner,
    'hybrid': parseHybrid,
  };
  final preflightColdInputs = _buildColdInputs(256, 0);
  final warmupColdBatches = _buildColdBatches(
    rounds: 1,
    candidates: _candidateOrder.length,
    inputCount: _coldInputCount,
    seed: preflightColdInputs.length,
  );
  final measuredColdBatches = _buildColdBatches(
    rounds: _sampleCount,
    candidates: _candidateOrder.length,
    inputCount: _coldInputCount,
    seed:
        preflightColdInputs.length + (_candidateOrder.length * _coldInputCount),
  );

  _preflight(candidates, <String>[...parserCorpus, ...preflightColdInputs]);
  for (var index = 0; index < _candidateOrder.length; index++) {
    final candidate = candidates[_candidateOrder[index]]!;
    _benchmarkSink = _mix(
      _benchmarkSink,
      _runColdWork(candidate, warmupColdBatches.single[index]).checksum,
    );
    _benchmarkSink = _mix(_benchmarkSink, _runHotWork(candidate).checksum);
  }

  final samples = <String, Map<String, List<int>>>{
    'cold': <String, List<int>>{
      for (final name in _candidateOrder) name: <int>[],
    },
    'hot': <String, List<int>>{
      for (final name in _candidateOrder) name: <int>[],
    },
  };
  final checksums = <String, Map<String, int>>{
    'cold': <String, int>{},
    'hot': <String, int>{},
  };
  for (var round = 0; round < _sampleCount; round++) {
    final scenarioOrder = round.isEven
        ? const ['cold', 'hot']
        : const ['hot', 'cold'];
    final candidateOrder = <String>[
      for (var index = 0; index < _candidateOrder.length; index++)
        _candidateOrder[(index + round) % _candidateOrder.length],
    ];
    for (final scenario in scenarioOrder) {
      for (final name in candidateOrder) {
        final candidate = candidates[name]!;
        final measurement = scenario == 'cold'
            ? _runColdWork(
                candidate,
                measuredColdBatches[round][_candidateOrder.indexOf(name)],
              )
            : _runHotWork(candidate);
        samples[scenario]![name]!.add(measurement.micros);
        final previous = checksums[scenario]![name];
        if (previous != null && previous != measurement.checksum) {
          throw StateError('$scenario/$name checksum changed between samples');
        }
        checksums[scenario]![name] = measurement.checksum;
        _benchmarkSink = _mix(_benchmarkSink, measurement.checksum);
      }
    }
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'kind': 'parser-strategy-runtime',
    'runtime': runtime,
    'environment': environmentInfo(),
    'config': <String, Object?>{
      'samplesPerScenario': _sampleCount,
      'coldInputs': _coldInputCount,
      'hotParsesPerSample': _hotParsesPerSample,
      'candidateOrder': _candidateOrder,
      'scenarioOrder': 'alternates cold/hot by round',
      'warmup': 'one complete cold and hot workload per candidate',
      'coldBatchPolicy': 'disjoint precreated batch per sample',
      'corpus': parserCorpus,
      'sink': _benchmarkSink,
    },
    'scenarios': <String, Object?>{
      for (final scenario in const ['cold', 'hot'])
        scenario: <String, Object?>{
          for (final name in _candidateOrder)
            name: <String, Object?>{
              'samplesMicros': samples[scenario]![name],
              'medianMicros': _median(samples[scenario]![name]!),
              'checksum': checksums[scenario]![name],
            },
        },
    },
  };
}

({int micros, int checksum}) _runColdWork(
  ParserCandidate candidate,
  List<String> inputs,
) {
  final stopwatch = Stopwatch()..start();
  var checksum = 17;
  for (final input in inputs) {
    checksum = _accumulateOutcome(checksum, candidate(input));
  }
  stopwatch.stop();
  return (micros: max(stopwatch.elapsedMicroseconds, 1), checksum: checksum);
}

({int micros, int checksum}) _runHotWork(ParserCandidate candidate) {
  final stopwatch = Stopwatch()..start();
  var checksum = 17;
  for (var index = 0; index < _hotParsesPerSample; index++) {
    checksum = _accumulateOutcome(
      checksum,
      candidate(parserCorpus[index % parserCorpus.length]),
    );
  }
  stopwatch.stop();
  return (micros: max(stopwatch.elapsedMicroseconds, 1), checksum: checksum);
}

int _accumulateOutcome(int checksum, ParserOutcome outcome) {
  var value = _mix(checksum, outcome.error?.index ?? -1);
  value = _mix(value, outcome.tokens.length);
  for (final token in outcome.tokens) {
    value = _mix(value, token.offset);
    value = _mixString(value, token.fragment);
    value = _mixString(value, token.flags);
    value = _mixString(value, token.width ?? '');
    value = _mixString(value, token.precision ?? '');
    value = _mixString(value, token.type);
  }
  return value;
}

int _mixString(int checksum, String value) {
  var result = _mix(checksum, value.length);
  for (var index = 0; index < value.length; index++) {
    result = _mix(result, value.codeUnitAt(index));
  }
  return result;
}

int _mix(int checksum, int value) => ((checksum * 65599) ^ value) & 0x3fffffff;

void _preflight(Map<String, ParserCandidate> candidates, List<String> inputs) {
  for (final input in inputs) {
    _expectCandidatesEquivalent(input, candidates);
  }
}

Map<String, Object?> _decodeObject(String source, String path) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('Expected JSON object in $path');
  }
  return decoded;
}

Map<String, int> _candidateSourceSizes(String source) => <String, int>{
  for (final name in _candidateOrder)
    name: utf8.encode(_sourceSection(source, name)).length,
};

String _sourceSection(String source, String name) {
  final startMarker = '// $name-source-start';
  final endMarker = '// $name-source-end';
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker);
  if (start < 0 || end <= start) {
    throw FormatException('Missing source-size markers for $name');
  }
  return source.substring(start + startMarker.length, end).trim();
}

void _writeJson(String path, Map<String, Object?> value) {
  writeTextFile(path, '${const JsonEncoder.withIndent('  ').convert(value)}\n');
}

void _runSelfTest() {
  const fixtures = <String, ParserOutcome>{
    'literal only': (tokens: <ParserToken>[], error: null),
    '%d': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: '%d',
          flags: '',
          width: null,
          precision: null,
          type: 'd',
        ),
      ],
      error: null,
    ),
    '%+08.3f': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: '%+08.3f',
          flags: '+0',
          width: '8',
          precision: '3',
          type: 'f',
        ),
      ],
      error: null,
    ),
    '%-*.*s': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: '%-*.*s',
          flags: '-',
          width: '*',
          precision: '*',
          type: 's',
        ),
      ],
      error: null,
    ),
    '%#x %d %s %.17g': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: '%#x',
          flags: '#',
          width: null,
          precision: null,
          type: 'x',
        ),
        (
          offset: 4,
          fragment: '%d',
          flags: '',
          width: null,
          precision: null,
          type: 'd',
        ),
        (
          offset: 7,
          fragment: '%s',
          flags: '',
          width: null,
          precision: null,
          type: 's',
        ),
        (
          offset: 10,
          fragment: '%.17g',
          flags: '',
          width: null,
          precision: '17',
          type: 'g',
        ),
      ],
      error: null,
    ),
    r'%1$d': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: r'%1$d',
          flags: '',
          width: null,
          precision: null,
          type: 'd',
        ),
      ],
      error: null,
    ),
    '%%': (
      tokens: <ParserToken>[
        (
          offset: 0,
          fragment: '%%',
          flags: '',
          width: null,
          precision: null,
          type: '%',
        ),
      ],
      error: null,
    ),
  };
  const invalid = <String>[
    '%llx',
    '%b',
    '%',
    r'%2$%',
    '%+%',
    r'%% %1$d %llx %b %',
  ];
  final candidates = <String, ParserCandidate>{
    'regexp': parseRegexp,
    'scanner': parseScanner,
    'hybrid': parseHybrid,
  };

  for (final entry in fixtures.entries) {
    for (final candidate in candidates.entries) {
      _expectOutcome(
        candidate.value(entry.key),
        entry.value,
        '${candidate.key} parses ${jsonEncode(entry.key)}',
      );
    }
  }
  for (final format in invalid) {
    for (final candidate in candidates.entries) {
      _expectOutcome(candidate.value(format), const (
        tokens: <ParserToken>[],
        error: ParseErrorCategory.invalidConversion,
      ), '${candidate.key} rejects ${jsonEncode(format)}');
    }
  }
  for (final format in parserCorpus) {
    _expectCandidatesEquivalent(format, candidates);
  }

  final immutable = parseScanner('%d');
  try {
    immutable.tokens.add(const (
      offset: 0,
      fragment: '%s',
      flags: '',
      width: null,
      precision: null,
      type: 's',
    ));
    // Catching the expected immutability error is the assertion in this
    // self-test.
    // ignore: avoid_catching_errors
  } on UnsupportedError {
    _runColdBatchSelfTest();
    _runMergeSelfTest();
    print('parser_strategy self-test: PASS');
    return;
  }
  throw StateError('Parser token lists must be immutable');
}

void _runColdBatchSelfTest() {
  final batches = _buildColdBatches(
    rounds: 2,
    candidates: 3,
    inputCount: 4,
    seed: 10,
  );
  _expect(batches.length == 2, 'cold batches preserve round count');
  _expect(
    batches.every((round) => round.length == 3),
    'cold batches preserve candidate count',
  );
  _expect(
    batches.expand((round) => round).every((batch) => batch.length == 4),
    'cold batches preserve input count',
  );
  final inputs = batches.expand((round) => round).expand((batch) => batch);
  _expect(inputs.toSet().length == 24, 'every cold input value is unique');
  _expect(
    !identical(batches[0][0][0], batches[0][1][0]),
    'candidate cold batches use distinct string objects',
  );
  _expect(
    batches[0][0][0].length == batches[1][2][0].length,
    'equivalent cold positions have equal input lengths',
  );
}

void _runMergeSelfTest() {
  final runtimeResults = <Map<String, Object?>>[
    _runtimeFixture('jit'),
    _runtimeFixture('aot'),
    _runtimeFixture('js'),
  ];
  final merged = mergeRuntimeResults(runtimeResults, const {
    'regexp': 100,
    'scanner': 90,
    'hybrid': 80,
  });
  _expect(
    merged['selected'] == 'scanner',
    'merge applies source-size tie-break',
  );
  final scores = merged['scores']! as Map<String, Object?>;
  _expect(
    ((scores['regexp']! as num).toDouble() - sqrt(2)).abs() < 1e-9,
    'merge computes regexp geometric score',
  );
  _expect(
    ((scores['scanner']! as num).toDouble() - sqrt(2)).abs() < 1e-9,
    'merge computes scanner geometric score',
  );
  _expect(
    ((scores['hybrid']! as num).toDouble() - 3).abs() < 1e-9,
    'merge computes hybrid geometric score',
  );

  _expect(
    chooseWinner(
          const {'regexp': 1, 'scanner': 1.009, 'hybrid': 1.2},
          const {'regexp': 100, 'scanner': 90, 'hybrid': 80},
        ) ==
        'scanner',
    'within one percent uses source size',
  );
  _expect(
    chooseWinner(
          const {'regexp': 1, 'scanner': 1.009, 'hybrid': 1.2},
          const {'regexp': 100, 'scanner': 100, 'hybrid': 80},
        ) ==
        'scanner',
    'equal source size uses scanner tie-break',
  );
  _expect(
    chooseWinner(
          const {'regexp': 1, 'scanner': 1.011, 'hybrid': 1.2},
          const {'regexp': 100, 'scanner': 90, 'hybrid': 80},
        ) ==
        'regexp',
    'outside one percent keeps faster candidate',
  );

  final badChecksum = _runtimeFixture('jit');
  final badScenarios = badChecksum['scenarios']! as Map<String, Object?>;
  final badHot = badScenarios['hot']! as Map<String, Object?>;
  final badScanner = badHot['scanner']! as Map<String, Object?>;
  badScanner['checksum'] = 999;
  _expectFormatException(
    () => validateRuntimeResult(badChecksum),
    'validator rejects unequal checksums',
  );

  final badMedian = _runtimeFixture('jit');
  final medianScenarios = badMedian['scenarios']! as Map<String, Object?>;
  final medianCold = medianScenarios['cold']! as Map<String, Object?>;
  final medianRegexp = medianCold['regexp']! as Map<String, Object?>;
  medianRegexp['medianMicros'] = 11;
  _expectFormatException(
    () => validateRuntimeResult(badMedian),
    'validator rejects stale median',
  );

  _expectFormatException(
    () => mergeRuntimeResults(
      <Map<String, Object?>>[
        _runtimeFixture('jit'),
        _runtimeFixture('aot'),
        _runtimeFixture('aot'),
      ],
      const {'regexp': 100, 'scanner': 90, 'hybrid': 80},
    ),
    'merge requires jit, aot, and js exactly once',
  );

  final mismatchedWorkload = <Map<String, Object?>>[
    _runtimeFixture('jit'),
    _runtimeFixture('aot'),
    _runtimeFixture('js'),
  ];
  final aotConfig = mismatchedWorkload[1]['config']! as Map<String, Object?>;
  aotConfig['coldInputs'] = 43;
  _expectFormatException(
    () => mergeRuntimeResults(mismatchedWorkload, const {
      'regexp': 100,
      'scanner': 90,
      'hybrid': 80,
    }),
    'merge rejects incomparable workload metadata',
  );

  final mismatchedRuntimeChecksum = <Map<String, Object?>>[
    _runtimeFixture('jit'),
    _runtimeFixture('aot'),
    _runtimeFixture('js'),
  ];
  final aotScenarios =
      mismatchedRuntimeChecksum[1]['scenarios']! as Map<String, Object?>;
  final aotCold = aotScenarios['cold']! as Map<String, Object?>;
  for (final measurement in aotCold.values.cast<Map<String, Object?>>()) {
    measurement['checksum'] = 333;
  }
  _expectFormatException(
    () => mergeRuntimeResults(mismatchedRuntimeChecksum, const {
      'regexp': 100,
      'scanner': 90,
      'hybrid': 80,
    }),
    'merge rejects cross-runtime checksum mismatch',
  );
}

Map<String, Object?> _runtimeFixture(String runtime) => <String, Object?>{
  'schemaVersion': 1,
  'kind': 'parser-strategy-runtime',
  'runtime': runtime,
  'environment': const <String, Object?>{
    'dartVersion': 'Dart test',
    'os': 'test-os',
    'cpu': 'test-cpu',
  },
  'config': <String, Object?>{
    'samplesPerScenario': 7,
    'coldInputs': 42,
    'hotParsesPerSample': 42,
    'candidateOrder': _candidateOrder,
    'scenarioOrder': 'alternates cold/hot by round',
    'warmup': 'one complete cold and hot workload per candidate',
    'coldBatchPolicy': 'disjoint precreated batch per sample',
    'corpus': parserCorpus,
  },
  'scenarios': <String, Object?>{
    'cold': <String, Object?>{
      'regexp': _measurementFixture(10, 111),
      'scanner': _measurementFixture(20, 111),
      'hybrid': _measurementFixture(30, 111),
    },
    'hot': <String, Object?>{
      'regexp': _measurementFixture(20, 222),
      'scanner': _measurementFixture(10, 222),
      'hybrid': _measurementFixture(30, 222),
    },
  },
};

Map<String, Object?> _measurementFixture(int micros, int checksum) =>
    <String, Object?>{
      'samplesMicros': <int>[
        micros,
        micros,
        micros,
        micros,
        micros,
        micros,
        micros,
      ],
      'medianMicros': micros,
      'checksum': checksum,
    };

void _expect(bool condition, String description) {
  if (!condition) {
    throw StateError('Self-test failed: $description');
  }
}

void _expectFormatException(void Function() callback, String description) {
  try {
    callback();
  } on FormatException {
    return;
  }
  throw StateError('Self-test failed: $description');
}

void _expectCandidatesEquivalent(
  String format,
  Map<String, ParserCandidate> candidates,
) {
  final entries = candidates.entries.toList(growable: false);
  final expected = entries.first.value(format);
  for (final candidate in entries.skip(1)) {
    _expectOutcome(
      candidate.value(format),
      expected,
      '${candidate.key} equivalent for ${jsonEncode(format)}',
    );
  }
}

void _expectOutcome(
  ParserOutcome actual,
  ParserOutcome expected,
  String description,
) {
  if (actual.error != expected.error ||
      actual.tokens.length != expected.tokens.length) {
    throw StateError('$description: expected $expected, got $actual');
  }
  for (var index = 0; index < actual.tokens.length; index++) {
    if (actual.tokens[index] != expected.tokens[index]) {
      throw StateError('$description: expected $expected, got $actual');
    }
  }
}
