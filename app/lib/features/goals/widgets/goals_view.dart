import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/smart_save_scaffold.dart';
import 'goal_card.dart';

/// Presentational savings-goals list. Takes plain data and callbacks so tests
/// can drive it without a controller.
class GoalsView extends StatelessWidget {
  const GoalsView({
    super.key,
    required this.goals,
    required this.available,
    required this.overAllocatedBy,
    required this.busy,
    required this.errorMessage,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onAllocate,
    required this.onRelease,
    required this.onRedeem,
  });

  /// All goals. Only [GoalStatus.active] and [GoalStatus.redeemed] are shown.
  final List<SavingsGoal> goals;

  /// Balance not yet allocated to any goal.
  final int available;

  /// Amount by which allocations exceed the balance (0 when healthy).
  final int overAllocatedBy;

  /// Whether an action is running; disables controls.
  final bool busy;

  /// Friendly failure text for the most recent action, if any.
  final String? errorMessage;

  /// Opens the create-goal sheet.
  final VoidCallback onCreate;

  /// Opens the edit-goal sheet for a goal.
  final ValueChanged<SavingsGoal> onEdit;

  /// Asks for confirmation, then deletes a goal.
  final ValueChanged<SavingsGoal> onDelete;

  /// Opens the allocate sheet for a goal.
  final ValueChanged<SavingsGoal> onAllocate;

  /// Opens the release sheet for a goal.
  final ValueChanged<SavingsGoal> onRelease;

  /// Starts the redeem flow for a goal.
  final ValueChanged<SavingsGoal> onRedeem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList(growable: false);
    final redeemed = goals
        .where((goal) => goal.status == GoalStatus.redeemed)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        // A Wrap (not a Row) so the button drops to its own line and its label
        // scales down instead of overflowing on narrow, large-text screens.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Goals', style: theme.textTheme.titleLarge),
            FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Create goal'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AvailableCard(available: available),
        if (overAllocatedBy > 0) ...[
          const SizedBox(height: 12),
          const SmartSaveErrorText(
            message:
                'Your goals are allocated more than your balance. Release some '
                'money to fix this.',
          ),
        ],
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          SmartSaveErrorText(message: errorMessage!),
        ],
        const SizedBox(height: 20),
        if (active.isEmpty && redeemed.isEmpty)
          const SmartSaveEmptyState(
            title: 'No goals yet',
            message: 'Create a goal to start saving toward something special.',
            icon: Icons.flag_outlined,
          )
        else ...[
          if (active.isNotEmpty) ...[
            _SectionLabel('Saving for'),
            for (var i = 0; i < active.length; i++)
              GoalCard(
                goal: active[i],
                featured: i == 0,
                busy: busy,
                onEdit: () => onEdit(active[i]),
                onDelete: () => onDelete(active[i]),
                onAllocate: () => onAllocate(active[i]),
                onRelease: () => onRelease(active[i]),
                onRedeem: () => onRedeem(active[i]),
              ),
          ],
          if (redeemed.isNotEmpty) ...[
            _SectionLabel('Redeemed'),
            for (final goal in redeemed) RedeemedGoalCard(goal: goal),
          ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.available});

  final int available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available to save',
              style: theme.textTheme.labelLarge?.copyWith(
                color: SmartSaveTokens.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(formatPeso(available), style: SmartSaveTokens.money),
          ],
        ),
      ),
    );
  }
}
