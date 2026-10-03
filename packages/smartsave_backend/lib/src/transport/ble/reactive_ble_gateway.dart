import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'ble_gateway.dart';

/// [BleGateway] implementation backed by `flutter_reactive_ble`.
final class ReactiveBleGateway implements BleGateway {
  /// Creates a gateway around [ble].
  ReactiveBleGateway([FlutterReactiveBle? ble]) : _providedBle = ble;

  final FlutterReactiveBle? _providedBle;
  FlutterReactiveBle? _lazyBle;
  FlutterReactiveBle get _ble => _lazyBle ??= _providedBle ?? FlutterReactiveBle();

  @override
  Stream<BleAdapterStatus> get statusStream => _ble.statusStream.map(_status);

  @override
  Stream<BleScanResult> scan({
    required List<String> namePrefixes,
    required Duration timeout,
  }) async* {
    final stream = _ble
        .scanForDevices(
          withServices: const <Uuid>[],
          scanMode: ScanMode.lowLatency,
        )
        .timeout(timeout, onTimeout: (sink) => sink.close());
    await for (final device in stream) {
      if (namePrefixes.any(device.name.startsWith)) {
        yield BleScanResult(id: device.id, name: device.name);
      }
    }
  }

  @override
  Stream<BleConnectionState> connect(
    String deviceId, {
    required Duration timeout,
  }) =>
      _ble
          .connectToDevice(
            id: deviceId,
            connectionTimeout: timeout,
          )
          .map((update) => switch (update.connectionState) {
                DeviceConnectionState.connecting =>
                  BleConnectionState.connecting,
                DeviceConnectionState.connected => BleConnectionState.connected,
                DeviceConnectionState.disconnected =>
                  BleConnectionState.disconnected,
                DeviceConnectionState.disconnecting =>
                  BleConnectionState.disconnected,
              });

  @override
  Future<bool> verifyServiceAndCharacteristic(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    try {
      final services = await _ble.getDiscoveredServices(deviceId);
      final service = services.cast<Service?>().firstWhere(
            (item) => _sameUuid(item!.id, serviceUuid),
            orElse: () => null,
          );
      if (service == null) return false;
      return service.characteristics.any(
        (item) => _sameUuid(item.id, characteristicUuid),
      );
    } on Object {
      return false;
    }
  }

  @override
  Stream<List<int>> notifications(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) =>
      _ble.subscribeToCharacteristic(
        QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
      );

  @override
  Future<void> writeWithoutResponse(
    String deviceId,
    List<int> value, {
    required String serviceUuid,
    required String characteristicUuid,
  }) =>
      _ble.writeCharacteristicWithoutResponse(
        QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: value,
      );

  @override
  Future<void> disconnect(String deviceId) => _ble.deinitialize();

  static BleAdapterStatus _status(BleStatus status) => switch (status) {
        BleStatus.poweredOff => BleAdapterStatus.poweredOff,
        BleStatus.unauthorized => BleAdapterStatus.unauthorized,
        BleStatus.unsupported => BleAdapterStatus.unsupported,
        BleStatus.ready => BleAdapterStatus.ready,
        BleStatus.locationServicesDisabled => BleAdapterStatus.unauthorized,
        BleStatus.unknown => BleAdapterStatus.unauthorized,
      };

  static bool _sameUuid(Uuid value, String expected) =>
      value.toString().toUpperCase() == expected.toUpperCase();
}
