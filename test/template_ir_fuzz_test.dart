/// Seeded differential fuzzing of the IR against the legacy oracle.
///
/// The hand-written parity matrices in `template_ir_diff_test.dart` cover what
/// their author thought to list. This file covers what nobody thought of: it
/// generates specifications by drawing each option independently, so
/// combinations appear that no one would write on purpose — a sign flag on a
/// string conversion, grouping with a Unicode fill and an `=` alignment, a
/// precision on a character. Those are the combinations where a hot op and the
/// general path are most likely to disagree.
///
/// Invalid specifications are wanted, not filtered. Most generated draws are
/// invalid, and a rejection is a result like any other: both paths must refuse
/// with the same exception type, the same payload and the same offset. Keeping
/// them makes the fuzzer a test of the *error* contract as much as of the
/// output.
///
/// The corpus is seeded so a failure is reproducible and identical on the VM
/// and on node — the two runtimes must draw the same values, or a divergence
/// found in one could not be investigated in the other. The seed comment below
/// records what that cost.
///
/// Three guards keep the fuzzer from silently degenerating. Distinctness
/// catches a generator that collapsed to a handful of templates; the rendered
/// count catches the subtler failure where the corpus stays varied but every
/// case turns into an error, so the layout paths stop being exercised while
/// everything still passes. Neither notices a corpus that was merely *swapped*
/// for a different one of the same quality, which is what an SDK changing
/// `Random`'s stream would do — so the stream itself is pinned, first test in
/// the file.
library;

import 'dart:math';

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

import 'parity_harness.dart';

/// Deterministic seed: the fuzzer draws the same values on every run of
/// every runtime. Both generators raise ten through `pow(10.0, e)` — a double
/// base, so every draw is an exact power of ten. With the former int base the
/// single exponent 19 overflowed int64 on the VM (turning that draw negative)
/// while JS yielded `+1e19`, which split the VM and node corpora on ~0.6% of
/// [_value] draws (analytically 2/8 branches that call [pow] × 1/40 exponents
/// = 0.625%; a 2000-draw sample happened to show 6, which is low for that
/// rate). With the double base 2000 consecutive draws agree numerically on
/// both runtimes. Reproducibility still assumes `Random(seed)`
/// keeps its stream, which the SDK does not contractually guarantee across
/// releases — that assumption is no longer only written down here, it is
/// checked by the first test in the file. Bump deliberately (with a comment)
/// if the corpus needs refreshing.
///
/// That [pow] change was itself the last corpus refresh, done without a seed
/// bump: the generators moved, so the affected draws are new even though the
/// seed is unchanged. The distinctness and rendering guards below were
/// re-verified against the refreshed corpus on the VM and on node.
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
  0 => random.nextDouble() * pow(10.0, random.nextInt(40) - 20),
  1 => -random.nextDouble() * pow(10.0, random.nextInt(40) - 20),
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
    _ => random.nextDouble() * pow(10.0, random.nextInt(20) - 10),
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

  // The assumption every other test in this file rests on, made executable.
  //
  // `Random(seed)` is documented as free to change its stream between SDK
  // releases, and the whole corpus below is that stream. A change would not
  // break anything visibly: the fuzzer would keep passing, on a different
  // set of cases, and a failure recorded as "#137 e2" would stop naming what
  // it named. The guards further down do not catch it either — they check
  // that the corpus is varied, and a different corpus is just as varied.
  //
  // So the stream is pinned directly. The three sequences cover the raw
  // draw (a power-of-two bound, no rejection), the rejection loop a
  // non-power-of-two bound runs, and the bit-level `nextBool`. The values
  // are recorded from both runtimes, which is the other half of the
  // assumption: the VM and node must draw alike, or a divergence found in
  // one could not be investigated in the other.
  //
  // If this fails, nothing is wrong with the package. The corpus has moved:
  // re-verify the distinctness and rendering guards on the VM *and* on node,
  // then record the new values here with a note saying which SDK moved them.
  test('the seeded stream both runtimes draw from is unchanged', () {
    final raw = Random(_seed);
    expect(
      [for (var i = 0; i < 8; i++) raw.nextInt(1 << 30)],
      [
        247297275,
        837082294,
        1035072399,
        673894849,
        449363615,
        32463177,
        255370889,
        497945114,
      ],
    );

    final bounded = Random(_seed);
    expect(
      [for (var i = 0; i < 10; i++) bounded.nextInt(7)],
      [4, 1, 4, 0, 3, 0, 5, 2, 4, 4],
    );

    // Continues the same generator rather than reseeding: these are the draws
    // that follow the ten above, so the pair also pins that mixing call shapes
    // does not desynchronize the stream — which is how the generators below
    // actually use it.
    expect(
      [for (var i = 0; i < 6; i++) bounded.nextBool()],
      [false, true, true, false, true, false],
    );
  });

  // Random specification, random value, random engine — the two drawn
  // independently, so the value usually does not suit the specification and
  // most cases end in a rejection. That is the point: this pass fuzzes the
  // error paths.
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

  // The same, in the printf dialect, with one addition: the generator counts
  // the asterisks it produced and supplies an integer for each, so dynamic
  // widths and precisions are exercised rather than always failing as missing
  // arguments.
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

  // The second pass draws a value that *suits* the generated specification, so
  // most cases render instead of failing. Without it the fuzzer would be an
  // elaborate test of the rejection paths only — hence the rendered-count guard
  // at the end, which is what makes that claim checkable.
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

  // The matched-value pass for printf, with the same two guards.
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
