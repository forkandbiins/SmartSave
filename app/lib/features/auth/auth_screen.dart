import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/theme.dart';
import '../../shared/widgets/smart_save_scaffold.dart';
import '../connection/connection_screen.dart';

/// Handles first-time PIN setup, login, and lockout feedback.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  /// Backend controller used for authentication.
  final SmartSaveController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  String? _error;

  bool get _isSetup => widget.controller.state.auth == AuthState.pinNotSet;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text;
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Use exactly four digits for your PIN.');
      return;
    }
    if (_isSetup && _confirm.text != pin) {
      setState(() => _error = 'The PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _isSetup
        ? await widget.controller.setInitialPin(pin)
        : await widget.controller.login(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.isSuccess ? null : friendlyError(result.errorOrNull);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final locked = state.auth == AuthState.lockedOut;
    final remaining = state.lockoutEndsAt == null
        ? Duration.zero
        : state.lockoutEndsAt!.difference(DateTime.now());
    final lockoutText = remaining.isNegative
        ? 'You can try again now.'
        : 'Try again in ${remaining.inSeconds + 1}s.';
    return Scaffold(
      backgroundColor: SmartSaveTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
          children: [
            SmartSaveWelcome(
              title: _isSetup ? 'Set your Bank PIN' : 'Welcome back',
              message: _isSetup
                  ? 'Choose a PIN to keep your savings safe.'
                  : 'Enter your PIN to see your savings.',
            ),
            const SizedBox(height: 32),
            if (_error != null) SmartSaveErrorText(message: _error!),
            if (_error != null) const SizedBox(height: 12),
            if (locked)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_clock, color: SmartSaveTokens.accent),
                  title: const Text('Bank temporarily locked'),
                  subtitle: Text(lockoutText),
                ),
              )
            else ...[
              TextField(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: '4-digit PIN'),
              ),
              if (_isSetup) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSetup ? 'Set PIN' : 'Log in'),
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConnectionScreen(controller: widget.controller),
                ),
              ),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Reconnect to another Bank'),
            ),
          ],
        ),
      ),
    );
  }
}
