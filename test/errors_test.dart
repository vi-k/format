/// The exception hierarchy as data: what each failure carries, and what it
/// says.
///
/// These exceptions are a public API. A caller that catches
/// [FormattingException] and reports the offset, or switches on the subtype to
/// decide whether the template or the value was at fault, depends on the
/// payload fields being there and being populated — none of which the engine's
/// own tests check, since they only assert that the right *type* was thrown.
///
/// The exceptions are constructed directly here rather than provoked through
/// the engine. That is deliberate: it separates "the engine throws the right
/// thing" (asserted everywhere else) from "the thing carries the right payload"
/// (asserted here), and it reaches types the engine only produces in rare
/// configurations.
library;

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  const context = FormatExceptionContext(
    template: '{value:q}',
    offset: 0,
    fragment: '{value:q}',
    specifier: 'q',
    conversion: 'r',
    argumentIndex: 2,
  );

  // The context survives construction as fields, not as text baked into a
  // message: a tool that wants to underline the offending fragment in an editor
  // reads `offset` and `specifier`, and would have to parse `toString` if these
  // were only rendered.
  test('formatting errors retain machine-readable context', () {
    const error = InvalidSpecifierException(context, 'unknown specifier');

    expect(error.context.offset, 0);
    expect(error.context.specifier, 'q');
    expect(error.reason, 'unknown specifier');
  });

  // A fragment is an excerpt, not a second copy of the template. A generated
  // template can run to hundreds of kilobytes, and the context already holds
  // all of it in `template`, so slicing an equally long fragment out of it
  // doubled what an error retained for text nobody could read anyway.
  test('caps the fragment while keeping the template whole', () {
    final long = 'x' * 500;
    final capped = FormatExceptionContext(template: long, fragment: long);

    expect(capped.template, hasLength(500));
    expect(capped.fragment, hasLength(80));
    expect(capped.fragment, endsWith('…'));
    expect(capped.fragment, startsWith('xxx'));
  });

  // Short fragments are the overwhelming majority and must stay verbatim:
  // capping is a ceiling, not a transformation applied to every diagnostic.
  test('leaves a fragment at the limit untouched', () {
    final exact = 'y' * 80;

    expect(FormatExceptionContext(fragment: exact).fragment, exact);
  });

  // The cut must not land between a high surrogate and its low one. This is
  // the same class of defect as reading a conversion by code unit: a fragment
  // carrying half a character cannot be printed or logged.
  test('never cuts a fragment inside a surrogate pair', () {
    final astral = '\u{1F600}' * 100;
    final capped = FormatExceptionContext(fragment: astral).fragment!;
    final body = capped.substring(0, capped.length - 1);

    expect(capped.length, lessThanOrEqualTo(80));
    expect(capped, endsWith('…'));
    expect(
      body.codeUnitAt(body.length - 1) & 0xfc00 == 0xd800,
      isFalse,
      reason: 'фрагмент не должен обрываться на старшем суррогате',
    );
  });

  // The roll call: every exception type the package can throw, in one list, so
  // that a new one added without a payload accessor — or dropped from the
  // common supertype — fails here. `everyElement` pins the supertype, which is
  // what makes a single `on FormattingException` catch complete for a caller.
  //
  // `FormatConfigurationException` is the odd one out and is checked as such:
  // it comes from constructing a misconfigured `Format`, before any template
  // exists, so its context has no template to point at.
  test('formatting errors retain their domain-specific values', () {
    final stackTrace = StackTrace.current;
    final errors = <FormattingException>[
      const InvalidFormatException(context, 'unmatched brace'),
      const InvalidSpecifierException(context, 'unknown specifier'),
      const MissingFormatArgumentException(context, 'value'),
      const FormatLookupException(context, 'field', 42),
      const UnsupportedConversionException(context, 42),
      const UnsupportedFormatValueException(context, 42),
      const FormatConfigurationException('invalid option', name: 'locale'),
      AmbiguousFormatterException(context, 42, ['first', 'second']),
      FormatExtensionException(
        context,
        'custom',
        StateError('broken'),
        stackTrace,
      ),
    ];

    expect(errors, everyElement(isA<FormattingException>()));
    expect((errors[0] as InvalidFormatException).reason, 'unmatched brace');
    expect((errors[2] as MissingFormatArgumentException).key, 'value');
    expect((errors[3] as FormatLookupException).segment, 'field');
    expect((errors[3] as FormatLookupException).value, 42);
    expect((errors[4] as UnsupportedConversionException).value, 42);
    expect((errors[5] as UnsupportedFormatValueException).value, 42);
    expect((errors[6] as FormatConfigurationException).name, 'locale');
    expect(
      (errors[6] as FormatConfigurationException).context.template,
      isNull,
    );
    expect((errors[7] as AmbiguousFormatterException).matches, [
      'first',
      'second',
    ]);
    expect((errors[8] as FormatExtensionException).extension, 'custom');
    expect((errors[8] as FormatExtensionException).error, isA<StateError>());
    expect((errors[8] as FormatExtensionException).stackTrace, stackTrace);
  });

  // The one payload that is a collection has to be handed out unmodifiable:
  // it is built from the registry's own state, and a caller that appended to
  // the list it received would be editing the registry through the exception.
  test('ambiguous formatter matches cannot be mutated', () {
    final error = AmbiguousFormatterException(context, 42, ['first']);

    expect(() => error.matches.add('second'), throwsUnsupportedError);
  });

  // What lands in a log when nobody catches it. Four things have to be in the
  // one line: which failure it is, what it means in prose, the specific reason,
  // and where in the template — enough to fix the template without a debugger.
  test('toString reports the type, message, payload, and context', () {
    const error = InvalidSpecifierException(context, 'unknown specifier');
    final text = error.toString();

    expect(text, contains('InvalidSpecifierException'));
    expect(text, contains('The format specifier is invalid.'));
    expect(text, contains('unknown specifier'));
    expect(text, contains('"{value:q}"'));
    expect(text, contains('offset: 0'));
  });

  // The same roll call again, from the other side: it is not enough for a
  // payload to be stored, it also has to be printed. A field that a subtype
  // holds but leaves out of its message is invisible in production — the type
  // says a lookup failed, but not which segment or on what value.
  test('toString carries each domain-specific payload', () {
    final stackTrace = StackTrace.current;

    expect(
      const InvalidFormatException(context, 'unmatched brace').toString(),
      contains('unmatched brace'),
    );
    expect(
      const MissingFormatArgumentException(context, 'value').toString(),
      contains('"value"'),
    );
    expect(
      const FormatLookupException(context, 'field', 42).toString(),
      allOf(contains('"field"'), contains('42')),
    );
    expect(
      const UnsupportedConversionException(context, 42).toString(),
      contains('42'),
    );
    expect(
      const UnsupportedFormatValueException(context, 42).toString(),
      contains('42'),
    );
    expect(
      const FormatConfigurationException(
        'invalid option',
        name: 'locale',
      ).toString(),
      allOf(contains('invalid option'), contains('locale')),
    );
    expect(
      AmbiguousFormatterException(context, 42, ['first', 'second']).toString(),
      allOf(contains('first'), contains('second')),
    );
    expect(
      FormatExtensionException(
        context,
        'custom',
        StateError('broken'),
        stackTrace,
      ).toString(),
      allOf(contains('custom'), contains('broken')),
    );
  });

  // The package is called `format` and its context type is called
  // `FormatExceptionContext`, so `on FormatException` is the first thing a
  // reader is likely to write — and it would let every failure here through.
  // The dartdoc says so; this pins it, since the two hierarchies are one
  // `implements` away from silently merging.
  test('formatting failures are not dart:core FormatException', () {
    const error = InvalidFormatException(context, 'unmatched brace');

    expect(error, isA<FormattingException>());
    expect(error, isNot(isA<FormatException>()));
    expect(() => format('{', 1), throwsA(isNot(isA<FormatException>())));
  });

  // A diagnostic line has to stay a line. Both of these grow with the input:
  // the template is whatever was passed in, and the specification is whatever
  // stood after `:` — a generated template of half a megabyte used to be
  // reprinted whole into every message, so the exception was longer than the
  // template that caused it. The cap applies to the printing only; the fields
  // still carry everything, which is what `offset` is measured against.
  test('toString caps the template and the specifier it prints', () {
    final long = 'x' * 500;
    final error = InvalidSpecifierException(
      FormatExceptionContext(template: long, specifier: long, offset: 3),
      'unknown specifier',
    );
    final text = error.toString();

    expect(error.context.template, hasLength(500));
    expect(error.context.specifier, hasLength(500));
    expect(text, isNot(contains('x' * 100)));
    expect(text, contains('template: "${'x' * 79}…"'));
    expect(text, contains('specifier: "${'x' * 79}…"'));
    expect(text, contains('offset: 3'));
  });

  // The same for the payload, where the risk is not only length: the value is
  // the caller's own object, and a failed lookup prints the map it looked in.
  // Capping is not confidentiality — the head of the value is still printed —
  // but it bounds what one unhandled exception copies into a log.
  test('toString caps the payload it describes', () {
    final long = 'y' * 500;
    final wide = <String, String>{for (var i = 0; i < 100; i++) 'k$i': long};

    expect(
      FormatLookupException(context, 'field', wide).toString(),
      allOf(isNot(contains('y' * 100)), contains('…')),
    );
    expect(
      UnsupportedFormatValueException(context, long).toString(),
      allOf(contains('"${'y' * 79}…"'), isNot(contains('y' * 100))),
    );
    expect(
      UnsupportedFormatValueException(context, wide).toString().length,
      lessThan(300),
    );
  });

  // The payload is the caller's value, and rendering it means calling its
  // `toString` — which can itself throw. If that escaped, the failure a user
  // sees would be the reporting of the error rather than the error, with the
  // original cause lost. Instead the type name is printed and the exception
  // still describes what went wrong.
  test('toString survives payload values whose own toString throws', () {
    final error = UnsupportedConversionException(context, _ThrowingToString());

    expect(error.toString, returnsNormally);
    expect(error.toString(), contains('_ThrowingToString'));
  });
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('boom');
}
