import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../errors/smartsave_error.dart';
import '../../models/discovered_bank.dart';
import '../../protocol/line_assembler.dart';
import '../device_transport.dart';
import 'ble_gateway.dart';
import 'hm10_constants.dart';

/// HM-10 line transport over a [BleGateway].
///
/// HM-10 service and characteristic identifiers, and advertised names, are
/// assumptions to verify on the real module because clones vary.
final class Hm10BleTransport implements DeviceTransport {
  /// Creates a transport using [gateway] and optional advertised-name prefixes.
  Hm10BleTransport(
    this.gateway, {
    this.namePrefixes = const <String>['SmartSave', 'HMSoft'],
    this.connectTimeout = Hm10Constants.connectTimeout,
  });

  /// BLE gateway used by this transport.
  final BleGateway gateway;

  /// Advertised-name prefixes retained for compatibility with gateway
  /// implementations that provide names during service-filtered scans.
  final List<String> namePrefixes;

  /// Maximum connection duration.
  final Duration connectTimeout;

  final _states = StreamController<TransportState>.broadcast(sync: true);
  final _lines = StreamController<String>.broadcast(sync: true);
  final _assembler = LineAssembler(maxLineLength: 23);
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  Future<void> _writeTail = Future<void>.value();
  String? _deviceId;
  bool _connected = false;
  bool _disposed = false;

  @override
  Stream<TransportState> get state => _states.stream;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<DiscoveredBank> scan({
    Duration timeout = Hm10Constants.connectTimeout,
  }) async* {
    await for (final device in gateway.scan(
      serviceUuid: Hm10Constants.serviceUuid,
      timeout: timeout,
    )) {
      yield DiscoveredBank(id: device.id, name: device.name);
    }
  }

  @override
  Future<void> connect(DiscoveredBank bank) async {
    if (_disposed) return;
    await _disconnectSubscriptions();
    _states.add(TransportState.connecting);
    _deviceId = bank.id;
    try {
      final connected = Completer<void>();
      late final StreamSubscription<BleConnectionState> subscription;
      subscription = gateway.connect(
        bank.id,
        timeout: connectTimeout,
      ).listen(
        (status) {
          if (status == BleConnectionState.connected &&
              !connected.isCompleted) {
            connected.complete();
          } else if (status == BleConnectionState.disconnected) {
            _handleDisconnected();
            if (!connected.isCompleted) {
              connected.completeError(const ConnectionError.connectFailed());
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!connected.isCompleted) {
            connected.completeError(ConnectionError.connectFailed(error), stack);
          }
        },
        onDone: () {
          if (!connected.isCompleted) {
            connected.completeError(const ConnectionError.connectFailed());
          }
        },
        cancelOnError: false,
      );
      _connectionSubscription = subscription;
      await connected.future;
      if (!await gateway.verifyServiceAndCharacteristic(
        bank.id,
        serviceUuid: Hm10Constants.serviceUuid,
        characteristicUuid: Hm10Constants.characteristicUuid,
      )) {
        await _disconnectSubscriptions();
        await gateway.disconnect(bank.id);
        _states.add(TransportState.disconnected);
        throw const ConnectionError.serviceNotFound();
      }
      _connected = true;
      _states.add(TransportState.connected);
      _notificationSubscription = gateway
          .notifications(
            bank.id,
            serviceUuid: Hm10Constants.serviceUuid,
            characteristicUuid: Hm10Constants.characteristicUuid,
          )
          .listen(
            _handleNotification,
            onError: (Object error, StackTrace stack) =>
                _handleDisconnected(error),
            onDone: _handleDisconnected,
          );
    } on SmartSaveError {
      rethrow;
    } on Object catch (error) {
      _handleDisconnected(error);
      throw ConnectionError.connectFailed(error);
    }
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    final id = _deviceId;
    _connected = false;
    await _disconnectSubscriptions();
    if (id != null) await gateway.disconnect(id);
    _states.add(TransportState.disconnected);
  }

  @override
  Future<void> writeLine(String line) {
    final operation = _writeTail.then((_) => _write(line));
    _writeTail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _write(String line) async {
    if (_disposed || !_connected || _deviceId == null) {
      throw const SmartSaveStateError.notConnected();
    }
    final bytes = utf8.encode('$line\n');
    for (var offset = 0; offset < bytes.length; offset += Hm10Constants.writeChunkSize) {
      final end = math.min(
        offset + Hm10Constants.writeChunkSize,
        bytes.length,
      );
      await gateway.writeWithoutResponse(
        _deviceId!,
        bytes.sublist(offset, end),
        serviceUuid: Hm10Constants.serviceUuid,
        characteristicUuid: Hm10Constants.characteristicUuid,
      );
      if (end < bytes.length) {
        await Future<void>.delayed(Hm10Constants.interChunkDelay);
      }
    }
  }

  void _handleNotification(List<int> bytes) {
    if (!_connected) return;
    for (final line in _assembler.addBytes(bytes)) {
      _lines.add(line);
    }
  }

  void _handleDisconnected([Object? error]) {
    if (!_connected && _deviceId == null) return;
    _connected = false;
    _assembler.reset();
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    if (!_disposed) _states.add(TransportState.disconnected);
  }

  Future<void> _disconnectSubscriptions() async {
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notificationSubscription = null;
    _connectionSubscription = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final id = _deviceId;
    _connected = false;
    await _disconnectSubscriptions();
    if (id != null) await gateway.disconnect(id);
    await _states.close();
    await _lines.close();
  }
}
