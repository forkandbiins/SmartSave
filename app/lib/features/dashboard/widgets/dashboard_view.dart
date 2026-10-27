import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/greeting_header.dart';
import '../../../shared/widgets/smart_save_scaffold.dart';
import 'error_banner.dart';
import 'goal_progress_card.dart';
import 'recent_deposits.dart';
import 'stat_grid.dart';
import 'total_savings_card.dart';

/// Presentational dashboard. Takes plain data so tests can drive it from fixtures.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.deviceTotal,
    required this.activeGoal,
    required this.todayTotal,
    required this.weekTotal,
    required this.totalDepositsCount,
    required this.lastDepositTime,
    required this.recentTransactions,
    required this.isSyncing,
    required this.lastError,
    required this.now,
    this.onOpenGoals,
  });

  /// Authoritative device total, or null before first sync.
  final int? deviceTotal;

  /// The first active goal, or null when none.
  final SavingsGoal? activeGoal;

  /// Total deposited today.
  final int todayTotal;

  /// Total deposited this week.
  final int weekTotal;

  /// Number of deposits all-time.
  final int totalDepositsCount;

  /// Time of the most recent deposit, or null.
  final DateTime? lastDepositTime;

  /// Latest transactions (newest first), already limited to a few entries.
  final List<SavingsTransaction> recentTransactions;

  /// Whether a synchronization is currently running.
  final bool isSyncing;

  /// Last typed error, if any.
  final SmartSaveError? lastError;

  /// Current time for greeting and relative timestamps.
  final DateTime now;

  /// Called when the goal card's button is pressed to open the Goal tab.
  final VoidCallback? onOpenGoals;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: GreetingHeader(now: now)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Savings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (isSyncing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (lastError != null) ...[
                  SmartSaveErrorText(
                    message: friendlyMessageFor(lastError!.code),
                  ),
                  const SizedBox(height: 12),
                ],
                TotalSavingsCard(deviceTotal: deviceTotal),
                const SizedBox(height: 12),
                GoalProgressCard(goal: activeGoal, onOpenGoals: onOpenGoals),
                const SizedBox(height: 12),
                StatGrid(
                  todayTotal: todayTotal,
                  weekTotal: weekTotal,
                  totalDepositsCount: totalDepositsCount,
                  lastDepositTime: lastDepositTime,
                  now: now,
                ),
                const SizedBox(height: 12),
                RecentDeposits(transactions: recentTransactions, now: now),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
