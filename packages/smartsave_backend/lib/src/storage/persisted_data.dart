import 'package:smartsave_backend/src/errors/smartsave_error.dart';
import 'package:smartsave_backend/src/models/savings_goal.dart';
import 'package:smartsave_backend/src/models/savings_transaction.dart';

/// The current persisted representation version.
const int currentPersistedSchemaVersion = 1;

/// The complete local snapshot required to restore repository state.
///
/// This JSON representation is intended for prototype-scale storage:
/// thousands of transactions are fine, while tens of thousands are not.
final class PersistedData {
  /// Creates a persisted snapshot.
  PersistedData({
    this.schemaVersion = currentPersistedSchemaVersion,
    this.boundDeviceId,
    this.lastAckedSeq,
    this.knownDeviceTotal,
    this.lastSyncedAt,
    List<SavingsTransaction> transactions = const [],
    List<SavingsGoal> goals = const [],
  })  : transactions = List.unmodifiable(transactions),
        goals = List.unmodifiable(goals);

  /// Serialization schema version.
  final int schemaVersion;
  /// Identifier of the bound bank, when one is known.
  final String? boundDeviceId;
  /// Last cumulatively acknowledged sequence number.
  final int? lastAckedSeq;
  /// Last known authoritative device total.
  final int? knownDeviceTotal;
  /// Time of the last successful synchronization.
  final DateTime? lastSyncedAt;
  /// Locally recorded transactions.
  final List<SavingsTransaction> transactions;
  /// Locally configured goals.
  final List<SavingsGoal> goals;

  /// Returns an empty current-version snapshot.
  factory PersistedData.empty() => PersistedData();

  /// Returns a copy with selected fields replaced.
  PersistedData copyWith({
    int? schemaVersion,
    String? boundDeviceId,
    int? lastAckedSeq,
    int? knownDeviceTotal,
    DateTime? lastSyncedAt,
    List<SavingsTransaction>? transactions,
    List<SavingsGoal>? goals,
  }) =>
      PersistedData(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        boundDeviceId: boundDeviceId ?? this.boundDeviceId,
        lastAckedSeq: lastAckedSeq ?? this.lastAckedSeq,
        knownDeviceTotal: knownDeviceTotal ?? this.knownDeviceTotal,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        transactions: transactions ?? this.transactions,
        goals: goals ?? this.goals,
      );

  /// Converts this snapshot to JSON-compatible values.
  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'boundDeviceId': boundDeviceId,
        'lastAckedSeq': lastAckedSeq,
        'knownDeviceTotal': knownDeviceTotal,
        'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'goals': goals.map((item) => item.toJson()).toList(),
      };

  /// Parses a persisted snapshot.
  ///
  /// The switch is the migration hook for future schema versions. Add a
  /// migration branch before accepting a newer version.
  factory PersistedData.fromJson(Map<String, Object?> json) {
    try {
      final version = json['schemaVersion'];
      if (version is! int) throw const StorageError.corrupt();
      switch (version) {
        case 1:
          return _fromVersionOne(json);
        default:
          throw const StorageError.corrupt();
      }
    } on StorageError {
      rethrow;
    } catch (error) {
      throw StorageError.corrupt(error);
    }
  }

  static PersistedData _fromVersionOne(Map<String, Object?> json) {
    final rawTransactions = json['transactions'];
    final rawGoals = json['goals'];
    if (rawTransactions is! List || rawGoals is! List) {
      throw const StorageError.corrupt();
    }
    return PersistedData(
      schemaVersion: 1,
      boundDeviceId: json['boundDeviceId'] as String?,
      lastAckedSeq: json['lastAckedSeq'] as int?,
      knownDeviceTotal: json['knownDeviceTotal'] as int?,
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
      transactions: rawTransactions
          .map((item) => SavingsTransaction.fromJson(_asJsonMap(item)))
          .toList(),
      goals: rawGoals.map((item) => SavingsGoal.fromJson(_asJsonMap(item))).toList(),
    );
  }

  static Map<String, Object?> _asJsonMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return Map<String, Object?>.from(value);
    throw const StorageError.corrupt();
  }

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}
