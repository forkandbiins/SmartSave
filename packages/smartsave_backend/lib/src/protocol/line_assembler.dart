import 'dart:convert';

/// Converts arbitrary byte or string chunks into newline-delimited lines.
final class LineAssembler {
  /// Creates an assembler with a maximum line length.
  LineAssembler({this.maxLineLength = 64});

  /// Maximum number of characters retained per line.
  final int maxLineLength;
  final StringBuffer _buffer = StringBuffer();
  bool _discarding = false;
  int _droppedLines = 0;

  /// Number of overlong lines discarded so far.
  int get droppedLines => _droppedLines;

  /// Adds UTF-8 bytes and returns all complete non-empty lines.
  List<String> addBytes(List<int> bytes) =>
      addString(utf8.decode(bytes, allowMalformed: true));

  /// Adds text and returns all complete non-empty lines.
  List<String> addString(String chunk) {
    final lines = <String>[];
    for (final character in chunk.runes) {
      if (character == 10) {
        if (_discarding) {
          _droppedLines++;
        } else if (_buffer.isNotEmpty) {
          lines.add(_buffer.toString());
        }
        _buffer.clear();
        _discarding = false;
        continue;
      }
      if (character == 13) continue;
      if (_discarding) continue;
      _buffer.writeCharCode(character);
      if (_buffer.length > maxLineLength) {
        _buffer.clear();
        _discarding = true;
      }
    }
    return lines;
  }

  /// Discards any partial line and clears assembler state.
  void reset() {
    _buffer.clear();
    _discarding = false;
  }
}
