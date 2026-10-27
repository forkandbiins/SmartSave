import 'package:smartsave_backend/smartsave_backend.dart';

/// Maps a [SmartSaveError.code] to a short, friendly message for the UI.
///
/// Never shows the raw developer-facing [SmartSaveError.message].
String friendlyMessageFor(SmartSaveErrorCode code) {
  switch (code) {
    case SmartSaveErrorCode.bluetoothOff:
      return 'Bluetooth is off. Turn it on to connect.';
    case SmartSaveErrorCode.permissionDenied:
      return 'Bluetooth permission was denied.';
    case SmartSaveErrorCode.permissionPermanentlyDenied:
      return 'Bluetooth permission is permanently denied.';
    case SmartSaveErrorCode.deviceNotFound:
      return "Couldn't find your SmartSave bank.";
    case SmartSaveErrorCode.connectFailed:
      return 'Connection failed. Try again.';
    case SmartSaveErrorCode.connectionLost:
      return 'Connection to the bank was lost.';
    case SmartSaveErrorCode.serviceNotFound:
      return "The bank's Bluetooth service wasn't found.";
    case SmartSaveErrorCode.unsupportedVersion:
      return "Your bank's firmware is incompatible with this app.";
    case SmartSaveErrorCode.commandTimeout:
      return 'The bank took too long to respond.';
    case SmartSaveErrorCode.unexpectedReply:
      return 'The bank sent an unexpected response.';
    case SmartSaveErrorCode.invalidArgument:
      return 'Something went wrong. Try again.';
    case SmartSaveErrorCode.pinNotSet:
      return 'No PIN is set on this bank yet.';
    case SmartSaveErrorCode.wrongPin:
      return 'Wrong PIN. Try again.';
    case SmartSaveErrorCode.lockedOut:
      return 'Too many wrong PINs. Wait a moment.';
    case SmartSaveErrorCode.notAuthenticated:
      return 'Please log in first.';
    case SmartSaveErrorCode.invalidPinFormat:
      return 'PIN must be 4 digits.';
    case SmartSaveErrorCode.invalidAmount:
      return 'That amount is not valid.';
    case SmartSaveErrorCode.badFormat:
      return 'The bank sent a garbled message.';
    case SmartSaveErrorCode.unknownCommand:
      return "The bank doesn't recognize that command.";
    case SmartSaveErrorCode.readFailed:
      return "Couldn't read your saved data.";
    case SmartSaveErrorCode.writeFailed:
      return "Couldn't save your data.";
    case SmartSaveErrorCode.corrupt:
      return 'Your saved data is corrupted.';
    case SmartSaveErrorCode.deviceMismatch:
      return "This isn't the bank you paired with.";
    case SmartSaveErrorCode.notConnected:
      return 'Connect to your bank first.';
    case SmartSaveErrorCode.invalidOperation:
      return "That action isn't available right now.";
  }
}
