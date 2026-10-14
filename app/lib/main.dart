import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'core/app.dart';
import 'core/dev_autologin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const devDemo = bool.fromEnvironment('DEV_DEMO');
  final backend = SmartSaveBackend.create(
    devDemo
        ? SmartSaveConfig.mock(profile: SimulatorProfileName.demo)
        : SmartSaveConfig.fromEnvironment(),
  );
  await backend.initialize();
  if (devDemo) {
    await devAutoLogin(backend.controller);
  }
  runApp(SmartSaveApp(controller: backend.controller));
}
