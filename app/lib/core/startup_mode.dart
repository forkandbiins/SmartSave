import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'mascot.dart';
import 'theme.dart';

/// Lets a developer choose a real Bluetooth bank or the local mock bank.
class StartupMode extends StatelessWidget {
  const StartupMode({super.key, required this.onSelected});

  /// Starts the application with the selected backend mode.
  final Future<void> Function(SmartSaveMode mode) onSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSave',
      theme: smartSaveTheme,
      home: Scaffold(
        backgroundColor: SmartSaveTokens.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            children: [
              const Column(
                children: [
                  PigMascot(size: 96),
                  SizedBox(height: 20),
                  Text(
                    'Choose your SmartSave connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: SmartSaveTokens.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Connect to your real Bank or explore the app with test data.',
                    textAlign: TextAlign.center,
                    style: SmartSaveTokens.body,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _ModeChoice(
                icon: Icons.bluetooth,
                title: 'Use Bluetooth Bank',
                message: 'Request Bluetooth permission and scan for your Bank.',
                onPressed: () => onSelected(SmartSaveMode.ble),
              ),
              const SizedBox(height: 12),
              _ModeChoice(
                icon: Icons.science_outlined,
                title: 'Use mock bank',
                message: 'Test the app without hardware or Bluetooth.',
                outlined: true,
                onPressed: () => onSelected(SmartSaveMode.mock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.icon,
    required this.title,
    required this.message,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final button = outlined
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(title),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(title),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            button,
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SmartSaveTokens.body.copyWith(
                color: SmartSaveTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
