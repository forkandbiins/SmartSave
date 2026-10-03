/// Aggregate statistics calculated from transactions.
final class SavingsStatistics {
  /// Creates aggregate statistics.
  SavingsStatistics({
    required this.totalDeposited,
    required this.transactionCount,
    required this.highestDay,
    required this.averagePerDay,
    required Map<DateTime, int> perDayTotals,
  }) : perDayTotals = Map.unmodifiable(perDayTotals);

  /// Total deposited amount.
  final int totalDeposited;
  /// Number of included transactions.
  final int transactionCount;
  /// Day with the highest total, if any.
  final DateTime? highestDay;
  /// Average deposited amount per day.
  final double averagePerDay;
  /// Totals keyed by UTC calendar day.
  final Map<DateTime, int> perDayTotals;

  /// Returns a copy with selected values replaced.
  SavingsStatistics copyWith({
    int? totalDeposited,
    int? transactionCount,
    DateTime? highestDay,
    double? averagePerDay,
    Map<DateTime, int>? perDayTotals,
  }) =>
      SavingsStatistics(
        totalDeposited: totalDeposited ?? this.totalDeposited,
        transactionCount: transactionCount ?? this.transactionCount,
        highestDay: highestDay ?? this.highestDay,
        averagePerDay: averagePerDay ?? this.averagePerDay,
        perDayTotals: perDayTotals ?? this.perDayTotals,
      );

  @override
  bool operator ==(Object other) =>
      other is SavingsStatistics &&
      totalDeposited == other.totalDeposited &&
      transactionCount == other.transactionCount &&
      highestDay == other.highestDay &&
      averagePerDay == other.averagePerDay &&
      _mapsEqual(perDayTotals, other.perDayTotals);

  @override
  int get hashCode => Object.hash(
        totalDeposited,
        transactionCount,
        highestDay,
        averagePerDay,
        Object.hashAll(perDayTotals.entries),
      );

  @override
  String toString() => 'SavingsStatistics(totalDeposited: $totalDeposited)';
}

bool _mapsEqual(Map<DateTime, int> first, Map<DateTime, int> second) =>
    first.length == second.length &&
    first.entries.every((entry) => second[entry.key] == entry.value);
