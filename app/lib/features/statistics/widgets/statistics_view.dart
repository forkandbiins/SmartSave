import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../deposit_buckets.dart';
import 'deposit_bar_chart.dart';
import 'range_selector.dart';
import 'statistics_empty_state.dart';
import 'statistics_summary.dart';

/// Presentational Statistics screen. Takes plain data so tests can drive it
/// from fixtures without a controller.
class StatisticsView extends StatelessWidget {
  /// Creates the view.
  const StatisticsView({
    super.key,
    required this.range,
    required this.onRangeChanged,
    required this.buckets,
    required this.depositCount,
    required this.totalSaved,
    required this.averagePerDay,
    required this.highestDay,
    required this.highestDayAmount,
  });

  /// Selected window.
  final StatsRange range;

  /// Called when the user picks another window.
  final ValueChanged<StatsRange> onRangeChanged;

  /// One bar per period, oldest first.
  final List<DepositBucket> buckets;

  /// Number of deposits in the range; zero shows the empty state.
  final int depositCount;

  /// Total pesos deposited in the range.
  final int totalSaved;

  /// Mean pesos deposited per day that had a deposit, already rounded.
  final int averagePerDay;

  /// Day with the largest deposited total, or null.
  final DateTime? highestDay;

  /// Pesos deposited on [highestDay].
  final int highestDayAmount;

  String get _semanticsSummary {
    if (highestDay == null) {
      return 'No deposits in this range.';
    }
    return 'Highest day: ${shortDate(highestDay!)}, '
        '${formatPeso(highestDayAmount)}. '
        'Total saved in this range: ${formatPeso(totalSaved)}.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Statistics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'See how your savings grow.',
            style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
          ),
          const SizedBox(height: 16),
          StatsRangeSelector(range: range, onChanged: onRangeChanged),
          const SizedBox(height: 16),
          if (depositCount == 0)
            const StatisticsEmptyState()
          else ...[
            DepositBarChart(
              buckets: buckets,
              semanticsSummary: _semanticsSummary,
            ),
            const SizedBox(height: 20),
            StatisticsSummary(
              highestDay: highestDay,
              highestDayAmount: highestDayAmount,
              averagePerDay: averagePerDay,
              depositCount: depositCount,
              totalSaved: totalSaved,
            ),
          ],
        ],
      ),
    );
  }
}
