import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/config/smartsave_config.dart';
import 'package:smartsave_backend/src/device/device_client.dart';
import 'package:smartsave_backend/src/device/device_event.dart' as device;
import 'package:smartsave_backend/src/device/protocol_device_client.dart';
import 'package:smartsave_backend/src/diagnostics/logger.dart';
import 'package:smartsave_backend/src/errors/smartsave_error.dart';
import 'package:smartsave_backend/src/models/denomination.dart';
import 'package:smartsave_backend/src/models/device_snapshot.dart';
import 'package:smartsave_backend/src/models/savings_transaction.dart';
import 'package:smartsave_backend/src/models/discovered_bank.dart';
import 'package:smartsave_backend/src/models/savings_goal.dart';
import 'package:smartsave_backend/src/models/smartsave_event.dart';
import 'package:smartsave_backend/src/models/transaction_query.dart';
import 'package:smartsave_backend/src/repository/default_smartsave_repository.dart';
import 'package:smartsave_backend/src/repository/reconciliation.dart';
import 'package:smartsave_backend/src/repository/sequence_math.dart';
import 'package:smartsave_backend/src/repository/statistics.dart';
import 'package:smartsave_backend/src/storage/in_memory_store.dart';
import 'package:smartsave_backend/src/storage/persisted_data.dart';
import 'package:smartsave_backend/src/transport/mock/fake_device_simulator.dart';
import 'package:smartsave_backend/src/transport/mock/mock_transport.dart';
import 'package:smartsave_backend/src/transport/mock/simulator_profile.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  test('uint16 sequence helpers wrap and detect contiguity', () {
    expect(next(65535), 0);
    expect(distance(65535, 0), 1);
    expect(contiguous(65535, 0), isTrue);
    expect(isAtOrBefore(65535, 0), isTrue);
    expect(isAtOrBefore(0, 0), isTrue);
  });

  test('reconciliation calculates opening balance and delta', () {
    expect(
      reconcile(knownTotal: null, reportedTotal: 100, newCoinsSum: 30)
          .openingBalance,
      70,
    );
    expect(
      reconcile(knownTotal: 100, reportedTotal: 140, newCoinsSum: 20).delta,
      20,
    );
  });

  test('statistics count deposits only', () {
    final day = DateTime.utc(2026, 10, 3);
    final transactions = [
      SavingsTransaction(
        id: 'a',
        type: TransactionType.deposit,
        amount: 5,
        timestamp: day,
        timeAccuracy: TimeAccuracy.observedLive,
      ),
      SavingsTransaction(
        id: 'b',
        type: TransactionType.adjustment,
        amount: 100,
        timestamp: day,
        timeAccuracy: TimeAccuracy.userAction,
      ),
    ];
    expect(perDayTotals(transactions)[day], 5);
    expect(count(transactions), 1);
    expect(highestDay(transactions), day);
    expect(averagePerDay(transactions), 5);
    final later = day.add(const Duration(days: 2));
    expect(weekly(transactions, later)[day], 5);
    expect(monthly(transactions, day)[day], 5);
    final aggregate = statistics(transactions);
    expect(aggregate.totalDeposited, 5);
    expect(aggregate.transactionCount, 1);
    expect(perDayTotals(const []), isEmpty);
    expect(highestDay(const []), isNull);
    expect(averagePerDay(const []), 0);
    expect(weekly(transactions, DateTime.utc(2027)), isEmpty);
    expect(monthly(transactions, DateTime.utc(2027)), isEmpty);
  });

  test('first demo sync persists deposits, opening balance, and ACK', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final simulator =
        FakeDeviceSimulator(clock, Random(1), SimulatorProfile.demo);
    final transport = MockTransport(simulator, autoTick: false);
    final client = ProtocolDeviceClient(
      transport,
      null,
      SmartSaveConfig.mock(),
      clock,
      const NoopLogger(),
    );
    final store = InMemoryStore();
    final repository =
        DefaultSmartSaveRepository(client, store, clock, const NoopLogger());
    await repository.initialize();
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    final report = await repository.synchronize();
    final data = await store.load();
    expect(report.newDeposits, 4);
    expect(data.transactions.where((item) => item.type == TransactionType.deposit),
        hasLength(4));
    expect(
      data.transactions
          .where((item) => item.type == TransactionType.openingBalance)
          .single
          .amount,
      1214,
    );
    expect(data.lastAckedSeq, 12);
    expect(simulator.acked, 12);
    await client.dispose();
    await transport.dispose();
  });

  test('offline replay, duplicate live coin, skipped sequence, and wrap', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final simulator = FakeDeviceSimulator(clock, Random(2), SimulatorProfile.fresh);
    final transport = MockTransport(simulator, autoTick: false);
    final client = ProtocolDeviceClient(
      transport, null, SmartSaveConfig.mock(), clock, const NoopLogger(),
    );
    final store = InMemoryStore();
    final repository = DefaultSmartSaveRepository(
      client, store, clock, const NoopLogger(),
    );
    await repository.initialize();
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    await repository.synchronize();
    await transport.disconnect();
    simulator.dropCoin(5);
    simulator.dropCoin(10);
    simulator.dropCoin(1);
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    expect((await repository.synchronize()).newDeposits, 3);
    simulator.dropCoin(5);
    await Future<void>.delayed(Duration.zero);
    expect((await store.load()).transactions.where(
      (item) => item.type == TransactionType.deposit,
    ), hasLength(4));
    await client.dispose();
    await transport.dispose();

    final wrapClient = _FakeClient(
      snapshots: [
        _snapshot(0, 0, const []),
        _snapshot(1, 0xffff, const [ReplayedCoin(
          denomination: Denomination.php1, seq: 0xffff,
        )]),
      ],
    );
    final wrapStore = InMemoryStore();
    final wrapRepository = DefaultSmartSaveRepository(
      wrapClient, wrapStore, clock, const NoopLogger(),
    );
    await wrapRepository.initialize();
    await wrapRepository.synchronize();
    await wrapRepository.synchronize();
    expect(wrapStore.load, isNotNull);
    expect(wrapClient.acks, [0xffff]);
  });

  test('buffer overflow records the lost-coin reconciliation gap', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final pending = <int, Denomination>{
      for (var i = 17; i <= 40; i++) i: Denomination.php1,
    };
    final simulator = FakeDeviceSimulator(
      clock,
      Random(3),
      SimulatorProfile(
        pinSet: true,
        pin: '1234',
        total: 40,
        seq: 40,
        acked: 8,
        pending: pending,
      ),
    );
    final transport = MockTransport(simulator, autoTick: false);
    final client = ProtocolDeviceClient(
      transport, null, SmartSaveConfig.mock(), clock, const NoopLogger(),
    );
    final store = InMemoryStore(
      initialData: PersistedData(knownDeviceTotal: 8, lastAckedSeq: 8),
    );
    final repository = DefaultSmartSaveRepository(
      client, store, clock, const NoopLogger(),
    );
    await repository.initialize();
    await transport.connect(
      const DiscoveredBank(id: 'mock-bank-1', name: 'SmartSave (mock)'),
    );
    final report = await repository.synchronize();
    expect(report.newDeposits, 24);
    expect(report.gapSize, 8);
    expect(report.reconciliationDelta, 8);
    await client.dispose();
    await transport.dispose();
  });

  test('save failure prevents ACK and emits an error', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final fake = _FakeClient(
      snapshots: [_snapshot(5, 1, const [
        ReplayedCoin(denomination: Denomination.php5, seq: 1),
      ])],
    );
    final store = InMemoryStore()..failNextSave = true;
    final events = <SmartSaveEvent>[];
    final repository = DefaultSmartSaveRepository(
      fake, store, clock, const NoopLogger(),
    )..events.listen(events.add);
    await repository.initialize();
    await expectLater(repository.synchronize(), throwsA(isA<StorageError>()));
    expect(fake.acks, isEmpty);
    expect(events.whereType<ErrorRaised>(), hasLength(1));
  });

  test('redemption succeeds and timeout inference calls unlock once', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final goal = SavingsGoal(
      id: 'g',
      name: 'Goal',
      targetAmount: 10,
      allocatedAmount: 5,
      status: GoalStatus.active,
      createdAt: clock.now(),
    );
    final fake = _FakeClient(
      snapshots: [
        _snapshot(10, 1, const []),
        _snapshot(5, 1, const []),
      ],
      unlockOutcomes: [const UnlockOutcome(5)],
    );
    final store = InMemoryStore(
      initialData: PersistedData(knownDeviceTotal: 10, goals: [goal]),
    );
    final repository = DefaultSmartSaveRepository(
      fake, store, clock, const NoopLogger(),
    );
    await repository.initialize();
    await repository.redeemGoal('g', '1234');
    expect(fake.unlockCalls, 1);
    expect((await store.load()).goals.single.status, GoalStatus.redeemed);
  });

  test('timeout inference distinguishes applied and unapplied unlocks', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    Future<void> run(bool applied) async {
      final goal = SavingsGoal(
        id: 'g',
        name: 'Goal',
        targetAmount: 10,
        allocatedAmount: 5,
        status: GoalStatus.active,
        createdAt: clock.now(),
      );
      final fake = _FakeClient(
        snapshots: [_snapshot(applied ? 5 : 10, 1, const [])],
        unlockThrowsTimeout: true,
      );
      final store = InMemoryStore(
        initialData: PersistedData(knownDeviceTotal: 10, goals: [goal]),
      );
      final repository = DefaultSmartSaveRepository(
        fake, store, clock, const NoopLogger(),
      );
      await repository.initialize();
      if (applied) {
        await repository.redeemGoal('g', '1234');
      } else {
        await expectLater(
          repository.redeemGoal('g', '1234'),
          throwsA(isA<ProtocolError>()),
        );
      }
      expect(fake.unlockCalls, 1);
    }
    await run(true);
    await run(false);
  });

  test('goals enforce allocation, release, reach, and over-allocation rules',
      () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final fake = _FakeClient(snapshots: []);
    final repository = DefaultSmartSaveRepository(
      fake,
      InMemoryStore(initialData: PersistedData(knownDeviceTotal: 10)),
      clock,
      const NoopLogger(),
    );
    final reached = <GoalReached>[];
    repository.events.listen((event) {
      if (event is GoalReached) reached.add(event);
    });
    await repository.initialize();
    final goal = await repository.createGoal('G', 5);
    await repository.allocateToGoal(goal.id, 5);
    expect(reached, hasLength(1));
    await repository.releaseFromGoal(goal.id, 2);
    await expectLater(
      repository.allocateToGoal(goal.id, 20),
      throwsA(isA<SmartSaveError>()),
    );
    await repository.updateGoal(goal.id, targetAmount: 3);
    await expectLater(
      repository.updateGoal(goal.id, targetAmount: 1),
      throwsA(isA<SmartSaveError>()),
    );
    await repository.deleteGoal(goal.id);
    expect((await (repository.store).load()).goals.single.status,
        GoalStatus.cancelled);
  });

  test('adjustment, binding, filtering, malformed lines, and lock events',
      () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final fake = _FakeClient(snapshots: [
      _snapshot(99999, 1, const []),
      _snapshot(99999, 1, const []),
    ]);
    final store = InMemoryStore(
      initialData: PersistedData(knownDeviceTotal: 10),
    );
    final repository = DefaultSmartSaveRepository(
      fake, store, clock, const NoopLogger(),
    );
    final events = <SmartSaveEvent>[];
    repository.events.listen(events.add);
    await repository.initialize();
    await repository.bindDevice('bank');
    await expectLater(
      repository.bindDevice('other'),
      throwsA(isA<SmartSaveStateError>()),
    );
    await repository.adjustBalance('1234', 99999, note: 'clamp');
    final query = repository.getTransactions(
      TransactionQuery(types: [TransactionType.adjustment], limit: 1),
    );
    expect(query, hasLength(1));
    expect(query.single.note, 'clamp');
    fake.emit(const device.MalformedLine('x'));
    fake.emit(const device.MalformedLine('y'));
    fake.emit(const device.MalformedLine('z'));
    fake.emit(const device.PinNotSetDetected());
    fake.emit(const device.LockChanged(true, unsolicited: true));
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<AutoRelocked>(), hasLength(1));
    expect((await store.load()).knownDeviceTotal, 99999);
  });

  test('sequence regression emits anomaly and does not ACK', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 3));
    final fake = _FakeClient(
      snapshots: [_snapshot(1, 4, const [])],
    );
    final repository = DefaultSmartSaveRepository(
      fake,
      InMemoryStore(initialData: PersistedData(
        knownDeviceTotal: 1,
        lastAckedSeq: 5,
      )),
      clock,
      const NoopLogger(),
    );
    final anomalies = <DeviceAnomaly>[];
    repository.events.listen((event) {
      if (event is DeviceAnomaly) anomalies.add(event);
    });
    await repository.initialize();
    await repository.synchronize();
    expect(anomalies.single.kind, DeviceAnomalyKind.seqRegressed);
    expect(fake.acks, isEmpty);
  });
}

