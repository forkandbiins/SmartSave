import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/theme.dart';
import '../../shared/widgets/smart_save_scaffold.dart';

/// Finds and connects to a SmartSave bank.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.controller});

  /// Backend controller used for Bluetooth actions.
  final SmartSaveController controller;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  List<DiscoveredBank> _banks = const [];
  bool _busy = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
      _banks = const [];
    });
    final readiness = await widget.controller.ensureBluetoothReady();
    final ready = readiness.valueOrNull;
    if (!mounted) return;
    if (ready != BluetoothReadiness.ready) {
      setState(() {
        _busy = false;
        _error = _readinessMessage(ready);
      });
      return;
    }
    final result = await widget.controller.scan();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _banks = result.valueOrNull ?? const [];
      _error = result.isSuccess ? null : friendlyError(result.errorOrNull);
    });
  }

  Future<void> _connect(DiscoveredBank bank) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.controller.connect(bank);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _busy = false;
        _error = friendlyError(result.errorOrNull);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.controller.state.link;
    final connecting =
        link == LinkState.scanning ||
        link == LinkState.connecting ||
        link == LinkState.handshaking;
    return Scaffold(
      backgroundColor: SmartSaveTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
          children: [
            const SmartSaveWelcome(
              title: 'Connect your SmartSave',
              message: 'Find your Bank nearby to start tracking every coin.',
            ),
            const SizedBox(height: 32),
            if (_error != null) SmartSaveErrorText(message: _error!),
            if (_error != null) const SizedBox(height: 12),
            if (connecting || _busy)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          link == LinkState.scanning
                              ? 'Scanning for your Bank…'
                              : 'Connecting to your Bank…',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_banks.isEmpty)
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Find my Bank'),
              )
            else
              ..._banks.map(
                (bank) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: SmartSaveTokens.primarySoft,
                      child: Icon(
                        Icons.savings_outlined,
                        color: SmartSaveTokens.ink,
                      ),
                    ),
                    title: Text(
                      bank.name.isEmpty ? 'SmartSave Bank' : bank.name,
                    ),
                    subtitle: Text(
                      bank.rssi == null
                          ? 'Available nearby'
                          : 'Signal ${bank.rssi} dBm',
                    ),
                    trailing: FilledButton(
                      onPressed: () => _connect(bank),
                      child: const Text('Connect'),
                    ),
                  ),
                ),
              ),
            if (_banks.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _readinessMessage(BluetoothReadiness? readiness) {
  switch (readiness) {
    case BluetoothReadiness.bluetoothOff:
      return 'Bluetooth is off. Turn it on to connect.';
    case BluetoothReadiness.permissionDenied:
      return 'Bluetooth permission is needed to find your Bank.';
    case BluetoothReadiness.permanentlyDenied:
      return 'Bluetooth permission is blocked. Enable it in Settings.';
    case BluetoothReadiness.unsupported:
      return 'This device does not support Bluetooth.';
    case BluetoothReadiness.ready:
    case null:
      return 'Bluetooth is not ready yet. Try again.';
  }
}

/// Maps backend error codes to safe text for UI surfaces.
String friendlyError(SmartSaveError? error) {
  switch (error?.code) {
    case SmartSaveErrorCode.bluetoothOff:
      return 'Bluetooth is off. Turn it on to connect.';
    case SmartSaveErrorCode.permissionDenied:
      return 'Bluetooth permission is needed to connect.';
    case SmartSaveErrorCode.permissionPermanentlyDenied:
      return 'Bluetooth permission is blocked. Enable it in Settings.';
    case SmartSaveErrorCode.wrongPin:
      return 'That PIN is incorrect.';
    case SmartSaveErrorCode.lockedOut:
      return 'Too many incorrect attempts. Please wait and try again.';
    case SmartSaveErrorCode.invalidPinFormat:
      return 'Use exactly four digits for your PIN.';
    case SmartSaveErrorCode.notAuthenticated:
      return 'Please log in again to continue.';
    case SmartSaveErrorCode.invalidAmount:
      return 'Enter a valid amount within the Bank limit.';
    case SmartSaveErrorCode.invalidOperation:
      return 'That action is not available right now.';
    case SmartSaveErrorCode.connectionLost:
      return 'The Bank connection was lost. Reconnect and try again.';
    case SmartSaveErrorCode.connectFailed:
      return 'Could not connect to your Bank. Make sure it is on and nearby, then try again.';
    case SmartSaveErrorCode.serviceNotFound:
      return 'The selected device does not provide the SmartSave Bluetooth service. Check that you selected your Bank.';
    case SmartSaveErrorCode.commandTimeout:
      return 'Your Bank connected but did not respond. Check its power and try again.';
    case SmartSaveErrorCode.unsupportedVersion:
      return 'This Bank uses an unsupported protocol version.';
    case SmartSaveErrorCode.unexpectedReply:
      return 'Your Bank sent an unexpected reply. Reconnect and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
