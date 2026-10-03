import 'dart:math';

import 'package:smartsave_backend/src/transport/mock/fake_device_simulator.dart';
import 'package:smartsave_backend/src/transport/mock/simulator_profile.dart';
import 'package:smartsave_backend/src/util/clock.dart';

import 'transcript.dart';

/// Runs a parsed conformance transcript against the fake simulator.
void runTranscript(String text) {
  final clock = FakeClock(DateTime.utc(2026));
  final simulator = FakeDeviceSimulator(clock, Random(1), SimulatorProfile.fresh);
  final output = <String>[];
  final subscription = simulator.output.listen(output.add);
  try {
    final sourceLines = text.split('\n');
    for (var index = 0; index < sourceLines.length; index++) {
      final parsed = parseTranscript('${sourceLines[index]}\n');
      for (final step in parsed) {
        final lineNumber = index + 1;
        switch (step.kind) {
          case TranscriptStepKind.section:
            break;
          case TranscriptStepKind.send:
            _requireEmpty(output, lineNumber);
            simulator.receiveLine(step.line!);
          case TranscriptStepKind.expect:
            if (output.isEmpty) {
              throw StateError('line $lineNumber: expected ${step.line}, got no output');
            }
            final actual = output.removeAt(0);
            if (actual != step.line) {
              throw StateError(
                'line $lineNumber: expected ${step.line}, got $actual',
              );
            }
          case TranscriptStepKind.usb:
            _requireEmpty(output, lineNumber);
            for (var repeat = 0; repeat < step.repeat; repeat++) {
              simulator.receiveLine(step.command!, fromUsb: true);
            }
          case TranscriptStepKind.wait:
            _requireEmpty(output, lineNumber);
            clock.advance(Duration(seconds: step.seconds!));
            simulator.tick();
          case TranscriptStepKind.drain:
            output.clear();
        }
      }
    }
    if (output.isNotEmpty) {
      throw StateError('transcript ended with unexpected output: ${output.first}');
    }
  } finally {
    subscription.cancel();
    simulator.dispose();
  }
}

void _requireEmpty(List<String> output, int lineNumber) {
  if (output.isNotEmpty) {
    throw StateError(
      'line $lineNumber: output was not consumed before next command: ${output.first}',
    );
  }
}
