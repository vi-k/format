part of 'engine.dart';

final class Format {
  static final RegExp _formatterNamePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*$',
  );
  static const Set<String> _reservedFormatterNames = {
    'b',
    'c',
    'd',
    'e',
    'E',
    'f',
    'F',
    'g',
    'G',
    'n',
    'o',
    's',
    'x',
    'X',
    '%',
  };

  final List<Formatter<dynamic>> formatters;
  late final Map<String, Formatter<dynamic>> _formattersBySpecifier;
  final List<AttributeLookup<dynamic>> lookups;
  final List<Representation<dynamic>> representations;
  final NumberLocale numberLocale;
  final TextUnit textUnit;

  Format({
    Iterable<Formatter<dynamic>> formatters = const [],
    Iterable<AttributeLookup<dynamic>> lookups = const [],
    Iterable<Representation<dynamic>> representations = const [],
    this.numberLocale = const CNumberLocale(),
    this.textUnit = TextUnit.unicodeScalars,
  }) : formatters = List.unmodifiable(formatters),
       lookups = List.unmodifiable(lookups),
       representations = List.unmodifiable(representations) {
    _validateConfiguration();
    _formattersBySpecifier = Map.unmodifiable({
      for (final formatter in this.formatters) formatter.specifier: formatter,
    });
  }

  Formatter<dynamic>? formatterFor(String specifier) =>
      _formattersBySpecifier[specifier];

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
  ]) => formatWith(
    template,
    positional: _collectOptionalValues(
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
  ]) => vsprintf(
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

  String vsprintf(String template, List<Object?> values) =>
      _PrintfProcessor(
        template,
        List<Object?>.unmodifiable(values),
        this,
      ).format();

  String formatWith(
    String template, {
    List<Object?> positional = const [],
    Map<String, Object?> named = const {},
  }) =>
      _BraceProcessor(
        template,
        positional: positional,
        named: named,
        engine: this,
      ).format();

  void _validateConfiguration() {
    final names = <String>{};
    final instances = Set<Formatter<dynamic>>.identity();

    for (final formatter in formatters) {
      final name = formatter.specifier;
      if (!_formatterNamePattern.hasMatch(name)) {
        throw FormatConfigurationException(
          'Formatter names must be ASCII identifiers.',
          name: name,
        );
      }
      if (_reservedFormatterNames.contains(name)) {
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
  }
}
