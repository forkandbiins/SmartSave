import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/mascot.dart';
import '../../../core/theme.dart';

/// Shows the active goal's progress, or a friendly empty state.
///
/// When [onOpenGoals] is provided, a button switches to the Goal tab: a
/// "View goal" button when a goal exists, otherwise "Create a goal".
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.goal, this.onOpenGoals});

  /// The active goal to display, or null when there is none.
  final SavingsGoal? goal;

  /// Called when the goal-tab button is pressed.
  final VoidCallback? onOpenGoals;

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
              if (onOpenGoals != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpenGoals,
                  icon: const Icon(Icons.add),
                  label: const Text('Create a goal'),
                ),
              ],
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
            if (onOpenGoals != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenGoals,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View goal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
