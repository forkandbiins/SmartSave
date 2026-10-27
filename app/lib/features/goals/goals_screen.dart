import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/format.dart';
import '../../core/mascot.dart';
import 'widgets/goal_error_text.dart';
import 'widgets/goal_form_sheet.dart';
import 'widgets/goal_validators.dart';
import 'widgets/goals_view.dart';
import 'widgets/money_action_sheet.dart';
import 'widgets/redeem_dialog.dart';

/// Savings Goal screen.
///
/// Thin wrapper that reads the controller via [ListenableBuilder], runs goal
/// actions, and feeds plain data to [GoalsView]. Handles every [ActionResult]
/// inline and celebrates [GoalReached] with a non-blocking snackbar.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, required this.controller});

  /// Backend controller whose state drives the screen.
  final SmartSaveController controller;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _busy = false;
  String? _errorMessage;
  StreamSubscription<SmartSaveEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = widget.controller.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _onEvent(SmartSaveEvent event) {
    if (event is! GoalReached || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const PigMascot(size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text('Goal reached: ${event.goal.name}!')),
          ],
        ),
      ),
    );
  }

  Future<void> _run<T>(
    Future<ActionResult<T>> Function() action, {
    String? success,
  }) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final result = await action();
    if (!mounted) return;
    final error = result.errorOrNull;
    setState(() {
      _busy = false;
      _errorMessage = error == null ? null : friendlyGoalError(error.code);
    });
    if (result.isSuccess && success != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    }
  }

  Future<void> _openCreate() async {
    final draft = await showModalBottomSheet<GoalDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const GoalFormSheet(),
    );
    if (draft == null || !mounted) return;
    await _run(() => widget.controller.createGoal(draft.name, draft.targetAmount));
  }

  Future<void> _openEdit(SavingsGoal goal) async {
    final draft = await showModalBottomSheet<GoalDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoalFormSheet(goal: goal),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => widget.controller.updateGoal(
        goal.id,
        name: draft.name,
        targetAmount: draft.targetAmount,
      ),
    );
  }

  Future<void> _confirmDelete(SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal'),
        content: Text('Delete "${goal.name}"? Any money set aside is released.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => widget.controller.deleteGoal(goal.id),
      success: 'Goal deleted.',
    );
  }

  Future<void> _openAllocate(SavingsGoal goal) async {
    final available = widget.controller.state.summary.available;
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MoneyActionSheet(
        title: 'Add to ${goal.name}',
        caption: 'You have ${formatPeso(available)} available.',
        submitLabel: 'Add money',
        maxAmount: available,
        validator: (value) => validateAllocateAmount(value, available),
      ),
    );
    if (amount == null || !mounted) return;
    await _run(() => widget.controller.allocateToGoal(goal.id, amount));
  }

  Future<void> _openRelease(SavingsGoal goal) async {
    final allocated = goal.allocatedAmount;
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MoneyActionSheet(
        title: 'Release from ${goal.name}',
        caption: '${formatPeso(allocated)} is set aside for this goal.',
        submitLabel: 'Release',
        maxAmount: allocated,
        validator: (value) => validateReleaseAmount(value, allocated),
      ),
    );
    if (amount == null || !mounted) return;
    await _run(() => widget.controller.releaseFromGoal(goal.id, amount));
  }

  Future<void> _startRedeem(SavingsGoal goal) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => RedeemDialog(goal: goal),
    );
    if (pin == null || !mounted) return;
    await _run(
      () => widget.controller.redeemGoal(goal.id, pin),
      success: 'Goal redeemed. Your bank is unlocked.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final summary = state.summary;
        return GoalsView(
          goals: state.goals,
          available: summary.available,
          overAllocatedBy: summary.overAllocatedBy,
          busy: _busy,
          errorMessage: _errorMessage,
          onCreate: _openCreate,
          onEdit: _openEdit,
          onDelete: _confirmDelete,
          onAllocate: _openAllocate,
          onRelease: _openRelease,
          onRedeem: _startRedeem,
        );
      },
    );
  }
}
