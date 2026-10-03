import 'denomination.dart';

/// The business meaning of a savings transaction.
enum TransactionType {
  /// Money deposited.
  deposit,
  /// Money redeemed.
  redemption,
  /// Balance reconciliation.
  adjustment,
  /// Initial balance.
  openingBalance,
}

/// The accuracy of a transaction timestamp.
enum TimeAccuracy {
  /// Observed while connected.
  observedLive,
  /// Observed later during synchronization.
  syncedLate,
  /// Created by a user action.
  userAction,
}

/// An immutable entry in the local savings history.
final class SavingsTransaction {
  /// Creates a savings transaction.
  const SavingsTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.denomination,
    this.seq,
    required this.timestamp,
    required this.timeAccuracy,
    this.goalId,
    this.note,
  });

  /// Stable transaction identifier.
  final String id;
  /// Transaction type.
  final TransactionType type;
  /// Signed amount in pesos.
  final int amount;
  /// Coin denomination, when applicable.
  final Denomination? denomination;
  /// Device sequence number, when applicable.
  final int? seq;
  /// Timestamp of the transaction.
  final DateTime timestamp;
  /// Timestamp accuracy.
  final TimeAccuracy timeAccuracy;
  /// Related goal identifier.
  final String? goalId;
  /// Optional note.
  final String? note;

  /// Serializes this transaction.
  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'denomination': denomination?.value,
        'seq': seq,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'timeAccuracy': timeAccuracy.name,
        'goalId': goalId,
        'note': note,
      };

  /// Deserializes a transaction.
  factory SavingsTransaction.fromJson(Map<String, Object?> json) {
    final type = _enumByName(TransactionType.values, json['type'], 'type');
    final accuracy =
        _enumByName(TimeAccuracy.values, json['timeAccuracy'], 'timeAccuracy');
    final denominationValue = json['denomination'] as int?;
    return SavingsTransaction(
      id: json['id']! as String,
      type: type,
      amount: json['amount']! as int,
      denomination: denominationValue == null
          ? null
          : Denomination.fromValue(denominationValue),
      seq: json['seq'] as int?,
      timestamp: DateTime.parse(json['timestamp']! as String).toUtc(),
      timeAccuracy: accuracy,
      goalId: json['goalId'] as String?,
      note: json['note'] as String?,
    );
  }

  /// Returns a copy with selected values replaced.
  SavingsTransaction copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    Denomination? denomination,
    int? seq,
    DateTime? timestamp,
    TimeAccuracy? timeAccuracy,
    String? goalId,
    String? note,
  }) =>
      SavingsTransaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        denomination: denomination ?? this.denomination,
        seq: seq ?? this.seq,
        timestamp: timestamp ?? this.timestamp,
        timeAccuracy: timeAccuracy ?? this.timeAccuracy,
        goalId: goalId ?? this.goalId,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is SavingsTransaction &&
      id == other.id &&
      type == other.type &&
      amount == other.amount &&
      denomination == other.denomination &&
      seq == other.seq &&
      timestamp == other.timestamp &&
      timeAccuracy == other.timeAccuracy &&
      goalId == other.goalId &&
      note == other.note;

  @override
  int get hashCode =>
      Object.hash(id, type, amount, denomination, seq, timestamp, timeAccuracy,
          goalId, note);

  @override
  String toString() => 'SavingsTransaction(id: $id, amount: $amount)';
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  throw FormatException('Unknown $field: $value');
}
