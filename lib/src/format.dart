part of 'processor.dart';

final class Format {
  // ignore: prefer_constructors_over_static_methods
  static Format get instance => _instance ??= Format();
  static Format? _instance;

  final List<FormatAutoSpecifier> _autoSpecifiers = [];

  final Map<String, List<Formatter>> _formatters = {};

  Format() {
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

  void registerAutoSpecifier(FormatAutoSpecifier autoSpecifier) {
    _autoSpecifiers.add(autoSpecifier);
  }

  void registerFormater(String specifier, Formatter formatter) {
    final list = _formatters[specifier];
    if (list == null) {
      _formatters[specifier] = [formatter];
    } else {
      list.add(formatter);
    }
  }

  String? autoSpecifierFor(Object? value) {
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
