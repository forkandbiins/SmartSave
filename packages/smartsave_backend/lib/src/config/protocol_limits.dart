/// Protocol constants shared with the SmartSave firmware.
final class ProtocolLimits {
  const ProtocolLimits._();

  /// Protocol version implemented by the firmware.
  static const int protoVersion = 1;
  /// Number of digits in a PIN.
  static const int pinLength = 4;
  /// Largest balance accepted by the firmware.
  static const int maxTotal = 99999;
  /// Number of unacknowledged coins retained for replay.
  static const int replayBufferSize = 32;
  /// Number of failed PIN attempts before lockout.
  static const int maxFailedPins = 3;
  /// Duration of a PIN lockout.
  static const Duration lockoutDuration = Duration(seconds: 30);
  /// Duration before an unlocked bank automatically relocks.
  static const Duration autoRelockDuration = Duration(seconds: 30);
  /// Largest uint16 sequence number.
  static const int maxSeq = 65535;
  /// Maximum outbound protocol line length, excluding its newline.
  static const int maxOutboundLineChars = 19;
  /// Maximum BLE write size in bytes.
  static const int maxBleWriteBytes = 20;
  /// Maximum accepted inbound line length, excluding its newline.
  static const int maxInboundLineCharsAccepted = 23;
  /// Denominations emitted by the firmware.
  static const List<int> validDenominations = <int>[1, 5, 10, 20];
}
