import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/features/goals/widgets/goal_card.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  testWidgets('GoalCard shows name and peso progress for a partial goal',
      (tester) async {
    final goal = DemoFixtures.sampleGoals()[1];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalCard(goal: goal),
        ),
      ),
    );

    expect(find.text('School supplies'), findsOneWidget);
    expect(find.text('₱450 of ₱1,000'), findsOneWidget);
    expect(find.text('Redeem'), findsNothing);
    expect(find.text('Redeemed'), findsNothing);
  });

  testWidgets(
      'GoalCard shows Redeem when funded and Redeemed when already redeemed',
      (tester) async {
    final goals = DemoFixtures.sampleGoals();
    var redeemed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GoalCard(
                goal: goals[0],
                onRedeem: () => redeemed = true,
              ),
              GoalCard(goal: goals[2]),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('₱500 of ₱500'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);
    expect(find.text('Old goal'), findsOneWidget);
    expect(find.text('Redeemed'), findsOneWidget);

    await tester.tap(find.text('Redeem'));
    expect(redeemed, isTrue);
  });
}
