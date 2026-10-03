import 'smartsave_event.dart';

/// The result of a synchronization operation.
final class SyncReport {
  /// Creates a synchronization report.
  SyncReport({
    required this.newDeposits,
    this.reconciliationDelta,
    this.gapSize,
    List<DeviceAnomalyKind> anomalies = const [],
  }) : anomalies = List.unmodifiable(anomalies);

  /// Number of new deposits received.
  final int newDeposits;
  /// Signed reconciliation adjustment.
  final int? reconciliationDelta;
  /// Sequence gap size, when detected.
  final int? gapSize;
  /// Device anomalies found during synchronization.
  final List<DeviceAnomalyKind> anomalies;

  /// Returns a copy with selected values replaced.
  SyncReport copyWith({
    int? newDeposits,
    int? reconciliationDelta,
    int? gapSize,
    List<DeviceAnomalyKind>? anomalies,
  }) =>
      SyncReport(
        newDeposits: newDeposits ?? this.newDeposits,
        reconciliationDelta: reconciliationDelta ?? this.reconciliationDelta,
        gapSize: gapSize ?? this.gapSize,
        anomalies: anomalies ?? this.anomalies,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncReport &&
      newDeposits == other.newDeposits &&
      reconciliationDelta == other.reconciliationDelta &&
      gapSize == other.gapSize &&
      _listEquals(anomalies, other.anomalies);

  @override
  int get hashCode => Object.hash(
        newDeposits,
        reconciliationDelta,
        gapSize,
        Object.hashAll(anomalies),
      );

  @override
  String toString() => 'SyncReport(newDeposits: $newDeposits)';
}

bool _listEquals<T>(List<T> first, List<T> second) =>
    first.length == second.length &&
    Iterable<int>.generate(first.length).every((index) => first[index] == second[index]);
