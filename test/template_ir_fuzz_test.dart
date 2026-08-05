import 'dart:math';

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

import 'parity_harness.dart';

/// Deterministic seed: the fuzzer reproduces identically on every run of a
/// given runtime, not across runtimes. The value generator calls
/// `pow(10, ...)` with two int arguments, and at the single exponent 19 the
/// result overflows int64 on the VM (turning negative) while JS yields
/// `+1e19`, so the VM and node corpora differ on ~0.6% of `_value` draws.
/// Reproducibility also assumes `Random(seed)` keeps its stream, which the SDK
/// does not contractually guarantee across releases. Bump deliberately (with a
/// comment) if the corpus needs refreshing.
const _seed = 20260805;
const _casesPerDialect = 400;

/// Every engine flavour the diff test pins by hand. The fuzzer picks one per
/// case so a single run walks the hot ops, the grapheme fallbacks, the
/// compatible double mode, the localized tail, and the short spellings.
final _engines = <Format>[
  defaultFormat,
  graphemeFormat,
  compatibleFormat,
  compatibleGraphemes,
  localeFormat,
  shortSpellingFormat,
];

/// Fill characters: ASCII, a precomposed code point, a combining sequence
/// (two code units, one grapheme cluster) and an astral emoji, so padding
/// arithmetic is exercised in both TextUnit modes.
const _fills = ['*', '0', '\u00e9', 'e\u0301', '\u{1F600}'];
const _aligns = ['<', '>', '^', '='];
const _signs = ['+', '-', ' '];
const _braceConversions = [
  'f',
  'F',
  'e',
  'E',
  'g',
  'G',
  '%',
  'd',
  'x',
  's',
  'n',
  'c',
];
const _printfFlags = ['-', '+', ' ', '#', '0'];
const _printfConversions = [
  'f',
  'F',
  'e',
  'E',
  'g',
  'G',
  'd',
  'i',
  'u',
  'x',
  's',
];

/// Doubles that reach the non-finite and signed-zero branches.
const _edgeDoubles = <double>[
  // ignore: prefer_int_literals
  0.0,
  // ignore: prefer_int_literals
  -0.0,
  double.nan,
  double.infinity,
  double.negativeInfinity,
  2.5,
  -2.5,
];

String _braceSpec(Random random) {
  final buffer = StringBuffer();
  // fill+align (fill may be multi-unit -> exercises fallback parity too)
  if (random.nextInt(4) == 0) {
    buffer
      ..write(_fills[random.nextInt(_fills.length)])
      ..write(_aligns[random.nextInt(_aligns.length)]);
  } else if (random.nextInt(4) == 0) {
    buffer.write(_aligns[random.nextInt(_aligns.length)]);
  }
  if (random.nextInt(3) == 0) {
    buffer.write(_signs[random.nextInt(_signs.length)]);
  }
  if (random.nextInt(5) == 0) buffer.write('z');
  if (random.nextInt(5) == 0) buffer.write('#');
  if (random.nextInt(4) == 0) buffer.write('0');
  if (random.nextInt(2) == 0) buffer.write(random.nextInt(25));
  if (random.nextInt(3) == 0) buffer.write(',');
  if (random.nextInt(2) == 0) {
    buffer
      ..write('.')
      ..write(random.nextInt(28));
  }
  if (random.nextInt(4) != 0) {
    buffer.write(_braceConversions[random.nextInt(_braceConversions.length)]);
  }
  return buffer.toString();
}

String _printfTemplate(Random random) {
  final buffer = StringBuffer('%');
  for (final flag in _printfFlags) {
    if (random.nextInt(4) == 0) buffer.write(flag);
  }
  if (random.nextInt(3) == 0) {
    buffer.write(random.nextInt(2) == 0 ? '*' : '${random.nextInt(20)}');
  }
  if (random.nextInt(2) == 0) {
    buffer
      ..write('.')
      ..write(random.nextInt(2) == 0 ? '*' : '${random.nextInt(25)}');
  }
  buffer.write(_printfConversions[random.nextInt(_printfConversions.length)]);
  return buffer.toString();
}

