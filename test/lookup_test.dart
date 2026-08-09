/// Resolving a field to a value: the argument itself, then `.attribute` and
/// `[item]` steps on top of it, then the [AttributeLookup] extension point.
///
/// Lookup is where the engine touches the caller's own objects, so most of what
/// is pinned here is about *failing well*. A lookup can fail for four different
/// reasons — the root was never passed, the step is out of range, the value has
/// no such attribute, or the caller's extension threw — and they must not
/// collapse into one another: a missing argument is a template bug, a failed
/// step is a data bug, and an extension that throws is the extension's bug and
/// has to arrive with its original error and stack trace intact. Each is
/// asserted as a type plus the field it happened in, because an exception that
/// cannot say which field it came from is nearly useless in a template with
/// ten.
///
/// The other theme is dispatch. Built-in types are resolved by the engine and
/// never offered to an extension — the [Map] case below is the one that catches
/// this — and two extensions claiming the same value is an error rather than a
/// race won by list order.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class Person {
  final String name;

  const Person(this.name);
}

final class PersonLookup extends AttributeLookup<Person> {
  @override
  bool canLookup(Object? value) => value is Person;

  @override
  Object? lookup(Person value, String attribute) => switch (attribute) {
    'name' => value.name,
    _ => null,
  };
}

final class AnotherPersonLookup extends AttributeLookup<Person> {
  @override
  bool canLookup(Object? value) => value is Person;

  @override
  Object? lookup(Person value, String attribute) => value.name;
}

final class MapFallbackLookup extends AttributeLookup<Map<Object?, Object?>> {
  @override
  bool canLookup(Object? value) => value is Map<Object?, Object?>;

  @override
  Object? lookup(Map<Object?, Object?> value, String attribute) => 'fallback';
}

final class ThrowingCanLookup extends AttributeLookup<Person> {
  final Object error;
  final StackTrace stackTrace;

  ThrowingCanLookup(this.error, this.stackTrace);

  @override
  bool canLookup(Object? value) => Error.throwWithStackTrace(error, stackTrace);

  @override
  Object? lookup(Person value, String attribute) => value.name;
}

final class ThrowingLookup extends AttributeLookup<Person> {
  final Object error;
  final StackTrace stackTrace;

  ThrowingLookup(this.error, this.stackTrace);

  @override
  bool canLookup(Object? value) => value is Person;

  @override
  Object? lookup(Person value, String attribute) =>
      Error.throwWithStackTrace(error, stackTrace);
}

