part of 'processor.dart';

final class Options {
  String? all;
  String? fill;
  String? align;
  String? sign;
  bool alt = false;
  bool zero = false;
  int? width;
  String? groupOption;
  int? precision;
  String? specifier;
  String? template;

  Options();

  String debugToString() => '$Options('
      'all: $all'
      ', fill: $fill'
      ', align: $align'
      ', sign: $sign'
      ', alt: $alt'
      ', zero: $zero'
      ', width: $width'
      ', groupOption: $groupOption'
      ', precision: $precision'
      ', specifier: $specifier'
      ', template: $template'
      ')';

  @override
  String toString() => all ?? super.toString();
}

// final class Options extends _MutableOptions {
//   Options() : super._();

//   String? get fill => _fill;
//   String? get align => _align;
//   String? get sign => _sign;
//   bool get alt => _alt;
//   bool get zero => _zero;
//   int? get width => _width;
//   String? get groupOption => _groupOption;
//   int? get precision => _precision;
//   String? get specifier => _specifier;
//   String? get template => _template;

//   @override
//   String toString() => '$Options('
//       'fill: $fill'
//       ', align: $align'
//       ', sign: $sign'
//       ', alt: $alt'
//       ', zero: $zero'
//       ', width: $width'
//       ', groupOption: $groupOption'
//       ', precision: $precision'
//       ', specifier: $specifier'
//       ', template: $template'
//       ')';
// }
