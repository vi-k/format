// The printf dialect's public surface: `sprintf`, `vsprintf`, and how values
// arrive.
//
// This is the counterpart of `api_test.dart` for the other mini-language, and
// its subject is argument handling rather than layout. printf has no named
// values and no automatic/manual distinction — arguments are consumed strictly
// in order — so the questions are which values a call sees, when it reads them,
// and what happens when there are too few. `sprintf` is variadic and `vsprintf`
// takes a list, which are two genuinely different contracts: one has a fixed
// maximum arity and needs a sentinel to tell "not passed" from an explicit
// `null`, the other has to snapshot a caller's list that formatting itself
// might mutate.
//
// The rest is the typed-failure contract, restated for this dialect because it
// is a separate parser and a separate processor: an unknown conversion, a
// dangling `%`, a missing argument, a value of the wrong type and a `toString`
// that throws — each with the offset and the argument index filled in, since a
// printf template gives a reader nothing else to locate the fault by.

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _ClearsSourceValues {
  final List<Object?> values;

  _ClearsSourceValues(this.values);

  @override
  String toString() {
    values.clear();
    return 'first';
  }
}

final class _BrokenToString {
  @override
  String toString() => throw StateError('broken');
}

void main() {
  // Both functions exist as top-level entry points and as tear-offs from a
  // configured instance — the same app-wide pattern the brace API supports, and
  // the same requirement that they stay instance methods to support it.
  test('exports sprintf and vsprintf at both API levels', () {
    expect(sprintf('%d %s', 42, 'answer'), '42 answer');
    expect(vsprintf('%s:%d', ['items', 3]), 'items:3');

    final engine = Format(textUnit: TextUnit.graphemeClusters);
    final appSprintf = engine.sprintf;
    final appVSprintf = engine.vsprintf;
    expect(appSprintf('%s', null), 'null');
    expect(appVSprintf('%%', const []), '%');
  });

  // Both ends of the variadic signature: no arguments at all, and the tenth —
  // the last one the signature declares. A template needing more than ten
  // values is what `vsprintf` is for.
  test('sprintf accepts zero and ten supplied arguments', () {
    expect(sprintf('literal'), 'literal');
    expect(
      sprintf('%d%d%d%d%d%d%d%d%d%d', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
      '12345678910',
    );
  });

  // A variadic signature with optional parameters cannot use `null` to mean
  // "not passed", because `null` is also a value someone may want printed. A
  // private sentinel separates them: an explicit `null` formats as `'null'`,
  // while the argument nobody supplied raises a missing-argument error naming
  // its index. Using `null` as the default would silently print `'null'` for a
  // template that asked for more values than the call provides.
  test(
    'sprintf preserves an explicit null before the missing-value sentinel',
    () {
      expect(sprintf('%s', null), 'null');
      expect(
        () => sprintf('%s %s', null),
        throwsA(
          isA<MissingFormatArgumentException>().having(
            (error) => error.context.argumentIndex,
            'argument index',
            1,
          ),
        ),
      );
    },
  );

  // The same ambiguity as in the brace API, and the same answer: a collection
  // passed to `sprintf` is one value, not a spread. Spreading would make the
  // two entry points differ in meaning for the same argument, and would leave
  // no way to print a list at all.
  test('sprintf treats List and Map as individual values', () {
    expect(
      sprintf('%s %s', const ['item'], const {'answer': 42}),
      '[item] {answer: 42}',
    );
  });

  // Extra values are not an error. The template decides how many it consumes,
  // and a caller passing a longer list — a row from a query, say, of which only
  // some columns are printed — is doing something reasonable. Too few is still
  // an error; too many is not.
  test('vsprintf ignores values beyond the consumed tokens', () {
    expect(vsprintf('%s', const ['used', 'ignored']), 'used');
  });

  // Formatting calls `toString` on the caller's objects, and one of those can
  // reach back and mutate the very list being formatted. Here the first value's
  // `toString` clears the list; without a snapshot the second value would be
  // gone by the time it is read, and the call would fail with a missing
  // argument for a value that was there when it started.
  test('vsprintf snapshots its input before formatting values', () {
    final values = <Object?>[];
    final clearingValue = _ClearsSourceValues(values);
    values.addAll([clearingValue, 'second']);

    expect(vsprintf('%s %s', values), 'first second');
  });

  // A smoke test that the parsed conversion reaches the layout: the public
  // entry point is wired to the same processor the dialect's own tests
  // exercise, not to a simplified path.
  test('sprintf applies parsed width through the public API', () {
    expect(sprintf('%6s', 'value'), ' value');
  });

  // An unknown conversion letter is a malformed template here, unlike in the
  // brace dialect where it is deferred to processing: printf has no way to
  // spell a custom conversion, so nothing later could give `%q` a meaning. The
  // context carries the letter twice — as the specifier and as the conversion —
  // because for printf they are the same character.
  test('sprintf keeps invalid conversions typed', () {
    try {
      sprintf('%q', 1);
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, '%q');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%q');
      expect(error.context.specifier, 'q');
      expect(error.context.conversion, 'q');
    }
  });

  // A `%` at the very end has no conversion to report, so the context has an
  // offset and a fragment but no specifier — and the offset is what makes the
  // message useful, since a long template can contain many percent signs.
  // Treating a trailing `%` as a literal would be the permissive alternative,
  // and it would hide a truncated format string.
  test('sprintf reports a dangling percent with typed context', () {
    try {
      sprintf('value %');
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, 'value %');
      expect(error.context.offset, 6);
      expect(error.context.fragment, '%');
      expect(error.context.specifier, isNull);
    }
  });

  // The missing-argument report for printf, where the key is a position rather
  // than a name — so the exception carries the index both as `key` and as
  // `argumentIndex`, and the offset points at the conversion that wanted it.
  test('sprintf reports a missing argument with typed context', () {
    try {
      sprintf('%d');
      fail('Expected MissingFormatArgumentException.');
    } on MissingFormatArgumentException catch (error) {
      expect(error.key, 0);
      expect(error.context.template, '%d');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%d');
      expect(error.context.specifier, 'd');
      expect(error.context.argumentIndex, 0);
    }
  });

  // `%d` accepts both integer types. The `BigInt` chosen is one past the last
  // exactly representable double, so a path that converted through `double`
  // would print `…992` — the same trap as on the brace side, checked here
  // because printf reaches the digits through its own conversion.
  test('sprintf formats integer and BigInt decimal values', () {
    expect(sprintf('%d', 42), '42');
    expect(sprintf('%d', BigInt.parse('9007199254740993')), '9007199254740993');
  });

  // A platform divergence that cannot be papered over. On the web `42.0` *is*
  // an `int` — there is no runtime distinction — so `%d` must accept it; on the
  // VM the same literal is a `double` and `%d` rejects it. The test asserts
  // both answers rather than picking one, because either behaviour alone would
  // be wrong on the other platform. Registered as a known divergence.
  test('sprintf canonicalizes integral doubles only on JavaScript', () {
    const integralDouble = 42.0;
    if (identical(1, 1.0)) {
      expect(sprintf('%d', integralDouble), '42');
    } else {
      expect(
        () => sprintf('%d', integralDouble),
        throwsA(isA<UnsupportedFormatValueException>()),
      );
    }
  });

  // C's printf is famously unsafe about argument types; this one is not. A
  // string handed to `%d` is a typed failure carrying the position and the
  // conversion, not a coercion and not undefined behaviour.
  test('sprintf reports incompatible decimal values as typed errors', () {
    try {
      sprintf('%d', '42');
      fail('Expected UnsupportedFormatValueException.');
    } on UnsupportedFormatValueException catch (error) {
      expect(error.context.template, '%d');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%d');
      expect(error.context.specifier, 'd');
      expect(error.context.conversion, 'd');
      expect(error.context.argumentIndex, 0);
    }
  });

  test('sprintf preserves the cause when toString fails', () {
    // Same contract as the brace path: the original error and stack trace
    // survive inside FormatExtensionException instead of being swallowed.
    try {
      sprintf('%s', _BrokenToString());
      fail('Expected FormatExtensionException.');
    } on FormatExtensionException catch (error) {
      expect(error.error, isA<StateError>());
      expect((error.error as StateError).message, 'broken');
      expect(error.extension, '_BrokenToString');
      expect(error.context.template, '%s');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%s');
      expect(error.context.specifier, 's');
      expect(error.context.argumentIndex, 0);
    }
  });
}
