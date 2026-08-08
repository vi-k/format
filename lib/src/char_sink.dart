part of 'engine.dart';

/// True on a web target, where a string is the platform's own type.
///
/// Not the same question as [_isWebInt], which asks whether an int is a JS
/// double and is therefore true only under dart2js. This asks how strings are
/// built, and both web backends answer the same way.
///
/// Measured for a sixteen-unit result: accumulating through a typed array and
/// calling `String.fromCharCodes` costs 574 ns under dart2js and 275 ns under
/// dart2wasm, against 4 ns and 25 ns for a `StringBuffer`. On the VM the same
/// round trip wins instead, 45 ns against 89. Being a `const`, this folds at
/// compile time, so each target keeps one branch and drops the other.
const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Growable UTF-16 code-unit sink for the template IR. Deliberately not
/// exported by `format.dart`; tests import it through
/// `package:format/src/engine.dart`.
final class CharSink {
  static const _lowerDigits = '0123456789abcdef';
  static const _upperDigits = '0123456789ABCDEF';
  static final Uint16List _unusedBuffer = Uint16List(0);

  /// Accumulates on the VM. On the web it stays the shared empty list and
  /// [_text] accumulates instead.
  Uint16List _buffer;

  /// Accumulates on the web, and is null on the VM.
  final StringBuffer? _text;

  /// Units written so far, on either platform.
  int _length = 0;

  // Lazy single-string mode. Many programs resolve to exactly one string
  // (e.g. '{:s}', '%s', or any one-op fallback program): if that string is
  // the sink's only write, it must not pay the copy-in + copy-out tax that
  // an accumulate-first design always pays, even when there is nothing to
  // accumulate. Instead the first `writeString` on an empty sink is held here
  // by reference and returned as-is from `toString`; any other write (a
  // second string, a char code, a fill, digits) materializes it first and
  // falls back to normal accumulation.
  String? _single;

  CharSink(int initialCapacity)
    : _buffer =
          _isWeb
              ? _unusedBuffer
              : Uint16List(initialCapacity < 16 ? 16 : initialCapacity),
      _text = _isWeb ? StringBuffer() : null;

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

  /// Moves a pending single-string value into the accumulator and clears
  /// single-string mode. A no-op when the sink is not holding a string.
  void _materialize() {
    final text = _single;
    if (text == null) return;
    _single = null;
    _append(text);
  }

