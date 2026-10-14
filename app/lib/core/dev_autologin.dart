import 'package:smartsave_backend/smartsave_backend.dart';

/// DEV ONLY: scans, connects to the first bank, logs in with PIN 1234, and syncs.
///
/// Used when the app is started with `--dart-define=DEV_DEMO=true`.
Future<void> devAutoLogin(SmartSaveController controller) async {
  final banks = (await controller.scan()).valueOrNull;
  if (banks == null || banks.isEmpty) {
    return;
  }
  await controller.connect(banks.first);
  await controller.login('1234');
  await controller.sync();
}
