part of 'engine.dart';

/// An immutable formatting engine: brace and printf mini-languages under
/// one configuration.
///
/// The default configuration (see [defaultFormat]) uses the C locale,
/// Unicode scalars for widths, and Dart SDK decimal double conversion.
/// Construct an instance to opt into custom [formatters], [lookups],
/// [representations], a [numberLocale], grapheme-cluster widths
/// ([textUnit]), or the Python/C++-compatible double profile
/// ([doubleFormatMode]).
final class Format {
  static final RegExp _formatterNamePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*$',
  );

  /// Custom formatters selectable by `{:name}` specifications.
  final List<Formatter<dynamic>> formatters;
  late final Map<String, Formatter<dynamic>> _formattersBySpecifier;

  /// Custom resolvers for `{value.attribute}` field access.
  final List<AttributeLookup<dynamic>> lookups;

  /// Custom `!r`/`!a` representations.
  final List<Representation<dynamic>> representations;

  /// Number symbols and grouping rules; the C locale by default.
  ///
  /// A [CNumberLocale] argument is stored as the canonical constant. The
  /// class is stateless and `final`, so every instance of it means the same
  /// thing, while the compiled printf path recognizes the default locale by
  /// identity — writing `CNumberLocale()` without `const` would otherwise
  /// cost every `%f`, `%e`, and `%g` a fallback to the uncompiled path, with
  /// no visible difference in output to explain it.
  final NumberLocale numberLocale;

  /// The unit in which widths and precisions measure text.
  final TextUnit textUnit;

  /// How decimal doubles are converted; the Dart SDK profile by default.
  final DoubleFormatMode doubleFormatMode;

  /// How non-finite doubles are spelled in Dart SDK mode.
  final DoubleSpecialValueSpelling doubleSpecialValueSpelling;

  /// Creates an engine; throws [FormatConfigurationException] when the
  /// configuration is invalid (reserved or duplicated formatter names), and
  /// [FormatExtensionException] when a formatter's own `specifier` getter
  /// throws.
  Format({
    Iterable<Formatter<dynamic>> formatters = const [],
    Iterable<AttributeLookup<dynamic>> lookups = const [],
    Iterable<Representation<dynamic>> representations = const [],
    NumberLocale numberLocale = const CNumberLocale(),
    this.textUnit = TextUnit.unicodeScalars,
    this.doubleFormatMode = DoubleFormatMode.dartSdk,
    this.doubleSpecialValueSpelling = DoubleSpecialValueSpelling.dartSdk,
  }) : numberLocale =
           numberLocale is CNumberLocale ? const CNumberLocale() : numberLocale,
       formatters = List.unmodifiable(formatters),
       lookups = List.unmodifiable(lookups),
       representations = List.unmodifiable(representations) {
    // Every specifier is read exactly once, here: the getter is user code,
    // so a second read could disagree with the one validation approved.
    final specifiers = _validateConfiguration();
    _formattersBySpecifier = Map.unmodifiable({
      for (var index = 0; index < this.formatters.length; index++)
        specifiers[index]: this.formatters[index],
    });
  }

  /// The configured custom formatter registered under [specifier], if any.
  Formatter<dynamic>? formatterFor(String specifier) =>
      _formattersBySpecifier[specifier];

  /// Formats a brace [template] with up to ten positional values; the
  /// instance counterpart of the top-level [format].
  String format(
    String template, [
    Object? value1 = _MissingValue.value,
    Object? value2 = _MissingValue.value,
    Object? value3 = _MissingValue.value,
    Object? value4 = _MissingValue.value,
    Object? value5 = _MissingValue.value,
    Object? value6 = _MissingValue.value,
    Object? value7 = _MissingValue.value,
    Object? value8 = _MissingValue.value,
    Object? value9 = _MissingValue.value,
    Object? value10 = _MissingValue.value,
  ]) => _formatWith(
    template,
    _collectOptionalValues(
      value1,
      value2,
      value3,
      value4,
      value5,
      value6,
      value7,
      value8,
      value9,
      value10,
    ),
    const {},
  );

  /// Formats a printf [template] with up to ten positional values; the
  /// instance counterpart of the top-level [sprintf].
  String sprintf(
    String template, [
    Object? value1 = _MissingValue.value,
    Object? value2 = _MissingValue.value,
    Object? value3 = _MissingValue.value,
    Object? value4 = _MissingValue.value,
    Object? value5 = _MissingValue.value,
    Object? value6 = _MissingValue.value,
    Object? value7 = _MissingValue.value,
    Object? value8 = _MissingValue.value,
    Object? value9 = _MissingValue.value,
    Object? value10 = _MissingValue.value,
  ]) => _vsprintf(
    template,
    _collectOptionalValues(
      value1,
      value2,
      value3,
      value4,
      value5,
      value6,
      value7,
      value8,
      value9,
      value10,
    ),
  );

  /// Formats a printf [template] with a list of [values]; the instance
  /// counterpart of the top-level [vsprintf].
  ///
  /// [values] is snapshotted first: formatting calls `toString` on its
  /// contents, and one of those can reach back and mutate the very list being
  /// formatted. Mutating it during a call therefore has no effect on that
  /// call, and the list itself is never modified.
  String vsprintf(String template, List<Object?> values) =>
      _vsprintf(template, _snapshot(values));

  /// Formats a brace [template] with [positional] and [named] value
  /// collections; the instance counterpart of the top-level [formatWith].
  ///
  /// Both collections are snapshotted first, for the reason given on
  /// [vsprintf]: a `toString` reached during formatting can mutate them.
  ///
  /// A copy, not an unmodifiable view of one. What the snapshot owes the
  /// caller is that the call reads what it was handed, and a copy already
  /// gives that; the view on top only guards the copy from this package's own
  /// code, which never writes to it, and the copy is never handed out. The
  /// guard is not free either — every named lookup during the call goes
  /// through the view.
  String formatWith(
    String template, {
    List<Object?> positional = const [],
    Map<String, Object?> named = const {},
  }) => _formatWith(
    template,
    _snapshot(positional),
    named.isEmpty ? named : Map.of(named),
  );

  // The two entry points below take collections this class built itself, from
  // values handed to a variadic call. Nothing outside can reach them, so they
  // skip the snapshot the public entry points owe their callers.
  String _vsprintf(String template, List<Object?> values) =>
      _PrintfProcessor(template, values, this).format();

  String _formatWith(
    String template,
    List<Object?> positional,
    Map<String, Object?> named,
  ) =>
      _BraceProcessor(
        template,
        positional: positional,
        named: named,
        engine: this,
      ).format();

  static List<Object?> _snapshot(List<Object?> values) =>
      values.isEmpty ? values : List.of(values, growable: false);

  List<String> _validateConfiguration() {
    final names = <String>{};
    final instances = Set<Formatter<dynamic>>.identity();
    final specifiers = <String>[];

    for (final formatter in formatters) {
      final name = _readExtensionSpecifier(formatter);
      specifiers.add(name);
      if (!_formatterNamePattern.hasMatch(name)) {
        throw FormatConfigurationException(
          'Formatter names must be ASCII identifiers.',
          name: name,
        );
      }
      // The reserved set is exactly the built-in presentation types of the
      // spec parser: one source of truth for both checks.
      if (_builtInTypes.contains(name)) {
        throw FormatConfigurationException(
          'Formatter name is reserved by a built-in formatter.',
          name: name,
        );
      }
      if (!names.add(name)) {
        throw FormatConfigurationException(
          'Formatter names must be unique.',
          name: name,
        );
      }
      if (!instances.add(formatter)) {
        throw FormatConfigurationException(
          'Formatter instances cannot be configured more than once.',
          name: name,
        );
      }
    }

    return specifiers;
  }
}
