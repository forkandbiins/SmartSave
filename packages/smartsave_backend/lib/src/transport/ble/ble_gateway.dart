/// Adapter status reported by a Bluetooth gateway.
enum BleAdapterStatus {
  /// The adapter is powered off.
  poweredOff,
  /// Bluetooth permission is not authorized.
  unauthorized,
  /// Bluetooth is not supported.
  unsupported,
  /// Bluetooth is ready.
  ready,
}

/// A device discovered during a BLE scan.
final class BleScanResult {
  /// Creates a scan result.
  const BleScanResult({required this.id, required this.name});

  /// Platform device identifier.
  final String id;

  /// Advertised device name.
  final String name;
}

/// Connection lifecycle state reported by a gateway.
enum BleConnectionState {
  /// A connection is being established.
  connecting,
  /// The device is connected.
  connected,
  /// The device disconnected.
  disconnected,
}

/// Thin, plugin-independent gateway used by the HM-10 transport.
abstract interface class BleGateway {
  /// Adapter status changes.
  Stream<BleAdapterStatus> get statusStream;

  /// Scans for devices whose names start with one of [namePrefixes].
  Stream<BleScanResult> scan({
    required List<String> namePrefixes,
    required Duration timeout,
  });

  /// Connects to [deviceId] and reports connection state.
  Stream<BleConnectionState> connect(
    String deviceId, {
    required Duration timeout,
  });

  /// Verifies the expected service and characteristic exist.
  Future<bool> verifyServiceAndCharacteristic(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  });

  /// Receives notification payloads from the connected characteristic.
  Stream<List<int>> notifications(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  });

  /// Writes one payload without a response.
  Future<void> writeWithoutResponse(
    String deviceId,
    List<int> value, {
    required String serviceUuid,
    required String characteristicUuid,
  });

  /// Disconnects [deviceId].
  Future<void> disconnect(String deviceId);
}
