import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/mascot.dart';
import 'package:smartsave/core/theme.dart';
import 'package:smartsave/features/statistics/deposit_buckets.dart';
import 'package:smartsave/features/statistics/widgets/deposit_bar_chart.dart';
import 'package:smartsave/features/statistics/widgets/statistics_view.dart';
import 'package:smartsave_backend/testing.dart';

SavingsTransaction txn({
  required String id,
  required TransactionType type,
  required int amount,
  required DateTime at,
}) => SavingsTransaction(
  id: id,
  type: type,
  amount: amount,
  timestamp: at,
  timeAccuracy: TimeAccuracy.observedLive,
);

SavingsTransaction deposit(String id, int amount, DateTime at) =>
    txn(id: id, type: TransactionType.deposit, amount: amount, at: at);

int sumOf(List<DepositBucket> buckets) =>
    buckets.fold<int>(0, (sum, bucket) => sum + bucket.total);

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

StatisticsView viewWith({
  required List<DepositBucket> buckets,
  int depositCount = 1,
  int totalSaved = 0,
  int averagePerDay = 0,
  DateTime? highestDay,
  int highestDayAmount = 0,
  StatsRange range = StatsRange.daily,
  ValueChanged<StatsRange>? onRangeChanged,
}) => StatisticsView(
  range: range,
  onRangeChanged: onRangeChanged ?? (_) {},
  buckets: buckets,
  depositCount: depositCount,
  totalSaved: totalSaved,
  averagePerDay: averagePerDay,
  highestDay: highestDay,
  highestDayAmount: highestDayAmount,
);

