import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';

/// A circular progress ring for the main active goal.
///
/// Shows the rounded percent in the middle and "₱X of ₱Y" below the ring.
class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({super.key, required this.goal, this.size = 160});

  /// Goal whose progress is drawn.
  final SavingsGoal goal;

  /// Diameter of the ring, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final percent = (goal.progress * 100).round();
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(progress: goal.progress),
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${formatPeso(goal.allocatedAmount)} of ${formatPeso(goal.targetAmount)}',
          style: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = SmartSaveTokens.primarySoft.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = SmartSaveTokens.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
