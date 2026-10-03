import '../models/device_snapshot.dart';
import 'device_event.dart';

/// Result of the HELLO handshake.
final class HandshakeResult {
  /// Creates a handshake result.
  const HandshakeResult(this.protocolVersion, this.pinSet);
  /// Negotiated protocol version.
  final int protocolVersion;
  /// Whether the bank has a configured PIN.
  final bool pinSet;
}

/// Result of a successful unlock.
final class UnlockOutcome {
  /// Creates an unlock result.
  const UnlockOutcome(this.newTotal);
  /// Balance reported immediately before `LOCK:0`.
  final int newTotal;
}

/// Typed operations available on a connected bank.
abstract interface class DeviceClient {
  /// Unsolicited typed device events.
  Stream<DeviceEvent> get events;
  /// Performs the protocol handshake.
  Future<HandshakeResult> handshake();
  /// Authenticates with [pin].
  Future<void> authenticate(String pin);
  /// Sets the initial PIN.
  Future<void> setInitialPin(String pin);
  /// Changes the PIN.
  Future<void> changePin(String oldPin, String newPin);
  /// Synchronizes the device snapshot.
  Future<DeviceSnapshot> sync();
  /// Sends a cumulative acknowledgement.
  void ack(int seq);
  /// Locks the bank.
  Future<void> lock();
  /// Unlocks and deducts [amount].
  Future<UnlockOutcome> unlock(String pin, int amount);
  /// Sets a new device total.
  Future<int> adjustTotal(String pin, int newTotal);
  /// Pings the bank.
  Future<void> ping();
}
