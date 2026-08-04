part of 'engine.dart';

/// Growable UTF-16 code-unit sink for the template IR. Deliberately not
/// exported by `format.dart`; tests import it through
/// `package:format/src/engine.dart`.
final class CharSink {
  static const _lowerDigits = '0123456789abcdef';
  static const _upperDigits = '0123456789ABCDEF';

  Uint16List _buffer;
  int _length = 0;

  // Lazy single-string mode. Many programs resolve to exactly one string
  // (e.g. '{:s}', '%s', or any one-op fallback program): if that string is
  // the sink's only write, it must not pay the copy-in (setRange into
  // `_buffer`) + copy-out (`String.fromCharCodes`) tax that a buffer-first
  // design always pays, even when there is nothing to accumulate. Instead
  // the first `writeString` on an empty sink is held here by reference and
  // returned as-is from `toString`; any other write (a second string, a
  // char code, a fill, digits) materializes it into `_buffer` first and
  // falls back to normal accumulation.
  String? _single;

  CharSink(int initialCapacity)
    : _buffer = Uint16List(initialCapacity < 16 ? 16 : initialCapacity);

  int get length => _single?.length ?? _length;

  void _ensure(int extra) {
    final required = _length + extra;
    if (required <= _buffer.length) return;
    var capacity = _buffer.length * 2;
    while (capacity < required) {
      capacity *= 2;
    }
    _buffer = Uint16List(capacity)..setRange(0, _length, _buffer);
  }

  /// Copies a pending single-string value into `_buffer` (via the same
  /// setRange path `writeString` would have used) and clears single-string
  /// mode. A no-op when the sink is not holding a single string.
  void _materialize() {
    final text = _single;
    if (text == null) return;
    _single = null;
    final units = text.codeUnits;
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void writeCharCode(int codeUnit) {
    _materialize();
    _ensure(1);
    _buffer[_length++] = codeUnit;
  }

  void writeString(String text) {
    if (_single == null && _length == 0) {
      _single = text;
      return;
    }
    _materialize();
    final units = text.codeUnits;
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void writeCodeUnits(Uint16List units) {
    _materialize();
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void fill(int codeUnit, int count) {
    _materialize();
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
    _materialize();
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
  String toString() => _single ?? String.fromCharCodes(_buffer, 0, _length);
}
