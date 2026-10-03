/// The lifecycle status of a savings goal.
enum GoalStatus {
  /// Goal is active.
  active,
  /// Goal was redeemed.
  redeemed,
  /// Goal was cancelled.
  cancelled,
}

/// An immutable app-local savings goal.
final class SavingsGoal {
  /// Creates a savings goal.
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.allocatedAmount,
    required this.status,
    required this.createdAt,
    this.redeemedAt,
  })  : assert(targetAmount > 0),
        assert(allocatedAmount >= 0);

  /// Stable goal identifier.
  final String id;
  /// Display name.
  final String name;
  /// Target amount in pesos.
  final int targetAmount;
  /// Earmarked amount in pesos.
  final int allocatedAmount;
  /// Goal lifecycle status.
  final GoalStatus status;
  /// Creation timestamp.
  final DateTime createdAt;
  /// Redemption timestamp.
  final DateTime? redeemedAt;

  /// Progress clamped to the range 0 through 1.
  double get progress =>
      targetAmount == 0 ? 0 : (allocatedAmount / targetAmount).clamp(0.0, 1.0);

  /// Whether the goal has reached its target.
  bool get isReached => progress >= 1.0;

  /// Serializes this goal.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'allocatedAmount': allocatedAmount,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'redeemedAt': redeemedAt?.toUtc().toIso8601String(),
      };

  /// Deserializes a goal.
  factory SavingsGoal.fromJson(Map<String, Object?> json) => SavingsGoal(
        id: json['id']! as String,
        name: json['name']! as String,
        targetAmount: json['targetAmount']! as int,
        allocatedAmount: json['allocatedAmount']! as int,
        status: _goalStatus(json['status']),
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        redeemedAt: (json['redeemedAt'] as String?) == null
            ? null
            : DateTime.parse(json['redeemedAt']! as String).toUtc(),
      );

  /// Returns a copy with selected values replaced.
  SavingsGoal copyWith({
    String? id,
    String? name,
    int? targetAmount,
    int? allocatedAmount,
    GoalStatus? status,
    DateTime? createdAt,
    DateTime? redeemedAt,
  }) =>
      SavingsGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        allocatedAmount: allocatedAmount ?? this.allocatedAmount,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        redeemedAt: redeemedAt ?? this.redeemedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is SavingsGoal &&
      id == other.id &&
      name == other.name &&
      targetAmount == other.targetAmount &&
      allocatedAmount == other.allocatedAmount &&
      status == other.status &&
      createdAt == other.createdAt &&
      redeemedAt == other.redeemedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, targetAmount, allocatedAmount, status, createdAt,
          redeemedAt);

  @override
  String toString() => 'SavingsGoal(id: $id, name: $name)';
}

GoalStatus _goalStatus(Object? value) {
  for (final status in GoalStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('Unknown status: $value');
}
