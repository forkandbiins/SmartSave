import 'dart:async';

import '../config/protocol_limits.dart';
import '../config/smartsave_config.dart';
import '../diagnostics/logger.dart';
import '../errors/smartsave_error.dart';
import '../models/device_snapshot.dart';
import '../protocol/device_command.dart';
import '../protocol/device_message.dart';
import '../protocol/protocol_codec.dart';
import '../transport/device_transport.dart';
import '../util/clock.dart';
import 'command_queue.dart';
import 'device_client.dart';
import 'device_event.dart';

/// Protocol implementation of [DeviceClient].
final class ProtocolDeviceClient implements DeviceClient {
  /// Creates a protocol client over [transport].
  ProtocolDeviceClient(
    this.transport,
    this.codec,
    this.config,
    this.clock,
    this.logger, {
    this.onTraffic,
  }) {
    _lineSubscription = transport.lines.listen(_onLine);
    _stateSubscription = transport.state.listen(_onState);
  }

  /// Underlying line transport.
  final DeviceTransport transport;
  /// Protocol codec used for wire conversion.
  final Object? codec;
  /// Client timing configuration.
  final SmartSaveConfig config;
  /// Injected clock.
  final Clock clock;
  /// Diagnostic logger.
  final SmartSaveLogger logger;
  /// Optional raw traffic callback.
  final void Function(String direction, String line)? onTraffic;
  final StreamController<DeviceEvent> _events =
      StreamController<DeviceEvent>.broadcast(sync: true);
  final CommandQueue _queue = CommandQueue();
  StreamSubscription<String>? _lineSubscription;
  StreamSubscription<TransportState>? _stateSubscription;
  _Pending? _pending;
  bool _disposed = false;

  @override
  Stream<DeviceEvent> get events => _events.stream;

  @override
  Future<HandshakeResult> handshake() => _queue.add(_handshake);

  @override
  Future<void> authenticate(String pin) =>
      _queue.add(() => _simple(LoginCommand(pin)));

  @override
  Future<void> setInitialPin(String pin) =>
      _queue.add(() => _simple(SetInitialPinCommand(pin)));

  @override
  Future<void> changePin(String oldPin, String newPin) =>
      _queue.add(() => _simple(ChangePinCommand(oldPin, newPin)));

  @override
  Future<DeviceSnapshot> sync() => _queue.add(_sync);

  @override
  void ack(int seq) {
    if (_disposed) return;
    _send(AckCommand(seq));
  }

  @override
  Future<void> lock() => _queue.add(() => _simple(const LockCommand()));

  @override
  Future<UnlockOutcome> unlock(String pin, int amount) =>
      _queue.add(() => _unlock(pin, amount));

  @override
  Future<int> adjustTotal(String pin, int newTotal) =>
      _queue.add(() => _adjust(pin, newTotal));

  @override
  Future<void> ping() => _queue.add(() => _simple(const PingCommand()));

  /// Releases subscriptions and event resources.
  Future<void> dispose() async {
    _disposed = true;
    _failPending(const ConnectionError.connectionLost());
    _queue.clear(const ConnectionError.connectionLost());
    await _lineSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _events.close();
  }

  Future<HandshakeResult> _handshake() async {
    var attempts = 0;
    while (true) {
      try {
        var version = -1;
        AuthStatusMessage? auth;
        return await _waitFor<HandshakeResult>(
          HelloCommand(),
          (message) {
            if (message is ProtoMessage) {
              version = message.version;
              return false;
            }
            if (message is AuthStatusMessage && version >= 0) {
              auth = message;
              return true;
            }
            return false;
          },
          config.commandTimeout,
          retryOnTimeout: false,
          allowPinNotSet: true,
          result: () {
            if (version != ProtocolLimits.protoVersion) {
              throw const ProtocolError.unsupportedVersion();
            }
            return HandshakeResult(version, auth!.reply != AuthReply.newDevice);
          },
          isSync: false,
        );
      } on ProtocolError catch (error) {
        if (error.code != SmartSaveErrorCode.commandTimeout || attempts >= 2) {
          rethrow;
        }
        attempts++;
      }
    }
  }

