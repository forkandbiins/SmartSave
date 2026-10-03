import '../models/denomination.dart';
import '../config/protocol_limits.dart';
import '../errors/smartsave_error.dart';
import 'device_message.dart';
import 'device_command.dart';

/// Decodes bank-to-app protocol lines.
final class ProtocolCodec {
  const ProtocolCodec._();

  /// Decodes [line] without throwing.
  static DeviceMessage decode(String line) {
    final raw = line.trim();
    if (raw.isEmpty) return const MalformedMessage('', MalformedReason.empty);
    if (raw == 'PONG') return const PongMessage();
    if (raw == 'SYNC:END') return const SyncEndMessage();

    final separator = raw.indexOf(':');
    final token = separator < 0 ? raw : raw.substring(0, separator);
    final argument = separator < 0 ? null : raw.substring(separator + 1);
    if (!_knownTokens.contains(token)) {
      return MalformedMessage(raw, MalformedReason.unknownToken);
    }

    if (argument == null) {
      return MalformedMessage(raw, MalformedReason.badArgument);
    }

    switch (token) {
      case 'PROTO':
        return _integerMessage(raw, argument, (value) => ProtoMessage(value));
      case 'AUTH':
        return _auth(raw, argument);
      case 'COIN':
        return _coin(raw, argument);
      case 'TOTAL':
        return _boundedInteger(
          raw,
          argument,
          0,
          99999,
          (value) => TotalMessage(value),
        );
      case 'LOCK':
        if (argument == '0') return const LockMessage(false);
        if (argument == '1') return const LockMessage(true);
        return MalformedMessage(
          raw,
          _isInteger(argument)
              ? MalformedReason.outOfRange
              : MalformedReason.badArgument,
        );
      case 'SEQ':
        return _boundedInteger(
          raw,
          argument,
          0,
          65535,
          (value) => SeqMessage(value),
        );
      case 'ERR':
        switch (argument) {
          case 'CMD':
            return const ErrorMessage(ErrorReply.unknownCommand);
          case 'FMT':
            return const ErrorMessage(ErrorReply.badFormat);
          case 'AMT':
            return const ErrorMessage(ErrorReply.badAmount);
          default:
            return MalformedMessage(raw, MalformedReason.badArgument);
        }
    }
    return MalformedMessage(raw, MalformedReason.unknownToken);
  }

  /// Encodes an app-to-bank command without a trailing newline.
  static String encode(DeviceCommand command) {
    final line = switch (command) {
      HelloCommand() => 'HELLO',
      LoginCommand(:final pin) => 'AUTH:$pin',
      SetInitialPinCommand(:final pin) => 'SETPIN:$pin',
      ChangePinCommand(:final oldPin, :final newPin) =>
        'SETPIN:$oldPin,$newPin',
      SyncCommand() => 'SYNC',
      AckCommand(:final seq) => 'ACK:$seq',
      LockCommand() => 'LOCK',
      UnlockCommand(:final pin, :final amount) => 'UNLOCK:$pin,$amount',
      AdjustCommand(:final pin, :final newTotal) => 'ADJ:$pin,$newTotal',
      PingCommand() => 'PING',
    };

    switch (command) {
      case LoginCommand(:final pin):
        _validatePin(pin);
      case SetInitialPinCommand(:final pin):
        _validatePin(pin);
      case ChangePinCommand(:final oldPin, :final newPin):
        _validatePin(oldPin);
        _validatePin(newPin);
      case UnlockCommand(:final pin, :final amount):
        _validatePin(pin);
        _validateRange(amount, 1, ProtocolLimits.maxTotal);
      case AdjustCommand(:final pin, :final newTotal):
        _validatePin(pin);
        _validateRange(newTotal, 0, ProtocolLimits.maxTotal);
      case AckCommand(:final seq):
        _validateRange(seq, 0, ProtocolLimits.maxSeq);
      default:
        break;
    }
    if (line.length > ProtocolLimits.maxOutboundLineChars) {
      throw InvalidArgumentError();
    }
    return line;
  }

  static void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw InvalidArgumentError();
  }

  static void _validateRange(int value, int minimum, int maximum) {
    if (value < minimum || value > maximum) throw InvalidArgumentError();
  }

  static const Set<String> _knownTokens = <String>{
    'PROTO',
    'AUTH',
    'COIN',
    'TOTAL',
    'LOCK',
    'SEQ',
    'ERR',
  };

  static DeviceMessage _auth(String raw, String argument) {
    switch (argument) {
      case 'NEW':
        return const AuthStatusMessage(AuthReply.newDevice);
      case 'REQ':
        return const AuthStatusMessage(AuthReply.required);
      case 'OK':
        return const AuthStatusMessage(AuthReply.ok);
      case 'FAIL':
        return const AuthStatusMessage(AuthReply.fail);
      case 'WAIT':
        return const AuthStatusMessage(AuthReply.wait);
      default:
        return MalformedMessage(raw, MalformedReason.unknownToken);
    }
  }

  static DeviceMessage _coin(String raw, String argument) {
    final parts = argument.split(',');
    if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
      return MalformedMessage(raw, MalformedReason.badArgument);
    }
    final denominationValue =
        _isDecimal(parts[0]) ? int.tryParse(parts[0]) : null;
    final seq = _isInteger(parts[1]) ? int.tryParse(parts[1]) : null;
    if (denominationValue == null || seq == null) {
      return MalformedMessage(raw, MalformedReason.badArgument);
    }
    final denomination = Denomination.tryFromValue(denominationValue);
    if (denomination == null) {
      return MalformedMessage(raw, MalformedReason.invalidDenomination);
    }
    if (seq < 0 || seq > 65535) {
      return MalformedMessage(raw, MalformedReason.outOfRange);
    }
    return CoinMessage(denomination, seq);
  }

  static DeviceMessage _integerMessage(
    String raw,
    String argument,
    DeviceMessage Function(int value) create,
  ) {
    final value = _isInteger(argument) ? int.tryParse(argument) : null;
    return value == null
        ? MalformedMessage(raw, MalformedReason.badArgument)
        : create(value);
  }

  static DeviceMessage _boundedInteger(
    String raw,
    String argument,
    int minimum,
    int maximum,
    DeviceMessage Function(int value) create,
  ) {
    final value = _isInteger(argument) ? int.tryParse(argument) : null;
    if (value == null) return MalformedMessage(raw, MalformedReason.badArgument);
    if (value < minimum || value > maximum) {
      return MalformedMessage(raw, MalformedReason.outOfRange);
    }
    return create(value);
  }

  static bool _isInteger(String value) => RegExp(r'^-?\d+$').hasMatch(value);

  static bool _isDecimal(String value) => RegExp(r'^\d+$').hasMatch(value);
}
