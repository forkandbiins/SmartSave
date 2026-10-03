import 'dart:math';

import '../config/smartsave_config.dart';
import '../transport/mock/simulator_profile.dart';
import '../models/denomination.dart';
import '../transport/mock/fake_device_simulator.dart';
import '../util/clock.dart';

/// A simulated bank that can be reused by multiple testing backends.
final class MockBank {
  /// Creates a simulated bank with [profile] and [clock].
  MockBank({
    required Clock clock,
    SimulatorProfileName profile = SimulatorProfileName.fresh,
  }) : _simulator = FakeDeviceSimulator(
          clock,
          Random(Object.hash(clock, profile)),
          SimulatorProfile.fromName(profile),
        );

  /// The simulated device state.
  final FakeDeviceSimulator _simulator;

  /// Internal handle used by the testing composition root.
  Object get simulatorHandle => _simulator;

  /// Drops a coin while no backend is connected.
  void dropCoin(Denomination denomination) =>
      _simulator.dropCoin(denomination.value);
}
