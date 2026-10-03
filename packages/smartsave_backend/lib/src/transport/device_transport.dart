import '../models/discovered_bank.dart';

/// Lifecycle state of a device transport.
enum TransportState {
  /// No active connection.
  disconnected,
  /// Connection is being established.
  connecting,
  /// Connection is active.
  connected,
}

/// Abstract line-oriented device transport.
abstract interface class DeviceTransport {
  /// Transport lifecycle changes.
  Stream<TransportState> get state;

  /// Complete lines received without terminators.
  Stream<String> get lines;

  /// Scans for banks for up to [timeout].
  Stream<DiscoveredBank> scan({Duration timeout});

  /// Connects to [bank].
  Future<void> connect(DiscoveredBank bank);

  /// Disconnects from the current bank.
  Future<void> disconnect();

  /// Writes one line without adding a terminator.
  Future<void> writeLine(String line);

  /// Releases transport resources.
  Future<void> dispose();
}
