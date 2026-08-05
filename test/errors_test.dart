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

  test('formatting errors retain machine-readable context', () {
    const error = InvalidSpecifierException(context, 'unknown specifier');

    expect(error.context.offset, 0);
    expect(error.context.specifier, 'q');
    expect(error.reason, 'unknown specifier');
  });

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

  test('ambiguous formatter matches cannot be mutated', () {
    final error = AmbiguousFormatterException(context, 42, ['first']);

    expect(() => error.matches.add('second'), throwsUnsupportedError);
  });

  test('toString reports the type, message, payload, and context', () {
    const error = InvalidSpecifierException(context, 'unknown specifier');
    final text = error.toString();

    expect(text, contains('InvalidSpecifierException'));
    expect(text, contains('The format specifier is invalid.'));
    expect(text, contains('unknown specifier'));
    expect(text, contains('"{value:q}"'));
    expect(text, contains('offset: 0'));
  });

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
