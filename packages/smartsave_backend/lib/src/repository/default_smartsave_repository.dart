import 'dart:async';

import '../device/device_client.dart';
import '../device/device_event.dart' as device;
import '../diagnostics/logger.dart';
import '../errors/smartsave_error.dart';
import '../models/denomination.dart';
import '../models/lock_state.dart';
import '../models/savings_goal.dart';
import '../models/savings_transaction.dart';
import '../models/smartsave_event.dart' as models;
import '../models/sync_report.dart';
import '../models/transaction_query.dart';
import '../storage/persisted_data.dart';
import '../storage/smartsave_store.dart';
import '../util/clock.dart';
import 'reconciliation.dart';
import 'sequence_math.dart' as sequence;
import 'smartsave_repository.dart';

/// The default SmartSave domain repository.
final class DefaultSmartSaveRepository implements SmartSaveRepository {
  /// Creates a repository over [client] and [store].
  DefaultSmartSaveRepository(this.client, this.store, this.clock, this.logger) {
    client.events.listen(_onDeviceEvent);
  }

  /// Device service.
  final DeviceClient client;
  /// Persistence boundary.
  final SmartSaveStore store;
  /// Injected time source.
  final Clock clock;
  /// Diagnostic logger.
  final SmartSaveLogger logger;

  final _changes = StreamController<RepositorySnapshot>.broadcast(sync: true);
  final _events = StreamController<models.SmartSaveEvent>.broadcast(sync: true);
  List<SavingsTransaction> _transactions = [];
  List<SavingsGoal> _goals = [];
  String? _boundDeviceId;
  int? _lastAckedSeq;
  int? _knownTotal;
  DateTime? _lastSyncedAt;
  LockState _lock = LockState.unknown;
  bool _initialized = false;
  bool _syncing = false;
  bool _liveCoinProcessing = false;
  bool _syncScheduled = false;
  int _malformedCount = 0;

