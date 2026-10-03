import 'dart:async';
import 'dart:math';

import '../../models/denomination.dart';
import '../../models/discovered_bank.dart';
import 'fake_device_simulator.dart';
import 'mock_transport.dart';

/// Test controls for a mock bank and its transport.
final class MockControls {
  /// Creates controls around [simulator] and [transport].
  MockControls(this.simulator, this.transport);

  /// Simulator under test.
  final FakeDeviceSimulator simulator;
  /// Transport under test.
  final MockTransport transport;
  Timer? _coinTimer;

  /// Drops one coin into the simulated bank.
  void dropCoin(Denomination denomination) => simulator.dropCoin(denomination.value);

  /// Starts periodic random coin drops.
  void startAutoCoins(Duration interval, {int? seed}) {
    stopAutoCoins();
    final random = Random(seed);
    _coinTimer = Timer.periodic(interval, (_) {
      final denomination =
          Denomination.values[random.nextInt(Denomination.values.length)];
      dropCoin(denomination);
    });
  }

  /// Stops automatic coin drops.
  void stopAutoCoins() {
    _coinTimer?.cancel();
    _coinTimer = null;
  }

  /// Simulates a lost link.
  Future<void> simulateLinkLoss() => transport.disconnect();

  /// Reconnects to the mock bank.
  Future<void> reconnect() => transport.connect(
        const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
      );

  /// Resets the simulated bank.
  void factoryResetBank() => simulator.factoryReset();

  /// Injects a raw line directly into the simulator.
  void injectRawLine(String line) => simulator.receiveLine(line);

  /// Changes transport delivery latency.
  void setLatency(Duration value) => transport.latency = value;

  /// Stops controls and timers.
  void dispose() => stopAutoCoins();
}
