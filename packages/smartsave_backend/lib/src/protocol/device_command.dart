/// A command sent from the app to the bank.
sealed class DeviceCommand {
  /// Creates a command.
  const DeviceCommand();
}

/// Requests the bank protocol and authentication status.
final class HelloCommand extends DeviceCommand {
  /// Creates a HELLO command.
  const HelloCommand();
}

/// Logs in with [pin].
final class LoginCommand extends DeviceCommand {
  /// Creates an AUTH command.
  const LoginCommand(this.pin);
  /// Four-digit PIN.
  final String pin;
}

/// Sets the first bank PIN.
final class SetInitialPinCommand extends DeviceCommand {
  /// Creates an initial SETPIN command.
  const SetInitialPinCommand(this.pin);
  /// New four-digit PIN.
  final String pin;
}

/// Changes the bank PIN.
final class ChangePinCommand extends DeviceCommand {
  /// Creates a PIN-change command.
  const ChangePinCommand(this.oldPin, this.newPin);
  /// Current PIN.
  final String oldPin;
  /// Replacement PIN.
  final String newPin;
}

/// Requests a synchronization snapshot.
final class SyncCommand extends DeviceCommand {
  /// Creates a SYNC command.
  const SyncCommand();
}

/// Acknowledges a sequence number.
final class AckCommand extends DeviceCommand {
  /// Creates an ACK command.
  const AckCommand(this.seq);
  /// Sequence number to acknowledge.
  final int seq;
}

/// Locks the bank.
final class LockCommand extends DeviceCommand {
  /// Creates a LOCK command.
  const LockCommand();
}

/// Unlocks the bank and deducts an amount.
final class UnlockCommand extends DeviceCommand {
  /// Creates an UNLOCK command.
  const UnlockCommand(this.pin, this.amount);
  /// Authentication PIN.
  final String pin;
  /// Amount to deduct.
  final int amount;
}

/// Adjusts the bank balance.
final class AdjustCommand extends DeviceCommand {
  /// Creates an ADJ command.
  const AdjustCommand(this.pin, this.newTotal);
  /// Authentication PIN.
  final String pin;
  /// Replacement balance.
  final int newTotal;
}

/// Checks that the bank is responsive.
final class PingCommand extends DeviceCommand {
  /// Creates a PING command.
  const PingCommand();
}
