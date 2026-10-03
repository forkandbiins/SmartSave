import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

void main() {
  test('protocol limits mirror the firmware', () {
    expect(ProtocolLimits.protoVersion, 1);
    expect(ProtocolLimits.pinLength, 4);
    expect(ProtocolLimits.maxTotal, 99999);
    expect(ProtocolLimits.replayBufferSize, 32);
    expect(ProtocolLimits.maxFailedPins, 3);
    expect(ProtocolLimits.lockoutDuration, const Duration(seconds: 30));
    expect(ProtocolLimits.autoRelockDuration, const Duration(seconds: 30));
    expect(ProtocolLimits.maxSeq, 65535);
    expect(ProtocolLimits.maxOutboundLineChars, 19);
    expect(ProtocolLimits.maxBleWriteBytes, 20);
    expect(ProtocolLimits.maxInboundLineCharsAccepted, 23);
    expect(ProtocolLimits.validDenominations, [1, 5, 10, 20]);
  });

  test('environment defaults to mock', () {
    final config = SmartSaveConfig.fromEnvironment();
    expect(config.mode, SmartSaveMode.mock);
  });

  test('configuration defaults and copyWith', () {
    final config = SmartSaveConfig.mock(profile: SimulatorProfileName.demo);
    expect(config.simulatorProfile, SimulatorProfileName.demo);
    expect(config.bleServiceUuid, 'FFE0');
    expect(config.bleCharacteristicUuid, 'FFE1');
    expect(config.scanNamePrefixes, ['SmartSave', 'HMSoft']);
    expect(config.commandTimeout, const Duration(seconds: 3));
    expect(config.syncTimeout, const Duration(seconds: 6));
    expect(config.lockoutDuration, const Duration(seconds: 30));
    expect(config.autoSyncOnConnect, isTrue);
    expect(config.autoReconnect, isTrue);
    expect(config.copyWith(mode: SmartSaveMode.ble).mode, SmartSaveMode.ble);
  });
}
