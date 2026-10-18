import 'dart:math';

import 'application/smartsave_controller.dart';
import 'application/connection_supervisor.dart';
import 'config/smartsave_config.dart';
import 'diagnostics/logger.dart';
import 'diagnostics/raw_traffic_log.dart';
import 'device/protocol_device_client.dart';
import 'repository/default_smartsave_repository.dart';
import 'storage/in_memory_store.dart';
import 'storage/smartsave_store.dart';
import 'transport/device_transport.dart';
import 'transport/ble/ble_permissions.dart';
import 'transport/ble/ble_readiness.dart';
import 'transport/ble/hm10_ble_transport.dart';
import 'transport/ble/reactive_ble_gateway.dart';
import 'transport/mock/fake_device_simulator.dart';
import 'transport/mock/mock_controls.dart';
import 'transport/mock/mock_transport.dart';
import 'transport/mock/simulator_profile.dart';
import 'testing/mock_bank.dart';
import 'util/clock.dart';

/// The SmartSave composition root.
final class SmartSaveBackend {
  SmartSaveBackend._({
    required this.controller,
    required this._transport,
    required this._repository,
    required this._client,
    required this.mockControls,
    required this.readinessProvider,
    required this.connectionSupervisor,
  });

  /// Creates a backend for [config].
  factory SmartSaveBackend.create(
    SmartSaveConfig config, {
    Clock? clock,
    SmartSaveStore? store,
    SmartSaveLogger? logger,
  }) =>
      _createBackend(config, clock: clock, store: store, logger: logger);

  static SmartSaveBackend _createBackend(
  SmartSaveConfig config, {
  Clock? clock,
  SmartSaveStore? store,
  SmartSaveLogger? logger,
  MockBank? mockBank,
}) {
    final actualClock = clock ?? SystemClock();
    final actualLogger = logger ?? const NoopLogger();
    final rawTraffic = RawTrafficLog(actualClock);
    late final DeviceTransport transport;
    late final MockControls? controls;
    late final BluetoothReadinessProvider readiness;
    if (config.mode.name == 'ble') {
      final gateway = ReactiveBleGateway();
      transport = Hm10BleTransport(
        gateway,
        namePrefixes: config.scanNamePrefixes,
      );
      readiness = BlePermissionsProvider(gateway);
      controls = null;
    } else {
      final simulator = (mockBank?.simulatorHandle as FakeDeviceSimulator?) ??
          FakeDeviceSimulator(
            actualClock,
            Random(Object.hash(actualClock, config.simulatorProfile)),
            SimulatorProfile.fromName(config.simulatorProfile),
          );
      final mockTransport = MockTransport(
        simulator,
        disposeSimulator: mockBank == null,
      );
      transport = mockTransport;
      controls = MockControls(simulator, mockTransport);
      readiness = const MockReadinessProvider();
    }

    final actualStore = store ?? InMemoryStore();
    final client = ProtocolDeviceClient(
      transport,
      null,
      config,
      actualClock,
      actualLogger,
      onTraffic: rawTraffic.add,
    );
    final repository = DefaultSmartSaveRepository(
      client,
      actualStore,
      actualClock,
      actualLogger,
    );
    ConnectionSupervisor? supervisor;
    final controller = SmartSaveController(
      config: config,
      clock: actualClock,
      transport: transport,
      repository: repository,
      client: repository.client,
      readinessProvider: readiness,
      rawTraffic: rawTraffic,
      onBankConnected: (bank) => supervisor?.remember(bank),
      onManualDisconnect: () => supervisor?.manualDisconnect(),
    );
    supervisor = ConnectionSupervisor(
      config: config,
      controller: controller,
      transport: transport,
      clock: actualClock,
    );
    return SmartSaveBackend._(
      controller: controller,
      transport: transport,
      repository: repository,
      mockControls: controls,
      readinessProvider: readiness,
      connectionSupervisor: supervisor,
      client: client,
    );
  }

  /// UI-facing controller.
  final SmartSaveController controller;
  final DeviceTransport _transport;
  final DefaultSmartSaveRepository _repository;
  final ProtocolDeviceClient _client;
  /// Controls for the mock bank, or null for non-mock modes.
  final MockControls? mockControls;
  /// Provider used to check Bluetooth readiness.
  final BluetoothReadinessProvider readinessProvider;
  /// Automatic reconnect supervisor.
  final ConnectionSupervisor connectionSupervisor;

  /// Initializes local persistence.
  Future<void> initialize() => _repository.initialize();

  /// Releases all resources.
  Future<void> dispose() async {
    await connectionSupervisor.dispose();
    await controller.dispose();
    await _client.dispose();
    await _transport.dispose();
  }

}

/// Creates a mock backend around a reusable testing bank.
///
/// This helper is exported only by `testing.dart`.
SmartSaveBackend createMockBackend(
  SmartSaveConfig config,
  MockBank bank, {
  Clock? clock,
  SmartSaveStore? store,
  SmartSaveLogger? logger,
}) =>
    SmartSaveBackend._createBackend(
      config,
      clock: clock,
      store: store,
      logger: logger,
      mockBank: bank,
    );
