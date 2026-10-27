import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../deposit_buckets.dart';

/// Four plain-language summary tiles for the selected range.
class StatisticsSummary extends StatelessWidget {
  /// Creates the summary block.
  const StatisticsSummary({
    super.key,
    required this.highestDay,
    required this.highestDayAmount,
    required this.averagePerDay,
    required this.depositCount,
    required this.totalSaved,
  });

  /// Day with the largest deposited total, or null when there are no deposits.
  final DateTime? highestDay;

  /// Pesos deposited on [highestDay].
  final int highestDayAmount;

  /// Mean pesos deposited per day that had a deposit, already rounded.
  final int averagePerDay;

  /// Number of deposits in the range.
  final int depositCount;

  /// Total pesos deposited in the range.
  final int totalSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _row(
          _SummaryTile(
            icon: Icons.emoji_events_outlined,
            label: 'Highest day',
            value: highestDay == null ? '—' : shortDate(highestDay!),
            caption: formatPeso(highestDayAmount),
          ),
          _SummaryTile(
            icon: Icons.calendar_today_outlined,
            label: 'Average per day',
            value: formatPeso(averagePerDay),
          ),
        ),
        const SizedBox(height: 12),
        _row(
          _SummaryTile(
            icon: Icons.receipt_long_outlined,
            label: 'Total transactions',
            value: '$depositCount deposit${depositCount == 1 ? '' : 's'}',
          ),
          _SummaryTile(
            icon: Icons.savings_outlined,
            label: 'Total saved',
            value: formatPeso(totalSaved),
          ),
        ),
      ],
    );
  }

  Widget _row(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmartSaveTokens.surface,
        borderRadius: BorderRadius.circular(SmartSaveTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SmartSaveTokens.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}
