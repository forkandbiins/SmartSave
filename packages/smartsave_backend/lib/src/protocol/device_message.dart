import '../models/denomination.dart';

/// Why a received protocol line could not be decoded.
enum MalformedReason {
  /// No content was supplied.
  empty,
  /// The line has no valid message token.
  unknownToken,
  /// An argument has invalid syntax.
  badArgument,
  /// An argument is outside its allowed range.
  outOfRange,
  /// A coin denomination is unsupported.
  invalidDenomination,
}

/// A decoded line sent by the bank.
sealed class DeviceMessage {
  const DeviceMessage();
}

/// The bank's protocol version.
final class ProtoMessage extends DeviceMessage {
  /// Creates a protocol-version message.
  const ProtoMessage(this.version);
  /// Reported protocol version.
  final int version;
}

/// Authentication status reported by the bank.
final class AuthStatusMessage extends DeviceMessage {
  /// Creates an authentication-status message.
  const AuthStatusMessage(this.reply);
  /// Reported authentication status.
  final AuthReply reply;
}

/// Authentication replies.
enum AuthReply {
  /// No PIN has been configured.
  newDevice,
  /// Authentication is required.
  required,
  /// Authentication succeeded.
  ok,
  /// Authentication failed.
  fail,
  /// Authentication is temporarily locked out.
  wait,
}

/// A coin notification or replay.
final class CoinMessage extends DeviceMessage {
  /// Creates a coin message.
  const CoinMessage(this.denomination, this.seq);
  /// Coin denomination.
  final Denomination denomination;
  /// Coin sequence number.
  final int seq;
}

/// The authoritative bank total.
final class TotalMessage extends DeviceMessage {
  /// Creates a total message.
  const TotalMessage(this.total);
  /// Authoritative balance in pesos.
  final int total;
}

/// The bank lock state.
final class LockMessage extends DeviceMessage {
  /// Creates a lock-state message.
  const LockMessage(this.locked);
  /// Whether the bank is locked.
  final bool locked;
}

/// The latest bank sequence number.
final class SeqMessage extends DeviceMessage {
  /// Creates a sequence message.
  const SeqMessage(this.seq);
  /// Latest bank sequence number.
  final int seq;
}

/// Marks the end of a synchronization response.
final class SyncEndMessage extends DeviceMessage {
  /// Creates a synchronization-end message.
  const SyncEndMessage();
}

/// A ping response.
final class PongMessage extends DeviceMessage {
  /// Creates a ping response.
  const PongMessage();
}

/// An error reported by the bank.
final class ErrorMessage extends DeviceMessage {
  /// Creates an error message.
  const ErrorMessage(this.reply);
  /// Reported error category.
  final ErrorReply reply;
}

/// Bank protocol error replies.
enum ErrorReply {
  /// The command is not recognized.
  unknownCommand,
  /// The command format is invalid.
  badFormat,
  /// The amount is invalid.
  badAmount,
}

/// A line that is not a valid bank message.
final class MalformedMessage extends DeviceMessage {
  /// Creates a malformed-message result.
  const MalformedMessage(this.raw, this.reason);
  /// Trimmed source line.
  final String raw;
  /// Why decoding failed.
  final MalformedReason reason;
}
