import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/src/diagnostics/raw_traffic_log.dart';
import 'package:smartsave_backend/src/util/clock.dart';

void main() {
  test('raw traffic redacts PINs and retains the last 200 entries', () {
    final log = RawTrafficLog(FakeClock(DateTime.utc(2026)));
    for (var index = 0; index < 201; index++) {
      log.add('tx', index == 200 ? 'UNLOCK:1234,5' : 'PING');
    }

    final entries = log.snapshot();
    expect(entries, hasLength(200));
    expect(entries.first.line, 'PING');
    expect(entries.last.line, 'UNLOCK:****,5');
    expect(entries.last.direction, 'tx');
  });

  test('supervisor pause and manual disconnect cancel scheduled retries',
      () async {
    final backend = SmartSaveBackend.create(
      SmartSaveConfig.mock().copyWith(autoSyncOnConnect: false),
    );
    final supervisor = backend.connectionSupervisor;
    supervisor.remember(
      const DiscoveredBank(id: 'bank', name: 'SmartSave (mock)'),
    );
    supervisor.pause();
    supervisor.resume();
    supervisor.manualDisconnect();
    await backend.dispose();
  });
}
