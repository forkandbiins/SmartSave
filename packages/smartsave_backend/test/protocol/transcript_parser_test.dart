import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/protocol/device_message.dart';
import 'package:smartsave_backend/src/protocol/protocol_codec.dart';

import '../support/transcript.dart';

void main() {
  test('parses the golden transcript and shorthand', () {
    final text = File('test/fixtures/stub_transcript.txt').readAsStringSync();
    final steps = parseTranscript(text);
    expect(steps.where((step) => step.kind == TranscriptStepKind.section), hasLength(9));
    expect(
      steps.where((step) => step.kind == TranscriptStepKind.expect && step.line?.startsWith('COIN:1,') == true),
      hasLength(32),
    );
    expect(
      steps.where((step) => step.kind == TranscriptStepKind.usb && step.command == 'SIM:1').single.repeat,
      40,
    );
    for (final step in steps.where((step) => step.kind == TranscriptStepKind.expect)) {
      expect(ProtocolCodec.decode(step.line!), isNot(isA<MalformedMessage>()),
          reason: step.line);
    }
  });
}
