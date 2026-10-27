import 'package:smartsave_backend/smartsave_backend.dart';

/// The time window shown on the Statistics screen.
enum StatsRange {
  /// One bar per local calendar day, for the last 7 days.
  daily,

  /// One bar per local calendar week, for the last 4 weeks.
  weekly,

  /// One bar per local calendar month, for the last 6 months.
  monthly,
}

/// A single bar: a local calendar period and the pesos deposited in it.
class DepositBucket {
  /// Creates a bucket.
  const DepositBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.total,
  });

  /// Inclusive start of the period, in local time.
  final DateTime start;

  /// Exclusive end of the period, in local time.
  final DateTime end;

  /// Short axis label: `Mon`, `01-05`, or `Jan`.
  final String label;

  /// Sum of deposits inside the period, in whole pesos.
  final int total;

  /// Returns a copy with a new [total].
  DepositBucket withTotal(int total) =>
      DepositBucket(start: start, end: end, label: label, total: total);
}

/// Number of bars drawn for [range].
int barCountFor(StatsRange range) {
  switch (range) {
    case StatsRange.daily:
      return 7;
    case StatsRange.weekly:
      return 4;
    case StatsRange.monthly:
      return 6;
  }
}

/// Inclusive local start of the window shown for [range] at [now].
DateTime rangeStart(StatsRange range, DateTime now) {
  final today = _localMidnight(now);
  switch (range) {
    case StatsRange.daily:
      return DateTime(today.year, today.month, today.day - 6);
    case StatsRange.weekly:
      return DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1) - 21,
      );
    case StatsRange.monthly:
      return DateTime(today.year, today.month - 5);
  }
}

/// Exclusive local end of the window shown for [range] at [now].
DateTime rangeEnd(StatsRange range, DateTime now) {
  final today = _localMidnight(now);
  switch (range) {
    case StatsRange.daily:
      return DateTime(today.year, today.month, today.day + 1);
    case StatsRange.weekly:
      return DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1) + 7,
      );
    case StatsRange.monthly:
      return DateTime(today.year, today.month + 1);
  }
}

/// Buckets the deposits in [transactions] into [range] bars ending at [now].
///
/// Only [TransactionType.deposit] counts, and each timestamp is converted to
/// local time first so early-morning deposits (UTC+8) land on the right day.
/// Redemptions and adjustments are ignored. Pure and deterministic given [now].
List<DepositBucket> bucketDeposits(
  List<SavingsTransaction> transactions,
  StatsRange range,
  DateTime now,
) {
  final buckets = _emptyBuckets(range, now);
  final start = rangeStart(range, now);
  final end = rangeEnd(range, now);

  for (final transaction in transactions) {
    if (transaction.type != TransactionType.deposit) continue;
    final local = transaction.timestamp.toLocal();
    if (local.isBefore(start) || !local.isBefore(end)) continue;
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      if (!local.isBefore(bucket.start) && local.isBefore(bucket.end)) {
        buckets[index] = bucket.withTotal(bucket.total + transaction.amount);
        break;
      }
    }
  }

  return List.unmodifiable(buckets);
}

/// Per-local-day deposit totals plus the headline numbers for a range.
class DepositStats {
  /// Creates the stats.
  const DepositStats({
    required this.perDayTotals,
    required this.highestDay,
    required this.highestDayAmount,
    required this.averagePerDay,
    required this.depositCount,
    required this.totalSaved,
  });

  /// Total pesos deposited on each local calendar day that had a deposit,
  /// keyed by that day's local midnight. Empty when the range has no deposits.
  final Map<DateTime, int> perDayTotals;

  /// Local day with the largest deposited total, or null when empty.
  final DateTime? highestDay;

  /// Pesos deposited on [highestDay]; zero when empty.
  final int highestDayAmount;

  /// Mean pesos per local day that had a deposit, rounded to a whole peso;
  /// zero when empty.
  final int averagePerDay;

  /// Number of deposits counted in the range.
  final int depositCount;

  /// Total pesos deposited in the range; equals the sum of the bars returned by
  /// [bucketDeposits] for the same inputs.
  final int totalSaved;
}

/// Computes [DepositStats] for [range] at [now] from [transactions].
///
/// Uses the same local-day bucketing as [bucketDeposits]: only
/// [TransactionType.deposit] counts, each timestamp is converted to local time
/// first so early-morning deposits (UTC+8) land on the right day, and
/// redemptions/adjustments are ignored. The highest day is the earliest day
/// that reaches the largest total, matching the tallest bar the chart
/// highlights. Pure and deterministic given [now].
DepositStats depositStats(
  List<SavingsTransaction> transactions,
  StatsRange range,
  DateTime now,
) {
  final start = rangeStart(range, now);
  final end = rangeEnd(range, now);
  final perDayTotals = <DateTime, int>{};
  var depositCount = 0;
  var totalSaved = 0;

  for (final transaction in transactions) {
    if (transaction.type != TransactionType.deposit) continue;
    final local = transaction.timestamp.toLocal();
    if (local.isBefore(start) || !local.isBefore(end)) continue;
    final day = DateTime(local.year, local.month, local.day);
    perDayTotals[day] = (perDayTotals[day] ?? 0) + transaction.amount;
    depositCount += 1;
    totalSaved += transaction.amount;
  }

  final days = perDayTotals.keys.toList()..sort();
  DateTime? highestDay;
  var highestDayAmount = 0;
  for (final day in days) {
    final amount = perDayTotals[day]!;
    if (highestDay == null || amount > highestDayAmount) {
      highestDay = day;
      highestDayAmount = amount;
    }
  }

  return DepositStats(
    perDayTotals: Map.unmodifiable(perDayTotals),
    highestDay: highestDay,
    highestDayAmount: highestDayAmount,
    averagePerDay: days.isEmpty ? 0 : (totalSaved / days.length).round(),
    depositCount: depositCount,
    totalSaved: totalSaved,
  );
}

/// Returns `Mon`..`Sun` for [date].
String weekdayLabel(DateTime date) => _weekdays[date.weekday - 1];

/// Returns `Jan`..`Dec` for [date].
String monthLabel(DateTime date) => _months[date.month - 1];

/// Formats the fields of [date] as `mm-dd-yy` without shifting its day.
String shortDate(DateTime date) =>
    '${_two(date.month)}-${_two(date.day)}-${_two(date.year % 100)}';

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime _localMidnight(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

List<DepositBucket> _emptyBuckets(StatsRange range, DateTime now) {
  final start = rangeStart(range, now);
  switch (range) {
    case StatsRange.daily:
      return List<DepositBucket>.generate(7, (index) {
        final day = DateTime(start.year, start.month, start.day + index);
        return DepositBucket(
          start: day,
          end: DateTime(start.year, start.month, start.day + index + 1),
          label: weekdayLabel(day),
          total: 0,
        );
      });
    case StatsRange.weekly:
      return List<DepositBucket>.generate(4, (index) {
        final week = DateTime(start.year, start.month, start.day + index * 7);
        return DepositBucket(
          start: week,
          end: DateTime(start.year, start.month, start.day + index * 7 + 7),
          label: '${_two(week.month)}-${_two(week.day)}',
          total: 0,
        );
      });
    case StatsRange.monthly:
      return List<DepositBucket>.generate(6, (index) {
        final month = DateTime(start.year, start.month + index);
        return DepositBucket(
          start: month,
          end: DateTime(month.year, month.month + 1),
          label: monthLabel(month),
          total: 0,
        );
      });
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
