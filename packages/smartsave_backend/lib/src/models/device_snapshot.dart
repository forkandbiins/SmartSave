import 'denomination.dart';

/// A coin replayed by the device during synchronization.
final class ReplayedCoin {
  /// Creates a replayed coin.
  const ReplayedCoin({required this.denomination, required this.seq});

  /// Coin denomination.
  final Denomination denomination;
  /// Device sequence number.
  final int seq;

  @override
  bool operator ==(Object other) =>
      other is ReplayedCoin &&
      denomination == other.denomination &&
      seq == other.seq;

  @override
  int get hashCode => Object.hash(denomination, seq);

  @override
  String toString() => 'ReplayedCoin($denomination, $seq)';
}

/// A point-in-time snapshot received from the device.
final class DeviceSnapshot {
  /// Creates a device snapshot.
  DeviceSnapshot({
    required this.total,
    required this.locked,
    required this.deviceSeq,
    required List<ReplayedCoin> replayedCoins,
    required this.receivedAt,
  }) : replayedCoins = List.unmodifiable(replayedCoins);

  /// Authoritative device balance.
  final int total;
  /// Whether the device is locked.
  final bool locked;
  /// Latest device sequence number.
  final int deviceSeq;
  /// Coins replayed by the device.
  final List<ReplayedCoin> replayedCoins;
  /// Time the snapshot was received.
  final DateTime receivedAt;

  /// Returns a copy with selected values replaced.
  DeviceSnapshot copyWith({
    int? total,
    bool? locked,
    int? deviceSeq,
    List<ReplayedCoin>? replayedCoins,
    DateTime? receivedAt,
  }) =>
      DeviceSnapshot(
        total: total ?? this.total,
        locked: locked ?? this.locked,
        deviceSeq: deviceSeq ?? this.deviceSeq,
        replayedCoins: replayedCoins ?? this.replayedCoins,
        receivedAt: receivedAt ?? this.receivedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is DeviceSnapshot &&
      total == other.total &&
      locked == other.locked &&
      deviceSeq == other.deviceSeq &&
      receivedAt == other.receivedAt &&
      _coinsEqual(replayedCoins, other.replayedCoins);

  @override
  int get hashCode =>
      Object.hash(total, locked, deviceSeq, Object.hashAll(replayedCoins), receivedAt);

  @override
  String toString() => 'DeviceSnapshot(total: $total, deviceSeq: $deviceSeq)';
}

bool _coinsEqual(List<ReplayedCoin> first, List<ReplayedCoin> second) =>
    first.length == second.length &&
    Iterable<int>.generate(first.length).every((index) => first[index] == second[index]);
