part of 'engine.dart';

_AsciiFloat _formatSpecialDouble(
  double value,
  bool uppercase,
  Format settings,
) {
  final short =
      settings.doubleFormatMode == DoubleFormatMode.compatible ||
      settings.doubleSpecialValueSpelling == DoubleSpecialValueSpelling.short;
  var body =
      value.isNaN ? (short ? 'nan' : 'NaN') : (short ? 'inf' : 'Infinity');
  if (short && uppercase) body = body.toUpperCase();
  return _AsciiFloat(body, false, special: true);
}

_AsciiFloat _formatDartDouble(
  double value,
  String? type,
  int? precision,
  bool alternate,
  FormatExceptionContext context,
) {
  _validateDartDoublePrecision(type, precision, context);
  final magnitude = value.abs();
  var body = switch (type) {
    'f' || 'F' => magnitude.toStringAsFixed(precision ?? 6),
    'e' || 'E' =>
      precision == null
          ? magnitude.toStringAsExponential()
          : magnitude.toStringAsExponential(precision),
    'g' || 'G' || 'n' || null =>
      precision == null
          ? magnitude.toString()
          : magnitude.toStringAsPrecision(precision),
    '%' => magnitude.toStringAsFixed(precision ?? 6),
    _ => throw StateError('Unsupported Dart double presentation: $type'),
  };
  if (type == 'E' || type == 'F' || type == 'G') {
    body = body.replaceFirst('e', 'E');
  }
  if (alternate) body = _ensureDartDecimalPoint(body);
  return _AsciiFloat(body, _dartDoubleBodyIsZero(body));
}

void _validateDartDoublePrecision(
  String? type,
  int? precision,
  FormatExceptionContext context,
) {
  if (precision == null) return;
  final general = type == null || type == 'g' || type == 'G' || type == 'n';
  final minimum = general ? 1 : 0;
  final maximum = general ? 21 : 20;
  if (precision < minimum || precision > maximum) {
    throw _invalidSpecifier(
      context,
      'Precision for this Dart double presentation must be between '
      '$minimum and $maximum.',
    );
  }
}

String _ensureDartDecimalPoint(String body) {
  if (body.contains('.')) return body;
  final exponent = body.indexOf(RegExp('[eE]'));
  if (exponent < 0) return '$body.';
  return '${body.substring(0, exponent)}.${body.substring(exponent)}';
}

bool _dartDoubleBodyIsZero(String body) {
  for (var index = 0; index < body.length; index++) {
    final codeUnit = body.codeUnitAt(index);
    if (codeUnit == 0x65 || codeUnit == 0x45) break;
    if (codeUnit >= 0x31 && codeUnit <= 0x39) return false;
  }
  return true;
}
