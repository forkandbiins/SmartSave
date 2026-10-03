import '../models/denomination.dart';

/// An unsolicited event reported by the bank client.
sealed class DeviceEvent {
  const DeviceEvent();
}

/// A coin was detected by the bank.
final class CoinDetected extends DeviceEvent {
  /// Creates a coin event.
  const CoinDetected(this.denomination, this.seq);
  /// Coin denomination.
  final Denomination denomination;
  /// Device sequence number.
  final int seq;
}

/// The bank reported a total.
final class TotalReported extends DeviceEvent {
  /// Creates a total event.
  const TotalReported(this.total);
  /// Reported total.
  final int total;
}

/// The bank lock state changed.
final class LockChanged extends DeviceEvent {
  /// Creates a lock event.
  const LockChanged(this.locked, {this.unsolicited = false});
  /// Whether the bank is locked.
  final bool locked;
  /// Whether this line was not a command reply.
  final bool unsolicited;
}

/// The bank reported that no PIN is configured.
final class PinNotSetDetected extends DeviceEvent {
  /// Creates a PIN-not-set event.
  const PinNotSetDetected();
}

/// A malformed protocol line was received.
final class MalformedLine extends DeviceEvent {
  /// Creates a malformed-line event.
  const MalformedLine(this.raw);
  /// Raw line.
  final String raw;
}

/// The transport connection was lost.
final class LinkLost extends DeviceEvent {
  /// Creates a link-lost event.
  const LinkLost();
}
