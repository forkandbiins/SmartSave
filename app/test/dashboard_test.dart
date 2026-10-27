import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/features/dashboard/widgets/dashboard_view.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  final now = DateTime(2026, 1, 13, 10, 42);

  DashboardView buildFromState(SmartSaveState state) {
    SavingsGoal? activeGoal;
    for (final goal in state.goals) {
      if (goal.status == GoalStatus.active) {
        activeGoal = goal;
        break;
      }
    }
    DateTime? lastDeposit;
    for (final txn in state.transactions) {
      if (txn.type == TransactionType.deposit) {
        lastDeposit = txn.timestamp;
        break;
      }
    }
    return DashboardView(
      deviceTotal: state.deviceTotal,
      activeGoal: activeGoal,
      todayTotal: 45,
      weekTotal: 320,
      totalDepositsCount: state.transactions.length,
      lastDepositTime: lastDeposit,
      recentTransactions: state.transactions.take(5).toList(),
      isSyncing: false,
      lastError: state.lastError,
      now: now,
    );
  }

  testWidgets('Dashboard shows ₱1,250 total for demo state', (tester) async {
    final state = DemoFixtures.demoState();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('₱1,250'), findsWidgets);
    expect(find.text('Not synced yet'), findsNothing);
  });

  testWidgets('Dashboard shows "Not synced yet" when deviceTotal is null', (
    tester,
  ) async {
    final state = SmartSaveState(
      mode: SmartSaveMode.mock,
      link: LinkState.ready,
      auth: AuthState.loggedIn,
      lock: LockState.locked,
      deviceTotal: null,
      syncStatus: SyncStatus.idle,
      goals: DemoFixtures.sampleGoals(),
      transactions: DemoFixtures.sampleTransactions(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('Not synced yet'), findsOneWidget);
  });

  testWidgets('Dashboard shows first active goal progress', (tester) async {
    final state = DemoFixtures.demoState();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('₱500 of ₱500'), findsOneWidget);
  });

  testWidgets('Dashboard shows friendly empty state when no active goal', (
    tester,
  ) async {
    final state = DemoFixtures.demoState().copyWith(goals: const []);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('No goal yet'), findsOneWidget);
  });

  testWidgets('Dashboard shows up to 5 recent deposits with labels', (
    tester,
  ) async {
    final state = DemoFixtures.demoState();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('Recent deposits'), findsOneWidget);
    final demoTxns = state.transactions.take(5).toList();
    for (final txn in demoTxns) {
      if (txn.type == TransactionType.deposit && txn.denomination != null) {
        expect(find.text('₱${txn.denomination!.value} coin'), findsWidgets);
      }
    }
  });

  testWidgets('Dashboard shows empty state when there are no transactions', (
    tester,
  ) async {
    final state = DemoFixtures.demoState().copyWith(transactions: const []);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('Dashboard maps error code to friendly text (not raw message)', (
    tester,
  ) async {
    final state = DemoFixtures.demoState().copyWith(
      lastError: const ConnectionError.bluetoothOff(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(
      find.text('Bluetooth is off. Turn it on to connect.'),
      findsOneWidget,
    );
    expect(find.text('Bluetooth is turned off.'), findsNothing);
  });

  testWidgets('Dashboard shows sync indicator when syncing', (tester) async {
    final state = DemoFixtures.demoState().copyWith(
      syncStatus: SyncStatus.syncing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildFromState(state).copyWithIsSyncing(true)),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Dashboard renders without overflow at text scale 1.5', (
    tester,
  ) async {
    final state = DemoFixtures.demoState();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: buildFromState(state)),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Dashboard renders without overflow at width 320 and text scale 1.5',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = DemoFixtures.demoState();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(body: buildFromState(state)),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recent deposits'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Total deposits'), findsOneWidget);
      expect(find.text('Last deposit'), findsOneWidget);
    },
  );

  testWidgets(
    'Fresh profile shows friendly empty states, not ₱0, at width 320',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = SmartSaveState(
        mode: SmartSaveMode.mock,
        link: LinkState.ready,
        auth: AuthState.loggedIn,
        lock: LockState.locked,
        deviceTotal: null,
        syncStatus: SyncStatus.idle,
        goals: const [],
        transactions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(body: buildFromState(state)),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Not synced yet'), findsOneWidget);
      expect(find.text('No goal yet'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    },
  );

  testWidgets('Total deposits tile shows the deposit count, not a peso sum', (
    tester,
  ) async {
    final state = DemoFixtures.demoState();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('${state.transactions.length} deposits'), findsOneWidget);
    expect(find.text('₱1,250'), findsWidgets);
  });

  testWidgets('syncedLate transactions show fixed mm-dd-yy 24h format', (
    tester,
  ) async {
    final txn = SavingsTransaction(
      id: 'txn-late',
      type: TransactionType.deposit,
      amount: 20,
      denomination: Denomination.php20,
      timestamp: DateTime(2026, 1, 13, 8, 23),
      timeAccuracy: TimeAccuracy.syncedLate,
    );
    final state = DemoFixtures.demoState().copyWith(transactions: [txn]);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('08:23, 01-13-26'), findsWidgets);
    expect(find.textContaining('Around'), findsNothing);
  });

  testWidgets('observedLive transactions show fixed mm-dd-yy 24h format', (
    tester,
  ) async {
    final txn = SavingsTransaction(
      id: 'txn-live',
      type: TransactionType.deposit,
      amount: 20,
      denomination: Denomination.php20,
      timestamp: DateTime(2026, 1, 13, 8, 23),
      timeAccuracy: TimeAccuracy.observedLive,
    );
    final state = DemoFixtures.demoState().copyWith(transactions: [txn]);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildFromState(state))),
    );

    expect(find.text('08:23, 01-13-26'), findsWidgets);
    expect(find.textContaining('Around'), findsNothing);
  });
}

extension on DashboardView {
  DashboardView copyWithIsSyncing(bool value) => DashboardView(
    deviceTotal: deviceTotal,
    activeGoal: activeGoal,
    todayTotal: todayTotal,
    weekTotal: weekTotal,
    totalDepositsCount: totalDepositsCount,
    lastDepositTime: lastDepositTime,
    recentTransactions: recentTransactions,
    isSyncing: value,
    lastError: lastError,
    now: now,
  );
}
