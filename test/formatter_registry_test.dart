import 'package:format/format.dart';
import 'package:test/test.dart';

final class CustomValue {}

final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is Map<String, Object?>;

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

final class IntAliasFormatter extends Formatter<int> {
  @override
  final String specifier;

  IntAliasFormatter(this.specifier);

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) => value.toString();
}

final class MatchingFormatter extends Formatter<CustomValue> {
  @override
  final String specifier;

  MatchingFormatter(this.specifier);

  @override
  bool canFormat(Object? value) => value is CustomValue;

  @override
  String format(CustomValue value, FormatOptions options) => specifier;
}

void main() {
  setUp(() => Format.unregisterFormatter('json'));
  tearDown(() => Format.unregisterFormatter('json'));

  test('registers and removes a custom formatter', () {
    Format.registerFormatter(JsonFormatter());
    expect(Format.unregisterFormatter('json'), isTrue);
    expect(Format.unregisterFormatter('json'), isFalse);
  });

  test('duplicate registration has a dedicated exception', () {
    Format.registerFormatter(JsonFormatter());
    expect(
      () => Format.registerFormatter(JsonFormatter()),
      throwsA(isA<FormatterAlreadyRegisteredException>()),
    );
  });

  test('built-in specifiers cannot be changed', () {
    expect(
      () => Format.registerFormatter(IntAliasFormatter('d')),
      throwsA(isA<BuiltInSpecifierException>()),
    );
    expect(
      () => Format.unregisterFormatter('d'),
      throwsA(isA<BuiltInSpecifierException>()),
    );
  });

  test('specifier must be an ASCII identifier', () {
    addTearDown(() => Format.unregisterFormatter('дата'));
    expect(
      () => Format.registerFormatter(IntAliasFormatter('дата')),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  test('multiple automatic matches are rejected', () {
    Format.registerFormatter(MatchingFormatter('first'));
    Format.registerFormatter(MatchingFormatter('second'));
    addTearDown(() {
      Format.unregisterFormatter('first');
      Format.unregisterFormatter('second');
    });

    expect(
      () => format('{}', [CustomValue()]),
      throwsA(isA<AmbiguousFormatterException>()),
    );
  });
}
