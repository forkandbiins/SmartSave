import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/errors/smartsave_error.dart';
import 'package:smartsave_backend/src/models/discovered_bank.dart';
import 'package:smartsave_backend/src/transport/ble/ble_gateway.dart';
import 'package:smartsave_backend/src/transport/ble/hm10_ble_transport.dart';
import 'package:smartsave_backend/src/transport/device_transport.dart';

void main() {
  test('serializes newline-terminated BLE writes into 20-byte chunks', () async {
    final gateway = _FakeBleGateway();
    final transport = Hm10BleTransport(gateway);
    await transport.connect(const DiscoveredBank(id: 'bank', name: 'HMSoft'));

    await Future.wait([
      transport.writeLine('a' * 44),
      transport.writeLine('b' * 44),
    ]);

    expect(
      gateway.writes.map(utf8.decode).toList(),
      <String>[
        'a' * 20,
        'a' * 20,
        'aaaa\n',
        'b' * 20,
        'b' * 20,
        'bbbb\n',
      ],
    );
    await transport.dispose();
  });

  test('discovers service advertisers without relying on their name', () async {
    final gateway = _FakeBleGateway()
      ..scanResult = const BleScanResult(id: 'bank', name: '');
    final transport = Hm10BleTransport(gateway);

    expect(await transport.scan().toList(), [
      const DiscoveredBank(id: 'bank', name: ''),
    ]);
    expect(gateway.scannedServiceUuid, 'FFE0');
    await transport.dispose();
  });

  test('assembles notification fragments into complete lines', () async {
    final gateway = _FakeBleGateway();
    final transport = Hm10BleTransport(gateway);
    await transport.connect(const DiscoveredBank(id: 'bank', name: 'HMSoft'));
    final lines = <String>[];
    final subscription = transport.lines.listen(lines.add);

    gateway.notificationsController
      ..add(utf8.encode('COIN:5,'))
      ..add(utf8.encode('1\nTOT'))
      ..add(utf8.encode('AL:5\n'));
    await Future<void>.delayed(Duration.zero);

    expect(lines, ['COIN:5,1', 'TOTAL:5']);
    await subscription.cancel();
    await transport.dispose();
  });

  test('missing characteristic is reported as serviceNotFound', () async {
    final gateway = _FakeBleGateway()..hasCharacteristic = false;
    final transport = Hm10BleTransport(gateway);

    await expectLater(
      transport.connect(const DiscoveredBank(id: 'bank', name: 'HMSoft')),
      throwsA(
        isA<ConnectionError>().having(
          (error) => error.code,
          'code',
          SmartSaveErrorCode.serviceNotFound,
        ),
      ),
    );
    await transport.dispose();
  });

  test('disconnect emits disconnected and ignores later notifications', () async {
    final gateway = _FakeBleGateway();
    final transport = Hm10BleTransport(gateway);
    final states = <TransportState>[];
    final lines = <String>[];
    final stateSubscription = transport.state.listen(states.add);
    final lineSubscription = transport.lines.listen(lines.add);
    await transport.connect(const DiscoveredBank(id: 'bank', name: 'HMSoft'));

    gateway.connectionController.add(BleConnectionState.disconnected);
    await Future<void>.delayed(Duration.zero);
    gateway.notificationsController.add(utf8.encode('PING\n'));
    await Future<void>.delayed(Duration.zero);

    expect(states, [TransportState.connecting, TransportState.connected,
      TransportState.disconnected]);
    expect(lines, isEmpty);
    await stateSubscription.cancel();
    await lineSubscription.cancel();
    await transport.dispose();
  });
}

final class _FakeBleGateway implements BleGateway {
  final statusController = StreamController<BleAdapterStatus>.broadcast();
  final connectionController = StreamController<BleConnectionState>.broadcast();
  final notificationsController = StreamController<List<int>>.broadcast();
  final writes = <List<int>>[];
  bool hasCharacteristic = true;
  String? scannedServiceUuid;
  BleScanResult scanResult = const BleScanResult(id: 'bank', name: 'HMSoft');

  @override
  Stream<BleAdapterStatus> get statusStream => statusController.stream;

  @override
  Stream<BleScanResult> scan({
    required String serviceUuid,
    required Duration timeout,
  }) async* {
    scannedServiceUuid = serviceUuid;
    yield scanResult;
  }

  @override
  Stream<BleConnectionState> connect(
    String deviceId, {
    required Duration timeout,
  }) {
    scheduleMicrotask(
      () => connectionController.add(BleConnectionState.connected),
    );
    return connectionController.stream;
  }

  @override
  Future<bool> verifyServiceAndCharacteristic(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async =>
      hasCharacteristic;

  @override
  Stream<List<int>> notifications(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) =>
      notificationsController.stream;

  @override
  Future<void> writeWithoutResponse(
    String deviceId,
    List<int> value, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    writes.add(List.unmodifiable(value));
  }

  @override
  Future<void> disconnect(String deviceId) async {}
}
