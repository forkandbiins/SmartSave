import 'package:flutter/material.dart';

import 'mascot.dart';
import 'theme.dart';

/// Primary-colored rounded hero with the mascot and a time-of-day greeting.
///
/// Does not include a user name. Pass [now] in tests; production uses local time.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, this.now});

  /// Instant used to pick morning / afternoon / evening. Defaults to now.
  final DateTime? now;

  /// Returns `Good morning!`, `Good afternoon!`, or `Good evening!`.
  ///
  /// Morning is before 12:00, afternoon before 18:00, otherwise evening.
  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour < 12) {
      return 'Good morning!';
    }
    if (hour < 18) {
      return 'Good afternoon!';
    }
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context) {
    final phrase = greetingFor(now ?? DateTime.now());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SmartSaveTokens.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(SmartSaveTokens.radiusCard),
        ),
        boxShadow: SmartSaveTokens.softShadows,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            children: [
              const PigMascot(size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  phrase,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: SmartSaveTokens.onAccent,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
