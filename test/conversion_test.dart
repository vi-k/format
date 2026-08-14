/// The three conversions — `!s`, `!r`, `!a` — and the [Representation]
/// extension point behind `!r`.
///
/// `!s` is Dart's [Object.toString]. `!r` and `!a` are Python's `repr` and
/// `ascii`, and that is the reason most of this file exists: the spelling they
/// produce is a compatibility promise, down to which quote character a string
/// gets, which scalars are escaped and in what notation, and how a container is
/// laid out. None of it is derivable from Dart's own conventions, so every rule
/// is pinned against a literal taken from Python's behaviour rather than from
/// ours.
///
/// Two structural hazards get their own tests. Containers are represented
/// recursively, so a cycle would be an infinite loop — it is detected and
/// printed as `...`, the way Python does. And a value can arrive from the
/// caller, which means [Object.toString], [Representation.canRepresent] and
/// [Representation.represent] are all foreign code that can throw; each has to
/// be attributed to its owner, and a [FormattingException] from inside must
/// pass through rather than be wrapped twice.
///
/// The dispatch rules mirror those in `lookup_test.dart`: built-in types are
/// spelled by the engine and never offered to a [Representation], and two
/// extensions claiming the same value is an error rather than list order
/// deciding.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _Token {
  final String value;

  const _Token(this.value);
}

final class _TokenRepresentation extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => '<${value.value}>';
}

final class _NamedTokenRepresentation extends Representation<_Token> {
  final String name;

  _NamedTokenRepresentation(this.name);

  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => name;
}

final class _ThrowingCanRepresent extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => throw StateError('can represent failed');

  @override
  String represent(_Token value) => 'unreachable';
}

final class _ThrowingRepresent extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => throw StateError('represent failed');
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('to string failed');
}

final class _FormattingToString {
  static const error = InvalidSpecifierException(
    FormatExceptionContext(specifier: 'inner'),
    'inner failure',
  );

  @override
  String toString() => throw error;
}

