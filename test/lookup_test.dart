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

  test('treats a null root as found', () {
    expect(formatWith('{value}', named: const {'value': null}), 'null');
  });

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
