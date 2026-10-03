import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/models/denomination.dart';
import 'package:smartsave_backend/src/protocol/device_message.dart';
import 'package:smartsave_backend/src/protocol/protocol_codec.dart';

void main() {
  test('decodes every valid inbound line type', () {
    final cases = <String, Type>{
      'PROTO:1': ProtoMessage,
      'AUTH:NEW': AuthStatusMessage,
      'AUTH:REQ': AuthStatusMessage,
      'AUTH:OK': AuthStatusMessage,
      'AUTH:FAIL': AuthStatusMessage,
      'AUTH:WAIT': AuthStatusMessage,
      'COIN:5,1': CoinMessage,
      'TOTAL:99999': TotalMessage,
      'LOCK:0': LockMessage,
      'LOCK:1': LockMessage,
      'SEQ:65535': SeqMessage,
      'SYNC:END': SyncEndMessage,
      'PONG': PongMessage,
      'ERR:CMD': ErrorMessage,
      'ERR:FMT': ErrorMessage,
      'ERR:AMT': ErrorMessage,
    };
    for (final entry in cases.entries) {
      expect(ProtocolCodec.decode(entry.key), isA<dynamic>().having(
            (value) => value.runtimeType,
            'runtimeType',
            entry.value,
          ));
    }
    expect((ProtocolCodec.decode('COIN:20,65535') as CoinMessage).denomination,
        Denomination.php20);
  });

  test('classifies malformed lines', () {
    final cases = <String, MalformedReason>{
      '': MalformedReason.empty,
      'HELLO': MalformedReason.unknownToken,
      'AUTH:1234': MalformedReason.unknownToken,
      'COIN:2,5': MalformedReason.invalidDenomination,
      'TOTAL:100000': MalformedReason.outOfRange,
      'TOTAL:abc': MalformedReason.badArgument,
      'COIN:5': MalformedReason.badArgument,
      'COIN:5,': MalformedReason.badArgument,
      'COIN:,3': MalformedReason.badArgument,
      'COIN:5,65536': MalformedReason.outOfRange,
      'COIN:5,-1': MalformedReason.outOfRange,
      'LOCK:2': MalformedReason.outOfRange,
      'ERR:XYZ': MalformedReason.badArgument,
      'coin:5,1': MalformedReason.unknownToken,
      'TOTAL: 5': MalformedReason.badArgument,
      'SEQ:-1': MalformedReason.outOfRange,
      'SEQ:65536': MalformedReason.outOfRange,
      'PROTO:abc': MalformedReason.badArgument,
    };
    for (final entry in cases.entries) {
      final result = ProtocolCodec.decode(entry.key);
      expect(result, isA<MalformedMessage>());
      expect((result as MalformedMessage).reason, entry.value,
          reason: entry.key);
    }
    expect(ProtocolCodec.decode('  TOTAL:5\r '), isA<TotalMessage>());
  });

  test('decoding never throws for random strings', () {
    final random = Random(12345);
    for (var i = 0; i < 1000; i++) {
      final length = random.nextInt(40);
      final value = String.fromCharCodes(
        List<int>.generate(length, (_) => 32 + random.nextInt(95)),
      );
      expect(() => ProtocolCodec.decode(value), returnsNormally);
    }
  });
}
