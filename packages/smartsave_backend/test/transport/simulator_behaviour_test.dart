import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/models/denomination.dart';
import 'package:smartsave_backend/src/transport/mock/fake_device_simulator.dart';
import 'package:smartsave_backend/src/transport/mock/simulator_profile.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  FakeDeviceSimulator create(FakeClock clock) =>
      FakeDeviceSimulator(clock, Random(1), SimulatorProfile.fresh);

  test('sequence wraps, totals clamp, and invalid ACKs are silent', () {
    final clock = FakeClock(DateTime.utc(2026));
    final simulator = create(clock);
    simulator.seedStateForTest(seq: 65535, total: 99990);
    final output = <String>[];
    final subscription = simulator.output.listen(output.add);
    simulator.dropCoin(20);
    expect(simulator.seq, 0);
    expect(simulator.total, 99999);
    simulator.receiveLine('ACK:65535');
    expect(output, ['COIN:20,0', 'TOTAL:99999']);
    subscription.cancel();
  });

  test('lockout expires from the injected clock', () {
    final clock = FakeClock(DateTime.utc(2026));
    final simulator = create(clock);
    simulator.receiveLine('SETPIN:1234');
    final output = <String>[];
    final subscription = simulator.output.listen(output.add);
    simulator.receiveLine('AUTH:0000');
    simulator.receiveLine('AUTH:0000');
    simulator.receiveLine('AUTH:0000');
    simulator.receiveLine('AUTH:1234');
    expect(output.last, 'AUTH:WAIT');
    clock.advance(const Duration(seconds: 31));
    simulator.tick();
    simulator.receiveLine('AUTH:1234');
    expect(output.last, 'AUTH:OK');
    subscription.cancel();
  });

  test('offline coins replay after reconnect and retain only 32', () {
    final clock = FakeClock(DateTime.utc(2026));
    final simulator = create(clock);
    for (var i = 0; i < 33; i++) {
      simulator.dropCoin(Denomination.php1.value);
    }
    final output = <String>[];
    final subscription = simulator.output.listen(output.add);
    simulator.receiveLine('SYNC');
    final replay = output.where((line) => line.startsWith('COIN:')).toList();
    expect(replay, hasLength(32));
    expect(replay.first, 'COIN:1,2');
    subscription.cancel();
  });
}
