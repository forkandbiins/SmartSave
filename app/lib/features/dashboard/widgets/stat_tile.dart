import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// A single stat tile with an icon, label, and value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  /// Icon shown above the label.
  final IconData icon;

  /// Short label describing the stat.
  final String label;

  /// The stat value, already formatted.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmartSaveTokens.surface,
        borderRadius: BorderRadius.circular(SmartSaveTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: SmartSaveTokens.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: SmartSaveTokens.body.copyWith(
              color: SmartSaveTokens.inkSoft,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
