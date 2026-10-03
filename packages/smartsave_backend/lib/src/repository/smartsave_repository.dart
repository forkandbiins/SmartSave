import '../models/lock_state.dart';
import '../models/savings_goal.dart';
import '../models/savings_transaction.dart';
import '../models/smartsave_event.dart';
import '../models/sync_report.dart';
import '../models/transaction_query.dart';

/// Immutable domain state published by the repository.
final class RepositorySnapshot {
  /// Creates a repository snapshot.
  RepositorySnapshot({
    required List<SavingsTransaction> transactions,
    required List<SavingsGoal> goals,
    required this.deviceTotal,
    required this.lock,
    required this.lastSyncedAt,
    this.pinNotSet = false,
  })  : transactions = List.unmodifiable(transactions),
        goals = List.unmodifiable(goals);

  /// Transactions, newest first.
  final List<SavingsTransaction> transactions;
  /// Local savings goals.
  final List<SavingsGoal> goals;
  /// Last authoritative device total.
  final int? deviceTotal;
  /// Current bank lock state.
  final LockState lock;
  /// Last successful synchronization time.
  final DateTime? lastSyncedAt;
  /// Whether the bank reported that no PIN is configured.
  final bool pinNotSet;
}

/// Domain operations between the bank client and local persistence.
abstract interface class SmartSaveRepository {
  /// Published immutable domain state.
  Stream<RepositorySnapshot> get changes;

  /// One-shot domain events.
  Stream<SmartSaveEvent> get events;

  /// Loads local data and starts listening to device events.
  Future<void> initialize();

  /// Synchronizes history and authoritative balance.
  Future<SyncReport> synchronize();

  /// Redeems an active goal.
  Future<void> redeemGoal(String goalId, String pin);

  /// Adjusts the balance and confirms it with synchronization.
  Future<void> adjustBalance(String pin, int newTotal, {String? note});

  /// Creates a local goal.
  Future<SavingsGoal> createGoal(String name, int targetAmount);

  /// Updates a local goal.
  Future<SavingsGoal> updateGoal(
    String goalId, {
    String? name,
    int? targetAmount,
  });

  /// Cancels a local goal and releases its allocation.
  Future<void> deleteGoal(String goalId);

  /// Allocates available balance to a goal.
  Future<SavingsGoal> allocateToGoal(String goalId, int amount);

  /// Releases an allocation from a goal.
  Future<SavingsGoal> releaseFromGoal(String goalId, int amount);

  /// Binds the repository to a bank identity.
  Future<void> bindDevice(String id);

  /// Clears all local data.
  Future<void> resetLocalData();

  /// Queries local transaction history.
  List<SavingsTransaction> getTransactions(TransactionQuery query);
}
