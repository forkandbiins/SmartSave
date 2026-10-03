import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

void main() {
  test('ActionResult exposes branches and when', () {
    const success = ActionSuccess<int>(7);
    const failure = ActionFailure<int>(ConnectionError.deviceNotFound());
    expect(success.isSuccess, isTrue);
    expect(success.valueOrNull, 7);
    expect(success.when(success: (value) => value, failure: (_) => 0), 7);
    expect(failure.isSuccess, isFalse);
    expect(failure.errorOrNull, isA<ConnectionError>());
    expect(failure.when(success: (_) => 0, failure: (_) => 9), 9);
  });

  test('every error code is constructible', () {
    final errors = <SmartSaveError>[
      ConnectionError.bluetoothOff(), ConnectionError.permissionDenied(),
      ConnectionError.permissionPermanentlyDenied(), ConnectionError.deviceNotFound(),
      ConnectionError.connectFailed(), ConnectionError.connectionLost(),
      ConnectionError.serviceNotFound(), ProtocolError.unsupportedVersion(),
      ProtocolError.commandTimeout(), ProtocolError.unexpectedReply(),
      ProtocolError.invalidArgument(), InvalidArgumentError(),
      AuthError.pinNotSet(), AuthError.wrongPin(), AuthError.lockedOut(null),
      AuthError.notAuthenticated(), AuthError.invalidPinFormat(),
      DeviceError.invalidAmount(), DeviceError.badFormat(), DeviceError.unknownCommand(),
      StorageError.readFailed(), StorageError.writeFailed(), StorageError.corrupt(),
      SmartSaveStateError.deviceMismatch(), SmartSaveStateError.notConnected(),
      SmartSaveStateError.invalidOperation(),
    ];
    expect(errors.map((error) => error.code).toSet(), hasLength(25));
  });
}
