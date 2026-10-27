import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'deposit_buckets.dart';
import 'widgets/statistics_view.dart';

/// Thin wrapper that reads the controller and feeds plain data to
/// [StatisticsView]. No controller dependency leaks into tests.
class StatisticsScreen extends StatefulWidget {
  /// Creates the screen.
  const StatisticsScreen({super.key, required this.controller});

  /// Backend controller whose history drives the statistics.
  final SmartSaveController controller;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatsRange _range = StatsRange.daily;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final now = DateTime.now();
        final from = rangeStart(_range, now);
        final to = rangeEnd(_range, now);

        // Bounds are local midnights, so comparing raw instants matches the
        // local calendar days used for the bars (the Philippines is UTC+8).
        final transactions = widget.controller.getTransactions(
          TransactionQuery(from: from, to: to),
        );
        final buckets = bucketDeposits(transactions, _range, now);
        // Summary numbers come from the same local-day bucketing as the bars,
        // so the Highest day matches the tallest bar and Total saved equals the
        // sum of the bars (SavingsStatistics uses UTC days instead).
        final stats = depositStats(transactions, _range, now);

        return StatisticsView(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          buckets: buckets,
          depositCount: stats.depositCount,
          totalSaved: stats.totalSaved,
          averagePerDay: stats.averagePerDay,
          highestDay: stats.highestDay,
          highestDayAmount: stats.highestDayAmount,
        );
      },
    );
  }
}