/// Shrinks the surface to a typical phone so overflow checks are realistic.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final now = DateTime(2026, 1, 7, 12); // Wednesday

  group('range selection', () {
    test('daily covers the last 7 local days', () {
      expect(barCountFor(StatsRange.daily), 7);
      expect(rangeStart(StatsRange.daily, now), DateTime(2026, 1, 1));
      expect(rangeEnd(StatsRange.daily, now), DateTime(2026, 1, 8));
    });

    test('weekly covers the last 4 local weeks starting Monday', () {
      expect(barCountFor(StatsRange.weekly), 4);
      expect(rangeStart(StatsRange.weekly, now), DateTime(2025, 12, 15));
      expect(rangeEnd(StatsRange.weekly, now), DateTime(2026, 1, 12));
    });

    test('monthly covers the last 6 local months', () {
      expect(barCountFor(StatsRange.monthly), 6);
      expect(rangeStart(StatsRange.monthly, now), DateTime(2025, 8, 1));
      expect(rangeEnd(StatsRange.monthly, now), DateTime(2026, 2, 1));
    });
  });

  group('bucketDeposits', () {
    test('daily buckets local days, counts only deposits, ignores others', () {
      final buckets = bucketDeposits(
        [
          deposit('a', 30, DateTime(2026, 1, 5, 10)),
          deposit('b', 20, DateTime(2026, 1, 5, 22)),
          txn(
            id: 'c',
            type: TransactionType.redemption,
            amount: -100,
            at: DateTime(2026, 1, 5, 11),
          ),
          txn(
            id: 'd',
            type: TransactionType.adjustment,
            amount: -10,
            at: DateTime(2026, 1, 5, 12),
          ),
          deposit('e', 55, DateTime(2026, 1, 7, 9)),
          deposit('f', 99, DateTime(2025, 12, 30, 9)), // outside the window
        ],
        StatsRange.daily,
        now,
      );

      expect(buckets.length, 7);
      expect(buckets.map((bucket) => bucket.label).toList(), [
        'Thu',
        'Fri',
        'Sat',
        'Sun',
        'Mon',
        'Tue',
        'Wed',
      ]);
      expect(buckets[4].total, 50); // Monday
      expect(buckets[6].total, 55); // today
      expect(sumOf(buckets), 105);
    });

    test('daily converts UTC timestamps to the local calendar day', () {
      final utc = DateTime.utc(2026, 1, 5, 20); // 04:00 Jan 6 in UTC+8
      final local = utc.toLocal();
      final localDay = DateTime(local.year, local.month, local.day);

      final buckets = bucketDeposits(
        [deposit('u', 40, utc)],
        StatsRange.daily,
        now,
      );

      final bucket = buckets.singleWhere((item) => item.start == localDay);
      expect(bucket.total, 40);
    });

    test('weekly buckets weeks and labels them by start date', () {
      final buckets = bucketDeposits(
        [
          deposit('a', 10, DateTime(2025, 12, 16, 9)),
          deposit('b', 20, DateTime(2025, 12, 30, 9)),
          deposit('c', 30, DateTime(2026, 1, 6, 9)),
          txn(
            id: 'd',
            type: TransactionType.redemption,
            amount: -50,
            at: DateTime(2026, 1, 6, 9),
          ),
        ],
        StatsRange.weekly,
        now,
      );

      expect(buckets.length, 4);
      expect(buckets.map((bucket) => bucket.label).toList(), [
        '12-15',
        '12-22',
        '12-29',
        '01-05',
      ]);
      expect(buckets.map((bucket) => bucket.total).toList(), [10, 0, 20, 30]);
    });

    test('monthly buckets months and skips older deposits', () {
      final buckets = bucketDeposits(
        [
          deposit('a', 5, DateTime(2025, 8, 3, 9)),
          deposit('b', 15, DateTime(2025, 12, 30, 9)),
          deposit('c', 25, DateTime(2026, 1, 6, 9)),
          deposit('d', 100, DateTime(2025, 7, 31, 9)), // too old
        ],
        StatsRange.monthly,
        DateTime(2026, 1, 20, 12),
      );

      expect(buckets.length, 6);
      expect(buckets.map((bucket) => bucket.label).toList(), [
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
        'Jan',
      ]);
      expect(buckets[0].total, 5);
      expect(buckets[4].total, 15);
      expect(buckets[5].total, 25);
      expect(sumOf(buckets), 45);
    });

    test(
      'demo fixtures count deposits only, not the redemption or adjustment',
      () {
        final buckets = bucketDeposits(
          DemoFixtures.sampleTransactions(),
          StatsRange.monthly,
          DateTime(2026, 1, 20, 12),
        );

        expect(sumOf(buckets), 425);
      },
    );
  });

  group('depositStats', () {
    test('summarises per-local-day totals, highest, average and count', () {
      final stats = depositStats(
        [
          deposit('a', 30, DateTime(2026, 1, 5, 10)),
          deposit('b', 20, DateTime(2026, 1, 5, 22)),
          deposit('c', 55, DateTime(2026, 1, 7, 9)),
          txn(
            id: 'd',
            type: TransactionType.redemption,
            amount: -100,
            at: DateTime(2026, 1, 5, 11),
          ),
          deposit('e', 99, DateTime(2025, 12, 30, 9)), // outside the window
        ],
        StatsRange.daily,
        now,
      );

      expect(stats.perDayTotals, {
        DateTime(2026, 1, 5): 50,
        DateTime(2026, 1, 7): 55,
      });
      expect(stats.highestDay, DateTime(2026, 1, 7));
      expect(stats.highestDayAmount, 55);
      expect(stats.depositCount, 3);
      expect(stats.totalSaved, 105);
      // Two days had deposits: (50 + 55) / 2 = 52.5 -> 53.
      expect(stats.averagePerDay, 53);
    });

    test('keeps total saved equal to the sum of the bars in every range', () {
      final transactions = [
        deposit('a', 25, DateTime(2026, 1, 5, 10)),
        deposit('b', 40, DateTime(2026, 1, 6, 23, 45)),
        deposit('c', 15, DateTime(2026, 1, 7, 6)),
      ];

      for (final range in StatsRange.values) {
        final buckets = bucketDeposits(transactions, range, now);
        final stats = depositStats(transactions, range, now);
        expect(stats.totalSaved, sumOf(buckets));
      }
    });

    test('highest day is the earliest day with the largest total', () {
      final transactions = [
        deposit('a', 40, DateTime(2026, 1, 5, 10)),
        deposit('b', 40, DateTime(2026, 1, 7, 10)),
      ];
      final buckets = bucketDeposits(transactions, StatsRange.daily, now);
      final stats = depositStats(transactions, StatsRange.daily, now);

      // The chart highlights the first (oldest) bar that reaches the maximum.
      final tallest = buckets.reduce((a, b) => b.total > a.total ? b : a);
      expect(stats.highestDay, tallest.start);
      expect(stats.highestDay, DateTime(2026, 1, 5));
    });

    test('ignores redemptions and adjustments', () {
      final stats = depositStats(
        [
          deposit('a', 30, DateTime(2026, 1, 6, 9)),
          txn(
            id: 'b',
            type: TransactionType.redemption,
            amount: -30,
            at: DateTime(2026, 1, 6, 10),
          ),
          txn(
            id: 'c',
            type: TransactionType.adjustment,
            amount: -5,
            at: DateTime(2026, 1, 6, 11),
          ),
        ],
        StatsRange.daily,
        now,
      );

      expect(stats.depositCount, 1);
      expect(stats.totalSaved, 30);
      expect(stats.perDayTotals, {DateTime(2026, 1, 6): 30});
    });

    test('empty range reports no highest day and zero averages', () {
      final stats = depositStats(const [], StatsRange.daily, now);

      expect(stats.perDayTotals, isEmpty);
      expect(stats.highestDay, isNull);
      expect(stats.highestDayAmount, 0);
      expect(stats.averagePerDay, 0);
      expect(stats.depositCount, 0);
      expect(stats.totalSaved, 0);
    });
  });

  group('StatisticsView', () {
    testWidgets('labels every bar with its pesos and its weekday', (
      tester,
    ) async {
      final buckets = bucketDeposits(
        [
          deposit('a', 30, DateTime(2026, 1, 5, 10)),
          deposit('b', 20, DateTime(2026, 1, 5, 22)),
          deposit('c', 55, DateTime(2026, 1, 7, 9)),
        ],
        StatsRange.daily,
        now,
      );

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: buckets,
            depositCount: 3,
            totalSaved: 105,
            averagePerDay: 53,
            highestDay: DateTime.utc(2026, 1, 7),
            highestDayAmount: 55,
          ),
        ),
      );

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('₱50'), findsOneWidget);
      expect(find.text('₱55'), findsNWidgets(2)); // bar label + highest day
      expect(find.text('₱0'), findsNWidgets(5));
    });

    testWidgets('highlights the tallest bar and softens the rest', (
      tester,
    ) async {
      final buckets = bucketDeposits(
        [
          deposit('a', 50, DateTime(2026, 1, 5, 10)),
          deposit('b', 55, DateTime(2026, 1, 7, 9)),
        ],
        StatsRange.daily,
        now,
      );

      await tester.pumpWidget(
        wrap(viewWith(buckets: buckets, depositCount: 2, totalSaved: 105)),
      );

      Color barColor(int index) {
        final container = tester.widget<Container>(
          find.byKey(ValueKey('stats-bar-$index')),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      expect(barColor(6), SmartSaveTokens.primary); // today, ₱55
      expect(barColor(4), SmartSaveTokens.primarySoft); // Monday, ₱50
      expect(barColor(0), SmartSaveTokens.primarySoft); // empty day
    });

    testWidgets(
      'an early-morning deposit shows on its local day, not the UTC day',
      (tester) async {
        // 00:30 local on Jan 6 (UTC+8) is still Jan 5 in UTC, so a UTC-day
        // grouping would wrongly place it on Monday.
        final instant = DateTime(2026, 1, 6, 0, 30).toUtc();
        final transactions = [deposit('a', 25, instant)];
        final buckets = bucketDeposits(transactions, StatsRange.daily, now);
        final stats = depositStats(transactions, StatsRange.daily, now);

        expect(buckets[4].label, 'Mon'); // the UTC day stays empty...
        expect(buckets[4].total, 0);
        expect(buckets[5].label, 'Tue'); // ...the local day gets the deposit
        expect(buckets[5].total, 25);
        expect(stats.highestDay, DateTime(2026, 1, 6));
        expect(stats.highestDayAmount, 25);

        await tester.pumpWidget(
          wrap(
            viewWith(
              buckets: buckets,
              depositCount: stats.depositCount,
              totalSaved: stats.totalSaved,
              averagePerDay: stats.averagePerDay,
              highestDay: stats.highestDay,
              highestDayAmount: stats.highestDayAmount,
            ),
          ),
        );

        // The Highest day card names the local day...
        expect(find.text('01-06-26'), findsOneWidget);
        // ...and the Tuesday bar carries the deposit and is highlighted.
        Color barColor(int index) {
          final container = tester.widget<Container>(
            find.byKey(ValueKey('stats-bar-$index')),
          );
          return (container.decoration! as BoxDecoration).color!;
        }

        expect(barColor(5), SmartSaveTokens.primary);
        expect(barColor(4), SmartSaveTokens.primarySoft);
      },
    );

    testWidgets('summary shows the rounded average, count and total', (
      tester,
    ) async {
      final buckets = bucketDeposits(const [], StatsRange.daily, now);

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: buckets,
            depositCount: 4,
            totalSaved: 700,
            averagePerDay: 350,
            highestDay: DateTime.utc(2026, 1, 6),
            highestDayAmount: 90,
          ),
        ),
      );

      expect(find.text('Highest day'), findsOneWidget);
      expect(find.text('01-06-26'), findsOneWidget);
      expect(find.text('₱90'), findsOneWidget);
      expect(find.text('₱350'), findsOneWidget);
      expect(find.text('4 deposits'), findsOneWidget);
      expect(find.text('₱700'), findsOneWidget);
    });

    testWidgets('shows the pig empty state when the range has no deposits', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: bucketDeposits(const [], StatsRange.daily, now),
            depositCount: 0,
          ),
        ),
      );

      expect(find.text('No deposits yet'), findsOneWidget);
      expect(find.byType(PigMascot), findsOneWidget);
      expect(find.byType(DepositBarChart), findsNothing);
    });

    testWidgets('switching the range reports the new window', (tester) async {
      StatsRange? picked;

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: bucketDeposits(const [], StatsRange.daily, now),
            depositCount: 0,
            onRangeChanged: (range) => picked = range,
          ),
        ),
      );

      await tester.tap(find.text('Weekly'));
      await tester.pump();

      expect(picked, StatsRange.weekly);
    });

    testWidgets('names the highest day for screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: bucketDeposits(
              [deposit('a', 55, DateTime(2026, 1, 7, 9))],
              StatsRange.daily,
              now,
            ),
            depositCount: 1,
            totalSaved: 55,
            highestDay: DateTime.utc(2026, 1, 7),
            highestDayAmount: 55,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Highest day: 01-07-26')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('renders all-zero bars without a largest value', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DepositBarChart(
            buckets: bucketDeposits(const [], StatsRange.daily, now),
            semanticsSummary: 'No deposits in this range.',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₱0'), findsNWidgets(7));
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
    });

    testWidgets('renders a single very large deposit without overflow', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final buckets = bucketDeposits(
        [deposit('a', 99999, DateTime(2026, 1, 7, 9))],
        StatsRange.daily,
        now,
      );

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: buckets,
            depositCount: 1,
            totalSaved: 99999,
            averagePerDay: 99999,
            highestDay: DateTime.utc(2026, 1, 7),
            highestDayAmount: 99999,
          ),
          textScale: 1.5,
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₱99,999'), findsWidgets);
    });

    testWidgets('renders without overflow at text scale 1.5', (tester) async {
      usePhoneSurface(tester);
      final buckets = bucketDeposits(
        [
          deposit('a', 50, DateTime(2026, 1, 5, 10)),
          deposit('b', 55, DateTime(2026, 1, 7, 9)),
        ],
        StatsRange.daily,
        now,
      );

      await tester.pumpWidget(
        wrap(
          viewWith(
            buckets: buckets,
            depositCount: 2,
            totalSaved: 105,
            averagePerDay: 53,
            highestDay: DateTime.utc(2026, 1, 7),
            highestDayAmount: 55,
          ),
          textScale: 1.5,
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
