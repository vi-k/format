part of 'processor.dart';

final class Format {
  static final RegExp _specifierPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
  static final Format _instance = Format._();
  static const Set<String> _builtInSpecifiers = {
    'c',
    's',
    'b',
    'o',
    'x',
    'X',
    'd',
    'f',
    'F',
    'e',
    'E',
    'g',
    'G',
    'n',
  };

  static void registerFormatter<T>(Formatter<T> formatter) =>
      _instance._registerFormatter(formatter);

  static bool unregisterFormatter(String specifier) =>
      _instance._unregisterFormatter(specifier);

  final Map<String, Formatter<dynamic>> _customFormatters = {};

  Format._();

  void _registerFormatter<T>(Formatter<T> formatter) {
    final specifier = formatter.specifier;
    if (!_specifierPattern.hasMatch(specifier)) {
      throw InvalidSpecifierException(specifier);
    }
    if (_builtInSpecifiers.contains(specifier)) {
      throw BuiltInSpecifierException(specifier);
    }
    if (_customFormatters.containsKey(specifier)) {
      throw FormatterAlreadyRegisteredException(specifier);
    }
    _customFormatters[specifier] = formatter;
  }

  bool _unregisterFormatter(String specifier) {
    if (_builtInSpecifiers.contains(specifier)) {
      throw BuiltInSpecifierException(specifier);
    }
    return _customFormatters.remove(specifier) != null;
  }

  Formatter<dynamic>? _formatterFor(String specifier) =>
      _customFormatters[specifier];

  Formatter<dynamic>? _automaticFormatterFor(Object? value) {
    Formatter<dynamic>? selected;
    List<String>? matches;
    for (final formatter in _customFormatters.values) {
      if (!formatter.canFormat(value)) {
        continue;
      }
      if (selected == null) {
        selected = formatter;
      } else {
        matches ??= [selected.specifier];
        matches.add(formatter.specifier);
      }
    }
    if (matches != null) {
      throw AmbiguousFormatterException(value, List.unmodifiable(matches));
    }
    return selected;
  }

}
