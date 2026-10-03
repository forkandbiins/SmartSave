import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

final class ScenarioHarness {
  ScenarioHarness({
    SimulatorProfileName profile = SimulatorProfileName.fresh,
    InMemoryStore? store,
    FakeClock? clock,
    MockBank? bank,
  })  : clock = clock ?? FakeClock(DateTime.utc(2026, 10, 3)),
        store = store ?? InMemoryStore(),
        bank = bank {
    backend = bank == null
        ? SmartSaveBackend.create(
            SmartSaveConfig.mock(profile: profile),
            clock: this.clock,
            store: this.store,
          )
        : createMockBackend(
            SmartSaveConfig.mock(profile: profile),
            this.bank!,
            clock: this.clock,
            store: this.store,
          );
  }

  final FakeClock clock;
  final InMemoryStore store;
  final MockBank? bank;
  late final SmartSaveBackend backend;

  SmartSaveController get controller => backend.controller;
  MockControls get controls => backend.mockControls!;

  Future<void> initializeAndConnect() async {
    await backend.initialize();
    final banks = (await controller.scan()).valueOrNull!;
    expect(banks, hasLength(1));
    expect((await controller.connect(banks.single)).isSuccess, isTrue);
  }

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.value();
    }
  }

  Future<void> dispose() => backend.dispose();
}
