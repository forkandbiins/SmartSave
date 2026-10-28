import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/transport/ble/ble_gateway.dart';
import 'package:smartsave_backend/src/transport/ble/ble_permissions.dart';
import 'package:smartsave_backend/src/transport/ble/ble_readiness.dart';

void main() {
  for (final entry in <(BleAdapterStatus, BluetoothReadiness)>[
    (BleAdapterStatus.poweredOff, BluetoothReadiness.bluetoothOff),
    (BleAdapterStatus.unsupported, BluetoothReadiness.unsupported),
    (BleAdapterStatus.ready, BluetoothReadiness.ready),
  ]) {
    test('${entry.$1} maps to ${entry.$2}', () async {
      final provider = BlePermissionsProvider(
        _FakeGateway(entry.$1),
        permissions: _FakePermissions(),
      );
      expect(await provider.check(), entry.$2);
    });
  }

  test('denied Bluetooth permission maps to permissionDenied', () async {
    final provider = BlePermissionsProvider(
      _FakeGateway(BleAdapterStatus.ready),
      permissions: _FakePermissions(
        statuses: <BlePermissionKind, BlePermissionStatus>{
          BlePermissionKind.bluetoothScan: BlePermissionStatus.denied,
        },
      ),
    );
    expect(await provider.check(), BluetoothReadiness.permissionDenied);
  });

  test('permanently denied Bluetooth permission maps to permanentlyDenied',
      () async {
    final provider = BlePermissionsProvider(
      _FakeGateway(BleAdapterStatus.ready),
      permissions: _FakePermissions(
        statuses: <BlePermissionKind, BlePermissionStatus>{
          BlePermissionKind.bluetoothConnect:
              BlePermissionStatus.permanentlyDenied,
        },
      ),
    );
    expect(await provider.check(), BluetoothReadiness.permanentlyDenied);
  });

  test('denied location is nonfatal when Bluetooth permissions are granted',
      () async {
    final provider = BlePermissionsProvider(
      _FakeGateway(BleAdapterStatus.ready),
      permissions: _FakePermissions(
        statuses: <BlePermissionKind, BlePermissionStatus>{
          BlePermissionKind.locationWhenInUse: BlePermissionStatus.denied,
        },
      ),
    );
    expect(await provider.check(), BluetoothReadiness.ready);
  });
}

final class _FakePermissions implements BlePermissionRequester {
  _FakePermissions({this.statuses = const <BlePermissionKind,
      BlePermissionStatus>{}});

  final Map<BlePermissionKind, BlePermissionStatus> statuses;

  @override
  Future<BlePermissionStatus> request(BlePermissionKind permission) async =>
      statuses[permission] ?? BlePermissionStatus.granted;
}

final class _FakeGateway implements BleGateway {
  _FakeGateway(this.status);

  final BleAdapterStatus status;

  @override
  Stream<BleAdapterStatus> get statusStream async* {
    yield status;
  }

  @override
  Stream<BleScanResult> scan({
    required String serviceUuid,
    required Duration timeout,
  }) async* {}

  @override
  Stream<BleConnectionState> connect(
    String deviceId, {
    required Duration timeout,
  }) async* {}

  @override
  Future<bool> verifyServiceAndCharacteristic(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async =>
      true;

  @override
  Stream<List<int>> notifications(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) =>
      const Stream<List<int>>.empty();

  @override
  Future<void> writeWithoutResponse(
    String deviceId,
    List<int> value, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {}

  @override
  Future<void> disconnect(String deviceId) async {}
}
