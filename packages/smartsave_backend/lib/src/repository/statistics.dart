import '../models/savings_statistics.dart';
import '../models/savings_transaction.dart';

/// Returns daily deposited totals keyed by UTC calendar day.
Map<DateTime, int> perDayTotals(List<SavingsTransaction> transactions) {
  final result = <DateTime, int>{};
  for (final transaction in transactions) {
    if (transaction.type != TransactionType.deposit) continue;
    final date = DateTime.utc(
      transaction.timestamp.year,
      transaction.timestamp.month,
      transaction.timestamp.day,
    );
    result[date] = (result[date] ?? 0) + transaction.amount;
  }
  return Map.unmodifiable(result);
}

/// Returns deposited totals for the seven-day period containing [day].
Map<DateTime, int> weekly(
  List<SavingsTransaction> transactions,
  DateTime day,
) {
  final end = DateTime.utc(day.year, day.month, day.day);
  final start = end.subtract(const Duration(days: 6));
  return Map.unmodifiable(
    perDayTotals(transactions).map(
      (date, total) => MapEntry(date, date.isBefore(start) || date.isAfter(end) ? 0 : total),
    )..removeWhere((_, total) => total == 0),
  );
}

/// Returns deposited totals for the calendar month containing [month].
Map<DateTime, int> monthly(
  List<SavingsTransaction> transactions,
  DateTime month,
) =>
    Map.unmodifiable(
      perDayTotals(transactions).map(
        (date, total) => MapEntry(
          date,
          date.year == month.year && date.month == month.month ? total : 0,
        ),
      )..removeWhere((_, total) => total == 0),
    );

/// Returns the day with the largest deposited total.
DateTime? highestDay(List<SavingsTransaction> transactions) {
  final totals = perDayTotals(transactions);
  if (totals.isEmpty) return null;
  return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Returns the average deposited amount per day with deposits.
double averagePerDay(List<SavingsTransaction> transactions) {
  final totals = perDayTotals(transactions);
  if (totals.isEmpty) return 0;
  return totals.values.fold<int>(0, (sum, value) => sum + value) / totals.length;
}

/// Counts deposited transactions.
int count(List<SavingsTransaction> transactions) =>
    transactions.where((item) => item.type == TransactionType.deposit).length;

/// Calculates all aggregate statistics for [transactions].
SavingsStatistics statistics(List<SavingsTransaction> transactions) {
  final totals = perDayTotals(transactions);
  return SavingsStatistics(
    totalDeposited: totals.values.fold<int>(0, (sum, value) => sum + value),
    transactionCount: count(transactions),
    highestDay: highestDay(transactions),
    averagePerDay: averagePerDay(transactions),
    perDayTotals: totals,
  );
}
