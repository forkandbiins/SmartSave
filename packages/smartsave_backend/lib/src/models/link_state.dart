/// BLE link lifecycle state.
enum LinkState {
  /// No active connection.
  disconnected,
  /// Scanning for banks.
  scanning,
  /// Connecting to a bank.
  connecting,
  /// Negotiating the protocol.
  handshaking,
  /// Ready for commands.
  ready,
}

/// Synchronization lifecycle state.
enum SyncStatus {
  /// No synchronization is running.
  idle,
  /// Synchronization is in progress.
  syncing,
  /// Last synchronization succeeded.
  synced,
  /// Last synchronization failed.
  failed,
}
