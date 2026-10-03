import 'dart:math';

import 'application/smartsave_controller.dart';
import 'config/smartsave_config.dart';
import 'diagnostics/logger.dart';
import 'device/protocol_device_client.dart';
import 'errors/smartsave_error.dart';
import 'repository/default_smartsave_repository.dart';
import 'storage/in_memory_store.dart';
import 'storage/smartsave_store.dart';
import 'transport/device_transport.dart';
import 'transport/mock/fake_device_simulator.dart';
import 'transport/mock/mock_controls.dart';
import 'transport/mock/mock_transport.dart';
import 'transport/mock/simulator_profile.dart';
import 'util/clock.dart';

/// The SmartSave composition root.
final class SmartSaveBackend {
  SmartSaveBackend._({
    required this.controller,
    required this._transport,
    required this._repository,
    required this.mockControls,
  });

  /// Creates a backend for [config].
  factory SmartSaveBackend.create(
    SmartSaveConfig config, {
    Clock? clock,
    SmartSaveStore? store,
    SmartSaveLogger? logger,
  }) {
    if (config.mode.name == 'ble') {
      throw const SmartSaveStateError.invalidOperation();
    }
    final actualClock = clock ?? SystemClock();
    final actualLogger = logger ?? const NoopLogger();
    final simulator = FakeDeviceSimulator(
      actualClock,
      Random(Object.hash(actualClock, config.simulatorProfile)),
      SimulatorProfile.fromName(config.simulatorProfile),
    );
    final transport = MockTransport(simulator);
    final actualStore = store ?? InMemoryStore();
    final repository = DefaultSmartSaveRepository(
      ProtocolDeviceClient(
        transport,
        null,
        config,
        actualClock,
        actualLogger,
      ),
      actualStore,
      actualClock,
      actualLogger,
    );
    final controls = MockControls(simulator, transport);
    final controller = SmartSaveController(
      config: config,
      clock: actualClock,
      transport: transport,
      repository: repository,
      client: repository.client,
    );
    return SmartSaveBackend._(
      controller: controller,
      transport: transport,
      repository: repository,
      mockControls: controls,
    );
  }

  /// UI-facing controller.
  final SmartSaveController controller;
  final DeviceTransport _transport;
  final DefaultSmartSaveRepository _repository;
  /// Controls for the mock bank, or null for non-mock modes.
  final MockControls? mockControls;

  /// Initializes local persistence.
  Future<void> initialize() => _repository.initialize();

  /// Releases all resources.
  Future<void> dispose() async {
    await controller.dispose();
    await _transport.dispose();
  }
}
