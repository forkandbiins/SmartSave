import 'package:smartsave_backend/smartsave_backend.dart';

/// Maps a [SmartSaveErrorCode] to a short, friendly message for goal actions.
///
/// Never shows the raw developer-facing `error.message`.
String friendlyGoalError(SmartSaveErrorCode code) {
  switch (code) {
    case SmartSaveErrorCode.wrongPin:
      return 'That PIN was not correct. Try again.';
    case SmartSaveErrorCode.lockedOut:
      return 'Too many tries. Wait a moment, then try again.';
    case SmartSaveErrorCode.notAuthenticated:
      return 'Please unlock the bank first.';
    case SmartSaveErrorCode.notConnected:
      return 'Connect to your bank first.';
    case SmartSaveErrorCode.connectionLost:
      return 'The connection was lost. Reconnect and try again.';
    case SmartSaveErrorCode.commandTimeout:
      return 'The bank took too long to respond. Try again.';
    case SmartSaveErrorCode.invalidOperation:
      return 'That is not possible right now.';
    case SmartSaveErrorCode.invalidAmount:
      return 'That amount is not valid.';
    case SmartSaveErrorCode.invalidPinFormat:
      return 'Enter a 4-digit PIN.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
