import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/mascot.dart';
import '../../../core/theme.dart';

/// Shows the active goal's progress, or a friendly empty state.
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.goal});

  /// The active goal to display, or null when there is none.
  final SavingsGoal? goal;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const PigMascot(size: 64),
              const SizedBox(height: 12),
              Text(
                'No goal yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Set a savings goal to watch your progress grow.',
                style: SmartSaveTokens.body.copyWith(
                  color: SmartSaveTokens.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: SmartSaveTokens.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 12,
                backgroundColor:
                    SmartSaveTokens.primarySoft.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatPeso(goal.allocatedAmount)} of ${formatPeso(goal.targetAmount)}',
              style: SmartSaveTokens.body.copyWith(
                color: SmartSaveTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
