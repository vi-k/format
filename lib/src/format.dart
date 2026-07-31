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

  final List<FormatAutoSpecifier> _autoSpecifiers = [];

  final Map<String, List<BuiltInFormatter>> _formatters = {};
  final Map<String, Formatter<dynamic>> _customFormatters = {};

  Format._() {
    _autoSpecifiers
      ..add(FormatAutoSpecifier((value) => value is String, specifier: 's'))
      ..add(FormatAutoSpecifier((value) => value is int, specifier: 'd'))
      ..add(FormatAutoSpecifier((value) => value is BigInt, specifier: 'd'))
      ..add(FormatAutoSpecifier((value) => value is double, specifier: 'g'));

    _formatters.addAll({
      's': [StringFormatter()],
      'c': [CharFormatter()],
      'b': [
        IntFormatter(
          precisionSupported: false,
          altSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          convertValue: (value, _) => value.toRadixString(2),
        ),
        BigIntFormatter(
          precisionSupported: false,
          altSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          convertValue: (value, _) => value.toRadixString(2),
        ),
      ],
      'o': [
        IntFormatter(
          precisionSupported: false,
          altSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          convertValue: (value, _) => value.toRadixString(8),
        ),
        BigIntFormatter(
          precisionSupported: false,
          altSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          convertValue: (value, _) => value.toRadixString(8),
        ),
      ],
      'x': [
        IntFormatter(
          precisionSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          prefix: (options) => options.alt ? '0x' : '',
          convertValue: (value, _) => value.toRadixString(16),
        ),
        BigIntFormatter(
          precisionSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          prefix: (options) => options.alt ? '0x' : '',
          convertValue: (value, _) => value.toRadixString(16),
        ),
      ],
      'X': [
        IntFormatter(
          precisionSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          prefix: (options) => options.alt ? '0x' : '',
          convertValue: (value, _) => value.toRadixString(16).toUpperCase(),
        ),
        BigIntFormatter(
          precisionSupported: false,
          standartGroupOptionSupported: false,
          groupSize: 4,
          prefix: (options) => options.alt ? '0x' : '',
          convertValue: (value, _) => value.toRadixString(16).toUpperCase(),
        ),
      ],
      'd': [
        IntFormatter(
          precisionSupported: false,
          altSupported: false,
          convertValue: (value, _) => value.toString(),
        ),
        BigIntFormatter(
          precisionSupported: false,
          altSupported: false,
          convertValue: (value, _) => value.toString(),
        ),
      ],
      'f': [
        NumFormatter<double>(
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsFixed(precision ?? 6),
        ),
      ],
      'F': [
        NumFormatter<double>(
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsFixed(precision ?? 6),
          convertResult: (result) => result.toUpperCase(),
        ),
      ],
      'e': [
        NumFormatter<double>(
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsExponential(precision ?? 6),
        ),
      ],
      'E': [
        NumFormatter<double>(
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsExponential(precision ?? 6),
          convertResult: (result) => result.toUpperCase(),
        ),
      ],
      'g': [
        NumFormatter<double>(
          minPrecision: 1,
          removeTrailingZeros: (options) => !options.alt,
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsPrecision(precision ?? 6),
        ),
      ],
      'G': [
        NumFormatter<double>(
          minPrecision: 1,
          removeTrailingZeros: (options) => !options.alt,
          needPoint: (options) => options.alt,
          convertValue: (value, precision) =>
              value.toStringAsPrecision(precision ?? 6),
          convertResult: (result) => result.toUpperCase(),
        ),
      ],
    });
  }

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

  void registerAutoSpecifier(FormatAutoSpecifier autoSpecifier) {
    _autoSpecifiers.add(autoSpecifier);
  }

  void registerFormater(String specifier, BuiltInFormatter formatter) {
    final list = _formatters[specifier];
    if (list == null) {
      _formatters[specifier] = [formatter];
    } else {
      list.add(formatter);
    }
  }

  String? _autoSpecifierFor(Object? value) {
    for (final autoSpecifier in _autoSpecifiers) {
      if (autoSpecifier.test(value)) {
        return autoSpecifier.specifier;
      }
    }

    return null;
  }
}

final class FormatAutoSpecifier {
  final String specifier;
  bool Function(Object? value) test;

  FormatAutoSpecifier(
    this.test, {
    required this.specifier,
  });
}
