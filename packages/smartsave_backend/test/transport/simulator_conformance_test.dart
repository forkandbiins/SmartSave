import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/transcript_runner.dart';

void main() {
  test('fake simulator passes the golden transcript', () {
    final transcript = File('test/fixtures/stub_transcript.txt').readAsStringSync();
    runTranscript(transcript);
  });
}