Object? _value(Random random) => switch (random.nextInt(8)) {
  0 => random.nextDouble() * pow(10, random.nextInt(40) - 20),
  1 => -random.nextDouble() * pow(10, random.nextInt(40) - 20),
  2 => random.nextInt(1 << 30) - (1 << 29),
  3 => _edgeDoubles[random.nextInt(_edgeDoubles.length)],
  4 => 'str${random.nextInt(1000)}',
  5 => BigInt.from(random.nextInt(1 << 30)).pow(1 + random.nextInt(4)),
  6 => null,
  _ => random.nextBool(),
};

/// A value whose runtime type matches the trailing conversion of [spec].
///
/// The type-blind [_value] drives most cases into rejection (a String under
/// `%d` never formats), which is exactly what pins error parity — but it
/// leaves the successful tails thin. Pairing the value with the conversion
/// flips the balance so the rendering paths get fuzzed too.
Object? _matchedValue(Random random, String spec) {
  final conversion = spec.isEmpty ? '' : spec.substring(spec.length - 1);
  return switch (conversion) {
    'd' ||
    'i' ||
    'u' ||
    'x' ||
    'X' ||
    'o' ||
    'b' => random.nextInt(1 << 30) - (1 << 29),
    's' => 'str${random.nextInt(1000)}',
    'c' => 33 + random.nextInt(90),
    // Trailing digit means "no conversion": the empty spec is the double
    // pipeline's general form, so a double is the matching value there too.
    _ => random.nextDouble() * pow(10, random.nextInt(20) - 10),
  };
}

/// Classifies one case as rendered (true) or rejected (false).
///
/// The parity helpers own the IR-vs-legacy comparison and deliberately do not
/// expose their outcome, so the success counter needs its own probe of the
/// public path. That costs one extra render per case, which the time budget
/// absorbs easily, and it keeps divergence handling in exactly one place.
bool _renders(void Function() probe) {
  try {
    probe();
    return true;
  } on FormattingException {
    return false;
  }
}

void main() {
  setUp(debugClearTemplateCaches);

  test('brace fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed);
    final templates = <String>{};
    for (var index = 0; index < _casesPerDialect; index++) {
      final spec = _braceSpec(random);
      final template = '<{:$spec}>';
      final value = _value(random);
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      // Invalid specs are wanted, not filtered: both paths must reject them
      // identically, contexts included. The label carries the case index, the
      // engine index and the value so a failure is triageable from the report
      // alone, without re-instrumenting the generator.
      expectBraceParity(
        template,
        positional: [value],
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} v=$value',
      );
    }
    // Guards against a degenerate generator silently collapsing the corpus.
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
  });

  test('printf fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed + 1);
    final templates = <String>{};
    for (var index = 0; index < _casesPerDialect; index++) {
      final template = 'x=${_printfTemplate(random)}!';
      final stars = '*'.allMatches(template).length;
      final values = <Object?>[
        for (var star = 0; star < stars; star++) random.nextInt(30) - 10,
        _value(random),
      ];
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      expectPrintfParity(
        template,
        values,
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} v=$values',
      );
    }
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
  });

  test('brace fuzz with matched values: IR matches the legacy oracle', () {
    final random = Random(_seed + 2);
    final templates = <String>{};
    var rendered = 0;
    for (var index = 0; index < _casesPerDialect; index++) {
      final spec = _braceSpec(random);
      final template = '<{:$spec}>';
      final value = _matchedValue(random, spec);
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      expectBraceParity(
        template,
        positional: [value],
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} v=$value',
      );
      if (_renders(() => engine.formatWith(template, positional: [value]))) {
        rendered++;
      }
    }
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
    // Distinctness alone would stay green if every case turned into an error:
    // the corpus would still look varied while the rendering paths quietly
    // stopped being fuzzed. This is the property that keeps them covered.
    expect(rendered, greaterThan(_casesPerDialect ~/ 2));
  });

  test('printf fuzz with matched values: IR matches the legacy oracle', () {
    final random = Random(_seed + 3);
    final templates = <String>{};
    var rendered = 0;
    for (var index = 0; index < _casesPerDialect; index++) {
      final spec = _printfTemplate(random);
      final template = 'x=$spec!';
      final stars = '*'.allMatches(template).length;
      final values = <Object?>[
        for (var star = 0; star < stars; star++) random.nextInt(30) - 10,
        _matchedValue(random, spec),
      ];
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      expectPrintfParity(
        template,
        values,
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} v=$values',
      );
      if (_renders(() => engine.vsprintf(template, values))) rendered++;
    }
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
    expect(rendered, greaterThan(_casesPerDialect ~/ 2));
  });
}
