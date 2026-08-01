abstract base class Formatter<T> {
  const Formatter();

  String get specifier;
  bool canFormat(Object? value);
  String format(T value, FormatOptions options);
}

final class FormatOptions {
  final String? sign;
  final bool normalizeNegativeZero;
  final bool alternate;
  final bool zero;
  final String? grouping;
  final int? precision;
  final String? payload;

  const FormatOptions({
    this.sign,
    this.normalizeNegativeZero = false,
    this.alternate = false,
    this.zero = false,
    this.grouping,
    this.precision,
    this.payload,
  });
}

abstract base class AttributeLookup<T> {
  const AttributeLookup();

  bool canLookup(Object? value);
  Object? lookup(T value, String attribute);
}

abstract base class Representation<T> {
  const Representation();

  bool canRepresent(Object? value);
  String represent(T value);
}
