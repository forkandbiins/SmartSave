import 'dart:async';
import 'dart:math';

import '../../config/protocol_limits.dart';
import '../../models/denomination.dart';
import '../../util/clock.dart';
import 'simulator_profile.dart';

/// A deterministic Dart port of the Arduino SmartSave stub.
final class FakeDeviceSimulator {
  /// Creates a simulator with [profile] and injected time/randomness.
  FakeDeviceSimulator(
    this.clock,
    this.random,
    this.profile,
  ) {
    _pinSet = profile.pinSet;
    _pin = profile.pin;
    _total = profile.total;
    _seq = profile.seq;
    _acked = profile.acked;
    _pending.addAll(profile.pending);
    _locked = true;
  }

  /// Clock used for lockout and auto-relock timing.
  final Clock clock;
  /// Random source retained for simulator parity and controls.
  final Random random;
  /// Initial profile.
  final SimulatorProfile profile;
  final StreamController<String> _output =
      StreamController<String>.broadcast(sync: true);
  final Map<int, Denomination> _pending = <int, Denomination>{};
  bool _pinSet = false;
  String _pin = '';
  int _total = 0;
  int _seq = 0;
  int _acked = 0;
  bool _locked = true;
  DateTime? _unlockedAt;
  int _failCount = 0;
  DateTime? _lockoutUntil;

  /// Complete emitted protocol lines.
  Stream<String> get output => _output.stream;
  /// Current balance.
  int get total => _total;
  /// Latest sequence number.
  int get seq => _seq;
  /// Highest acknowledged sequence.
  int get acked => _acked;
  /// Whether the bank is locked.
  bool get locked => _locked;
  /// Whether a PIN is configured.
  bool get pinSet => _pinSet;

  /// Receives one protocol line.
  void receiveLine(String line, {bool fromUsb = false}) {
    final normalized = line.replaceAll('\r', '');
    if (normalized.isEmpty || normalized.length > 23) return;
    final separator = normalized.indexOf(':');
    final command =
        separator < 0 ? normalized : normalized.substring(0, separator);
    final argument =
        separator < 0 ? '' : normalized.substring(separator + 1);

    switch (command) {
      case 'HELLO':
        _emit('PROTO:1');
        _emit(_pinSet ? 'AUTH:REQ' : 'AUTH:NEW');
      case 'AUTH':
        if (_authorize(argument) != null) _emit('AUTH:OK');
      case 'SETPIN':
        _setPin(argument);
      case 'SYNC':
        _emit('TOTAL:$_total');
        _emit('LOCK:${_locked ? 1 : 0}');
        _emit('SEQ:$_seq');
        _replayPending();
        _emit('SYNC:END');
      case 'ACK':
        final value = _parseU32(argument);
        if (value != null && value <= ProtocolLimits.maxSeq) _handleAck(value);
      case 'LOCK':
        _setLock(true);
        _emit('LOCK:1');
      case 'UNLOCK':
        final rest = _authorize(argument);
        if (rest == null) return;
        final amount = _parseU32(rest);
        if (amount == null || amount == 0 || amount > _total) {
          _emit('ERR:AMT');
          return;
        }
        _total -= amount;
        _setLock(false);
        _emit('TOTAL:$_total');
        _emit('LOCK:0');
      case 'ADJ':
        final rest = _authorize(argument);
        if (rest == null) return;
        final amount = _parseU32(rest);
        if (amount == null || amount > ProtocolLimits.maxTotal) {
          _emit('ERR:AMT');
          return;
        }
        _total = amount;
        _emit('TOTAL:$_total');
      case 'PING':
        _emit('PONG');
      case 'SIM':
        if (fromUsb) {
          final value = _parseU32(argument);
          if (value != null) dropCoin(value);
        } else {
          _emit('ERR:CMD');
        }
      case 'FACTORY':
        if (fromUsb) {
          factoryReset();
        } else {
          _emit('ERR:CMD');
        }
      default:
        _emit('ERR:CMD');
    }
  }

