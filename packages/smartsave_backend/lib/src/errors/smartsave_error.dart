/// Stable categories for backend failures.
enum SmartSaveErrorCode {
  /// Bluetooth is disabled.
  bluetoothOff,
  /// Bluetooth permission was denied.
  permissionDenied,
  /// Bluetooth permission was permanently denied.
  permissionPermanentlyDenied,
  /// No matching device was found.
  deviceNotFound,
  /// A connection attempt failed.
  connectFailed,
  /// The connection was lost.
  connectionLost,
  /// Required BLE service was not found.
  serviceNotFound,
  /// The device protocol version is unsupported.
  unsupportedVersion,
  /// A command timed out.
  commandTimeout,
  /// A reply did not match the pending command.
  unexpectedReply,
  /// An argument was invalid.
  invalidArgument,
  /// The device has no configured PIN.
  pinNotSet,
  /// The supplied PIN was incorrect.
  wrongPin,
  /// The device is temporarily locked out.
  lockedOut,
  /// Authentication is required.
  notAuthenticated,
  /// The PIN format is invalid.
  invalidPinFormat,
  /// The requested amount is invalid.
  invalidAmount,
  /// A device line has invalid formatting.
  badFormat,
  /// The device does not recognize a command.
  unknownCommand,
  /// A persisted value could not be read.
  readFailed,
  /// A value could not be persisted.
  writeFailed,
  /// Persisted data is corrupt.
  corrupt,
  /// The connected device is not the expected device.
  deviceMismatch,
  /// An operation requires a connection.
  notConnected,
  /// The operation is invalid in the current state.
  invalidOperation,
}

/// Base type for typed SmartSave failures.
sealed class SmartSaveError implements Exception {
  /// Creates a typed failure.
  const SmartSaveError(this.code, this.message, [this.cause]);

  /// Stable machine-readable error code.
  final SmartSaveErrorCode code;

  /// Developer-facing English description.
  final String message;

  /// Optional underlying cause.
  final Object? cause;

  @override
  String toString() => 'SmartSaveError($code): $message';
}

/// A connection-related failure.
final class ConnectionError extends SmartSaveError {
  const ConnectionError._(super.code, super.message, [super.cause]);
  /// Bluetooth is disabled.
  const ConnectionError.bluetoothOff()
      : this._(SmartSaveErrorCode.bluetoothOff, 'Bluetooth is turned off.');
  /// Permission was denied.
  const ConnectionError.permissionDenied()
      : this._(SmartSaveErrorCode.permissionDenied, 'Bluetooth permission denied.');
  /// Permission was permanently denied.
  const ConnectionError.permissionPermanentlyDenied()
      : this._(SmartSaveErrorCode.permissionPermanentlyDenied,
            'Bluetooth permission permanently denied.');
  /// No device was found.
  const ConnectionError.deviceNotFound()
      : this._(SmartSaveErrorCode.deviceNotFound, 'SmartSave device not found.');
  /// Connection failed.
  const ConnectionError.connectFailed([Object? cause])
      : this._(SmartSaveErrorCode.connectFailed, 'Connection failed.', cause);
  /// The connection was lost.
  const ConnectionError.connectionLost([Object? cause])
      : this._(SmartSaveErrorCode.connectionLost, 'Connection lost.', cause);
  /// The required service was not found.
  const ConnectionError.serviceNotFound()
      : this._(SmartSaveErrorCode.serviceNotFound, 'BLE service not found.');
}

/// A protocol-related failure.
class ProtocolError extends SmartSaveError {
  const ProtocolError._(super.code, super.message, [super.cause]);
  /// The protocol version is unsupported.
  const ProtocolError.unsupportedVersion()
      : this._(SmartSaveErrorCode.unsupportedVersion, 'Unsupported protocol version.');
  /// A command timed out.
  const ProtocolError.commandTimeout()
      : this._(SmartSaveErrorCode.commandTimeout, 'Command timed out.');
  /// A reply was unexpected.
  const ProtocolError.unexpectedReply()
      : this._(SmartSaveErrorCode.unexpectedReply, 'Unexpected device reply.');
  /// An argument was invalid.
  const ProtocolError.invalidArgument([Object? cause])
      : this._(SmartSaveErrorCode.invalidArgument, 'Invalid argument.', cause);
}

