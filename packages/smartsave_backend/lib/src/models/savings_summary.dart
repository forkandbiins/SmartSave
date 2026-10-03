import 'savings_goal.dart';

/// A balance summary combining the device total and active earmarks.
final class SavingsSummary {
  /// Creates a summary.
  const SavingsSummary({
    required this.deviceTotal,
    required this.allocatedTotal,
  });

  /// Authoritative device total.
  final int deviceTotal;
  /// Total allocated to active goals.
  final int allocatedTotal;
  /// Amount not allocated to a goal.
  int get available => (deviceTotal - allocatedTotal).clamp(0, deviceTotal);
  /// Amount by which allocations exceed the device total.
  int get overAllocatedBy => (allocatedTotal - deviceTotal).clamp(0, allocatedTotal);

  /// Builds a summary from a nullable device total and goals.
  factory SavingsSummary.from(int? deviceTotal, List<SavingsGoal> goals) =>
      SavingsSummary(
        deviceTotal: deviceTotal ?? 0,
        allocatedTotal: goals
            .where((goal) => goal.status == GoalStatus.active)
            .fold<int>(0, (sum, goal) => sum + goal.allocatedAmount),
      );

  /// Returns a copy with selected values replaced.
  SavingsSummary copyWith({int? deviceTotal, int? allocatedTotal}) =>
      SavingsSummary(
        deviceTotal: deviceTotal ?? this.deviceTotal,
        allocatedTotal: allocatedTotal ?? this.allocatedTotal,
      );

  @override
  bool operator ==(Object other) =>
      other is SavingsSummary &&
      deviceTotal == other.deviceTotal &&
      allocatedTotal == other.allocatedTotal;

  @override
  int get hashCode => Object.hash(deviceTotal, allocatedTotal);

  @override
  String toString() =>
      'SavingsSummary(deviceTotal: $deviceTotal, allocatedTotal: $allocatedTotal)';
}
