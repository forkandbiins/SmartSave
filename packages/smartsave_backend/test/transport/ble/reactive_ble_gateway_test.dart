import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/transport/ble/reactive_ble_gateway.dart';

void main() {
  test(
    'scan ends after its duration while advertisements keep arriving',
    () async {
      var sourceCancelled = false;
      final scanResults = StreamController<DiscoveredDevice>(
        sync: true,
        onCancel: () => sourceCancelled = true,
      );
      final ble = _FakeFlutterReactiveBle(scanResults.stream);
      late _FakeTimer scanTimer;
      Duration? scanDuration;
      final gateway = ReactiveBleGateway(ble, (duration, callback) {
        scanDuration = duration;
        scanTimer = _FakeTimer(callback);
        return scanTimer;
      });

      final resultsFuture = gateway
          .scan(serviceUuid: 'FFE0', timeout: const Duration(seconds: 5))
          .toList();
      scanResults
        ..add(_device)
        ..add(_device);
      scanTimer.fire();

      final results = await resultsFuture;
      expect(results, hasLength(2));
      expect(results.map((result) => (result.id, result.name)).toList(), [
        ('bank', 'SmartSave'),
        ('bank', 'SmartSave'),
      ]);
      expect(scanDuration, const Duration(seconds: 5));
      expect(sourceCancelled, isTrue);
      expect(ble.scannedServices, [Uuid.parse('FFE0')]);
      await scanResults.close();
    },
  );

  test('matches expanded Bluetooth service and characteristic UUIDs', () async {
    final ble = _FakeFlutterReactiveBle(
      const Stream<DiscoveredDevice>.empty(),
      services: [
        _FakeService(
          id: Uuid.parse('0000FFE0-0000-1000-8000-00805F9B34FB'),
          characteristics: [
            _FakeCharacteristic(
              Uuid.parse('0000FFE1-0000-1000-8000-00805F9B34FB'),
            ),
          ],
        ),
      ],
    );
    final gateway = ReactiveBleGateway(ble);

    expect(
      await gateway.verifyServiceAndCharacteristic(
        'bank',
        serviceUuid: 'FFE0',
        characteristicUuid: 'FFE1',
      ),
      isTrue,
    );
  });
}

final _device = DiscoveredDevice(
  id: 'bank',
  name: 'SmartSave',
  serviceUuids: const [],
  serviceData: const {},
  manufacturerData: Uint8List(0),
  rssi: -50,
  connectable: Connectable.unknown,
);

final class _FakeFlutterReactiveBle implements FlutterReactiveBle {
  _FakeFlutterReactiveBle(this.scanResults, {this.services = const []});

  final Stream<DiscoveredDevice> scanResults;
  final List<Service> services;
  List<Uuid>? scannedServices;

  @override
  Stream<DiscoveredDevice> scanForDevices({
    required List<Uuid> withServices,
    ScanMode scanMode = ScanMode.balanced,
    bool requireLocationServicesEnabled = true,
  }) {
    scannedServices = withServices;
    return scanResults;
  }

  @override
  Future<List<Service>> getDiscoveredServices(String deviceId) async =>
      services;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeService implements Service {
  _FakeService({required this.id, required this.characteristics});

  @override
  final Uuid id;

  @override
  final List<Characteristic> characteristics;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeCharacteristic implements Characteristic {
  _FakeCharacteristic(this.id);

  @override
  final Uuid id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  bool _isActive = true;
  int _tick = 0;

  void fire() {
    _isActive = false;
    _tick++;
    _callback();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;
}