DeviceSnapshot _snapshot(
  int total,
  int seq,
  List<ReplayedCoin> coins,
) =>
    DeviceSnapshot(
      total: total,
      locked: true,
      deviceSeq: seq,
      replayedCoins: coins,
      receivedAt: DateTime.utc(2026, 10, 3),
    );

final class _FakeClient implements DeviceClient {
  _FakeClient({
    required this.snapshots,
    this.unlockOutcomes = const [],
    this.unlockThrowsTimeout = false,
  });

  final List<DeviceSnapshot> snapshots;
  final List<UnlockOutcome> unlockOutcomes;
  final bool unlockThrowsTimeout;
  final _events = StreamController<device.DeviceEvent>.broadcast(sync: true);
  final acks = <int>[];
  int unlockCalls = 0;

  void emit(device.DeviceEvent event) => _events.add(event);

  @override
  Stream<device.DeviceEvent> get events => _events.stream;
  @override
  Future<DeviceSnapshot> sync() async => snapshots.removeAt(0);
  @override
  void ack(int seq) => acks.add(seq);
  @override
  Future<UnlockOutcome> unlock(String pin, int amount) async {
    unlockCalls++;
    if (unlockThrowsTimeout) throw const ProtocolError.commandTimeout();
    return unlockOutcomes.removeAt(0);
  }
  @override
  Future<int> adjustTotal(String pin, int newTotal) async => newTotal;
  @override
  Future<HandshakeResult> handshake() async => const HandshakeResult(1, true);
  @override
  Future<void> authenticate(String pin) async {}
  @override
  Future<void> setInitialPin(String pin) async {}
  @override
  Future<void> changePin(String oldPin, String newPin) async {}
  @override
  Future<void> lock() async {}
  @override
  Future<void> ping() async {}
}
