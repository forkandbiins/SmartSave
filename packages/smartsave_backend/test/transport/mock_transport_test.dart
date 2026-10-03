import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/models/discovered_bank.dart';
import 'package:smartsave_backend/src/transport/device_transport.dart';
import 'package:smartsave_backend/src/transport/mock/fake_device_simulator.dart';
import 'package:smartsave_backend/src/transport/mock/mock_transport.dart';
import 'package:smartsave_backend/src/transport/mock/simulator_profile.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  test('does not deliver simulator output while disconnected', () async {
    final simulator = FakeDeviceSimulator(
      FakeClock(DateTime.utc(2026)),
      Random(1),
      SimulatorProfile.fresh,
    );
    final transport = MockTransport(simulator, autoTick: false);
    final lines = <String>[];
    final subscription = transport.lines.listen(lines.add);
    await transport.writeLine('PING');
    expect(lines, isEmpty);
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    await transport.writeLine('PING');
    expect(lines, ['PONG']);
    await subscription.cancel();
    await transport.dispose();
  });

  test('scan and zero-latency state transitions work', () async {
    final simulator = FakeDeviceSimulator(
      FakeClock(DateTime.utc(2026)),
      Random(1),
      SimulatorProfile.fresh,
    );
    final transport = MockTransport(simulator, autoTick: false);
    expect(await transport.scan().toList(), [
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    ]);
    final states = <TransportState>[];
    final subscription = transport.state.listen(states.add);
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    await transport.disconnect();
    expect(states, [
      TransportState.connecting,
      TransportState.connected,
      TransportState.disconnected,
    ]);
    await subscription.cancel();
    await transport.dispose();
  });
}
