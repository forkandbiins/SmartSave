import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/features/connection/connection_screen.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

void main() {
  test('connection errors explain whether connect or handshake failed', () {
    expect(
      friendlyError(const ConnectionError.connectFailed()),
      contains('Could not connect'),
    );
    expect(
      friendlyError(const ConnectionError.serviceNotFound()),
      contains('Bluetooth service'),
    );
    expect(
      friendlyError(const ProtocolError.commandTimeout()),
      contains('did not respond'),
    );
  });
}
