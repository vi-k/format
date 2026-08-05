import 'package:format/format.dart';
import 'package:test/test.dart';

final class _TraceValue {
  const _TraceValue();
}

final class _TracingRepresentation extends Representation<_TraceValue> {
  final List<String> events;

  _TracingRepresentation(this.events);

  @override
  bool canRepresent(Object? value) {
    events.add('canRepresent');
    return value is _TraceValue;
  }

  @override
  String represent(_TraceValue value) {
    events.add('represent');
    return 'trace';
  }
}

void main() {
  test('public engine completes the full brace formatting pipeline', () {
    expect(
      formatWith(
        '{{{user[score]:{width}.{precision}f}}}',
        named: const {
          'precision': 2,
          'user': {'score': 12.3456},
          'width': 8,
        },
      ),
      '{   12.35}',
    );
  });

  test('conversion runs before resolving a nested specification', () {
    final events = <String>[];
    final configured = Format(
      representations: [_TracingRepresentation(events)],
    );

    expect(
      () => configured.formatWith(
        '{value!r:{missing}}',
        named: const {'value': _TraceValue()},
      ),
      throwsA(isA<MissingFormatArgumentException>()),
    );
    expect(events, ['canRepresent', 'represent']);
  });

  test('nested fields share automatic positional numbering', () {
    expect(format('{:{}} {}', 'value', 8, 'tail'), 'value    tail');
  });

  test('rejects brace widths above the safety ceiling', () {
    // Same contract as the printf options limit: a single field must not
    // be able to demand an arbitrarily large allocation.
    expect(format('{:100000d}', 1).length, 100000);
    expect(
      () => format('{:100001d}', 1),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => format('{:100001s}', 'x'),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => format('{:2000000000}', 1),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(format('{:{}d}', 1, 100000).length, 100000);
    expect(
      () => format('{:{}d}', 1, 100001),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  test('a formatting failure never returns partial output', () {
    expect(
      () => formatWith(
        'prefix {present} suffix {missing}',
        named: const {'present': 'value'},
      ),
      throwsA(
        isA<MissingFormatArgumentException>().having(
          (error) => error.key,
          'key',
          'missing',
        ),
      ),
    );
  });
}