  void _append(String text) {
    if (_isWeb) {
      _text!.write(text);
      _length += text.length;
      return;
    }
    final units = text.codeUnits;
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void writeCharCode(int codeUnit) {
    _materialize();
    if (_isWeb) {
      _text!.writeCharCode(codeUnit);
      _length++;
      return;
    }
    _ensure(1);
    _buffer[_length++] = codeUnit;
  }

  void writeString(String text) {
    if (_single == null && _length == 0) {
      _single = text;
      return;
    }
    _materialize();
    _append(text);
  }

  /// Appends units prepared once at compile time.
  ///
  /// VM only. `setRange` from a `Uint16List` is a block copy, where the
  /// `codeUnits` view a string yields is walked element by element — a
  /// literal written this way measured 78 ns against 117 ns per call.
  void writeCodeUnits(Uint16List units) {
    _materialize();
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void fill(int codeUnit, int count) {
    if (count <= 0) return;
    _materialize();
    if (_isWeb) {
      _text!.write(String.fromCharCode(codeUnit) * count);
      _length += count;
      return;
    }
    _ensure(count);
    _buffer.fillRange(_length, _length + count, codeUnit);
    _length += count;
  }

  /// Counts the digits of |value| in [radix]. Runs in negative space, so the
  /// minimum int does not overflow, and uses division only, which is also
  /// exact on dart2js within the web-safe integer range.
  static int digitCount(int value, int radix) {
    var negative = value <= 0 ? value : -value;
    var count = 1;
    while (negative <= -radix) {
      negative = negative ~/ radix;
      count++;
    }
    return count;
  }

  /// Writes the digits of |value| in [radix].
  void writeMagnitude(int value, int radix, {bool uppercase = false}) {
    _materialize();
    if (_isWeb) {
      // Callers route anything past the web-safe range through BigInt before
      // reaching here, so negating is exact and toRadixString is faithful.
      final digits = (value < 0 ? -value : value).toRadixString(radix);
      _text!.write(uppercase ? digits.toUpperCase() : digits);
      _length += digits.length;
      return;
    }
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

  /// The length [writeGroupedMagnitude] writes for [digits] digits: one
  /// separator before every group after the first.
  static int groupedLength(int digits, int groupSize) =>
      digits + (digits - 1) ~/ groupSize;

  /// Writes the digits of |value| in [radix] behind [leadingZeros] zeros,
  /// with [separator] between groups of [groupSize] digits from the right.
  ///
  /// The zeros are grouped along with the digits rather than padded around
  /// them, which is what `{:010,d}` asks for: the separators fall where they
  /// would if the number really had that many digits.
  void writeGroupedMagnitude(
    int value,
    int radix,
    int separator,
    int groupSize, {
    int leadingZeros = 0,
    bool uppercase = false,
  }) {
    _materialize();
    final significant = digitCount(value, radix);
    final count = significant + leadingZeros;
    final total = groupedLength(count, groupSize);
    if (_isWeb) {
      // Above the web-safe range callers take the BigInt branch, so negating
      // and converting stay exact here.
      final magnitude = (value < 0 ? -value : value).toRadixString(radix);
      _text!.write(
        _groupAscii(
          (uppercase ? magnitude.toUpperCase() : magnitude).padLeft(count, '0'),
          separator,
          groupSize,
        ),
      );
      _length += total;
      return;
    }
    _ensure(total);
    final digits = uppercase ? _upperDigits : _lowerDigits;
    var negative = value <= 0 ? value : -value;
    var index = _length + total;
    _length = index;
    for (var written = 0; written < count; written++) {
      if (written > 0 && written % groupSize == 0) {
        _buffer[--index] = separator;
      }
      if (written < significant) {
        _buffer[--index] = digits.codeUnitAt(-negative.remainder(radix));
        negative = negative ~/ radix;
      } else {
        _buffer[--index] = 0x30;
      }
    }
  }

  /// Writes [leadingZeros] zeros, then `text`, with [separator] between
  /// groups of [groupSize] characters counted back from [digitEnd].
  ///
  /// Only the digits before [digitEnd] are grouped; the rest of [text] — a
  /// fraction, an exponent — is copied through.
  void writeGroupedBody(
    String text,
    int digitEnd,
    int separator,
    int groupSize, {
    int leadingZeros = 0,
  }) {
    _materialize();
    final count = digitEnd + leadingZeros;
    final total = groupedLength(count, groupSize) + (text.length - digitEnd);
    if (_isWeb) {
      final buffer = StringBuffer();
      _writeGroupedBodyUnits(
        text,
        digitEnd,
        separator,
        groupSize,
        leadingZeros,
        buffer.writeCharCode,
      );
      _text!.write(buffer);
      _length += total;
      return;
    }
    _ensure(total);
    var index = _length;
    _writeGroupedBodyUnits(text, digitEnd, separator, groupSize, leadingZeros, (
      unit,
    ) {
      _buffer[index++] = unit;
    });
    _length = index;
  }

  static void _writeGroupedBodyUnits(
    String text,
    int digitEnd,
    int separator,
    int groupSize,
    int leadingZeros,
    void Function(int unit) write,
  ) {
    final count = digitEnd + leadingZeros;
    for (var written = 0; written < count; written++) {
      write(
        written < leadingZeros ? 0x30 : text.codeUnitAt(written - leadingZeros),
      );
      final remaining = count - 1 - written;
      if (remaining > 0 && remaining % groupSize == 0) write(separator);
    }
    for (var index = digitEnd; index < text.length; index++) {
      write(text.codeUnitAt(index));
    }
  }

  static String _groupAscii(String digits, int separator, int groupSize) {
    final remainder = digits.length % groupSize;
    final first = remainder == 0 ? groupSize : remainder;
    final buffer = StringBuffer(digits.substring(0, first));
    final separatorText = String.fromCharCode(separator);
    for (var start = first; start < digits.length; start += groupSize) {
      buffer
        ..write(separatorText)
        ..write(digits.substring(start, start + groupSize));
    }

    return buffer.toString();
  }

  @override
  String toString() =>
      _single ??
      (_isWeb ? _text!.toString() : String.fromCharCodes(_buffer, 0, _length));
}
