import 'dart:async';

import '../config/smartsave_config.dart';
import '../models/discovered_bank.dart';
import '../transport/device_transport.dart';
import '../util/clock.dart';
import 'smartsave_controller.dart';

/// Reconnects a controller after unexpected transport loss.
final class ConnectionSupervisor {
  /// Creates a supervisor for [controller] and [transport].
  ConnectionSupervisor({
    required this.config,
    required this.controller,
    required this.transport,
    required this.clock,
  }) {
    _subscription = transport.state.listen(_onState);
  }

  /// Runtime configuration.
  final SmartSaveConfig config;
  /// Controller to reconnect.
  final SmartSaveController controller;
  /// Transport being monitored.
  final DeviceTransport transport;
  /// Injected clock retained for deterministic policy decisions.
  final Clock clock;

  StreamSubscription<TransportState>? _subscription;
  Timer? _timer;
  DiscoveredBank? _bank;
  bool _manualDisconnect = false;
  bool _paused = false;
  bool _disposed = false;
  int _attempt = 0;

  /// Records the bank used by the next reconnect.
  void remember(DiscoveredBank bank) => _bank = bank;

  /// Pauses scheduled reconnect attempts.
  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Resumes scheduled reconnect attempts.
  void resume() {
    _paused = false;
    if (_bank != null && !_manualDisconnect && _timer == null) {
      _schedule();
    }
  }

  /// Marks the next disconnect as intentional.
  void manualDisconnect() {
    _manualDisconnect = true;
    _timer?.cancel();
    _timer = null;
  }

  void _onState(TransportState state) {
    if (state == TransportState.connected) {
      _attempt = 0;
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (state == TransportState.disconnected &&
        !_manualDisconnect &&
        config.autoReconnect &&
        !_paused &&
        _bank != null) {
      _schedule();
    }
  }

  void _schedule() {
    if (_disposed || _timer != null || _attempt >= 10) return;
    final seconds = _attempt < 4 ? 1 << _attempt : 30;
    _timer = Timer(Duration(seconds: seconds), () {
      _timer = null;
      unawaited(_attemptReconnect());
    });
  }

  Future<void> _attemptReconnect() async {
    if (_disposed || _paused || _manualDisconnect || _bank == null) return;
    _attempt++;
    try {
      final result = await controller.connect(_bank!);
      if (result.isSuccess) return;
    } on Object {
      // Controller actions are expected to return failures; this guard keeps
      // a malformed implementation from escaping the supervisor callback.
    }
    if (!_disposed && !_paused && !_manualDisconnect) _schedule();
  }

  /// Cancels retries and releases the state subscription.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
  }
}
