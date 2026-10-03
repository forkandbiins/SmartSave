import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartsave_backend/src/errors/smartsave_error.dart';
import 'package:smartsave_backend/src/models/denomination.dart';
import 'package:smartsave_backend/src/models/savings_goal.dart';
import 'package:smartsave_backend/src/models/savings_transaction.dart';
import 'package:smartsave_backend/src/storage/in_memory_store.dart';
import 'package:smartsave_backend/src/storage/persisted_data.dart';
import 'package:smartsave_backend/src/storage/shared_prefs_store.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 3);

  PersistedData sampleData() => PersistedData(
        boundDeviceId: 'bank-1',
        lastAckedSeq: 42,
        knownDeviceTotal: 500,
        lastSyncedAt: timestamp,
        transactions: List.generate(
          500,
          (index) => SavingsTransaction(
            id: 'txn-$index',
            type: TransactionType.deposit,
            amount: 1,
            denomination: Denomination.php1,
            seq: index,
            timestamp: timestamp,
            timeAccuracy: TimeAccuracy.syncedLate,
          ),
        ),
        goals: List.generate(
          5,
          (index) => SavingsGoal(
            id: 'goal-$index',
            name: 'Goal $index',
            targetAmount: 100,
            allocatedAmount: index,
            status: GoalStatus.active,
            createdAt: timestamp,
          ),
        ),
      );

  void expectSame(PersistedData actual, PersistedData expected) {
    expect(actual.toJson(), expected.toJson());
  }

  test('in-memory store round-trips and clears the whole snapshot', () async {
    final store = InMemoryStore();
    final data = sampleData();
    await store.save(data);
    expectSame(await store.load(), data);
    await store.clear();
    expectSame(await store.load(), PersistedData.empty());
  });

  test('in-memory store exposes one-shot failures', () async {
    final store = InMemoryStore();
    store.failNextLoad = true;
    await expectLater(store.load(), throwsA(isA<StorageError>()));
    store.failNextSave = true;
    await expectLater(
      store.save(sampleData()),
      throwsA(isA<StorageError>()),
    );
    expectSame(await store.load(), PersistedData.empty());
  });

  test('shared preferences store round-trips 500 transactions and five goals',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsStore(prefs);
    final data = sampleData();
    await store.save(data);
    expectSame(await store.load(), data);
    await store.clear();
    expectSame(await store.load(), PersistedData.empty());
  });

  test('missing shared preferences key loads empty data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expectSame(await SharedPrefsStore(prefs).load(), PersistedData.empty());
  });

  test('invalid JSON and unknown schema are corrupt storage errors', () async {
    SharedPreferences.setMockInitialValues({'smartsave.v1': '{not-json'});
    var prefs = await SharedPreferences.getInstance();
    await expectLater(
      SharedPrefsStore(prefs).load(),
      throwsA(isA<StorageError>()),
    );

    SharedPreferences.setMockInitialValues({
      'smartsave.v1': '{"schemaVersion":2,"transactions":[],"goals":[]}',
    });
    prefs = await SharedPreferences.getInstance();
    await expectLater(
      SharedPrefsStore(prefs).load(),
      throwsA(isA<StorageError>()),
    );
  });
}
