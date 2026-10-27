import 'package:flutter/material.dart' hide LockState;
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../connection/connection_screen.dart';

/// Bank status, PIN, balance correction, and local data controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  /// Backend controller for settings actions.
  final SmartSaveController controller;

  Future<void> _changePin(BuildContext context) async {
    final pin = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change PIN'),
        content: TextField(
          controller: pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'New 4-digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pin.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    pin.dispose();
    if (result == null || !context.mounted) return;
    final action = await controller.changePin(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action.isSuccess ? 'PIN changed.' : friendlyError(action.errorOrNull),
        ),
      ),
    );
  }

  Future<void> _adjustBalance(BuildContext context) async {
    final amount = TextEditingController(
      text: controller.state.deviceTotal?.toString() ?? '',
    );
    final note = TextEditingController();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix your balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the total amount that is really in your Bank.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New total (₱)'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (amount.text, note.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    amount.dispose();
    note.dispose();
    if (values == null || !context.mounted) return;
    final parsed = int.tryParse(values.$1);
    if (parsed == null || parsed < 0 || parsed > 99999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount from ₱0 to ₱99,999.')),
      );
      return;
    }
    final pin = await _pinDialog(context);
    if (pin == null || !context.mounted) return;
    final action = await controller.adjustBalance(
      pin,
      parsed,
      note: values.$2.isEmpty ? null : values.$2,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action.isSuccess
              ? 'Balance corrected.'
              : friendlyError(action.errorOrNull),
        ),
      ),
    );
  }

  Future<String?> _pinDialog(BuildContext context) => showDialog<String>(
    context: context,
    builder: (context) {
      final pin = TextEditingController();
      return AlertDialog(
        title: const Text('Confirm with PIN'),
        content: TextField(
          controller: pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pin.text),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
          'This removes cached history, goals, and the Bank binding from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await controller.resetLocalData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Local data reset.'
              : friendlyError(result.errorOrNull),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final total = state.deviceTotal;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(
                  state.lock == LockState.unlocked
                      ? Icons.lock_open
                      : Icons.lock,
                  color: SmartSaveTokens.primary,
                ),
                title: Text(
                  state.lock == LockState.unlocked
                      ? 'Bank unlocked'
                      : 'Bank locked',
                ),
                subtitle: Text(
                  <String>[
                    total == null
                        ? 'Balance not synced yet'
                        : 'Balance ${formatPeso(total)}',
                    if (state.lock != LockState.unlocked)
                      'Redeem a goal to unlock',
                  ].join('\n'),
                ),
                trailing: state.lock == LockState.unlocked
                    ? OutlinedButton(
                        onPressed: () => controller.lockBank(),
                        child: const Text('Lock'),
                      )
                    : null,
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: const Text('Bank connection'),
                    subtitle: Text(
                      state.link == LinkState.ready
                          ? 'Connected'
                          : 'Disconnected',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ConnectionScreen(controller: controller),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('Change PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePin(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Correct Bank balance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _adjustBalance(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => controller.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _reset(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Reset local data'),
            ),
          ],
        );
      },
    );
  }
}
