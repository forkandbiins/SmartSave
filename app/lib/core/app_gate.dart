import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../features/auth/auth_screen.dart';
import '../features/connection/connection_screen.dart';
import 'home_shell.dart';
import 'theme.dart';

/// Routes between connection/auth screens and [HomeShell] from link/auth state.
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
            return ConnectionScreen(controller: controller);
          case LinkState.scanning:
          case LinkState.connecting:
          case LinkState.handshaking:
            return ConnectionScreen(controller: controller);
          case LinkState.ready:
            switch (state.auth) {
              case AuthState.pinNotSet:
                return AuthScreen(controller: controller);
              case AuthState.loggedOut:
                return AuthScreen(controller: controller);
              case AuthState.lockedOut:
                return AuthScreen(controller: controller);
              case AuthState.loggedIn:
                return HomeShell(controller: controller);
              case AuthState.unknown:
                return const Scaffold(
                  backgroundColor: SmartSaveTokens.background,
                  body: Center(child: CircularProgressIndicator()),
                );
            }
        }
      },
    );
  }
}
