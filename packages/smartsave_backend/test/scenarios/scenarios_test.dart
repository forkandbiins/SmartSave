import 'package:flutter_test/flutter_test.dart';
// flutter_test supplies fake_async transitively; scenarios use it without
// adding a production dependency.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

import '../support/scenario_helpers.dart';

void main() {
  test('A: fresh bank records every denomination and matching balance',
      () async {
    final harness = ScenarioHarness();
    await harness.initializeAndConnect();
    expect(harness.controller.state.auth, AuthState.pinNotSet);
    expect((await harness.controller.setInitialPin('4321')).isSuccess, isTrue);
    for (final denomination in Denomination.values) {
      harness.controls.dropCoin(denomination);
    }
    await harness.settle();
    expect(harness.controller.state.deviceTotal, 36);
    expect(
      harness.controller.state.transactions
          .where((transaction) => transaction.type == TransactionType.deposit),
      hasLength(4),
    );
    await harness.dispose();
  });

  test('B: cached coins survive backend restart and remain exactly once',
      () async {
    final store = InMemoryStore();
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final bank = MockBank(clock: clock);
    final first = ScenarioHarness(store: store, clock: clock, bank: bank);
    await first.initializeAndConnect();
    await first.controller.setInitialPin('4321');
    await first.controller.disconnect();
    await first.dispose();

    bank.dropCoin(Denomination.php5);
    bank.dropCoin(Denomination.php10);

    final second = ScenarioHarness(store: store, clock: clock, bank: bank);
    await second.initializeAndConnect();
    expect(second.controller.state.deviceTotal, 15);
    expect(
      second.controller.state.transactions
          .where((transaction) => transaction.type == TransactionType.deposit),
      hasLength(2),
    );
    await second.controller.sync();
    expect(
      second.controller.state.transactions
          .where((transaction) => transaction.type == TransactionType.deposit),
      hasLength(2),
    );
    await second.dispose();
  });

  test('C: more than 32 offline coins produces reconciliation evidence',
      () async {
    final harness = ScenarioHarness();
    await harness.initializeAndConnect();
    await harness.controller.setInitialPin('4321');
    await harness.controller.disconnect();
    for (var i = 0; i < 33; i++) {
      harness.controls.dropCoin(Denomination.php1);
    }
    final events = <SmartSaveEvent>[];
    harness.controller.events.listen(events.add);
    await harness.controller.reconnectLast();
    expect(events.whereType<ReconciliationApplied>(), isNotEmpty);
    expect(harness.controller.state.deviceTotal, 33);
    await harness.dispose();
  });

  test('D: sequence wrap remains usable across a restart', () async {
    final store = InMemoryStore();
    final first = ScenarioHarness(store: store);
    await first.initializeAndConnect();
    await first.controller.setInitialPin('4321');
    first.controls.simulator.seedStateForTest(seq: 65535, acked: 65535);
    first.controls.dropCoin(Denomination.php1);
    await first.settle();
    expect(
      first.controller.state.transactions.any((transaction) => transaction.seq == 0),
      isTrue,
    );
    await first.dispose();

    final second = ScenarioHarness(store: store);
    await second.initializeAndConnect();
    expect(
      second.controller.state.transactions.any((transaction) => transaction.seq == 0),
      isTrue,
    );
    await second.dispose();
  });

  test('E: wrong PIN lockout recovers after thirty fake seconds', () async {
    final harness = ScenarioHarness();
    await harness.initializeAndConnect();
    await harness.controller.setInitialPin('4321');
    await harness.controller.logout();
    for (var i = 0; i < 3; i++) {
      await harness.controller.login('0000');
    }
    expect(harness.controller.state.auth, AuthState.lockedOut);
    fakeAsync((async) {
      harness.clock.advance(const Duration(seconds: 30));
      harness.controls.simulator.tick();
      async.flushMicrotasks();
    });
    expect(harness.controller.state.auth, AuthState.loggedOut);
    expect((await harness.controller.login('4321')).isSuccess, isTrue);
    await harness.dispose();
  });

  test('F: goal reaches target, redeems, and auto-relocks', () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    await harness.controller.login('1234');
    final events = <SmartSaveEvent>[];
    harness.controller.events.listen(events.add);
    final goal = (await harness.controller.createGoal('Trip', 300)).valueOrNull!;
    await harness.controller.allocateToGoal(goal.id, 300);
    expect(events.whereType<GoalReached>(), isNotEmpty);
    await harness.controller.redeemGoal(goal.id, '1234');
    expect(harness.controller.state.deviceTotal, 950);
    expect(harness.controller.state.lock, LockState.unlocked);
    harness.clock.advance(const Duration(seconds: 30));
    harness.controls.simulator.tick();
    await harness.settle();
    expect(events.whereType<AutoRelocked>(), isNotEmpty);
    await harness.dispose();
  });

  test('G: link loss during redemption fails safely and preserves cached state',
      () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    await harness.controller.login('1234');
    final goal = (await harness.controller.createGoal('Trip', 10)).valueOrNull!;
    await harness.controller.allocateToGoal(goal.id, 10);
    await harness.controls.simulateLinkLoss();
    final result = await harness.controller.redeemGoal(goal.id, '1234');
    expect(result.errorOrNull?.code, SmartSaveErrorCode.notAuthenticated);
    expect(harness.controller.state.deviceTotal, 1250);
    await harness.dispose();
  });

  test('H: manual recount updates balance and exposes over-allocation',
      () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    await harness.controller.login('1234');
    final goal = (await harness.controller.createGoal('Fund', 100)).valueOrNull!;
    await harness.controller.allocateToGoal(goal.id, 100);
    await harness.controller.adjustBalance('1234', 50);
    expect(harness.controller.state.deviceTotal, 50);
    expect(harness.controller.summary.overAllocatedBy, 50);
    await harness.dispose();
  });

  test('I: changed PIN rejects the old value and accepts the new value',
      () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    await harness.controller.login('1234');
    await harness.controller.changePin('5678');
    await harness.controller.logout();
    expect((await harness.controller.login('1234')).isSuccess, isFalse);
    expect((await harness.controller.login('5678')).isSuccess, isTrue);
    await harness.dispose();
  });

  test('J: factory reset is surfaced as pin-not-set on synchronization',
      () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    await harness.controller.login('1234');
    harness.controls.factoryResetBank();
    final result = await harness.controller.reconnectLast();
    expect(result.isSuccess, isTrue);
    expect(harness.controller.state.auth, AuthState.pinNotSet);
    await harness.dispose();
  });

  test('K: malformed injected lines do not change application state',
      () async {
    final harness = ScenarioHarness(profile: SimulatorProfileName.demo);
    await harness.initializeAndConnect();
    final before = harness.controller.state;
    harness.controls.injectRawLine('not a protocol line');
    harness.controls.injectRawLine('TOTAL:not-a-number');
    await harness.settle();
    expect(harness.controller.state.deviceTotal, before.deviceTotal);
    await harness.dispose();
  });

  test('L: simulator clamps totals at 99,999', () async {
    final harness = ScenarioHarness();
    await harness.initializeAndConnect();
    harness.controls.simulator.seedStateForTest(total: 99998);
    harness.controls.dropCoin(Denomination.php5);
    await harness.settle();
    expect(harness.controls.simulator.total, 99999);
    await harness.dispose();
  });

  test('M: a different bank is rejected until local data is reset', () async {
    final harness = ScenarioHarness();
    await harness.initializeAndConnect();
    final result = await harness.controller.connect(
      const DiscoveredBank(id: 'another-bank', name: 'Other'),
    );
    expect(result.errorOrNull?.code, SmartSaveErrorCode.deviceMismatch);
    expect((await harness.controller.resetLocalData()).isSuccess, isTrue);
    expect((await harness.controller.connect(
      const DiscoveredBank(id: 'another-bank', name: 'Other'),
    )).isSuccess, isTrue);
    await harness.dispose();
  });

  test('N: controller actions return failures instead of throwing when invalid',
      () async {
    final harness = ScenarioHarness();
    await harness.backend.initialize();
    final controller = harness.controller;
    final results = <ActionResult<Object?>>[
      await controller.ensureBluetoothReady(),
      await controller.scan(),
      await controller.reconnectLast(),
      await controller.disconnect(),
      await controller.login('0000'),
      await controller.changePin('1234'),
      await controller.sync(),
      await controller.updateGoal('missing'),
      await controller.deleteGoal('missing'),
      await controller.allocateToGoal('missing', 1),
      await controller.releaseFromGoal('missing', 1),
      await controller.redeemGoal('missing', '0000'),
      await controller.lockBank(),
      await controller.adjustBalance('0000', 1),
      await controller.resetLocalData(),
      await controller.logout(),
    ];
    expect(results, hasLength(16));
    await harness.dispose();
  });
}
