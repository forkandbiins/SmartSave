import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/config/smartsave_config.dart';
import 'package:smartsave_backend/src/device/device_event.dart';
import 'package:smartsave_backend/src/device/protocol_device_client.dart';
import 'package:smartsave_backend/src/diagnostics/logger.dart';
import 'package:smartsave_backend/src/errors/smartsave_error.dart';
import 'package:smartsave_backend/src/models/discovered_bank.dart';
import 'package:smartsave_backend/src/transport/mock/fake_device_simulator.dart';
import 'package:smartsave_backend/src/transport/mock/mock_transport.dart';
import 'package:smartsave_backend/src/transport/mock/simulator_profile.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  late FakeClock clock;
  late FakeDeviceSimulator simulator;
  late MockTransport transport;
  late ProtocolDeviceClient client;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026));
    simulator = FakeDeviceSimulator(clock, Random(1), SimulatorProfile.fresh);
    transport = MockTransport(simulator, autoTick: false);
    client = ProtocolDeviceClient(
      transport,
      null,
      SmartSaveConfig.mock(),
      clock,
      const NoopLogger(),
    );
  });

  tearDown(() async {
    await client.dispose();
    await transport.dispose();
  });

  Future<void> connect() => transport.connect(
        const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
      );

  test('handshake reports fresh and demo PIN state', () async {
    await connect();
    expect((await client.handshake()).pinSet, isFalse);
    simulator.factoryReset();
    simulator.receiveLine('SETPIN:1234');
    final demoClient = ProtocolDeviceClient(
      transport,
      null,
      SmartSaveConfig.mock(),
      clock,
      const NoopLogger(),
    );
    expect((await demoClient.handshake()).pinSet, isTrue);
    await demoClient.dispose();
  });

  test('authentication maps failures and emits coin events', () async {
    await connect();
    await client.setInitialPin('1234');
    final events = <DeviceEvent>[];
    final subscription = client.events.listen(events.add);
    final pending = client.authenticate('1234');
    simulator.dropCoin(5);
    await pending;
    expect(events.whereType<CoinDetected>(), hasLength(1));
    await subscription.cancel();
  });

  test('wrong PIN lockout carries the injected deadline', () async {
    await connect();
    await client.setInitialPin('1234');
    for (var i = 0; i < 3; i++) {
      await expectLater(
        client.authenticate('0000'),
        throwsA(isA<AuthError>()),
      );
    }
    try {
      await client.authenticate('1234');
      fail('expected lockout');
    } on AuthError catch (error) {
      expect(error.code, SmartSaveErrorCode.lockedOut);
      expect(error.until, clock.now().add(const Duration(seconds: 30)));
    }
  });

  test('sync returns demo replay snapshot', () async {
    await connect();
    final demoSimulator =
        FakeDeviceSimulator(clock, Random(1), SimulatorProfile.demo);
    final demoTransport = MockTransport(demoSimulator, autoTick: false);
    final demoClient = ProtocolDeviceClient(
      demoTransport,
      null,
      SmartSaveConfig.mock(),
      clock,
      const NoopLogger(),
    );
    await demoTransport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    final snapshot = await demoClient.sync();
    expect(snapshot.total, 1250);
    expect(snapshot.deviceSeq, 12);
    expect(snapshot.replayedCoins.map((coin) => coin.seq), [9, 10, 11, 12]);
    await demoClient.dispose();
    await demoTransport.dispose();
  });

  test('commands execute FIFO', () async {
    await connect();
    await client.setInitialPin('1234');
    final futures = <Future<void>>[
      client.authenticate('1234'),
      client.ping(),
      client.lock(),
    ];
    await Future.wait(futures);
    expect(simulator.locked, isTrue);
  });

  test('link loss fails pending sync and emits LinkLost', () async {
    await connect();
    final events = <DeviceEvent>[];
    final subscription = client.events.listen(events.add);
    final future = client.sync();
    await transport.disconnect();
    try {
      await future;
      fail('expected connection loss');
    } on ConnectionError {
      // Expected.
    }
    expect(events.whereType<LinkLost>(), hasLength(1));
    await subscription.cancel();
  });
}
