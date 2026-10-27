import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../deposit_buckets.dart';

/// Segmented control that switches the Statistics window.
class StatsRangeSelector extends StatelessWidget {
  /// Creates the selector.
  const StatsRangeSelector({
    super.key,
    required this.range,
    required this.onChanged,
  });

  /// Currently selected window.
  final StatsRange range;

  /// Called when the user picks another window.
  final ValueChanged<StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<StatsRange>(
      segments: const [
        ButtonSegment(value: StatsRange.daily, label: Text('Daily')),
        ButtonSegment(value: StatsRange.weekly, label: Text('Weekly')),
        ButtonSegment(value: StatsRange.monthly, label: Text('Monthly')),
      ],
      selected: {range},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: SmartSaveTokens.bodySize, fontWeight: FontWeight.w600),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(0, SmartSaveTokens.minTapTarget),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SmartSaveTokens.onAccent
              : SmartSaveTokens.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SmartSaveTokens.primary
              : SmartSaveTokens.surface,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: SmartSaveTokens.primary, width: 1.5),
        ),
      ),
    );
  }
}
