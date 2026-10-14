import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';

/// Card that shows a savings goal's name, peso progress, and redeem affordance.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onRedeem});

  /// Goal to display.
  final SavingsGoal goal;

  /// Called when Redeem is pressed. The button is shown only when the goal is
  /// fully funded, not redeemed, and this callback is provided.
  final VoidCallback? onRedeem;

  bool get _isRedeemed => goal.status == GoalStatus.redeemed;

  bool get _showRedeem =>
      goal.isReached && !_isRedeemed && onRedeem != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(goal.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: goal.progress),
            const SizedBox(height: 8),
            Text(
              '${formatPeso(goal.allocatedAmount)} of ${formatPeso(goal.targetAmount)}',
            ),
            if (_isRedeemed) ...[
              const SizedBox(height: 8),
              Text('Redeemed', style: theme.textTheme.labelLarge),
            ],
            if (_showRedeem) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onRedeem,
                  child: const Text('Redeem'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
