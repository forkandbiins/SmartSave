import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/protocol/device_command.dart';
import 'package:smartsave_backend/src/protocol/protocol_codec.dart';

void main() {
  test('encodes every command', () {
    final commands = <DeviceCommand, String>{
      const HelloCommand(): 'HELLO',
      const LoginCommand('1234'): 'AUTH:1234',
      const SetInitialPinCommand('1234'): 'SETPIN:1234',
      const ChangePinCommand('1234', '5678'): 'SETPIN:1234,5678',
      const SyncCommand(): 'SYNC',
      const AckCommand(65535): 'ACK:65535',
      const LockCommand(): 'LOCK',
      const UnlockCommand('1234', 99999): 'UNLOCK:1234,99999',
      const AdjustCommand('1234', 99999): 'ADJ:1234,99999',
      const PingCommand(): 'PING',
    };
    for (final entry in commands.entries) {
      expect(ProtocolCodec.encode(entry.key), entry.value);
    }
  });

  test('rejects invalid PINs, ranges, and line lengths', () {
    expect(() => ProtocolCodec.encode(const LoginCommand('12')),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const LoginCommand('12345')),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const LoginCommand('abcd')),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const UnlockCommand('1234', 0)),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const UnlockCommand('1234', 100000)),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const UnlockCommand('1234', -1)),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const AckCommand(65536)),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const AdjustCommand('1234', 100000)),
        throwsA(isA<Exception>()));
    expect(() => ProtocolCodec.encode(const LoginCommand('12345678901234567890')),
        throwsA(isA<Exception>()));
  });
}
