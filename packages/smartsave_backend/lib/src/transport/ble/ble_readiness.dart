/// The current Bluetooth readiness state.
enum BluetoothReadiness {
  /// Bluetooth is available.
  ready,
  /// Bluetooth is disabled.
  bluetoothOff,
  /// Runtime permission was denied.
  permissionDenied,
  /// Permission was permanently denied.
  permanentlyDenied,
  /// Bluetooth is unsupported.
  unsupported,
}

/// Provides Bluetooth readiness information.
abstract interface class BluetoothReadinessProvider {
  /// Returns the current readiness state.
  Future<BluetoothReadiness> check();
}

/// Readiness provider used by mock mode.
final class MockReadinessProvider implements BluetoothReadinessProvider {
  /// Creates an always-ready provider.
  const MockReadinessProvider();

  @override
  Future<BluetoothReadiness> check() async => BluetoothReadiness.ready;
}
