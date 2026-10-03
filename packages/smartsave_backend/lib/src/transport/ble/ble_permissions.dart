import 'package:permission_handler/permission_handler.dart';

import 'ble_gateway.dart';
import 'ble_readiness.dart';

/// Permission categories requested by the Bluetooth readiness provider.
enum BlePermissionKind {
  /// Android Bluetooth scan permission.
  bluetoothScan,
  /// Android Bluetooth connection permission.
  bluetoothConnect,
  /// Location permission used by older Android versions.
  locationWhenInUse,
}

/// Result of a runtime permission request.
enum BlePermissionStatus {
  /// Permission is granted.
  granted,
  /// Permission is denied but can be requested again.
  denied,
  /// Permission is permanently denied.
  permanentlyDenied,
}

/// Abstract permission requester for the readiness provider.
abstract interface class BlePermissionRequester {
  /// Requests [permission].
  Future<BlePermissionStatus> request(BlePermissionKind permission);
}

final class _PermissionHandlerRequester implements BlePermissionRequester {
  @override
  Future<BlePermissionStatus> request(BlePermissionKind permission) async {
    final result = await switch (permission) {
      BlePermissionKind.bluetoothScan => Permission.bluetoothScan.request(),
      BlePermissionKind.bluetoothConnect => Permission.bluetoothConnect.request(),
      BlePermissionKind.locationWhenInUse =>
        Permission.locationWhenInUse.request(),
    };
    if (result.isGranted) return BlePermissionStatus.granted;
    if (result.isPermanentlyDenied) {
      return BlePermissionStatus.permanentlyDenied;
    }
    return BlePermissionStatus.denied;
  }
}

/// Bluetooth readiness provider for real devices.
final class BlePermissionsProvider implements BluetoothReadinessProvider {
  /// Creates a provider using [gateway] for adapter status.
  BlePermissionsProvider(
    this.gateway, {
    BlePermissionRequester? permissions,
  }) : permissions = permissions ?? _PermissionHandlerRequester();

  /// Gateway that reports adapter status.
  final BleGateway gateway;
  /// Runtime permission requester.
  final BlePermissionRequester permissions;

  @override
  Future<BluetoothReadiness> check() async {
    final scan = await permissions.request(BlePermissionKind.bluetoothScan);
    final connect =
        await permissions.request(BlePermissionKind.bluetoothConnect);
    await permissions.request(BlePermissionKind.locationWhenInUse);

    if (scan == BlePermissionStatus.permanentlyDenied ||
        connect == BlePermissionStatus.permanentlyDenied) {
      return BluetoothReadiness.permanentlyDenied;
    }
    if (scan != BlePermissionStatus.granted ||
        connect != BlePermissionStatus.granted) {
      return BluetoothReadiness.permissionDenied;
    }
    final status = await gateway.statusStream.first;
    return switch (status) {
      BleAdapterStatus.ready => BluetoothReadiness.ready,
      BleAdapterStatus.poweredOff => BluetoothReadiness.bluetoothOff,
      BleAdapterStatus.unauthorized => BluetoothReadiness.permissionDenied,
      BleAdapterStatus.unsupported => BluetoothReadiness.unsupported,
    };
  }
}
