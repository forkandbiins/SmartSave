import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';

/// Bottom sheet for allocating to or releasing from a goal.
///
/// Collects a whole-peso amount with quick-amount shortcuts, validates it with
/// [validator], and returns the amount through `Navigator.pop` (or null).
class MoneyActionSheet extends StatefulWidget {
  const MoneyActionSheet({
    super.key,
    required this.title,
    required this.caption,
    required this.submitLabel,
    required this.maxAmount,
    required this.validator,
    this.quickAmounts = const [20, 50, 100, 200],
  });

  /// Sheet title, e.g. `Add to New shoes`.
  final String title;

  /// One short line of context, e.g. `You have ₱300 available`.
  final String caption;

  /// Submit button label.
  final String submitLabel;

  /// Largest amount the amount field can accept; used to filter shortcuts.
  final int maxAmount;

  /// Returns a friendly error message, or null when [amount] is valid.
  final String? Function(int? amount) validator;

  /// Quick-amount shortcuts offered as chips.
  final List<int> quickAmounts;

  @override
  State<MoneyActionSheet> createState() => _MoneyActionSheetState();
}

class _MoneyActionSheetState extends State<MoneyActionSheet> {
  final TextEditingController _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _amount.text.trim();
    final value = text.isEmpty ? null : int.tryParse(text);
    final error = widget.validator(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortcuts = widget.quickAmounts
        .where((amount) => amount > 0 && amount <= widget.maxAmount)
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              widget.caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
              ),
            ),
            if (shortcuts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in shortcuts)
                    ActionChip(
                      label: Text(formatPeso(amount)),
                      onPressed: () => setState(() {
                        _amount.text = amount.toString();
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
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
                    child: Text(widget.submitLabel),
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
