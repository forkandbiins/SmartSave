import 'package:flutter/material.dart';

import '../../../core/format.dart';
import 'stat_tile.dart';

/// A 2x2 grid of stat tiles: Today, This week, Total deposits, Last deposit.
class StatGrid extends StatelessWidget {
  const StatGrid({
    super.key,
    required this.todayTotal,
    required this.weekTotal,
    required this.totalDepositsCount,
    required this.lastDepositTime,
    required this.now,
  });

  /// Total deposited today.
  final int todayTotal;

  /// Total deposited this week.
  final int weekTotal;

  /// Number of deposits all-time.
  final int totalDepositsCount;

  /// Time of the most recent deposit, or null if there are none.
  final DateTime? lastDepositTime;

  /// Current time used to render the relative "Last deposit" label.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        StatTile(
          icon: Icons.today_outlined,
          label: 'Today',
          value: formatPeso(todayTotal),
        ),
        StatTile(
          icon: Icons.calendar_view_week_outlined,
          label: 'This week',
          value: formatPeso(weekTotal),
        ),
        StatTile(
          icon: Icons.savings_outlined,
          label: 'Total deposits',
          value:
              '$totalDepositsCount deposit${totalDepositsCount == 1 ? '' : 's'}',
        ),
        StatTile(
          icon: Icons.schedule_outlined,
          label: 'Last deposit',
          value: lastDepositTime == null
              ? '—'
              : formatDateTime(lastDepositTime!, now),
        ),
      ],
    );
  }
}
