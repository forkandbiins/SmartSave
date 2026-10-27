import 'package:flutter/material.dart';

import '../../../core/mascot.dart';
import '../../../core/theme.dart';

/// Friendly "nothing saved yet" state for the Statistics screen.
class StatisticsEmptyState extends StatelessWidget {
  /// Creates the empty state.
  const StatisticsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const PigMascot(size: 96),
          const SizedBox(height: 16),
          Text(
            'No deposits yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Drop a coin into your Bank and your progress will show up here.',
            textAlign: TextAlign.center,
            style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}
