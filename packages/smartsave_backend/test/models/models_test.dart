import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2, 3, 4, 5);

  test('denomination conversion accepts only new coin values', () {
    expect(Denomination.fromValue(20), Denomination.php20);
    expect(Denomination.tryFromValue(2), isNull);
    expect(() => Denomination.fromValue(2), throwsA(isA<InvalidArgumentError>()));
    expect(() => Denomination.fromValue(50), throwsA(isA<InvalidArgumentError>()));
  });

  test('transaction JSON round-trips every enum value', () {
    for (final type in TransactionType.values) {
      for (final accuracy in TimeAccuracy.values) {
        final transaction = SavingsTransaction(
          id: 'id',
          type: type,
          amount: -5,
          denomination: Denomination.php5,
          seq: 4,
          timestamp: timestamp,
          timeAccuracy: accuracy,
          goalId: 'goal',
          note: 'note',
        );
        expect(SavingsTransaction.fromJson(transaction.toJson()), transaction);
      }
    }
  });

  test('goal JSON, progress, and summary invariants', () {
    for (final status in GoalStatus.values) {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Goal',
        targetAmount: 100,
        allocatedAmount: 120,
        status: status,
        createdAt: timestamp,
      );
      expect(SavingsGoal.fromJson(goal.toJson()), goal);
      expect(goal.progress, 1.0);
      expect(goal.isReached, isTrue);
    }
    final activeA = SavingsGoal(
      id: 'a',
      name: 'A',
      targetAmount: 100,
      allocatedAmount: 30,
      status: GoalStatus.active,
      createdAt: timestamp,
    );
    final activeB = activeA.copyWith(id: 'b', allocatedAmount: 20);
    final redeemed = activeA.copyWith(id: 'r', status: GoalStatus.redeemed);
    final cancelled = activeA.copyWith(id: 'c', status: GoalStatus.cancelled);
    expect(SavingsSummary.from(100, [activeA, activeB, redeemed, cancelled])
        .available, 50);
    expect(SavingsSummary.from(40, [activeA, activeB]).overAllocatedBy, 10);
  });

  test('initial state and fixtures have expected shape', () {
    final initial = SmartSaveState.initial(SmartSaveMode.mock);
    expect(initial.link, LinkState.disconnected);
    expect(initial.auth, AuthState.unknown);
    expect(initial.deviceTotal, isNull);
    expect(DemoFixtures.demoState().goals, hasLength(3));
    expect(DemoFixtures.demoState().transactions, hasLength(12));
  });
}
