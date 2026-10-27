import '../../../core/format.dart';

/// Smallest allowed goal target, in whole pesos.
const int goalTargetMin = 1;

/// Largest allowed goal target, in whole pesos.
const int goalTargetMax = 99999;

final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

/// Validates a goal name. Returns a friendly message, or null when valid.
String? validateGoalName(String raw) {
  if (raw.trim().isEmpty) return 'Enter a goal name.';
  return null;
}

/// Validates a goal target typed as text.
///
/// Requires digits only between [goalTargetMin] and [goalTargetMax]. When
/// editing, pass [allocatedAmount] so the target cannot drop below it.
String? validateTargetAmount(String raw, {int? allocatedAmount}) {
  final text = raw.trim();
  if (text.isEmpty) return 'Enter a target amount.';
  if (!_digitsOnly.hasMatch(text)) return 'Use whole pesos only.';
  final value = int.tryParse(text);
  if (value == null) return 'Use whole pesos only.';
  if (value < goalTargetMin || value > goalTargetMax) {
    return 'Target must be between ${formatPeso(goalTargetMin)} and '
        '${formatPeso(goalTargetMax)}.';
  }
  if (allocatedAmount != null && value < allocatedAmount) {
    return 'Target must be at least ${formatPeso(allocatedAmount)}.';
  }
  return null;
}

/// Validates an allocation amount against the [available] balance.
String? validateAllocateAmount(int? amount, int available) {
  if (amount == null) return 'Enter an amount.';
  if (amount <= 0) return 'Amount must be more than ₱0.';
  if (amount > available) {
    return 'You only have ${formatPeso(available)} available.';
  }
  return null;
}

/// Validates a release amount against the goal's [allocatedAmount].
String? validateReleaseAmount(int? amount, int allocatedAmount) {
  if (amount == null) return 'Enter an amount.';
  if (amount <= 0) return 'Amount must be more than ₱0.';
  if (amount > allocatedAmount) {
    return 'You can release up to ${formatPeso(allocatedAmount)}.';
  }
  return null;
}
