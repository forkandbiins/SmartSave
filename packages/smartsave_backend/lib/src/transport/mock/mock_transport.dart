import 'dart:async';

import '../../models/discovered_bank.dart';
import '../device_transport.dart';
import 'fake_device_simulator.dart';

/// A line transport backed by [FakeDeviceSimulator].
final class MockTransport implements DeviceTransport {
  /// Creates a mock transport.
  MockTransport(
    this.simulator, {
    this.latency = Duration.zero,
    this.autoTick = true,
  }) {
    _outputSubscription = simulator.output.listen((line) {
      if (_connected) {
        if (latency == Duration.zero) {
          _lines.add(line);
        } else {
          Future<void>.delayed(latency, () {
            if (_connected) _lines.add(line);
          });
        }
      }
    });
    if (autoTick) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => simulator.tick(),
      );
    }
  }

  /// Simulator behind this transport.
  final FakeDeviceSimulator simulator;
  /// Delay applied to delivered lines.
  Duration latency;
  /// Whether the periodic simulator clock hook is enabled.
  final bool autoTick;
  final StreamController<TransportState> _states =
      StreamController<TransportState>.broadcast(sync: true);
  final StreamController<String> _lines =
      StreamController<String>.broadcast(sync: true);
  StreamSubscription<String>? _outputSubscription;
  Timer? _timer;
  bool _connected = false;
  bool _disposed = false;

  @override
  Stream<TransportState> get state => _states.stream;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<DiscoveredBank> scan({Duration timeout = Duration.zero}) async* {
    yield const DiscoveredBank(
      id: 'mock-bank-1',
      name: 'SmartSave (mock)',
    );
  }

  @override
  Future<void> connect(DiscoveredBank bank) async {
    if (_disposed) return;
    _states.add(TransportState.connecting);
    _connected = true;
    _states.add(TransportState.connected);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _connected = false;
    _states.add(TransportState.disconnected);
  }

  @override
  Future<void> writeLine(String line) async {
    if (_disposed) return;
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    simulator.receiveLine(line);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _connected = false;
    _timer?.cancel();
    await _outputSubscription?.cancel();
    await simulator.dispose();
    await _states.close();
    await _lines.close();
  }
}