  Future<void> _simple(DeviceCommand command) async {
    await _waitFor<void>(
      command,
      (message) => message is AuthStatusMessage ||
          message is ErrorMessage ||
          message is PongMessage ||
          message is LockMessage,
      config.commandTimeout,
      retryOnTimeout: false,
      operation: command,
    );
  }

  Future<UnlockOutcome> _unlock(String pin, int amount) async {
    var newTotal = 0;
    await _waitFor<void>(
      UnlockCommand(pin, amount),
      (message) {
        if (message is TotalMessage) {
          newTotal = message.total;
          return false;
        }
        return message is LockMessage && !message.locked ||
            message is AuthStatusMessage ||
            message is ErrorMessage;
      },
      config.commandTimeout,
      retryOnTimeout: false,
      operation: UnlockCommand(pin, amount),
    );
    return UnlockOutcome(newTotal);
  }

  Future<int> _adjust(String pin, int newTotal) async {
    final result = await _waitFor<TotalMessage>(
      AdjustCommand(pin, newTotal),
      (message) => message is TotalMessage ||
          message is AuthStatusMessage ||
          message is ErrorMessage,
      config.commandTimeout,
      retryOnTimeout: false,
      operation: AdjustCommand(pin, newTotal),
    );
    return result.total;
  }

  Future<DeviceSnapshot> _sync() async {
    var attempt = 0;
    while (true) {
      try {
        var total = 0;
        var locked = true;
        var seq = 0;
        final replayed = <ReplayedCoin>[];
        return await _waitFor<DeviceSnapshot>(
          const SyncCommand(),
          (message) {
            if (message is TotalMessage) {
              total = message.total;
            } else if (message is LockMessage) {
              locked = message.locked;
            } else if (message is SeqMessage) {
              seq = message.seq;
            } else if (message is CoinMessage) {
              replayed.add(ReplayedCoin(
                denomination: message.denomination,
                seq: message.seq,
              ));
            } else if (message is SyncEndMessage) {
              return true;
            }
            return false;
          },
          config.syncTimeout,
          retryOnTimeout: false,
          operation: const SyncCommand(),
          result: () => DeviceSnapshot(
            total: total,
            locked: locked,
            deviceSeq: seq,
            replayedCoins: replayed,
            receivedAt: clock.now(),
          ),
          isSync: true,
        );
      } on ProtocolError catch (error) {
        if (error.code != SmartSaveErrorCode.commandTimeout || attempt >= 1) {
          rethrow;
        }
        attempt++;
      }
    }
  }

