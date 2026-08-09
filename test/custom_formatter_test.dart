/// The [Formatter] extension point: the third-party conversion, reached either
/// by name (`{:json}`) or automatically by an empty specification (`{}`).
///
/// A custom formatter has to be given enough to do its job and no more, and the
/// split is the subject of most of this file. The engine keeps width, alignment
/// and fill for itself — a formatter should not have to implement padding — and
/// hands over everything that describes the *number* rather than the field:
/// sign, alternate form, grouping, precision, and the free-form payload after
/// the name. Where a single option means different things to the two sides (`0`
/// is zero padding for the engine, an option for the formatter), the split is
/// pinned explicitly.
///
/// Automatic selection is the riskier half. An empty `{}` consults every
/// registered formatter, so built-in types must be answered by the engine
/// before the extensions are asked (otherwise one registration changes how
/// every [int] in every template prints), an unclaimed value falls back to
/// [Object.toString], and two formatters claiming the same value is an error
/// rather than list order.
///
/// The rest is the failure contract shared with the other extension points:
/// both halves of the callback pair are wrapped and attributed by specifier, a
/// [FormattingException] from inside passes through unwrapped, and a
/// specification the engine can reject on its own is rejected before any of the
/// caller's code runs.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

final class _ProbeFormatter extends Formatter<Object?> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(Object? value, FormatOptions options) =>
      '${options.payload}:$value';
}

final class _OptionsFormatter extends Formatter<int> {
  @override
  String get specifier => 'options';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) => [
    options.sign,
    options.normalizeNegativeZero,
    options.alternate,
    options.zero,
    options.grouping,
    options.precision,
    options.payload,
  ].join('|');
}

final class _AutomaticFormatter extends Formatter<_Value> {
  @override
  String get specifier => 'auto';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) => 'auto:${value.name}';
}

final class _NamedFormatter extends Formatter<Object?> {
  @override
  final String specifier;

  _NamedFormatter(this.specifier);

  @override
  bool canFormat(Object? value) => true;

  @override
  String format(Object? value, FormatOptions options) => '$specifier:$value';
}

final class _ThrowingCanFormat extends Formatter<_Value> {
  @override
  String get specifier => 'throwsCan';

  @override
  bool canFormat(Object? value) => throw StateError('canFormat failed');

  @override
  String format(_Value value, FormatOptions options) => 'unreachable';
}

final class _ThrowingFormat extends Formatter<_Value> {
  @override
  String get specifier => 'throwsFormat';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) =>
      throw StateError('format failed');
}

final class _FormattingErrorFormatter extends Formatter<_Value> {
  @override
  String get specifier => 'typed';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) =>
      throw UnsupportedFormatValueException(
        const FormatExceptionContext(specifier: 'inner'),
        value,
      );
}

final class _Value {
  final String name;

  const _Value(this.name);

  @override
  String toString() => 'value:$name';
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('toString failed');
}

