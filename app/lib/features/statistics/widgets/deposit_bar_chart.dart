import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../deposit_buckets.dart';

/// A scrollable bar chart of deposited totals.
///
/// Bars scale to the largest value; the tallest (or tapped) bar is highlighted
/// with [SmartSaveTokens.primary] and the rest with [SmartSaveTokens.primarySoft].
/// Peso and period labels sit on the card, never on the soft fill.
class DepositBarChart extends StatefulWidget {
  /// Creates the chart.
  const DepositBarChart({
    super.key,
    required this.buckets,
    required this.semanticsSummary,
  });

  /// One entry per bar, oldest first.
  final List<DepositBucket> buckets;

  /// Accessibility summary read in place of the bars, e.g.
  /// `Highest day: 01-05-26, ₱80.`
  final String semanticsSummary;

  @override
  State<DepositBarChart> createState() => _DepositBarChartState();
}

class _DepositBarChartState extends State<DepositBarChart> {
  int? _tapped;

  int get _tallest {
    var tallest = 0;
    for (var index = 1; index < widget.buckets.length; index++) {
      if (widget.buckets[index].total > widget.buckets[tallest].total) {
        tallest = index;
      }
    }
    return tallest;
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _tapped ?? _tallest;
    var largest = 0;
    for (final bucket in widget.buckets) {
      largest = math.max(largest, bucket.total);
    }

    return Semantics(
      container: true,
      label: widget.semanticsSummary,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        decoration: BoxDecoration(
          color: SmartSaveTokens.surface,
          borderRadius: BorderRadius.circular(SmartSaveTokens.radiusCard),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < widget.buckets.length; index++)
                _Bar(
                  index: index,
                  bucket: widget.buckets[index],
                  height: _barHeight(widget.buckets[index].total, largest),
                  highlighted: index == highlighted,
                  onTap: () => setState(
                    () => _tapped = _tapped == index ? null : index,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _barHeight(int total, int largest) {
    if (total <= 0 || largest <= 0) return _minBarHeight;
    return _maxBarHeight * (total / largest);
  }
}

const double _maxBarHeight = 140;
const double _minBarHeight = 4;
const double _slotWidth = 76;

class _Bar extends StatelessWidget {
  const _Bar({
    required this.index,
    required this.bucket,
    required this.height,
    required this.highlighted,
    required this.onTap,
  });

  final int index;
  final DepositBucket bucket;
  final double height;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      selected: highlighted,
      label: '${bucket.label}: ${formatPeso(bucket.total)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
        child: SizedBox(
          width: _slotWidth * scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatPeso(bucket.total),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: SmartSaveTokens.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: _maxBarHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      key: ValueKey('stats-bar-$index'),
                      width: 26 * scale,
                      height: height,
                      decoration: BoxDecoration(
                        color: highlighted
                            ? SmartSaveTokens.primary
                            : SmartSaveTokens.primarySoft,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bucket.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: SmartSaveTokens.body.copyWith(
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
