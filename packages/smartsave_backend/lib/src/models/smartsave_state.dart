import '../config/smartsave_mode.dart';
import '../errors/smartsave_error.dart';
import 'link_state.dart';
import 'auth_state.dart';
import 'lock_state.dart';
import 'savings_goal.dart';
import 'savings_summary.dart';
import 'savings_transaction.dart';

/// Immutable aggregate state exposed by the backend.
final class SmartSaveState {
  /// Creates application state.
  SmartSaveState({
    required this.mode,
    required this.link,
    required this.auth,
    this.lockoutEndsAt,
    required this.lock,
    this.deviceTotal,
    this.deviceSeq,
    required this.syncStatus,
    this.lastSyncedAt,
    required List<SavingsGoal> goals,
    required List<SavingsTransaction> transactions,
    this.lastError,
  })  : goals = List.unmodifiable(goals),
        transactions = List.unmodifiable(transactions);

  /// Creates initial disconnected state.
  factory SmartSaveState.initial(SmartSaveMode mode) => SmartSaveState(
        mode: mode,
        link: LinkState.disconnected,
        auth: AuthState.unknown,
        lock: LockState.unknown,
        syncStatus: SyncStatus.idle,
        goals: const [],
        transactions: const [],
      );

  /// Runtime mode.
  final SmartSaveMode mode;
  /// Link state.
  final LinkState link;
  /// Authentication state.
  final AuthState auth;
  /// Lockout deadline.
  final DateTime? lockoutEndsAt;
  /// Device lock state.
  final LockState lock;
  /// Last authoritative device total.
  final int? deviceTotal;
  /// Last device sequence number.
  final int? deviceSeq;
  /// Synchronization state.
  final SyncStatus syncStatus;
  /// Time of the last successful synchronization.
  final DateTime? lastSyncedAt;
  /// Current goals.
  final List<SavingsGoal> goals;
  /// Transactions, newest first.
  final List<SavingsTransaction> transactions;
  /// Last typed error.
  final SmartSaveError? lastError;
  /// Current balance and allocation summary.
  SavingsSummary get summary => SavingsSummary.from(deviceTotal, goals);

  /// Returns a copy with selected values replaced.
  SmartSaveState copyWith({
    SmartSaveMode? mode,
    LinkState? link,
    AuthState? auth,
    DateTime? lockoutEndsAt,
    LockState? lock,
    int? deviceTotal,
    int? deviceSeq,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    List<SavingsGoal>? goals,
    List<SavingsTransaction>? transactions,
    SmartSaveError? lastError,
  }) =>
      SmartSaveState(
        mode: mode ?? this.mode,
        link: link ?? this.link,
        auth: auth ?? this.auth,
        lockoutEndsAt: lockoutEndsAt ?? this.lockoutEndsAt,
        lock: lock ?? this.lock,
        deviceTotal: deviceTotal ?? this.deviceTotal,
        deviceSeq: deviceSeq ?? this.deviceSeq,
        syncStatus: syncStatus ?? this.syncStatus,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        goals: goals ?? this.goals,
        transactions: transactions ?? this.transactions,
        lastError: lastError ?? this.lastError,
      );

  @override
  bool operator ==(Object other) =>
      other is SmartSaveState &&
      mode == other.mode &&
      link == other.link &&
      auth == other.auth &&
      lockoutEndsAt == other.lockoutEndsAt &&
      lock == other.lock &&
      deviceTotal == other.deviceTotal &&
      deviceSeq == other.deviceSeq &&
      syncStatus == other.syncStatus &&
      lastSyncedAt == other.lastSyncedAt &&
      _listEquals(goals, other.goals) &&
      _listEquals(transactions, other.transactions) &&
      lastError?.code == other.lastError?.code &&
      lastError?.message == other.lastError?.message;

  @override
  int get hashCode => Object.hash(
        mode,
        link,
        auth,
        lockoutEndsAt,
        lock,
        deviceTotal,
        deviceSeq,
        syncStatus,
        lastSyncedAt,
        Object.hashAll(goals),
        Object.hashAll(transactions),
        lastError?.code,
        lastError?.message,
      );

  @override
  String toString() => 'SmartSaveState(link: $link, deviceTotal: $deviceTotal)';
}

bool _listEquals<T>(List<T> first, List<T> second) =>
    first.length == second.length &&
    Iterable<int>.generate(first.length).every((index) => first[index] == second[index]);