  /// Evaluates time-dependent lockout and auto-relock behavior.
  void tick() {
    final now = clock.now();
    if (_lockoutUntil != null && !now.isBefore(_lockoutUntil!)) {
      _lockoutUntil = null;
      _failCount = 0;
    }
    if (!_locked &&
        _unlockedAt != null &&
        !now.isBefore(_unlockedAt!.add(ProtocolLimits.autoRelockDuration))) {
      _setLock(true);
      _emit('LOCK:1');
    }
  }

  /// Drops a simulated coin using the firmware's coin handler.
  void dropCoin(int denomination) {
    final coin = Denomination.tryFromValue(denomination);
    if (coin == null) return;
    _seq = (_seq + 1) & ProtocolLimits.maxSeq;
    _pending[_seq] = coin;
    _total += denomination;
    if (_total > ProtocolLimits.maxTotal) _total = ProtocolLimits.maxTotal;
    _emit('COIN:$denomination,$_seq');
    _emit('TOTAL:$_total');
  }

  /// Resets persisted state and locks the bank.
  void factoryReset() {
    _pinSet = false;
    _pin = '';
    _total = 0;
    _seq = 0;
    _acked = 0;
    _pending.clear();
    _locked = true;
    _unlockedAt = null;
    _failCount = 0;
    _lockoutUntil = null;
  }

  /// Seeds selected persisted fields for boundary tests.
  void seedStateForTest({int? seq, int? acked, int? total}) {
    if (seq != null) _seq = seq & ProtocolLimits.maxSeq;
    if (acked != null) _acked = acked & ProtocolLimits.maxSeq;
    if (total != null) _total = total.clamp(0, ProtocolLimits.maxTotal);
  }

  /// Closes the output stream.
  Future<void> dispose() => _output.close();

  String? _authorize(String argument) {
    if (!_pinSet) {
      _emit('AUTH:NEW');
      return null;
    }
    final split = argument.split(',');
    if (split.isEmpty || !_validPin(split.first)) {
      _emit('ERR:FMT');
      return null;
    }
    final now = clock.now();
    if (_lockoutUntil != null && now.isBefore(_lockoutUntil!)) {
      _emit('AUTH:WAIT');
      return null;
    }
    if (split.first != _pin) {
      _failCount++;
      if (_failCount >= 3) {
        _lockoutUntil = now.add(ProtocolLimits.lockoutDuration);
      }
      _emit('AUTH:FAIL');
      return null;
    }
    _failCount = 0;
    return split.length == 1 ? '' : split.sublist(1).join(',');
  }

  void _setPin(String argument) {
    if (!_pinSet) {
      if (!_validPin(argument) || argument.contains(',')) {
        _emit('ERR:FMT');
        return;
      }
      _pin = argument;
      _pinSet = true;
      _emit('AUTH:OK');
      return;
    }
    final rest = _authorize(argument);
    if (rest == null) return;
    if (!_validPin(rest) || argument.split(',').length != 2) {
      _emit('ERR:FMT');
      return;
    }
    _pin = rest;
    _emit('AUTH:OK');
  }

  void _handleAck(int value) {
    final newly = (value - _acked) & ProtocolLimits.maxSeq;
    final outstanding = (_seq - _acked) & ProtocolLimits.maxSeq;
    if (newly > 0 && newly <= outstanding) {
      _acked = value;
      _pending.removeWhere((key, _) => _isAtOrBefore(key, value));
    }
  }

  bool _isAtOrBefore(int value, int boundary) {
    final distance = (boundary - value) & ProtocolLimits.maxSeq;
    return distance < 0x8000;
  }

  void _replayPending() {
    final unacked = (_seq - _acked) & ProtocolLimits.maxSeq;
    final count = min(unacked, ProtocolLimits.replayBufferSize);
    for (var i = count; i > 0; i--) {
      final sequence = (_seq - i + 1) & ProtocolLimits.maxSeq;
      final denomination = _pending[sequence];
      if (denomination != null) _emit('COIN:${denomination.value},$sequence');
    }
  }

  void _setLock(bool lock) {
    _locked = lock;
    if (!lock) _unlockedAt = clock.now();
  }

  void _emit(String line) {
    if (line.length <= ProtocolLimits.maxOutboundLineChars) {
      _output.add(line);
    }
  }

  static bool _validPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

  static int? _parseU32(String value) {
    if (!RegExp(r'^\d+$').hasMatch(value)) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed <= 999999 ? parsed : null;
  }
}
