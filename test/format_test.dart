/// Contracts that belong to no single stage of the brace pipeline, and so would
/// belong to no single one of the other test files: the order the stages run
/// in, how automatic numbering counts across nesting, the width ceiling, and
/// what a caller gets when formatting fails halfway.
///
/// The per-stage files each pin their own stage in isolation and would all stay
/// green if the stages were wired together in the wrong order. That is the gap
/// this file covers, so it is deliberately small: a handful of cases, each one
/// a property of the pipeline as a whole.
library;

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
  // One template that needs every stage at once: literal braces to unescape, a
  // named field, an attribute lookup into a map, two nested fields resolved
  // into the specification, and a float laid out to that width and precision.
  // Any stage that silently drops out of the chain shows up here as a wrong
  // string, where a stage-local test would still pass.
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

  // Two stages that both touch the same field, in an order that is only
  // observable through side effects: the conversion (`!r`) runs first, and the
  // nested specification is resolved after. The tracing representation records
  // that it ran even though the resolution then failed — swap the order and the
  // recorded events are empty, while the thrown exception stays the same.
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

  // Automatic numbering is a single counter over the whole template, and a
  // nested `{}` inside a specification draws from it like any other field. So
  // `'{:{}} {}'` consumes three values in written order — value, width, tail —
  // and not two with the width coming from somewhere else.
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

  // Formatting is all or nothing. The engine writes into a sink as it goes, so
  // by the time the missing field is reached the prefix is already written —
  // and it must still be thrown away rather than returned as a half-formatted
  // string. A caller catching the exception gets no output at all.
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
