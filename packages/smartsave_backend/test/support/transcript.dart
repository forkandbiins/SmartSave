/// The kind of operation represented by a transcript step.
enum TranscriptStepKind { send, expect, usb, wait, drain, section }

/// One parsed operation in the conformance transcript.
final class TranscriptStep {
  const TranscriptStep._(
    this.kind, {
    this.line,
    this.command,
    this.repeat = 1,
    this.seconds,
    this.sectionNumber,
  });

  /// Creates an app-to-bank step.
  const TranscriptStep.send(String line)
      : this._(TranscriptStepKind.send, line: line);

  /// Creates an expected bank-output step.
  const TranscriptStep.expect(String line)
      : this._(TranscriptStepKind.expect, line: line);

  /// Creates a USB command step.
  const TranscriptStep.usb(String command, {int repeat = 1})
      : this._(TranscriptStepKind.usb, command: command, repeat: repeat);

  /// Creates a time-advance step.
  const TranscriptStep.wait(int seconds)
      : this._(TranscriptStepKind.wait, seconds: seconds);

  /// Creates a drain step.
  const TranscriptStep.drain() : this._(TranscriptStepKind.drain);

  /// Creates a section marker step.
  const TranscriptStep.section(int number)
      : this._(TranscriptStepKind.section, sectionNumber: number);

  /// Operation kind.
  final TranscriptStepKind kind;
  /// Line for send/expect steps.
  final String? line;
  /// USB command text.
  final String? command;
  /// USB repeat count.
  final int repeat;
  /// Wait duration in seconds.
  final int? seconds;
  /// Section number for section markers.
  final int? sectionNumber;
}

/// Parses a SmartSave conformance transcript.
List<TranscriptStep> parseTranscript(String text) {
  final steps = <TranscriptStep>[];
  for (final sourceLine in text.split('\n')) {
    final line = sourceLine.trimRight().replaceFirst('\r', '');
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      final match = RegExp(r'^#\s*S(\d+)\b').firstMatch(line);
      if (match != null) steps.add(TranscriptStep.section(int.parse(match.group(1)!)));
      continue;
    }
    if (line.startsWith('> ')) {
      steps.add(TranscriptStep.send(line.substring(2)));
      continue;
    }
    if (line.startsWith('< ')) {
      final expected = line.substring(2);
      final shorthand = RegExp(r'\{(-?\d+)\.\.(-?\d+)\}').firstMatch(expected);
      if (shorthand == null) {
        steps.add(TranscriptStep.expect(expected));
      } else {
        final start = int.parse(shorthand.group(1)!);
        final end = int.parse(shorthand.group(2)!);
        final increment = start <= end ? 1 : -1;
        for (var value = start;; value += increment) {
          steps.add(TranscriptStep.expect(expected.replaceFirst(shorthand.group(0)!, '$value')));
          if (value == end) break;
        }
      }
      continue;
    }
    if (line == '@drain') {
      steps.add(const TranscriptStep.drain());
      continue;
    }
    final wait = RegExp(r'^@wait\s+(\d+)$').firstMatch(line);
    if (wait != null) {
      steps.add(TranscriptStep.wait(int.parse(wait.group(1)!)));
      continue;
    }
    final usb = RegExp(r'^@usb\s+(\S+)(?:\s+x(\d+))?$').firstMatch(line);
    if (usb != null) {
      steps.add(TranscriptStep.usb(
        usb.group(1)!,
        repeat: int.parse(usb.group(2) ?? '1'),
      ));
    }
  }
  return steps;
}
