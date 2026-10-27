import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import 'goal_progress_ring.dart';

/// An editable card for an active goal.
///
/// The [featured] goal (the main active goal) shows a large progress ring;
/// other active goals show a compact progress bar.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.featured = false,
    this.busy = false,
    this.onEdit,
    this.onDelete,
    this.onAllocate,
    this.onRelease,
    this.onRedeem,
  });

  /// Goal to display.
  final SavingsGoal goal;

  /// Whether this is the main active goal shown with a progress ring.
  final bool featured;

  /// Whether an action is running; disables every control when true.
  final bool busy;

  /// Called when Edit is pressed.
  final VoidCallback? onEdit;

  /// Called when Delete is pressed.
  final VoidCallback? onDelete;

  /// Called when Add money is pressed.
  final VoidCallback? onAllocate;

  /// Called when Release is pressed.
  final VoidCallback? onRelease;

  /// Called when Redeem is pressed.
  final VoidCallback? onRedeem;

  bool get _showRedeem =>
      goal.isReached && goal.allocatedAmount > 0 && onRedeem != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (goal.progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : onEdit,
                  tooltip: 'Edit goal',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: busy ? null : onDelete,
                  tooltip: 'Delete goal',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (featured)
              Center(child: GoalProgressRing(goal: goal))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SmartSaveTokens.radiusInput,
                      ),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 12,
                        backgroundColor: SmartSaveTokens.primarySoft.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$percent%', style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatPeso(goal.allocatedAmount)} of ${formatPeso(goal.targetAmount)}',
                style: SmartSaveTokens.body.copyWith(
                  color: SmartSaveTokens.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onAllocate,
                  icon: const Icon(Icons.add),
                  label: const Text('Add money'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || goal.allocatedAmount <= 0 ? null : onRelease,
                  icon: const Icon(Icons.remove),
                  label: const Text('Release'),
                ),
                if (_showRedeem)
                  FilledButton(
                    onPressed: busy ? null : onRedeem,
                    child: const Text('Redeem'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only card for a redeemed goal.
class RedeemedGoalCard extends StatelessWidget {
  const RedeemedGoalCard({super.key, required this.goal});

  /// The redeemed goal to display.
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: SmartSaveTokens.success,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Redeemed · ${formatPeso(goal.targetAmount)}',
                    style: SmartSaveTokens.body.copyWith(
                      color: SmartSaveTokens.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
