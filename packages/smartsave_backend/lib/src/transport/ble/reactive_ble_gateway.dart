import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'ble_gateway.dart';

/// [BleGateway] implementation backed by `flutter_reactive_ble`.
final class ReactiveBleGateway implements BleGateway {
  /// Creates a gateway around [ble].
  ///
  /// [timerFactory] overrides scan timeout timers, primarily for testing.
  ReactiveBleGateway([
    FlutterReactiveBle? ble,
    Timer Function(Duration, void Function())? timerFactory,
  ]) : _providedBle = ble,
       _timerFactory =
           timerFactory ?? ((duration, callback) => Timer(duration, callback));

  final FlutterReactiveBle? _providedBle;
  final Timer Function(Duration, void Function()) _timerFactory;
  FlutterReactiveBle? _lazyBle;
  FlutterReactiveBle get _ble =>
      _lazyBle ??= _providedBle ?? FlutterReactiveBle();

  @override
  Stream<BleAdapterStatus> get statusStream => _ble.statusStream.map(_status);

  @override
  Stream<BleScanResult> scan({
    required String serviceUuid,
    required Duration timeout,
  }) {
    final controller = StreamController<BleScanResult>();
    StreamSubscription<DiscoveredDevice>? subscription;
    Timer? timer;

    controller
      ..onListen = () {
        timer = _timerFactory(timeout, () {
          final activeSubscription = subscription;
          if (activeSubscription == null) {
            unawaited(controller.close());
            return;
          }
          unawaited(controller.close());
          unawaited(
            activeSubscription.cancel().then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {
                Zone.current.handleUncaughtError(error, stack);
              },
            ),
          );
        });
        subscription = _ble
            .scanForDevices(
              withServices: <Uuid>[Uuid.parse(serviceUuid)],
              scanMode: ScanMode.lowLatency,
            )
            .listen(
              (device) => controller.add(
                BleScanResult(id: device.id, name: device.name),
              ),
              onError: controller.addError,
              onDone: () {
                timer?.cancel();
                unawaited(controller.close());
              },
            );
      }
      ..onCancel = () async {
        timer?.cancel();
        await subscription?.cancel();
      };

    return controller.stream;
  }

  @override
  Stream<BleConnectionState> connect(
    String deviceId, {
    required Duration timeout,
  }) => _ble
      .connectToDevice(id: deviceId, connectionTimeout: timeout)
      .map(
        (update) => switch (update.connectionState) {
          DeviceConnectionState.connecting => BleConnectionState.connecting,
          DeviceConnectionState.connected => BleConnectionState.connected,
          DeviceConnectionState.disconnected => BleConnectionState.disconnected,
          DeviceConnectionState.disconnecting =>
            BleConnectionState.disconnected,
        },
      );

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
  }) => _ble.subscribeToCharacteristic(
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
  }) => _ble.writeCharacteristicWithoutResponse(
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
      value.expanded == Uuid.parse(expected).expanded;
}
