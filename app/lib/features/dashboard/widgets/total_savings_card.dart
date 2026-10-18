import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';

/// Hero card showing the authoritative total savings.
///
/// Displays the peso amount in [AppText]-style money copy. When [deviceTotal]
/// is null it shows "Not synced yet" and never falls back to ₱0.
class TotalSavingsCard extends StatelessWidget {
  const TotalSavingsCard({super.key, required this.deviceTotal});

  /// Authoritative device total, or null before the first sync.
  final int? deviceTotal;

  @override
  Widget build(BuildContext context) {
    final total = deviceTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total savings',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: SmartSaveTokens.inkSoft),
            ),
            const SizedBox(height: 8),
            Text(
              total == null ? 'Not synced yet' : formatPeso(total),
              style: SmartSaveTokens.money,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: SmartSaveTokens.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drop coins into the bank to add money. The balance updates automatically.',
                    style: SmartSaveTokens.body.copyWith(
                      color: SmartSaveTokens.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
