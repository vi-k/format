/// Constructing a [Format] with extensions: what the constructor accepts, what
/// it copies, and how it fails.
///
/// Configuration is the one place the package runs the caller's code *before*
/// any formatting happens, and the ordinary contracts still apply there. A
/// [Formatter]'s `specifier` is a getter, so reading it can throw; the list of
/// formatters is the caller's collection, so it can be mutated afterwards or be
/// an [Iterable] that only iterates once; and two formatters can claim the same
/// name. All of that has to be resolved at construction, into an immutable
/// index — because a [Format] is meant to be built once and shared, and an
/// instance that could change its behaviour later is not shareable at all.
///
/// The naming rules are checked here rather than at format time for the same
/// reason: a formatter named `s` or `дата` would be unreachable or would shadow
/// a built-in, and the useful moment to say so is where the mistake was made.
library;

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
  // Both directions of the copy, for all three extension lists. The caller's
  // lists are emptied right after construction and the instance keeps its
  // entries — so a `Format` built inside a function that then reuses its
  // scratch list is still valid. And the lists it exposes are unmodifiable, so
  // the reverse cannot happen either: nobody reconfigures a shared engine by
  // appending to `configured.formatters`.
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

  // A specifier has to be spellable in a template, which the specification
  // grammar defines narrowly: ASCII letters only. The four rejected names are
  // the four ways to miss that — non-ASCII, a leading underscore, an
  // interior dash, and empty — and each would otherwise produce a formatter
  // that can be registered but never named.
  test('Format rejects invalid formatter names', () {
    for (final name in ['дата', '_name', 'has-dash', '']) {
      expect(
        () => Format(formatters: [NamedFormatter(name)]),
        throwsA(isA<FormatConfigurationException>()),
      );
    }
  });

  // Two collisions. A built-in conversion letter cannot be taken over — `{:s}`
  // has a meaning the engine owes every caller — and two formatters cannot
  // share a name, since the template would then have no way to say which one
  // it meant.
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

  // The same instance listed twice trips the duplicate check as well. It is
  // harmless in effect — one entry would simply win — but it is always a
  // mistake in the caller's code, and reporting it is cheaper than letting them
  // wonder why their second registration had no effect.
  test('Format rejects repeated formatter instances by identity', () {
    final formatter = NamedFormatter('once');

    expect(
      () => Format(formatters: [formatter, formatter]),
      throwsA(isA<FormatConfigurationException>()),
    );
  });

  // The parameter is an `Iterable`, and an `Iterable` is allowed to be
  // single-use. `SingleUseFormatters` yields its formatter once and nothing
  // afterwards, so an implementation that walked the argument a second time —
  // to validate, then to index — would build an empty registry and the template
  // below would fail. The copy is made first, and everything else reads it.
  test('Format derives its immutable formatter index from its copied list', () {
    final formatter = NamedFormatter('singleUse');
    final configured = Format(formatters: SingleUseFormatters(formatter));

    expect(configured.format('{:singleUse}', 42), 'singleUse:42');
  });

  // The specifier is a getter on the caller's class — an uninitialized `late
  // final` behind it throws on the first read, during construction. That has to
  // arrive as the package's own extension failure, naming the class, rather
  // than as a raw `StateError` from somewhere inside a constructor the caller
  // never sees.
  // The documented way for an extension to report a failure is to throw a
  // FormattingException, which the engine passes through unchanged. Until
  // `options.context` existed that produced *worse* diagnostics than an
  // ordinary error did: a wrapped StateError arrived with the template,
  // offset, fragment and specifier filled in, while the deliberate exception
  // arrived with all four empty, because a context is not something an
  // extension can know.
  test('an extension can report a failure that points at the placeholder', () {
    final engine = Format(formatters: [_LocatedFailureFormatter()]);

    Object? caught;
    try {
      engine.format('a {0:loc} b', 42);
    } on FormattingException catch (error) {
      caught = error;
    }

    expect(caught, isA<InvalidSpecifierException>());
    final failure = caught! as InvalidSpecifierException;
    expect(failure.context.template, 'a {0:loc} b');
    expect(failure.context.offset, 2);
    expect(failure.context.fragment, '{0:loc}');
    expect(failure.context.specifier, 'loc');
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

  // Error reporting must not itself depend on the caller's code behaving. This
  // formatter's specifier works once — long enough to be registered — and
  // throws afterwards, so a failure report that read it again to build its
  // message would replace the real cause (`canFormat boom`) with a second,
  // unrelated error raised while reporting the first. The name is captured at
  // configuration time and reused.
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

final class _LocatedFailureFormatter extends Formatter<Object> {
  @override
  String get specifier => 'loc';

  @override
  bool canFormat(Object? value) => true;

  @override
  String format(Object value, FormatOptions options) =>
      throw InvalidSpecifierException(options.context, 'reported by the test');
}
