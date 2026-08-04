part of 'engine.dart';

/// Growable UTF-16 code-unit sink for the template IR. Deliberately not
/// exported by `format.dart`; tests import it through
/// `package:format/src/engine.dart`.
final class CharSink {
  static const _lowerDigits = '0123456789abcdef';
  static const _upperDigits = '0123456789ABCDEF';

  Uint16List _buffer;
  int _length = 0;

  CharSink(int initialCapacity)
    : _buffer = Uint16List(initialCapacity < 16 ? 16 : initialCapacity);

  int get length => _length;

  void _ensure(int extra) {
    final required = _length + extra;
    if (required <= _buffer.length) return;
    var capacity = _buffer.length * 2;
    while (capacity < required) {
      capacity *= 2;
    }
    _buffer = Uint16List(capacity)..setRange(0, _length, _buffer);
  }

  void writeCharCode(int codeUnit) {
    _ensure(1);
    _buffer[_length++] = codeUnit;
  }

  void writeString(String text) {
    final units = text.codeUnits;
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void writeCodeUnits(Uint16List units) {
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void fill(int codeUnit, int count) {
    if (count <= 0) return;
    _ensure(count);
    _buffer.fillRange(_length, _length + count, codeUnit);
    _length += count;
  }

  /// Counts the digits of |value| in [radix]. Runs in negative space, so
  /// the minimum int does not overflow, and uses division only, which is
  /// also exact on dart2js within the web-safe integer range.
  static int digitCount(int value, int radix) {
    var negative = value <= 0 ? value : -value;
    var count = 1;
    while (negative <= -radix) {
      negative = negative ~/ radix;
      count++;
    }
    return count;
  }

  /// Writes the digits of |value| in [radix] without allocating.
  void writeMagnitude(int value, int radix, {bool uppercase = false}) {
    var negative = value <= 0 ? value : -value;
    final count = digitCount(value, radix);
    _ensure(count);
    final digits = uppercase ? _upperDigits : _lowerDigits;
    var index = _length + count;
    _length = index;
    var remaining = count;
    while (remaining-- > 0) {
      _buffer[--index] = digits.codeUnitAt(-negative.remainder(radix));
      negative = negative ~/ radix;
    }
  }

  @override
  String toString() => String.fromCharCodes(_buffer, 0, _length);
}