void main() {
  const isJavaScript = identical(1, 1.0);

  // `!s` is exactly Dart's `toString`, including for `null` — where the engine
  // must call the same conversion a Dart interpolation would rather than
  // substituting an empty string.
  test('s conversion uses Dart toString and preserves null', () {
    expect(format('{!s}', 42), '42');
    expect(format('{!s}', null), 'null');
  });

  // Python picks the quote character from the content: single quotes normally,
  // double quotes when the string contains a single quote and no double one,
  // and single quotes with escaping when it contains both. All four branches
  // are here, in the order the rule decides them.
  test('r conversion follows Python quote selection', () {
    expect(format('{!r}', "a\n'b"), r'''"a\n'b"''');
    expect(format('{!r}', 'a"b'), "'a\"b'");
    expect(format('{!r}', 'a\'\'\'b"c'), "'a\\'\\'\\'b\"c'");
    expect(format('{!r}', 'plain'), "'plain'");
  });

  // Which scalars are escaped, and in which of the three notations. Python
  // prefers the short forms where they exist (`\t`, `\n`, `\r`), falls back to
  // `\xNN` below 256 and `\uNNNN` above. The second line is the part that is
  // easy to get wrong: a line separator, a zero-width space and a soft hyphen
  // are invisible rather than absent, and printing them literally would give a
  // representation that reads as if the characters were not there.
  test('r conversion escapes Python non-printable scalars exactly', () {
    expect(
      format('{!r}', '\\\t\n\r\u0000\u001f\u007f'),
      r"'\\\t\n\r\x00\x1f\x7f'",
    );
    expect(format('{!r}', '\u2028\u200b\u00ad'), r"'\u2028\u200b\xad'");
  });

  // The scalars that are not strings. These follow Dart's spelling rather than
  // Python's — `true`, not `True`; `null`, not `None` — because a Dart reader
  // is the audience for a `repr`. Negative zero keeps its sign, which is the
  // whole point of a representation: `0.0` and `-0.0` are different values and
  // must not print the same.
  test('r conversion represents built-in scalars deterministically', () {
    expect(format('{!r}', true), 'true');
    expect(format('{!r}', false), 'false');
    expect(format('{!r}', null), 'null');
    expect(format('{!r}', double.nan), 'NaN');
    expect(format('{!r}', double.infinity), 'Infinity');
    expect(format('{!r}', double.negativeInfinity), '-Infinity');
    expect(format('{!r}', -0.0), '-0.0');
  });

  // Under the `compatible` profile the numbers inside a representation are
  // spelled Python's way too: a two-digit exponent, `1e-07`. The large value is
  // where the platforms genuinely differ — on the web an integral double has no
  // separate integer spelling, so `1e20` comes out in full digits — and the
  // expectation follows the platform instead of pretending they agree.
  test('compatible r and a use platform-aware Python number spelling', () {
    const integralSpelling = isJavaScript ? '100000000000000000000' : '1e+20';
    final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

    expect(compatible.format('{!r}', 1e20), integralSpelling);
    expect(compatible.format('{!r}', 1e-7), '1e-07');
    expect(compatible.format('{!a}', 1e20), integralSpelling);
    expect(compatible.format('{!a}', 1e-7), '1e-07');
  });

  // A representation of a container formats its elements, and those elements
  // must be formatted by the same configured engine — not by a default one
  // reached through a static helper. The doubles are nested inside lists
  // precisely so that a profile that stopped applying one level down would
  // show up: `[1e-07, inf]` versus `[1e-7, Infinity]`.
  test('r conversion uses the configured double profile recursively', () {
    final short = Format(
      doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
    );
    final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

    expect(format('{!r}', [1e-7, double.infinity]), '[1e-7, Infinity]');
    expect(short.format('{!r}', [double.nan]), '[nan]');
    expect(compatible.format('{!r}', [1e-7, double.infinity]), '[1e-07, inf]');
    expect(format('{!a}', ['é', double.infinity]), r"['\xe9', Infinity]");
  });

  // A deliberate ambiguity, recorded so it is not "fixed" by accident: an
  // empty map and an empty set both print `{}`, as they do in Dart. Python
  // distinguishes them (`set()`), but borrowing that here would make the
  // representation of a Dart set unreadable as Dart.
  test('empty maps and sets intentionally share Dart spelling', () {
    expect(format('{!r}', <Object?, Object?>{}), '{}');
    expect(format('{!r}', <Object?>{}), '{}');
  });

  // `BigInt` is a built-in for representation purposes, and one that has to
  // survive being longer than any primitive: the digits are printed in full,
  // never in exponential notation, with the sign in front.
  test('r conversion represents positive and negative BigInt values', () {
    expect(
      format('{!r}', BigInt.parse('123456789012345678901234567890')),
      '123456789012345678901234567890',
    );
    expect(format('{!r}', BigInt.parse('-42')), '-42');
  });

  // `!a` differs from `!r` only in escaping non-ASCII, and decimal digits are
  // already ASCII — so the two must agree here. An implementation that ran the
  // escaping over an already-safe string could still corrupt the sign or the
  // length; this pins that it does not.
  test('a conversion keeps BigInt decimal output ASCII', () {
    expect(
      format('{!a}', BigInt.parse('-123456789012345678901234567890')),
      '-123456789012345678901234567890',
    );
  });

  // Containers print in iteration order, not sorted: the map's keys come out
  // `second, first` because that is how it was built. Sorting would be a
  // plausible-looking improvement that makes the representation disagree with
  // the object it represents.
  test('r conversion preserves built-in container iteration order', () {
    expect(format('{!r}', [true, null, 'x']), "[true, null, 'x']");
    expect(
      format('{!r}', <String, Object?>{'second': 2, 'first': 1}),
      "{'second': 2, 'first': 1}",
    );
    expect(format('{!r}', <Object?>{'x', 2}), "{'x', 2}");
    expect(format('{!r}', <Object?>{}), '{}');
  });

  // "Built-in" means the specific types the engine knows, not anything that
  // implements `Iterable`. A caller's own `Iterable` is not silently printed as
  // a list — it is unsupported until a representation claims it. Iterating it
  // would mean deciding on the caller's behalf that their type is a sequence
  // and that iterating it is free of side effects.
  test('r conversion dispatches custom Iterable values as extensions', () {
    final value = _OrderedValues([1, 'x']);
    final configured = Format(
      representations: [_OrderedValuesRepresentation()],
    );

    expect(
      () => format('{!r}', value),
      throwsA(isA<UnsupportedConversionException>()),
    );
    expect(configured.format('{!r}', value), '<ordered>');
  });

  // The same rule, proved rather than asserted: this `Iterable` throws from
  // its `iterator`, so if the engine touched it at all the failure would be a
  // `StateError` instead of the unsupported-conversion error. It is rejected
  // on its type, before anything is read from it.
  test('r conversion does not iterate unsupported recursive Iterables', () {
    expect(
      () => format('{!r}', _RecursiveIterable()),
      throwsA(isA<UnsupportedConversionException>()),
    );
  });

  // A cycle would otherwise recurse until the stack runs out — the failure
  // mode being a crash of the program that was only trying to log something.
  // All four shapes are here because the detection has to be per container
  // kind and per traversal, not per type: a list holding itself, a map, a set,
  // and the case that catches a naive "am I my own element" check — a list and
  // a map holding each other.
  test('r conversion marks recursive list map set and mutual containers', () {
    final list = <Object?>[];
    list.add(list);
    final map = <String, Object?>{};
    map['self'] = map;
    final set = <Object?>{};
    set.add(set);
    final parent = <Object?>[];
    final child = <String, Object?>{'parent': parent};
    parent.add(child);

    expect(format('{!r}', list), '[[...]]');
    expect(format('{!r}', map), "{'self': {...}}");
    expect(format('{!r}', set), '{{...}}');
    expect(format('{!r}', parent), "[{'parent': [...]}]");
  });

  // `!a` escapes what `!r` leaves alone, over the whole representation and not
  // only over string content — including the quotes it has already chosen. The
  // notation follows the code point: `\xNN`, `\uNNNN`, and `\UNNNNNNNN` for
  // anything past the basic plane, where the value is one scalar even though
  // it is two code units.
  test('a conversion applies fixed ascii escaping after representation', () {
    expect(format('{!a}', 'Привет'), r"'\u041f\u0440\u0438\u0432\u0435\u0442'");
    expect(format('{!a}', 'é😀'), r"'\xe9\U0001f600'");
  });

  // `toString` is the caller's code, so `!s` is an extension point whether or
  // not it looks like one, and a throw from it is attributed to the type that
  // threw. The location matters more here than elsewhere: the exception says
  // which field of which template was being formatted, which is the only way
  // to find the offending value among a template's arguments.
  test('s conversion wraps toString failures with full field context', () {
    try {
      formatWith('prefix {item!s}', named: {'item': _ThrowingToString()});
      fail('expected extension failure');
    } on FormatExtensionException catch (error) {
      expect(error.extension, '_ThrowingToString');
      expect(error.error, isA<StateError>());
      expect(error.stackTrace, isNot(StackTrace.empty));
      expect(error.context.template, 'prefix {item!s}');
      expect(error.context.offset, 7);
      expect(error.context.fragment, '{item!s}');
      expect(error.context.conversion, 's');
    }
  });

  // The exception to the rule above: a value whose `toString` formats
  // something itself and fails is already speaking the engine's vocabulary, so
  // its exception passes through by identity. Wrapping it would bury a precise
  // inner complaint under a generic outer one. Documented in `extensions.dart`.
  test('s conversion does not double-wrap FormattingException', () {
    expect(
      () => format('{!s}', _FormattingToString()),
      throwsA(same(_FormattingToString.error)),
    );
  });

  // A conversion letter that parses but means nothing. The parser deliberately
  // lets it through (see `parser_test.dart`) so that the complaint can be made
  // here, where the letter is known and can be named along with the value and
  // the position.
  test('unknown conversion is a typed unsupported conversion error', () {
    expect(
      () => format('{!q}', 1),
      throwsA(
        isA<UnsupportedConversionException>()
            .having((error) => error.value, 'value', 1)
            .having((error) => error.context.template, 'template', '{!q}')
            .having((error) => error.context.offset, 'offset', 0)
            .having((error) => error.context.fragment, 'fragment', '{!q}')
            .having((error) => error.context.conversion, 'conversion', 'q'),
      ),
    );
  });

  // The other side of that split: no letter, or two, is malformed grammar
  // rather than an unknown conversion, and fails as a format error at parse
  // time. The distinction is what lets the message say "there is no conversion
  // `q`" in one case and "this is not a conversion" in the other.
  for (final template in ['{!}', '{!qq}']) {
    test('missing or malformed conversion remains invalid: $template', () {
      expect(() => format(template, 1), throwsA(isA<InvalidFormatException>()));
    });
  }

  // The extension point working: a type the engine cannot represent, given a
  // spelling by the caller. Baseline for the precedence and ambiguity cases
  // that follow.
  test('r conversion uses exactly one matching custom representation', () {
    final configured = Format(representations: [_TokenRepresentation()]);

    expect(configured.format('{!r}', const _Token('ok')), '<ok>');
  });

  // Built-in types win, even against an extension that explicitly claims them.
  // A registered `Map` representation would otherwise change the spelling of
  // every map anywhere in any template — including maps the caller passes for
  // unrelated reasons — which is why the priority is fixed rather than
  // first-match.
  test(
    'r conversion gives built-ins precedence over custom representations',
    () {
      final configured = Format(representations: [_MapRepresentation()]);

      expect(configured.format('{!r}', <String, int>{'x': 1}), "{'x': 1}");
    },
  );

  // The same precedence for `BigInt`, which is the easiest built-in to forget:
  // it is not a container and not a primitive, and it reaches the
  // representation code by a different route than `Map` does.
  test('r conversion gives BigInt precedence over custom representations', () {
    final configured = Format(representations: [_BigIntRepresentation()]);

    expect(configured.format('{!r}', BigInt.from(42)), '42');
  });

  // With no representation registered, an unknown type has no `repr` — and
  // falling back to `toString` would be the wrong kindness: `!r` promises a
  // representation, and a `toString` that happens to look like one is how a
  // caller ends up parsing output that was never guaranteed.
  test('r conversion rejects unsupported objects', () {
    expect(
      () => formatWith('{item!r}', named: {'item': const _Token('missing')}),
      throwsA(isA<UnsupportedConversionException>()),
    );
  });

  // Two representations claiming the same value: an error, not a first-match
  // win. Both candidates are the same class here on purpose — the report names
  // types, so this is the case where the message is least helpful, and it still
  // has to list both entries rather than deduplicate them into one.
  test('r conversion rejects ambiguously represented objects stably', () {
    final configured = Format(
      representations: [
        _NamedTokenRepresentation('first'),
        _NamedTokenRepresentation('second'),
      ],
    );

    expect(
      () =>
          configured.formatWith('{item!r}', named: {'item': const _Token('x')}),
      throwsA(
        isA<AmbiguousFormatterException>().having(
          (error) => error.matches,
          'matches',
          ['_NamedTokenRepresentation', '_NamedTokenRepresentation'],
        ),
      ),
    );
  });

  // Both halves of the `Representation` contract can throw — the one that
  // decides whether to claim the value, and the one that spells it — and both
  // are wrapped and attributed. Same rule as for `AttributeLookup`; the two
  // extension points reach the engine through different code, so neither
  // inherits the other's guarantee.
  // A structure that refers to itself is caught by identity, and that is the
  // loop with no depth at all. One that is merely very deep has depth, and the
  // walk is recursive, so past some nesting it exhausts the stack. That used to
  // leave `{!r}` and `{!a}` throwing a bare `StackOverflowError` — not a
  // `FormattingException`, and not what the README promises — while `{}` and
  // `{!s}` on an equivalent value already reported it as an extension failure,
  // because they go through `toString`. Each conversion gets a fresh structure:
  // after a stack overflow the SDK's identity-based `toString` cycle guard can
  // retain part of the old structure, making a later call on that same object
  // return `[...]` instead of walking it again. What matters here is that the
  // structure cannot produce two different failure classes depending on the
  // conversion written.
  test(
    'a structure too deep to walk fails alike for every conversion',
    () {
      for (final template in ['{}', '{!s}', '{!r}', '{!a}']) {
        Object deep = 'leaf';
        for (var level = 0; level < 20000; level++) {
          deep = [deep];
        }
        expect(
          () => format(template, deep),
          throwsA(isA<FormatExtensionException>()),
          reason: template,
        );
      }

      // The cycle guard is untouched by the depth guard: a self-referential map
      // still renders rather than failing.
      final cycle = <String, Object?>{};
      cycle['self'] = cycle;
      expect(format('{!r}', cycle), "{'self': {...}}");
    },
    // Not skipped for what the package does but for what the runtime does
    // with it: under dart2wasm the exhausted stack surfaces on the JS side
    // as `RangeError: Maximum call stack size exceeded`, thrown out of the
    // string interop inside `toString`, and it takes the module down instead
    // of arriving as a Dart error. Nothing in this package can catch that,
    // and it happens on `'{}'` alone — the conversions this test is about
    // make no difference there. The VM and dart2js both raise a catchable
    // `StackOverflowError`, which is where the promise this pins applies.
    skip:
        const bool.fromEnvironment('dart.library.js_interop') &&
                !identical(1, 1.0)
            ? 'dart2wasm turns the exhausted stack into a host RangeError'
            : null,
  );

  test('r conversion wraps failures from custom representation callbacks', () {
    final failedCanRepresent = Format(
      representations: [_ThrowingCanRepresent()],
    );
    final failedRepresent = Format(representations: [_ThrowingRepresent()]);

    expect(
      () => failedCanRepresent.formatWith(
        '{item!r}',
        named: {'item': const _Token('x')},
      ),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.context.conversion, 'conversion', 'r')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
    expect(
      () => failedRepresent.formatWith(
        '{item!r}',
        named: {'item': const _Token('x')},
      ),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.context.fragment, 'fragment', '{item!r}')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
  });
}

final class _OrderedValues extends Iterable<Object?> {
  final Iterable<Object?> values;

  _OrderedValues(this.values);

  @override
  Iterator<Object?> get iterator => values.iterator;
}

final class _RecursiveIterable extends Iterable<Object?> {
  @override
  Iterator<Object?> get iterator => throw StateError('must not iterate');
}

final class _OrderedValuesRepresentation
    extends Representation<_OrderedValues> {
  @override
  bool canRepresent(Object? value) => value is _OrderedValues;

  @override
  String represent(_OrderedValues value) => '<ordered>';
}

final class _MapRepresentation extends Representation<Map<Object?, Object?>> {
  @override
  bool canRepresent(Object? value) => value is Map<Object?, Object?>;

  @override
  String represent(Map<Object?, Object?> value) => 'custom-map';
}

final class _BigIntRepresentation extends Representation<BigInt> {
  @override
  bool canRepresent(Object? value) => value is BigInt;

  @override
  String represent(BigInt value) => 'custom-big-int';
}
