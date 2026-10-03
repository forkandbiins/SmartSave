import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  test('mock mode works end to end through redemption and auto-relock',
      () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final backend = SmartSaveBackend.create(
      SmartSaveConfig.mock(profile: SimulatorProfileName.demo),
      clock: clock,
    );
    await backend.initialize();
    final controller = backend.controller;
    final events = <SmartSaveEvent>[];
    controller.events.listen(events.add);

    final banks = await controller.scan();
    expect(banks.valueOrNull, hasLength(1));
    expect(
      (await controller.connect(banks.valueOrNull!.single)).isSuccess,
      isTrue,
    );
    expect(controller.state.link, LinkState.ready);
    expect(controller.state.auth, AuthState.loggedOut);
    expect(controller.state.deviceTotal, 1250);

    expect((await controller.login('1234')).isSuccess, isTrue);
    backend.mockControls!.dropCoin(Denomination.php5);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.deviceTotal, 1255);
    expect(events.whereType<CoinReceived>(), hasLength(1));

    final goal = (await controller.createGoal('Trip', 300)).valueOrNull!;
    expect((await controller.allocateToGoal(goal.id, 300)).isSuccess, isTrue);
    expect((await controller.redeemGoal(goal.id, '1234')).isSuccess, isTrue);
    expect(controller.state.lock, LockState.unlocked);
    expect(controller.state.deviceTotal, 955);
    expect(controller.state.goals.single.status, GoalStatus.redeemed);
    expect(
      controller.state.transactions.any(
        (transaction) => transaction.type == TransactionType.redemption &&
            transaction.amount == -300,
      ),
      isTrue,
    );

    clock.advance(const Duration(seconds: 30));
    backend.mockControls!.simulator.tick();
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<AutoRelocked>(), hasLength(1));
    await backend.dispose();
  });

  test('fresh bank setup and wrong PIN lockout are reflected in state',
      () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final backend = SmartSaveBackend.create(
      SmartSaveConfig.mock(),
      clock: clock,
    );
    await backend.initialize();
    final controller = backend.controller;
    final bank = (await controller.scan()).valueOrNull!.single;
    await controller.connect(bank);
    expect(controller.state.auth, AuthState.pinNotSet);
    expect((await controller.setInitialPin('4321')).isSuccess, isTrue);
    expect(controller.state.auth, AuthState.loggedIn);
    await controller.logout();
    for (var i = 0; i < 3; i++) {
      final result = await controller.login('0000');
      expect(result.errorOrNull?.code, SmartSaveErrorCode.wrongPin);
    }
    expect(controller.state.auth, AuthState.lockedOut);
    expect(
      controller.state.lockoutEndsAt,
      clock.now().add(const Duration(seconds: 30)),
    );
    await backend.dispose();
  });

  test('privileged invalid actions never throw and link loss clears session',
      () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final backend = SmartSaveBackend.create(
      SmartSaveConfig.mock(profile: SimulatorProfileName.demo),
      clock: clock,
    );
    await backend.initialize();
    final controller = backend.controller;
    final goal = await controller.createGoal('Nope', 1);
    expect(
      (await controller.redeemGoal(goal.valueOrNull!.id, '1234')).errorOrNull,
      isA<AuthError>(),
    );
    expect((await controller.adjustBalance('1234', 10)).errorOrNull,
        isA<AuthError>());
    expect((await controller.changePin('5678')).errorOrNull, isA<AuthError>());
    expect((await controller.lockBank()).isSuccess, isFalse);
    await controller.connect((await controller.scan()).valueOrNull!.single);
    await controller.login('1234');
    await backend.mockControls!.simulateLinkLoss();
    expect(controller.state.link, LinkState.disconnected);
    expect(controller.state.auth, AuthState.loggedOut);
    expect((await controller.redeemGoal(goal.valueOrNull!.id, '1234')).errorOrNull,
        isA<AuthError>());
    await backend.dispose();
  });

  test('BLE mode can be composed without hardware', () async {
    final backend = SmartSaveBackend.create(SmartSaveConfig.ble());
    expect(backend.mockControls, isNull);
    await backend.dispose();
  });
}
