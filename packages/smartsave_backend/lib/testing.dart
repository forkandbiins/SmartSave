/// Public testing helpers for SmartSave consumers.
library;

export 'src/util/clock.dart' show FakeClock;
export 'src/models/denomination.dart';
export 'src/models/savings_goal.dart';
export 'src/models/savings_transaction.dart';
export 'src/models/smartsave_state.dart';
export 'src/config/smartsave_mode.dart';
export 'src/storage/in_memory_store.dart' show InMemoryStore;
export 'src/testing/mock_bank.dart' show MockBank;
export 'src/backend.dart' show createMockBackend;

import 'src/config/smartsave_mode.dart';
import 'src/models/denomination.dart';
import 'src/models/link_state.dart';
import 'src/models/auth_state.dart';
import 'src/models/lock_state.dart';
import 'src/models/savings_goal.dart';
import 'src/models/savings_transaction.dart';
import 'src/models/smartsave_state.dart';

/// Deterministic model-only fixtures for tests and examples.
final class DemoFixtures {
  const DemoFixtures._();

  /// Returns an empty initial state.
  static SmartSaveState emptyState() =>
      SmartSaveState.initial(SmartSaveMode.mock);

  /// Returns a connected demonstration state.
  static SmartSaveState demoState() {
    final goals = sampleGoals();
    final transactions = sampleTransactions();
    return SmartSaveState(
      mode: SmartSaveMode.mock,
      link: LinkState.ready,
      auth: AuthState.loggedIn,
      lock: LockState.locked,
      deviceTotal: 1250,
      deviceSeq: 12,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.utc(2026, 1, 13),
      goals: goals,
      transactions: transactions,
    );
  }

  /// Returns twelve mixed sample transactions.
  static List<SavingsTransaction> sampleTransactions() {
    final base = DateTime.utc(2026, 1, 1);
    return List<SavingsTransaction>.generate(12, (index) {
      final type = index == 10
          ? TransactionType.redemption
          : index == 11
              ? TransactionType.adjustment
              : TransactionType.deposit;
      return SavingsTransaction(
        id: 'txn-${index + 1}',
        type: type,
        amount: type == TransactionType.adjustment
            ? -10
            : type == TransactionType.redemption
                ? -100
                : 20 + index * 5,
        denomination: type == TransactionType.deposit
            ? Denomination.values[index % Denomination.values.length]
            : null,
        seq: index < 10 ? index + 1 : null,
        timestamp: base.add(Duration(days: index)),
        timeAccuracy: index.isEven
            ? TimeAccuracy.observedLive
            : TimeAccuracy.syncedLate,
        goalId: index < 3 ? 'goal-${index + 1}' : null,
      );
    }).reversed.toList();
  }

  /// Returns three sample goals, including one reached goal.
  static List<SavingsGoal> sampleGoals() {
    final created = DateTime.utc(2026, 1, 1);
    return [
      SavingsGoal(
        id: 'goal-1',
        name: 'Emergency fund',
        targetAmount: 500,
        allocatedAmount: 500,
        status: GoalStatus.active,
        createdAt: created,
      ),
      SavingsGoal(
        id: 'goal-2',
        name: 'School supplies',
        targetAmount: 1000,
        allocatedAmount: 450,
        status: GoalStatus.active,
        createdAt: created.add(const Duration(days: 1)),
      ),
      SavingsGoal(
        id: 'goal-3',
        name: 'Old goal',
        targetAmount: 300,
        allocatedAmount: 300,
        status: GoalStatus.redeemed,
        createdAt: created.add(const Duration(days: 2)),
        redeemedAt: created.add(const Duration(days: 10)),
      ),
    ];
  }
}
