import 'package:flutter/material.dart';

import '../../core/mascot.dart';
import '../../core/theme.dart';

/// A consistent empty state used by list screens.
class SmartSaveEmptyState extends StatelessWidget {
  const SmartSaveEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  /// Short explanation shown above [message].
  final String title;

  /// Guidance shown to the user.
  final String message;

  /// Illustration icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: SmartSaveTokens.primarySoft),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact friendly error banner for controller action failures.
class SmartSaveErrorText extends StatelessWidget {
  const SmartSaveErrorText({super.key, required this.message});

  /// Friendly, non-protocol error text.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SmartSaveTokens.accentSoft.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: SmartSaveTokens.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// Branded welcome header for connection and authentication screens.
class SmartSaveWelcome extends StatelessWidget {
  const SmartSaveWelcome({super.key, required this.title, required this.message});

  /// Screen title.
  final String title;

  /// Supporting copy.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PigMascot(size: 96),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
        ),
      ],
    );
  }
}
