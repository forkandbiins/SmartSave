import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';

/// Confirmation dialog for redeeming a goal.
///
/// Explains that the bank unlocks and the allocated amount is removed, then
/// collects a masked 4-digit PIN. Returns the PIN through `Navigator.pop`, or
/// null when cancelled. The PIN lives only in this field and is never stored.
class RedeemDialog extends StatefulWidget {
  const RedeemDialog({super.key, required this.goal});

  /// The goal being redeemed.
  final SavingsGoal goal;

  @override
  State<RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<RedeemDialog> {
  final TextEditingController _pin = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _pin.addListener(() {
      final ready = _pin.text.length == 4;
      if (ready != _canSubmit) setState(() => _canSubmit = ready);
    });
  }

  @override
  void dispose() {
    _pin.clear();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Redeem goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Redeeming "${widget.goal.name}" unlocks your bank and removes '
            '${formatPeso(widget.goal.allocatedAmount)} from this goal.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Bank PIN',
              hintText: '4 digits',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _canSubmit ? () => Navigator.of(context).pop(_pin.text) : null,
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
