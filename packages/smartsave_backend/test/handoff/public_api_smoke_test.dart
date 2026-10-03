import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

void main() {
  test('public API supports the documented mock flow', () async {
    final backend = SmartSaveBackend.create(
      SmartSaveConfig.mock(profile: SimulatorProfileName.demo),
    );
    final events = <SmartSaveEvent>[];
    final controller = backend.controller;
    final subscription = controller.events.listen(events.add);
    void onState() {}
    controller.addListener(onState);

    await backend.initialize();
    final banks = await controller.scan();
    expect(banks.isSuccess, isTrue);
    expect((await controller.connect(banks.valueOrNull!.single)).isSuccess, isTrue);
    expect((await controller.login('1234')).isSuccess, isTrue);
    await controller.sync();

    final goal = (await controller.createGoal('Trip', 5)).valueOrNull!;
    expect((await controller.allocateToGoal(goal.id, 5)).isSuccess, isTrue);
    backend.mockControls!.dropCoin(Denomination.php5);
    await Future<void>.value();
    expect(controller.state.deviceTotal, 1255);
    expect((await controller.redeemGoal(goal.id, '1234')).isSuccess, isTrue);
    expect(events.whereType<CoinReceived>(), isNotEmpty);
    expect(controller.state.transactions, isNotEmpty);

    controller.removeListener(onState);
    await subscription.cancel();
    await backend.dispose();
  });
}
