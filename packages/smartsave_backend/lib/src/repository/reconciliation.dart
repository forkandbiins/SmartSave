/// The result of comparing a reported balance with local knowledge.
final class Reconciliation {
  /// Creates a reconciliation result.
  const Reconciliation({this.openingBalance, this.delta});

  /// Opening balance to record when no previous total exists.
  final int? openingBalance;

  /// Difference from the expected balance when a previous total exists.
  final int? delta;
}

/// Calculates the balance correction without performing I/O.
Reconciliation reconcile({
  int? knownTotal,
  required int reportedTotal,
  required int newCoinsSum,
}) =>
    knownTotal == null
        ? Reconciliation(openingBalance: reportedTotal - newCoinsSum)
        : Reconciliation(
            delta: reportedTotal - (knownTotal + newCoinsSum),
          );
