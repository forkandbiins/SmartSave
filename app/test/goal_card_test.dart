import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/features/goals/widgets/goal_card.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  final goals = DemoFixtures.sampleGoals();
  final reached = goals[0]; // Emergency fund, 500/500, active.
  final partial = goals[1]; // School supplies, 450/1000, active.
  final redeemed = goals[2]; // Old goal, 300/300, redeemed.

  testWidgets('GoalCard shows a compact percent for a partial goal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GoalCard(goal: partial))),
    );

    expect(find.text('School supplies'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('₱450 of ₱1,000'), findsOneWidget);
    expect(find.text('Redeem'), findsNothing);
  });

  testWidgets('GoalCard shows a ring and Redeem for a reached goal', (
    tester,
  ) async {
    var redeemed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalCard(
            goal: reached,
            featured: true,
            onRedeem: () => redeemed = true,
          ),
        ),
      ),
    );

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('₱500 of ₱500'), findsOneWidget);

    await tester.tap(find.text('Redeem'));
    expect(redeemed, isTrue);
  });

  testWidgets('GoalCard has no Redeem when not fully funded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GoalCard(goal: partial, onRedeem: () {})),
      ),
    );

    expect(find.text('Redeem'), findsNothing);
  });

  testWidgets('RedeemedGoalCard shows a check icon and Redeemed label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RedeemedGoalCard(goal: redeemed))),
    );

    expect(find.text('Old goal'), findsOneWidget);
    expect(find.text('Redeemed · ₱300'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
