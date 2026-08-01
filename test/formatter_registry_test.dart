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
}
