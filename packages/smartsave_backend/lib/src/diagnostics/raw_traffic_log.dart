import 'dart:async';

import '../util/clock.dart';
import 'logger.dart';

/// One redacted line exchanged with the device.
final class RawTrafficEntry {
  /// Creates a traffic entry.
  const RawTrafficEntry({
    required this.timestamp,
    required this.direction,
    required this.line,
  });

  /// Time at which the line was recorded.
  final DateTime timestamp;

  /// Either `tx` or `rx`.
  final String direction;

  /// PIN-redacted protocol line.
  final String line;
}

/// A bounded observable log of recent device traffic.
final class RawTrafficLog {
  /// Creates a log retaining at most [capacity] entries.
  RawTrafficLog(this.clock, {this.capacity = 200});

  /// Clock used for entry timestamps.
  final Clock clock;

  /// Maximum retained entries.
  final int capacity;

  final _entries = <RawTrafficEntry>[];
  final _stream = StreamController<RawTrafficEntry>.broadcast(sync: true);

  /// Newly recorded traffic entries.
  Stream<RawTrafficEntry> get stream => _stream.stream;

  /// Records a redacted line.
  void add(String direction, String line) {
    final entry = RawTrafficEntry(
      timestamp: clock.now(),
      direction: direction,
      line: redactPin(line),
    );
    _entries.add(entry);
    if (_entries.length > capacity) _entries.removeAt(0);
    _stream.add(entry);
  }

  /// Returns entries from oldest to newest.
  List<RawTrafficEntry> snapshot() => List.unmodifiable(_entries);

  /// Releases stream resources.
  Future<void> dispose() => _stream.close();
}
