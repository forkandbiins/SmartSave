import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  test('FakeClock advances without sleeping', () {
    final clock = FakeClock(DateTime(2026, 1, 1));
    expect(clock.now(), DateTime(2026, 1, 1));
    clock.advance(const Duration(minutes: 2));
    expect(clock.now(), DateTime(2026, 1, 1, 0, 2));
  });
}
