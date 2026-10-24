import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'widgets/dashboard_view.dart';

/// Thin wrapper that reads the controller via [ListenableBuilder] and feeds
/// plain data to [DashboardView]. No controller dependency leaks into tests.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    this.onOpenGoals,
  });

  /// Backend controller whose state drives the dashboard.
  final SmartSaveController controller;

  /// Called to switch to the Goal tab from the goal card.
  final VoidCallback? onOpenGoals;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        final nextWeekStart = weekStart.add(const Duration(days: 7));

        final todayStats = controller.statistics(
          from: todayStart,
          to: tomorrowStart,
        );
        final weekStats = controller.statistics(
          from: weekStart,
          to: nextWeekStart,
        );
        final allStats = controller.statistics();

        SavingsGoal? activeGoal;
        for (final goal in state.goals) {
          if (goal.status == GoalStatus.active) {
            activeGoal = goal;
            break;
          }
        }

        DateTime? lastDepositTime;
        for (final txn in state.transactions) {
          if (txn.type == TransactionType.deposit) {
            lastDepositTime = txn.timestamp;
            break;
          }
        }

        return DashboardView(
          deviceTotal: state.deviceTotal,
          activeGoal: activeGoal,
          todayTotal: todayStats.totalDeposited,
          weekTotal: weekStats.totalDeposited,
          totalDepositsCount: allStats.transactionCount,
          lastDepositTime: lastDepositTime,
          recentTransactions: state.transactions.take(5).toList(),
          isSyncing: state.syncStatus == SyncStatus.syncing,
          lastError: state.lastError,
          now: now,
          onOpenGoals: onOpenGoals,
        );
      },
    );
  }
}
