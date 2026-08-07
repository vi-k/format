import 'dart:collection';

import 'package:format/format.dart';
import 'package:test/test.dart';

final class NamedFormatter extends Formatter<Object?> {
  @override
  final String specifier;

  NamedFormatter(this.specifier);

  @override
  bool canFormat(Object? value) => true;

  @override
  String format(Object? value, FormatOptions options) => '$specifier:$value';
}

final class EmptyLookup extends AttributeLookup<Object?> {
  @override
  bool canLookup(Object? value) => false;

  @override
  Object? lookup(Object? value, String attribute) => null;
}

final class EmptyRepresentation extends Representation<Object?> {
  @override
  bool canRepresent(Object? value) => false;

  @override
  String represent(Object? value) => '';
}

/// A formatter whose specifier getter fails the way a `late final` field
/// left uninitialized would.
final class ThrowingSpecifierFormatter extends Formatter<Object?> {
  @override
  String get specifier => throw StateError('specifier boom');

  @override
  bool canFormat(Object? value) => true;

  @override
  String format(Object? value, FormatOptions options) => '$value';
}

/// A formatter whose specifier survives configuration and fails afterwards,
/// so a failure report cannot rely on reading it a second time.
final class DecayingSpecifierFormatter extends Formatter<Object?> {
  var _reads = 0;

  @override
  String get specifier {
    if (_reads++ > 0) throw StateError('specifier decayed');
    return 'decaying';
  }

  @override
  bool canFormat(Object? value) => throw StateError('canFormat boom');

  @override
  String format(Object? value, FormatOptions options) => '$value';
}

final class SingleUseFormatters extends IterableBase<Formatter<dynamic>> {
  final Formatter<dynamic> formatter;
  var _hasIterated = false;

  SingleUseFormatters(this.formatter);

  @override
  Iterator<Formatter<dynamic>> get iterator {
    if (_hasIterated) return const <Formatter<dynamic>>[].iterator;
    _hasIterated = true;
    return <Formatter<dynamic>>[formatter].iterator;
  }
}

void main() {
  test('Format defensively copies immutable extension configuration', () {
    final formatter = NamedFormatter('json');
    final formatters = [formatter];
    final lookups = [EmptyLookup()];
    final representations = [EmptyRepresentation()];
    final configured = Format(
      formatters: formatters,
      lookups: lookups,
      representations: representations,
    );

    formatters.clear();
    lookups.clear();
    representations.clear();

    expect(configured.formatters, [formatter]);
    expect(configured.lookups, hasLength(1));
    expect(configured.representations, hasLength(1));
    expect(
      () => configured.formatters.add(NamedFormatter('other')),
      throwsUnsupportedError,
    );
    expect(configured.lookups.clear, throwsUnsupportedError);
    expect(configured.representations.clear, throwsUnsupportedError);
  });

  test('Format rejects invalid formatter names', () {
    for (final name in ['дата', '_name', 'has-dash', '']) {
      expect(
        () => Format(formatters: [NamedFormatter(name)]),
        throwsA(isA<FormatConfigurationException>()),
      );
    }
  });

  test('Format rejects reserved and duplicate formatter specifiers', () {
    expect(
      () => Format(formatters: [NamedFormatter('s')]),
      throwsA(isA<FormatConfigurationException>()),
    );
    expect(
      () =>
          Format(formatters: [NamedFormatter('same'), NamedFormatter('same')]),
      throwsA(isA<FormatConfigurationException>()),
    );
  });

  test('Format rejects repeated formatter instances by identity', () {
    final formatter = NamedFormatter('once');

    expect(
      () => Format(formatters: [formatter, formatter]),
      throwsA(isA<FormatConfigurationException>()),
    );
  });

  test('Format derives its immutable formatter index from its copied list', () {
    final formatter = NamedFormatter('singleUse');
    final configured = Format(formatters: SingleUseFormatters(formatter));

    expect(configured.format('{:singleUse}', 42), 'singleUse:42');
  });

  test('Format reports a throwing specifier as a formatting failure', () {
    // Configuration reads user code, so it owes the same typed-failure
    // contract as formatting itself.
    Object? caught;
    try {
      Format(formatters: [ThrowingSpecifierFormatter()]);
    } on FormattingException catch (error) {
      caught = error;
    }

    expect(caught, isA<FormatExtensionException>());
    final failure = caught! as FormatExtensionException;
    expect(failure.error, isA<StateError>());
    expect(failure.extension, contains('ThrowingSpecifierFormatter'));
  });

  test('A decaying specifier does not mask the original extension failure', () {
    final configured = Format(formatters: [DecayingSpecifierFormatter()]);

    Object? caught;
    try {
      // Built-in kinds never consult custom formatters, so the value has to
      // be one only the extension loop can reach.
      configured.format('{}', Object());
    } on FormattingException catch (error) {
      caught = error;
    }

    expect(caught, isA<FormatExtensionException>());
    final failure = caught! as FormatExtensionException;
    expect((failure.error as StateError).message, 'canFormat boom');
  });
}
