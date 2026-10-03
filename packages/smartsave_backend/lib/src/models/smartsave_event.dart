import '../errors/smartsave_error.dart';
import 'link_state.dart';
import 'lock_state.dart';
import 'savings_goal.dart';
import 'savings_transaction.dart';

/// The kind of device anomaly detected during synchronization.
enum DeviceAnomalyKind {
  /// The device sequence moved backwards.
  seqRegressed,
  /// The device identity changed.
  deviceMismatch,
  /// The device reported an impossible state.
  unexpectedState,
}

/// A one-shot event emitted by the backend.
sealed class SmartSaveEvent {
  /// Creates an event.
  const SmartSaveEvent();
}

/// A coin transaction was received.
final class CoinReceived extends SmartSaveEvent {
  /// Creates a coin event.
  const CoinReceived(this.transaction);
  /// The received transaction.
  final SavingsTransaction transaction;
}

/// The device balance changed.
final class BalanceChanged extends SmartSaveEvent {
  /// Creates a balance event.
  const BalanceChanged(this.oldTotal, this.newTotal);
  /// Previous total.
  final int oldTotal;
  /// New total.
  final int newTotal;
}

/// The physical lock state changed.
final class LockChanged extends SmartSaveEvent {
  /// Creates a lock event.
  const LockChanged(this.lock);
  /// New lock state.
  final LockState lock;
}

/// The bank automatically relocked.
final class AutoRelocked extends SmartSaveEvent {
  /// Creates an auto-relock event.
  const AutoRelocked();
}

/// A goal reached its target.
final class GoalReached extends SmartSaveEvent {
  /// Creates a goal event.
  const GoalReached(this.goal);
  /// The reached goal.
  final SavingsGoal goal;
}

/// A reconciliation adjustment was applied.
final class ReconciliationApplied extends SmartSaveEvent {
  /// Creates a reconciliation event.
  const ReconciliationApplied(this.delta, {this.gapSize});
  /// Signed adjustment.
  final int delta;
  /// Number of missing sequence entries, when known.
  final int? gapSize;
}

/// A device anomaly was detected.
final class DeviceAnomaly extends SmartSaveEvent {
  /// Creates an anomaly event.
  const DeviceAnomaly(this.kind);
  /// Anomaly kind.
  final DeviceAnomalyKind kind;
}

/// An error was raised.
final class ErrorRaised extends SmartSaveEvent {
  /// Creates an error event.
  const ErrorRaised(this.error);
  /// Raised error.
  final SmartSaveError error;
}

/// The link state changed.
final class LinkChanged extends SmartSaveEvent {
  /// Creates a link event.
  const LinkChanged(this.link);
  /// New link state.
  final LinkState link;
}
