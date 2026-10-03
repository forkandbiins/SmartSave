import 'savings_transaction.dart';

/// Filters used when querying transaction history.
final class TransactionQuery {
  /// Creates a transaction query.
  TransactionQuery({
    this.from,
    this.to,
    List<TransactionType> types = const <TransactionType>[],
    this.goalId,
    this.limit,
  }) : types = List.unmodifiable(types);

  /// Inclusive start date.
  final DateTime? from;
  /// Exclusive end date.
  final DateTime? to;
  /// Transaction types to include.
  final List<TransactionType> types;
  /// Goal identifier to include.
  final String? goalId;
  /// Maximum number of results.
  final int? limit;

  /// Returns a copy with selected values replaced.
  TransactionQuery copyWith({
    DateTime? from,
    DateTime? to,
    List<TransactionType>? types,
    String? goalId,
    int? limit,
  }) =>
      TransactionQuery(
        from: from ?? this.from,
        to: to ?? this.to,
        types: types ?? this.types,
        goalId: goalId ?? this.goalId,
        limit: limit ?? this.limit,
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionQuery &&
      from == other.from &&
      to == other.to &&
      _listEquals(types, other.types) &&
      goalId == other.goalId &&
      limit == other.limit;

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(types), goalId, limit);

  @override
  String toString() => 'TransactionQuery(from: $from, to: $to, limit: $limit)';
}

bool _listEquals<T>(List<T> first, List<T> second) =>
    first.length == second.length &&
    Iterable<int>.generate(first.length).every((index) => first[index] == second[index]);
