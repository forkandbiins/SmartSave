import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'home_shell.dart';
import 'mascot.dart';
import 'theme.dart';

/// Routes between connection/auth placeholders and [HomeShell] from link/auth state.
class AppGate extends StatelessWidget {
  const AppGate({super.key, required this.controller});

  /// Backend controller to listen to.
  final SmartSaveController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        switch (state.link) {
          case LinkState.disconnected:
            return const _PlaceholderScreen(
              label: 'Connection screen (Member 3)',
              message: 'Find your Bank to get started.',
            );
          case LinkState.scanning:
          case LinkState.connecting:
          case LinkState.handshaking:
            return const _ProgressScreen();
          case LinkState.ready:
            switch (state.auth) {
              case AuthState.pinNotSet:
                return const _PlaceholderScreen(
                  label: 'Set PIN screen (Member 3)',
                  message: 'Choose a 4-digit PIN for your Bank.',
                );
              case AuthState.loggedOut:
                return const _PlaceholderScreen(
                  label: 'Login screen (Member 3)',
                  message: 'Enter your PIN to see your savings.',
                );
              case AuthState.lockedOut:
                return const _PlaceholderScreen(
                  label: 'Lockout countdown (Member 3)',
                  message: 'Too many tries. Please wait a little.',
                );
              case AuthState.loggedIn:
                return HomeShell(controller: controller);
              case AuthState.unknown:
                return const _ProgressScreen();
            }
        }
      },
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartSaveTokens.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PigMascot(size: 96),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: SmartSaveTokens.inkSoft,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartSaveTokens.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PigMascot(size: 96),
                const SizedBox(height: 24),
                Text(
                  'Hang on, connecting…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: SmartSaveTokens.minTapTarget,
                  height: SmartSaveTokens.minTapTarget,
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