  @override
  Stream<RepositorySnapshot> get changes => _changes.stream;
  @override
  Stream<models.SmartSaveEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final data = await store.load();
      _apply(data);
    } on StorageError catch (error) {
      if (error.code != SmartSaveErrorCode.corrupt) rethrow;
      _events.add(models.ErrorRaised(error));
      _apply(PersistedData.empty());
    }
    _initialized = true;
    _publish();
  }

  void _apply(PersistedData data) {
    _transactions = List<SavingsTransaction>.from(data.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _goals = List<SavingsGoal>.from(data.goals);
    _boundDeviceId = data.boundDeviceId;
    _lastAckedSeq = data.lastAckedSeq;
    _knownTotal = data.knownDeviceTotal;
    _lastSyncedAt = data.lastSyncedAt;
  }

  Future<void> _persist() => store.save(PersistedData(
        boundDeviceId: _boundDeviceId,
        lastAckedSeq: _lastAckedSeq,
        knownDeviceTotal: _knownTotal,
        lastSyncedAt: _lastSyncedAt,
        transactions: _transactions,
        goals: _goals,
      ));

  void _publish() => _changes.add(RepositorySnapshot(
        transactions: _transactions,
        goals: _goals,
        deviceTotal: _knownTotal,
        lock: _lock,
      lastSyncedAt: _lastSyncedAt,
      pinNotSet: false,
    ));

  void _publishPinNotSet() => _changes.add(RepositorySnapshot(
        transactions: _transactions,
        goals: _goals,
        deviceTotal: _knownTotal,
        lock: _lock,
        lastSyncedAt: _lastSyncedAt,
        pinNotSet: true,
      ));

  void _emitError(SmartSaveError error) {
    logger.error(error.message);
    _events.add(models.ErrorRaised(error));
  }

  @override
  Future<SyncReport> synchronize() async {
    if (!_initialized) await initialize();
    if (_syncing) return SyncReport(newDeposits: 0);
    _syncing = true;
    final previousTransactions = List<SavingsTransaction>.from(_transactions);
    final previousAcked = _lastAckedSeq;
    final previousTotal = _knownTotal;
    final previousSyncedAt = _lastSyncedAt;
    try {
      final snapshot = await client.sync();
      final lastAcked = _lastAckedSeq;
      final storedSeqs = _transactions
          .where((item) => item.seq != null)
          .map((item) => item.seq!)
          .toSet();
      final replayed = snapshot.replayedCoins.where((coin) {
        if (lastAcked != null && sequence.isAtOrBefore(coin.seq, lastAcked)) {
          return false;
        }
        return !storedSeqs.contains(coin.seq);
      }).toList();
      int? gapSize;
      if (lastAcked != null && replayed.isNotEmpty) {
        final expected = sequence.next(lastAcked);
        if (replayed.first.seq != expected) {
          gapSize = sequence.distance(expected, replayed.first.seq);
        }
      }
      final anomalies = <models.DeviceAnomalyKind>[];
      final regressed = lastAcked != null &&
          sequence.isAtOrBefore(snapshot.deviceSeq, lastAcked) &&
          snapshot.deviceSeq != lastAcked;
      if (regressed) {
        anomalies.add(models.DeviceAnomalyKind.seqRegressed);
        _events.add(const models.DeviceAnomaly(models.DeviceAnomalyKind.seqRegressed));
      }
      final now = clock.now();
      final deposits = <SavingsTransaction>[];
      for (final coin in replayed) {
        deposits.add(_deposit(
          coin.denomination,
          coin.seq,
          now,
          TimeAccuracy.syncedLate,
        ));
      }
      final coinSum = deposits.fold<int>(0, (sum, item) => sum + item.amount);
      final correction = reconcile(
        knownTotal: regressed ? _knownTotal : _knownTotal,
        reportedTotal: snapshot.total,
        newCoinsSum: regressed ? 0 : coinSum,
      );
      if (deposits.isNotEmpty) _transactions.insertAll(0, deposits.reversed);
      int? reconciliationDelta;
      final correctionAmount = correction.openingBalance ?? correction.delta;
      if (correctionAmount != null && correctionAmount != 0) {
        reconciliationDelta = correctionAmount;
        _transactions.insert(
          0,
          SavingsTransaction(
            id: 'adj-${now.microsecondsSinceEpoch}',
            type: correction.openingBalance != null
                ? TransactionType.openingBalance
                : TransactionType.adjustment,
            amount: correctionAmount,
            timestamp: now,
            timeAccuracy: TimeAccuracy.syncedLate,
            note: gapSize == null ? null : 'Missing sequence gap: $gapSize',
          ),
        );
        if (correction.delta != null) {
          _events.add(models.ReconciliationApplied(correction.delta!, gapSize: gapSize));
        }
      }
      final previousTotal = _knownTotal;
      _knownTotal = snapshot.total;
      _lastSyncedAt = now;
      if (!regressed && replayed.isNotEmpty) {
        _lastAckedSeq = replayed.last.seq;
      }
      await _persist();
      if (!regressed && replayed.isNotEmpty) client.ack(replayed.last.seq);
      _updateDeviceState(previousTotal, snapshot.total, snapshot.locked);
      _publish();
      return SyncReport(
        newDeposits: deposits.length,
        reconciliationDelta: reconciliationDelta,
        gapSize: gapSize,
        anomalies: anomalies,
      );
    } on StorageError catch (error) {
      _transactions = previousTransactions;
      _lastAckedSeq = previousAcked;
      _knownTotal = previousTotal;
      _lastSyncedAt = previousSyncedAt;
      _emitError(error);
      rethrow;
    } finally {
      _syncing = false;
    }
  }

  SavingsTransaction _deposit(
    Denomination denomination,
    int seq,
    DateTime timestamp,
    TimeAccuracy accuracy,
  ) =>
      SavingsTransaction(
        id: 'dep-${_boundDeviceId ?? 'dev'}-$seq-${timestamp.millisecondsSinceEpoch}',
        type: TransactionType.deposit,
        amount: denomination.value,
        denomination: denomination,
        seq: seq,
        timestamp: timestamp,
        timeAccuracy: accuracy,
      );

  void _updateDeviceState(int? oldTotal, int total, bool locked) {
    _lock = locked ? LockState.locked : LockState.unlocked;
    if (oldTotal != null && oldTotal != total) {
      _events.add(models.BalanceChanged(oldTotal, total));
    }
  }

  @override
  Future<void> redeemGoal(String goalId, String pin) async {
    final index = _goals.indexWhere((goal) => goal.id == goalId);
    if (index < 0) throw const SmartSaveStateError.invalidOperation();
    final goal = _goals[index];
    final total = _knownTotal;
    if (goal.status != GoalStatus.active ||
        total == null ||
        goal.allocatedAmount <= 0 ||
        goal.allocatedAmount > total) {
      throw const SmartSaveStateError.invalidOperation();
    }
    final amount = goal.allocatedAmount;
    final original = total;
    try {
      final outcome = await client.unlock(pin, amount);
      _knownTotal = outcome.newTotal;
    } on ProtocolError catch (error) {
      if (error.code != SmartSaveErrorCode.commandTimeout) rethrow;
      await synchronize();
      if (_knownTotal == original - amount) {
        // Treat the timed-out operation as applied.
      } else if (_knownTotal == original) {
        rethrow;
      } else {
        _events.add(const models.DeviceAnomaly(models.DeviceAnomalyKind.unexpectedState));
        rethrow;
      }
    }
    final now = clock.now();
    _transactions.insert(
      0,
      SavingsTransaction(
        id: 'red-${goal.id}-${now.microsecondsSinceEpoch}',
        type: TransactionType.redemption,
        amount: -amount,
        timestamp: now,
        timeAccuracy: TimeAccuracy.userAction,
        goalId: goal.id,
      ),
    );
    _goals[index] = goal.copyWith(
      status: GoalStatus.redeemed,
      redeemedAt: now,
    );
    _knownTotal = original - amount;
    await _persist();
    _publish();
  }

  @override
  Future<void> adjustBalance(String pin, int newTotal, {String? note}) async {
    final old = _knownTotal;
    if (old == null) throw const SmartSaveStateError.invalidOperation();
    final reported = await client.adjustTotal(pin, newTotal);
    final now = clock.now();
    _transactions.insert(
      0,
      SavingsTransaction(
        id: 'adj-${now.microsecondsSinceEpoch}',
        type: TransactionType.adjustment,
        amount: reported - old,
        timestamp: now,
        timeAccuracy: TimeAccuracy.userAction,
        note: note,
      ),
    );
    _knownTotal = reported;
    await _persist();
    _publish();
    await synchronize();
  }

  SavingsGoal _goal(String id) {
    final index = _goals.indexWhere((goal) => goal.id == id);
    if (index < 0) throw const SmartSaveStateError.invalidOperation();
    return _goals[index];
  }

  Future<void> _saveGoals() async {
    await _persist();
    _publish();
  }

  @override
  Future<SavingsGoal> createGoal(String name, int targetAmount) async {
    if (targetAmount <= 0) throw const SmartSaveStateError.invalidOperation();
    final goal = SavingsGoal(
      id: 'goal-${clock.now().microsecondsSinceEpoch}',
      name: name,
      targetAmount: targetAmount,
      allocatedAmount: 0,
      status: GoalStatus.active,
      createdAt: clock.now(),
    );
    _goals.add(goal);
    await _saveGoals();
    return goal;
  }

  @override
  Future<SavingsGoal> updateGoal(
    String goalId, {
    String? name,
    int? targetAmount,
  }) async {
    final old = _goal(goalId);
    final target = targetAmount ?? old.targetAmount;
    if (target < old.allocatedAmount || target <= 0) {
      throw const SmartSaveStateError.invalidOperation();
    }
    final updated = old.copyWith(name: name, targetAmount: target);
    _goals[_goals.indexOf(old)] = updated;
    await _saveGoals();
    return updated;
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final goal = _goal(goalId);
    _goals[_goals.indexOf(goal)] = goal.copyWith(
      status: GoalStatus.cancelled,
      allocatedAmount: 0,
    );
    await _saveGoals();
  }

  @override
  Future<SavingsGoal> allocateToGoal(String goalId, int amount) async {
    final goal = _goal(goalId);
    final available = (_knownTotal ?? 0) -
        _goals.where((item) => item.status == GoalStatus.active).fold<int>(
            0, (sum, item) => sum + item.allocatedAmount);
    if (goal.status != GoalStatus.active || amount <= 0 || amount > available) {
      throw const SmartSaveStateError.invalidOperation();
    }
    final updated = goal.copyWith(allocatedAmount: goal.allocatedAmount + amount);
    _goals[_goals.indexOf(goal)] = updated;
    await _saveGoals();
    if (!goal.isReached && updated.isReached) {
      _events.add(models.GoalReached(updated));
    }
    return updated;
  }

  @override
  Future<SavingsGoal> releaseFromGoal(String goalId, int amount) async {
    final goal = _goal(goalId);
    if (goal.status != GoalStatus.active ||
        amount <= 0 ||
        amount > goal.allocatedAmount) {
      throw const SmartSaveStateError.invalidOperation();
    }
    final updated = goal.copyWith(allocatedAmount: goal.allocatedAmount - amount);
    _goals[_goals.indexOf(goal)] = updated;
    await _saveGoals();
    return updated;
  }

  @override
  Future<void> bindDevice(String id) async {
    if (_boundDeviceId != null && _boundDeviceId != id) {
      throw const SmartSaveStateError.deviceMismatch();
    }
    _boundDeviceId = id;
    await _persist();
    _publish();
  }

  @override
  Future<void> resetLocalData() async {
    await store.clear();
    _apply(PersistedData.empty());
    _publish();
  }

  @override
  List<SavingsTransaction> getTransactions(TransactionQuery query) {
    final result = _transactions.where((transaction) {
      if (query.from != null && transaction.timestamp.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && !transaction.timestamp.isBefore(query.to!)) {
        return false;
      }
      if (query.types.isNotEmpty && !query.types.contains(transaction.type)) {
        return false;
      }
      return query.goalId == null || transaction.goalId == query.goalId;
    }).toList();
    return List.unmodifiable(
      query.limit == null ? result : result.take(query.limit!).toList(),
    );
  }

  void _onDeviceEvent(device.DeviceEvent event) {
    if (event is device.MalformedLine) {
      _malformedCount++;
      if (_malformedCount >= 3) _scheduleSync();
      return;
    }
    _malformedCount = 0;
    if (event is device.CoinDetected) {
      _onCoin(event);
    } else if (event is device.TotalReported) {
      if (!_syncing &&
          !_liveCoinProcessing &&
          _knownTotal != null &&
          event.total != _knownTotal) {
        _applyLiveAdjustment(event.total);
      }
    } else if (event is device.LockChanged) {
      _lock = event.locked ? LockState.locked : LockState.unlocked;
      if (event.unsolicited && event.locked) {
        _events.add(const models.AutoRelocked());
      }
      _events.add(models.LockChanged(_lock));
      _publish();
    } else if (event is device.PinNotSetDetected) {
      _publishPinNotSet();
    }
  }

  Future<void> _onCoin(device.CoinDetected event) async {
    if (_lastAckedSeq == null ||
        event.seq != sequence.next(_lastAckedSeq!)) {
      _scheduleSync();
      return;
    }
    final transaction =
        _deposit(event.denomination, event.seq, clock.now(), TimeAccuracy.observedLive);
    final old = _knownTotal;
    final oldAcked = _lastAckedSeq;
    _liveCoinProcessing = true;
    _transactions.insert(0, transaction);
    if (old != null) _knownTotal = old + event.denomination.value;
    _lastAckedSeq = event.seq;
    try {
      await _persist();
      client.ack(event.seq);
      _events.add(models.CoinReceived(transaction));
      _publish();
    } on StorageError catch (error) {
      _transactions.remove(transaction);
      _knownTotal = old;
      _lastAckedSeq = oldAcked;
      _emitError(error);
    } finally {
      _liveCoinProcessing = false;
    }
  }

  Future<void> _applyLiveAdjustment(int total) async {
    final old = _knownTotal!;
    final transaction = SavingsTransaction(
      id: 'adj-${clock.now().microsecondsSinceEpoch}',
      type: TransactionType.adjustment,
      amount: total - old,
      timestamp: clock.now(),
      timeAccuracy: TimeAccuracy.syncedLate,
    );
    _transactions.insert(0, transaction);
    _knownTotal = total;
    try {
      await _persist();
      _events.add(models.ReconciliationApplied(transaction.amount));
      _publish();
    } on StorageError catch (error) {
      _emitError(error);
    }
  }

  void _scheduleSync() {
    if (_syncScheduled || _syncing) return;
    _syncScheduled = true;
    scheduleMicrotask(() async {
      _syncScheduled = false;
      try {
        await synchronize();
      } on SmartSaveError catch (error) {
        _emitError(error);
      }
    });
  }
}
