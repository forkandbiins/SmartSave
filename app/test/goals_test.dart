import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/theme.dart';
import 'package:smartsave/features/goals/widgets/goal_validators.dart';
import 'package:smartsave/features/goals/widgets/goals_view.dart';
import 'package:smartsave/features/goals/widgets/money_action_sheet.dart';
import 'package:smartsave_backend/testing.dart';

GoalsView buildView({
  required List<SavingsGoal> goals,
  int available = 300,
  int overAllocatedBy = 0,
  bool busy = false,
  String? errorMessage,
}) {
  return GoalsView(
    goals: goals,
    available: available,
    overAllocatedBy: overAllocatedBy,
    busy: busy,
    errorMessage: errorMessage,
    onCreate: () {},
    onEdit: (_) {},
    onDelete: (_) {},
    onAllocate: (_) {},
    onRelease: (_) {},
    onRedeem: (_) {},
  );
}

/// Gives the test a tall surface so every list card is laid out (ListView is
/// lazy and would otherwise skip off-screen cards).
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget wrap(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: smartSaveTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  final sample = DemoFixtures.sampleGoals();

  testWidgets('Goals list hides cancelled goals', (tester) async {
    useTallSurface(tester);
    final cancelled = SavingsGoal(
      id: 'goal-cancelled',
      name: 'Cancelled plan',
      targetAmount: 200,
      allocatedAmount: 0,
      status: GoalStatus.cancelled,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(wrap(buildView(goals: [...sample, cancelled])));

    expect(find.text('Cancelled plan'), findsNothing);
    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('School supplies'), findsOneWidget);
    expect(find.text('Old goal'), findsOneWidget);
  });

  testWidgets('Goals list shows the progress-ring percent for the main goal', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: sample)));

    // Main (first active) goal is fully funded; the next active goal is 45%.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('₱500 of ₱500'), findsOneWidget);
    expect(find.text('₱450 of ₱1,000'), findsOneWidget);
  });

  testWidgets('Redeem shows only for a fully funded active goal', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: sample)));

    expect(find.text('Redeem'), findsOneWidget);
    expect(find.text('Redeemed · ₱300'), findsOneWidget);
  });

  testWidgets('Redeem is absent when no active goal is reached', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: [sample[1], sample[2]])));

    expect(find.text('Redeem'), findsNothing);
  });

  testWidgets('Over-allocated warning shows when allocations exceed balance', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrap(buildView(goals: sample, overAllocatedBy: 100)),
    );

    expect(
      find.textContaining('allocated more than your balance'),
      findsOneWidget,
    );
  });

  testWidgets('No over-allocated warning when the balance is healthy', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: sample)));

    expect(
      find.textContaining('allocated more than your balance'),
      findsNothing,
    );
  });

  testWidgets('Empty state shows when there are no active or redeemed goals', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: const [])));

    expect(find.text('No goals yet'), findsOneWidget);
  });

  testWidgets('Goals screen renders without overflow at text scale 1.5', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(buildView(goals: sample), textScale: 1.5));

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goals header fits width 320 at text scale 1.5 with no goals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildView(goals: const []), textScale: 1.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Create goal'), findsOneWidget);
    expect(find.text('No goals yet'), findsOneWidget);
  });

  group('amount validation', () {
    test('allocate rejects zero, negative, and over-available amounts', () {
      expect(validateAllocateAmount(0, 300), isNotNull);
      expect(validateAllocateAmount(-5, 300), isNotNull);
      expect(validateAllocateAmount(301, 300), isNotNull);
      expect(validateAllocateAmount(null, 300), isNotNull);
      expect(validateAllocateAmount(300, 300), isNull);
      expect(validateAllocateAmount(20, 300), isNull);
    });

    test('release rejects zero, negative, and over-allocated amounts', () {
      expect(validateReleaseAmount(0, 450), isNotNull);
      expect(validateReleaseAmount(-1, 450), isNotNull);
      expect(validateReleaseAmount(451, 450), isNotNull);
      expect(validateReleaseAmount(450, 450), isNull);
    });

    testWidgets('money sheet shows a friendly error for an invalid amount', (
      tester,
    ) async {
      useTallSurface(tester);
      const available = 300;
      await tester.pumpWidget(
        wrap(
          MoneyActionSheet(
            title: 'Add to Emergency fund',
            caption: 'You have ₱300 available.',
            submitLabel: 'Add money',
            maxAmount: available,
            validator: (value) => validateAllocateAmount(value, available),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '500');
      await tester.tap(find.widgetWithText(FilledButton, 'Add money'));
      await tester.pump();

      expect(find.text('You only have ₱300 available.'), findsOneWidget);
    });

    testWidgets('money sheet leaves no error for a valid amount', (
      tester,
    ) async {
      useTallSurface(tester);
      const available = 300;
      await tester.pumpWidget(
        wrap(
          MoneyActionSheet(
            title: 'Add to Emergency fund',
            caption: 'You have ₱300 available.',
            submitLabel: 'Add money',
            maxAmount: available,
            validator: (value) => validateAllocateAmount(value, available),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();

      expect(find.textContaining('You only have'), findsNothing);
    });
  });
}