  Future<T> _waitFor<T>(
    DeviceCommand? command,
    bool Function(DeviceMessage message) matches,
    Duration timeout, {
    required bool retryOnTimeout,
    DeviceCommand? operation,
    T Function()? result,
    bool allowPinNotSet = false,
    bool isSync = false,
  }) {
    final completer = Completer<T>();
    completer.future.ignore();
    late final _Pending pending;
    pending = _Pending(
      completer: completer,
      matches: matches,
      result: result,
      allowPinNotSet: allowPinNotSet,
      isSync: isSync,
      onMessage: (message) => _handlePendingMessage(message, pending),
    );
    _pending = pending;
    if (command != null) _send(command);
    pending.timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _pending = null;
        completer.completeError(const ProtocolError.commandTimeout());
      }
    });
    return completer.future;
  }

  void _handlePendingMessage(DeviceMessage message, _Pending pending) {
    if (pending.completer.isCompleted) return;
    if (message is AuthStatusMessage || message is ErrorMessage) {
      final error = _errorFor(message);
      if (error != null &&
          !(message is AuthStatusMessage &&
              message.reply == AuthReply.newDevice &&
              pending.allowPinNotSet)) {
        _completeError(pending, error);
        return;
      }
    }
    if (!pending.matches(message)) return;
    if (message is ProtoMessage && pending.completer.isCompleted) return;
    try {
      _completeSuccess(pending, pending.result?.call() ?? _castResult(message));
    } on SmartSaveError catch (error) {
      _completeError(pending, error);
    }
  }

  T _castResult<T>(DeviceMessage message) {
    if (message is TotalMessage && T == TotalMessage) return message as T;
    if (message is LockMessage) return null as T;
    if (message is AuthStatusMessage) return null as T;
    if (message is PongMessage) return null as T;
    if (message is SyncEndMessage && T == DeviceSnapshot) {
      throw StateError('sync result was not provided');
    }
    return message as T;
  }

  SmartSaveError? _errorFor(DeviceMessage message) => switch (message) {
        AuthStatusMessage(:final reply) when reply == AuthReply.fail =>
          const AuthError.wrongPin(),
        AuthStatusMessage(:final reply) when reply == AuthReply.wait =>
          AuthError.lockedOut(clock.now().add(config.lockoutDuration)),
        AuthStatusMessage(:final reply) when reply == AuthReply.newDevice =>
          const AuthError.pinNotSet(),
        ErrorMessage(:final reply) when reply == ErrorReply.badFormat =>
          const DeviceError.badFormat(),
        ErrorMessage(:final reply) when reply == ErrorReply.badAmount =>
          const DeviceError.invalidAmount(),
        _ => null,
      };

  void _completeSuccess(_Pending pending, Object? value) {
    pending.timer?.cancel();
    if (identical(_pending, pending)) _pending = null;
    pending.completer.complete(value);
  }

  void _completeError(_Pending pending, SmartSaveError error) {
    pending.timer?.cancel();
    if (identical(_pending, pending)) _pending = null;
    scheduleMicrotask(() {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    });
  }

  void _onLine(String line) {
    _traffic('rx', line);
    final message = ProtocolCodec.decode(line);
    if (message is MalformedMessage) {
      _events.add(MalformedLine(message.raw));
      _pending?.onMessage(message);
      return;
    }
    if (message is AuthStatusMessage && message.reply == AuthReply.newDevice) {
      _events.add(const PinNotSetDetected());
    }
    final pending = _pending;
    if (pending != null) {
      if (pending.isSync) {
        pending.onMessage(message);
        return;
      }
      if (message is LockMessage && message.locked && pending.isLock) {
        pending.onMessage(message);
        return;
      }
      if (message is TotalMessage && pending.isUnlock) {
        pending.onMessage(message);
        return;
      }
      if (pending.matches(message) ||
          message is AuthStatusMessage ||
          message is ErrorMessage) {
        pending.onMessage(message);
        return;
      }
    }
    _emitEvent(message);
  }

  void _emitEvent(DeviceMessage message) {
    switch (message) {
      case CoinMessage(:final denomination, :final seq):
        _events.add(CoinDetected(denomination, seq));
      case TotalMessage(:final total):
        _events.add(TotalReported(total));
      case LockMessage(:final locked):
        _events.add(LockChanged(locked, unsolicited: true));
      case AuthStatusMessage(reply: AuthReply.newDevice):
        break;
      default:
        break;
    }
  }

  void _onState(TransportState state) {
    if (state == TransportState.disconnected && !_disposed) {
      _events.add(const LinkLost());
      _failPending(const ConnectionError.connectionLost());
      _queue.clear(const ConnectionError.connectionLost());
    }
  }

  void _failPending(SmartSaveError error) {
    final pending = _pending;
    if (pending == null) return;
    pending.timer?.cancel();
    _pending = null;
    if (!pending.completer.isCompleted) pending.completer.completeError(error);
  }

  void _send(DeviceCommand command) {
    final line = ProtocolCodec.encode(command);
    _traffic('tx', line);
    unawaited(Future<void>.microtask(() => transport.writeLine(line)));
  }

  void _traffic(String direction, String line) {
    final redacted = redactPin(line);
    if (direction == 'tx') {
      logger.debug(redacted);
    } else {
      logger.debug(redacted);
    }
    onTraffic?.call(direction, redacted);
  }
}

final class _Pending {
  _Pending({
    required this.completer,
    required this.matches,
    required this.onMessage,
    this.isSync = false,
    this.result,
    this.allowPinNotSet = false,
  });
  final Completer<dynamic> completer;
  final bool Function(DeviceMessage message) matches;
  final void Function(DeviceMessage message) onMessage;
  final Object? Function()? result;
  final bool allowPinNotSet;
  Timer? timer;

  final bool isSync;
  bool get isLock => matches(const LockMessage(true));
  bool get isUnlock => matches(const LockMessage(false));
}
