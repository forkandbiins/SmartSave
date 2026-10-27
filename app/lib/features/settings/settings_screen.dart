import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../shared/widgets/smart_save_scaffold.dart';
import '../connection/connection_screen.dart';

/// Bank status, PIN, balance correction, and local data controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  /// Backend controller for settings actions.
  final SmartSaveController controller;

  Future<void> _changePin(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePinDialog(controller: controller),
    );
    if (changed != true || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('PIN changed.')));
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

/// Wrong current-PIN attempts allowed before the dialog pauses the form.
///
/// The device uses `ProtocolLimits.maxFailedPins`, which the backend package
/// does not export, so the limit is mirrored here as a local constant.
const int _maxWrongPinAttempts = 3;

/// Three-field Change PIN dialog that verifies the current PIN on the device.
///
/// `SmartSaveController.changePin` reports a failure but does not track wrong
/// attempts nor flip the app into a locked-out state, so this dialog owns the
/// attempt counter, the "tries left" copy and the lockout countdown.
class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog({required this.controller});

  /// Backend controller used to verify and change the PIN.
  final SmartSaveController controller;

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _newPin = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _attemptMessage;
  bool _busy = false;
  int _wrongAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _countdown;

  bool get _locked => _lockedUntil != null;

  Duration get _lockoutDuration => widget.controller.config.lockoutDuration;

  int get _remainingSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final left = until.difference(widget.controller.clock.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  String? get _notice {
    if (_locked) {
      return 'Too many incorrect attempts. '
          'Try again in ${_remainingSeconds}s.';
    }
    return _attemptMessage;
  }

  @override
  void dispose() {
    // Disposing the controllers drops all three PIN fields on close; the PINs
    // are never logged or persisted.
    _countdown?.cancel();
    _current.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static bool _isFourDigits(String value) => RegExp(r'^\d{4}$').hasMatch(value);

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _countdown?.cancel();
        setState(() {
          _lockedUntil = null;
          _wrongAttempts = 0;
          _attemptMessage = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  void _lockFor(DateTime until) {
    setState(() {
      _lockedUntil = until;
      _wrongAttempts = _maxWrongPinAttempts;
      _attemptMessage = null;
    });
    _startCountdown();
  }

  Future<void> _save() async {
    final current = _current.text;
    final next = _newPin.text;
    final confirm = _confirm.text;

    final currentError = _isFourDigits(current)
        ? null
        : 'Enter your current 4-digit PIN.';
    final String? newError;
    if (!_isFourDigits(next)) {
      newError = 'Enter a new 4-digit PIN.';
    } else if (next == current) {
      newError = 'Choose a PIN different from your current one.';
    } else {
      newError = null;
    }
    final confirmError = confirm == next ? null : 'The new PINs do not match.';

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
      _attemptMessage = null;
    });
    if (currentError != null || newError != null || confirmError != null) {
      return;
    }

    setState(() => _busy = true);
    final action = await widget.controller.changePin(next, oldPin: current);
    if (!mounted) return;
    setState(() => _busy = false);

    if (action.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    _handleFailure(action.errorOrNull);
  }

  void _handleFailure(SmartSaveError? error) {
    final now = widget.controller.clock.now();
    if (error is AuthError && error.code == SmartSaveErrorCode.lockedOut) {
      _lockFor(error.until ?? now.add(_lockoutDuration));
      return;
    }
    if (error is AuthError && error.code == SmartSaveErrorCode.wrongPin) {
      final attempts = _wrongAttempts + 1;
      if (attempts >= _maxWrongPinAttempts) {
        _lockFor(now.add(_lockoutDuration));
      } else {
        setState(() {
          _wrongAttempts = attempts;
          _attemptMessage =
              'Incorrect PIN. ${_maxWrongPinAttempts - attempts} tries left.';
        });
      }
      return;
    }
    setState(() => _attemptMessage = friendlyError(error));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    String? errorText,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_locked;
    final notice = _notice;
    return AlertDialog(
      title: const Text('Change PIN'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice != null) ...[
            SmartSaveErrorText(message: notice),
            const SizedBox(height: 12),
          ],
          // TODO: gate this on a 24-hour PIN-change cooldown. The backend
          // exposes no PIN-created timestamp, so a canChangePinAt check cannot
          // be implemented yet.
          _field(
            controller: _current,
            label: 'Current PIN',
            enabled: enabled,
            errorText: _currentError,
            onSubmitted: _save,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _newPin,
            label: 'New PIN',
            enabled: enabled,
            errorText: _newError,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _confirm,
            label: 'Confirm new PIN',
            enabled: enabled,
            errorText: _confirmError,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: enabled ? _save : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
