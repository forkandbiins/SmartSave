import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'core/app.dart';
import 'core/dev_autologin.dart';
import 'core/startup_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const devDemo = bool.fromEnvironment('DEV_DEMO');
  const requestedMode = String.fromEnvironment('SMARTSAVE_MODE');
  if (!devDemo && requestedMode.isEmpty) {
    runApp(StartupMode(onSelected: _startWithMode));
    return;
  }
  await _startWithMode(
    devDemo || requestedMode == 'mock' ? SmartSaveMode.mock : SmartSaveMode.ble,
    demoProfile: devDemo,
  );
}

Future<void> _startWithMode(
  SmartSaveMode mode, {
  bool demoProfile = false,
}) async {
  final backend = SmartSaveBackend.create(
    mode == SmartSaveMode.ble
        ? SmartSaveConfig.ble()
        : SmartSaveConfig.mock(
            profile: demoProfile
                ? SimulatorProfileName.demo
                : SimulatorProfileName.fresh,
          ),
  );
  await backend.initialize();
  if (mode == SmartSaveMode.ble) {
    await backend.controller.ensureBluetoothReady();
  }
  if (demoProfile) {
    await devAutoLogin(backend.controller);
  }
  runApp(SmartSaveApp(controller: backend.controller));
}