void main() {
  // The built-in resolutions in one template: an index into a positional list,
  // a named root, and both step kinds on a `Map` — where `.name` and
  // `[address]` reach the same map through different syntax. That equivalence
  // is the shortcut that makes the `Map` case in the dispatch tests below
  // necessary.
  test('resolves positional, named, item and Map attribute paths', () {
    expect(
      formatWith(
        '{0[1]} {user.name} {user[address]}',
        positional: const [
          <String>['zero', 'one'],
        ],
        named: const {
          'user': {'name': 'Ada', 'address': 'London'},
        },
      ),
      'one Ada London',
    );
  });

  // The extension point working at all: a type the engine knows nothing about,
  // reached through `.name` because the caller registered a lookup for it.
  // This is the baseline the ambiguity and failure cases below deviate from.
  test('uses exactly one custom attribute lookup', () {
    final engine = Format(lookups: [PersonLookup()]);

    expect(
      engine.formatWith(
        '{person.name}',
        named: {'person': const Person('Ada')},
      ),
      'Ada',
    );
  });

  // Named fields do not consume positional values: the automatic counter is
  // advanced by `{}` alone, so `'{name} {} {}'` still reads the two positional
  // values in order. A counter incremented per field would skip one.
  test('keeps automatic indexing across all fields', () {
    expect(
      formatWith(
        '{name} {} {}',
        positional: const ['zero', 'one'],
        named: const {'name': 'Ada'},
      ),
      'Ada zero one',
    );
  });

  // An argument that was never passed is a different failure from a step
  // that did not resolve, and it is reported before the steps are attempted —
  // `absent.name` complains about `absent`, not about `name`. The context has
  // to carry the whole field so the caller can see which one of many is
  // unfilled.
  test('reports a missing root with complete field context', () {
    try {
      formatWith('{absent.name}');
      fail('expected missing argument');
    } on MissingFormatArgumentException catch (error) {
      expect(error.key, 'absent');
      expect(error.context.template, '{absent.name}');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '{absent.name}');
    }
  });

  // `null` is a value, not an absence. A map lookup that decided presence by
  // `map[key] != null` would report a passed null as a missing argument — the
  // opposite of what the caller asked for, which was to print it.
  test('treats a null root as found', () {
    expect(formatWith('{value}', named: const {'value': null}), 'null');
  });

  // An out-of-range index raises `RangeError` from the list, which is a Dart
  // error and would escape the package's own exception hierarchy — a caller
  // catching `FormattingException` around `format` would miss it entirely. It
  // is caught and re-reported with the step and the value that was indexed.
  test('wraps list range errors as lookup errors', () {
    const values = ['only'];

    try {
      formatWith('{values[1]}', named: {'values': values});
      fail('expected lookup error');
    } on FormatLookupException catch (error) {
      expect(error.segment, 1);
      expect(error.value, same(values));
      expect(error.context.fragment, '{values[1]}');
    }
  });

  // A map returns null for an absent key instead of throwing, so the engine
  // has to detect the absence itself — and, given the previous test, cannot do
  // it by comparing to null. An absent key is a lookup failure, not the string
  // `'null'`.
  test('reports a missing Map key as a lookup error', () {
    const values = {'present': 'yes'};

    try {
      formatWith('{values[missing]}', named: {'values': values});
      fail('expected lookup error');
    } on FormatLookupException catch (error) {
      expect(error.segment, 'missing');
      expect(error.value, same(values));
      expect(error.context.fragment, '{values[missing]}');
    }
  });

  // Built-in types are resolved by the engine and never offered to an
  // extension, even when the engine's own attempt fails. The registered lookup
  // here would happily answer `'fallback'` for any map, and must not be asked:
  // otherwise adding one extension for one type would silently change how every
  // map in every template behaves. Documented in `extensions.dart`, pinned
  // here.
  test('does not dispatch missing Map attributes to custom lookups', () {
    final engine = Format(lookups: [MapFallbackLookup()]);
    const values = {'present': 'yes'};

    expect(
      () => engine.formatWith('{values.missing}', named: {'values': values}),
      throwsA(
        isA<FormatLookupException>()
            .having((error) => error.segment, 'segment', 'missing')
            .having((error) => error.value, 'value', same(values)),
      ),
    );
  });

  // Dart has no runtime attribute access, so an arbitrary object simply has no
  // reachable `.name` without an extension. That is a lookup failure naming the
  // segment and the value — not a crash, and not an empty string.
  test('reports an unsupported attribute as a lookup error', () {
    const person = Person('Ada');

    try {
      formatWith('{person.name}', named: {'person': person});
      fail('expected lookup error');
    } on FormatLookupException catch (error) {
      expect(error.segment, 'name');
      expect(error.value, same(person));
      expect(error.context.fragment, '{person.name}');
    }
  });

  // Two extensions claiming the same value is a configuration mistake, and
  // resolving it by list order would make the behaviour depend on the order
  // registrations happen to be written in — quiet, and different in a test
  // than in production. It is an error instead, and it names both candidates
  // in registration order so the mistake can be found without a debugger.
  test('rejects two matching custom lookups with stable type names', () {
    final engine = Format(lookups: [PersonLookup(), AnotherPersonLookup()]);
    const person = Person('Ada');

    try {
      engine.formatWith('{person.name}', named: {'person': person});
      fail('expected ambiguous lookup');
    } on AmbiguousFormatterException catch (error) {
      expect(error.value, same(person));
      expect(error.matches, ['PersonLookup', 'AnotherPersonLookup']);
      expect(error.context.fragment, '{person.name}');
    }
  });

  // An extension throws from the *selection* half of the contract, before it
  // has been chosen. That still has to be attributed to it by name rather than
  // surfacing as an anonymous failure of the engine, and the original error
  // and stack trace must be carried through by identity — a rethrow that
  // re-captured the stack would point at the engine's own frames and lose the
  // line in the caller's code that actually threw.
  test(
    'wraps canLookup failures with their original error and stack trace',
    () {
      final originalError = StateError('can lookup failed');
      final originalStack = StackTrace.current;
      final engine = Format(
        lookups: [ThrowingCanLookup(originalError, originalStack)],
      );

      try {
        engine.formatWith(
          '{person.name}',
          named: {'person': const Person('Ada')},
        );
        fail('expected extension error');
      } on FormatExtensionException catch (error) {
        expect(error.error, same(originalError));
        expect(error.stackTrace, same(originalStack));
        expect(error.extension, 'ThrowingCanLookup');
        expect(error.context.fragment, '{person.name}');
      }
    },
  );

  // The same contract for the other half, where the extension has already been
  // chosen and is doing the work. Both halves are wrapped, and they are
  // separate code paths — one runs during selection, one after it.
  test('wraps lookup failures with their original error and stack trace', () {
    final originalError = StateError('lookup failed');
    final originalStack = StackTrace.current;
    final engine = Format(
      lookups: [ThrowingLookup(originalError, originalStack)],
    );

    try {
      engine.formatWith(
        '{person.name}',
        named: {'person': const Person('Ada')},
      );
      fail('expected extension error');
    } on FormatExtensionException catch (error) {
      expect(error.error, same(originalError));
      expect(error.stackTrace, same(originalStack));
      expect(error.extension, 'ThrowingLookup');
      expect(error.context.fragment, '{person.name}');
    }
  });
}