void main() {
  // The whole shape in one template: fill and alignment for the engine, the
  // formatter name, and a payload that is itself a nested field. The payload is
  // resolved before the formatter is called — it receives `'pretty'`, not
  // `'{mode}'` — and the engine still pads the result the formatter returned.
  test(
    'passes resolved payload and options to an explicit custom formatter',
    () {
      final engine = Format(formatters: [_ProbeFormatter()]);

      expect(
        engine.formatWith(
          '{value:*^12json:{mode}}',
          named: const {'value': 42, 'mode': 'pretty'},
        ),
        '*pretty:42**',
      );
    },
  );

  // Three states a formatter must be able to tell apart: no payload at all
  // (`null`), a payload that is the empty string, and one containing the
  // separator. Collapsing the first two — the obvious simplification — takes
  // away a formatter's ability to distinguish "unset" from "explicitly empty",
  // and splitting on every `:` would truncate `'a:b'` to `'a'`.
  test('keeps empty custom payload distinct from no payload', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(engine.format('{:json}', 42), 'null:42');
    expect(engine.format('{:json:}', 42), ':42');
    expect(engine.format('{:json:a:b}', 42), 'a:b:42');
  });

  // Every option that is not layout, in one specification, joined in order so
  // that one dropped field is visible as a shifted result rather than as a
  // subtly different string. These are the options the engine cannot apply on a
  // formatter's behalf: only the formatter knows where its digits are.
  test('passes every non-layout option through to a custom formatter', () {
    final engine = Format(formatters: [_OptionsFormatter()]);

    expect(
      engine.format('{:+z#08_.3options:data}', 7),
      '+|true|true|true|_|3|data',
    );
  });

  // The one genuinely ambiguous character. In `{:0>12json:x}` the `0` is a fill
  // followed by an alignment, so the engine pads with zeros; in `{:012json:x}`
  // it is the `zero` option, which belongs to the formatter — the engine then
  // has only a width, and pads with spaces in the default alignment. Same two
  // characters, two different owners, decided by what follows them.
  test('custom formatter owns zero while core owns width and alignment', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(engine.format('{:0>12json:x}', 42), '00000000x:42');
    expect(engine.format('{:012json:x}', 42), 'x:42        ');
  });

  // Automatic selection: a bare `{}` on a type the engine does not know finds
  // the formatter that claims it, without the template naming anything. This is
  // what lets an application print its own types with plain interpolation.
  test('empty specifications select one automatic formatter', () {
    final engine = Format(formatters: [_AutomaticFormatter()]);

    expect(engine.format('{}', const _Value('ok')), 'auto:ok');
  });

  // And the guard on it. The registered formatter claims *everything*
  // (`canFormat` returns true), yet none of the four built-in values reach it:
  // registering one extension must not change how ordinary values print
  // anywhere in the program. Named use still works — the last line — so the
  // formatter is registered and reachable, just not consulted.
  test('empty specifications give built-in values precedence', () {
    final engine = Format(formatters: [_NamedFormatter('custom')]);

    expect(engine.format('{}', 42), '42');
    expect(engine.format('{}', 'text'), 'text');
    expect(engine.format('{}', true), 'true');
    expect(engine.format('{}', null), 'null');
    expect(engine.format('{:custom}', 42), 'custom:42');
  });

  // With nothing registered, `{}` on an unknown type is `toString` — the same
  // answer Dart interpolation gives. Unlike `!r`, which promises a
  // representation and refuses to guess, `{}` promises only "print this".
  test('ordinary objects fall back to toString when no formatter matches', () {
    expect(format('{}', const _Value('plain')), 'value:plain');
  });

  // Two formatters claiming the same value under automatic selection: an
  // error, and one that names them by *specifier* rather than by class — both
  // are the same class here, so the class name would identify neither. The
  // order is registration order, which is what makes the message reproducible.
  test(
    'ambiguous automatic formatter matches report stable specifier names',
    () {
      final engine = Format(
        formatters: [_NamedFormatter('first'), _NamedFormatter('second')],
      );

      expect(
        () => engine.format('{}', const _Value('x')),
        throwsA(
          isA<AmbiguousFormatterException>().having(
            (error) => error.matches,
            'matches',
            ['first', 'second'],
          ),
        ),
      );
    },
  );

  // Naming a formatter explicitly has two ways to fail, and they are different
  // complaints: a name nobody registered is an invalid specifier (the template
  // is wrong), while a registered formatter that declines the value is an
  // unsupported value (the data is wrong). Neither falls back to `toString` —
  // the template asked for `json` specifically.
  test('explicit custom formatter rejects unknown names and values', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(
      () => engine.format('{:missing}', 42),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => engine.format('{:json}', 'text'),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  // A payload begins at `:` and nowhere else. Text glued to the name without
  // the separator is a malformed specification rather than a payload — a
  // permissive reading would silently accept `{:json!bad}` as a formatter named
  // `json` with some payload, and typos in a template would never be reported.
  test('custom syntax rejects non-payload trailing text', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(
      () => engine.format('{:json!bad}', 42),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  // `bool` and `null` are built-in for `{}` — Dart's own tokens, not Python's
  // — but they are not numbers. `{:d}` on `true` is rejected rather than
  // printing 1, which is C's convention and a silent source of wrong output for
  // anyone who did not mean it.
  test('bool and null use Dart tokens but reject numeric specifications', () {
    expect(format('{}', true), 'true');
    expect(format('{}', null), 'null');
    expect(
      () => format('{:d}', true),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
    expect(
      () => format('{:f}', null),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  // Both halves of the callback pair, wrapped and attributed by specifier —
  // the name the template used, which is what a reader of the log can search
  // for. Same contract as `AttributeLookup` and `Representation`, enforced
  // separately because it is separate code.
  test('custom formatter callback failures retain formatting context', () {
    final canFail = Format(formatters: [_ThrowingCanFormat()]);
    final formatFail = Format(formatters: [_ThrowingFormat()]);

    expect(
      () => canFail.format('{:throwsCan}', const _Value('x')),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.extension, 'extension', 'throwsCan')
            .having(
              (error) => error.context.specifier,
              'specifier',
              'throwsCan',
            )
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
    expect(
      () => formatFail.format('{:throwsFormat}', const _Value('x')),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.extension, 'extension', 'throwsFormat')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
  });

  // `=` puts padding between the sign and the digits, which only the producer
  // of the digits could do — so it is not offered to custom formatters at all.
  // The formatter used here throws from `format`, so if the specification were
  // accepted the failure would be a `StateError` instead of the invalid
  // specifier: the rejection provably happens first.
  test(
    'custom numeric alignment is rejected before invoking its formatter',
    () {
      final engine = Format(formatters: [_ThrowingFormat()]);

      expect(
        () => engine.format('{:=4throwsFormat}', const _Value('x')),
        throwsA(isA<InvalidSpecifierException>()),
      );
    },
  );

  // The same proof one step earlier: this formatter throws from `canFormat`,
  // so the rejection happens before even the selection half of the contract is
  // consulted. A specification the engine can refuse on its own never reaches
  // the caller's code.
  test('custom numeric alignment is rejected before calling canFormat', () {
    final engine = Format(formatters: [_ThrowingCanFormat()]);

    expect(
      () => engine.format('{:=4throwsCan}', const _Value('x')),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  // The pass-through half of the wrapping rule: a formatter that reports its
  // failure in the engine's own vocabulary — "this value is unsupported" —
  // keeps that type instead of being wrapped as a generic extension failure.
  // Otherwise the precise complaint would be buried one level down.
  test('custom formatter preserves typed formatting errors', () {
    final engine = Format(formatters: [_FormattingErrorFormatter()]);

    expect(
      () => engine.format('{:typed}', const _Value('x')),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  // The `toString` fallback is still the caller's code, so a throw from it is
  // wrapped like any extension failure — even though nothing was registered and
  // the template looks like it involves no extensions at all.
  test('fallback toString errors are wrapped as formatting errors', () {
    expect(
      () => format('{}', _ThrowingToString()),
      throwsA(
        isA<FormatExtensionException>().having(
          (error) => error.error,
          'error',
          isA<StateError>(),
        ),
      ),
    );
  });

  // Deliberately the same case as in `format_test.dart`. Custom formatters are
  // reached through the specification, which is also where nested fields live,
  // so the numbering rule is restated in this file's context: the counter is
  // shared, and a specification consumes its values before the field it
  // decorates.
  test('nested fields share automatic numbering with outer fields', () {
    expect(format('{:{}} {}', 'value', 8, 'tail'), 'value    tail');
  });
}