/// A convenience name for an invalid protocol argument.
final class InvalidArgumentError extends ProtocolError {
  /// Creates an invalid argument error.
  const InvalidArgumentError([Object? cause])
      : super._(SmartSaveErrorCode.invalidArgument, 'Invalid argument.', cause);
}

/// An authentication-related failure.
final class AuthError extends SmartSaveError {
  /// Creates an authentication error.
  const AuthError._(super.code, super.message, [super.cause]) : until = null;

  /// Creates an authentication error with a lockout deadline.
  const AuthError._lockedOut(this.until)
      : super(SmartSaveErrorCode.lockedOut, 'Device is locked out.');

  /// Lockout deadline, when this is a [lockedOut] error.
  final DateTime? until;
  /// The device has no PIN.
  const AuthError.pinNotSet()
      : this._(SmartSaveErrorCode.pinNotSet, 'Device PIN is not set.');
  /// The PIN was wrong.
  const AuthError.wrongPin()
      : this._(SmartSaveErrorCode.wrongPin, 'Wrong PIN.');
  /// The device is locked until [until].
  const AuthError.lockedOut(DateTime? until)
      : this._lockedOut(until);
  /// The session is not authenticated.
  const AuthError.notAuthenticated()
      : this._(SmartSaveErrorCode.notAuthenticated, 'Not authenticated.');
  /// The PIN format is invalid.
  const AuthError.invalidPinFormat()
      : this._(SmartSaveErrorCode.invalidPinFormat, 'Invalid PIN format.');
}

/// A device-reported failure.
final class DeviceError extends SmartSaveError {
  const DeviceError._(super.code, super.message, [super.cause]);
  /// The amount is invalid.
  const DeviceError.invalidAmount()
      : this._(SmartSaveErrorCode.invalidAmount, 'Invalid amount.');
  /// The device line has bad format.
  const DeviceError.badFormat()
      : this._(SmartSaveErrorCode.badFormat, 'Bad device format.');
  /// The command is unknown.
  const DeviceError.unknownCommand()
      : this._(SmartSaveErrorCode.unknownCommand, 'Unknown device command.');
}

/// A persistence-related failure.
final class StorageError extends SmartSaveError {
  const StorageError._(super.code, super.message, [super.cause]);
  /// Reading persisted data failed.
  const StorageError.readFailed([Object? cause])
      : this._(SmartSaveErrorCode.readFailed, 'Storage read failed.', cause);
  /// Writing persisted data failed.
  const StorageError.writeFailed([Object? cause])
      : this._(SmartSaveErrorCode.writeFailed, 'Storage write failed.', cause);
  /// Persisted data is corrupt.
  const StorageError.corrupt([Object? cause])
      : this._(SmartSaveErrorCode.corrupt, 'Stored data is corrupt.', cause);
}

/// A state-related failure.
final class SmartSaveStateError extends SmartSaveError {
  const SmartSaveStateError._(super.code, super.message, [super.cause]);
  /// The device does not match the expected device.
  const SmartSaveStateError.deviceMismatch()
      : this._(SmartSaveErrorCode.deviceMismatch, 'Device mismatch.');
  /// The device is not connected.
  const SmartSaveStateError.notConnected()
      : this._(SmartSaveErrorCode.notConnected, 'Device is not connected.');
  /// The operation is invalid for the current state.
  const SmartSaveStateError.invalidOperation()
      : this._(SmartSaveErrorCode.invalidOperation, 'Invalid operation.');
}
