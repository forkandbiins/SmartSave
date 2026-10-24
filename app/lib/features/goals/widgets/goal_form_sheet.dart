import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'goal_validators.dart';

/// The values collected by [GoalFormSheet].
class GoalDraft {
  const GoalDraft({required this.name, required this.targetAmount});

  /// Trimmed goal name.
  final String name;

  /// Target amount in whole pesos.
  final int targetAmount;
}

/// Bottom sheet used to create or edit a goal.
///
/// Returns a [GoalDraft] through `Navigator.pop`, or null when cancelled.
class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.goal});

  /// The goal being edited, or null when creating a new goal.
  final SavingsGoal? goal;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  String? _error;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.goal?.name ?? '');
    _target = TextEditingController(
      text: widget.goal == null ? '' : widget.goal!.targetAmount.toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    final nameError = validateGoalName(_name.text);
    final targetError = validateTargetAmount(
      _target.text,
      allocatedAmount: widget.goal?.allocatedAmount,
    );
    final error = nameError ?? targetError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      GoalDraft(
        name: _name.text.trim(),
        targetAmount: int.parse(_target.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit goal' : 'Create a goal',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Goal name',
                hintText: 'e.g. New shoes',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₱ ',
                hintText: 'e.g. 500',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(_isEditing ? 'Save' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
