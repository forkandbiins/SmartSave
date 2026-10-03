import '../../config/smartsave_config.dart';
import '../../models/denomination.dart';

/// Initial state used by a fake bank simulator.
final class SimulatorProfile {
  /// Creates a simulator profile.
  const SimulatorProfile({
    required this.pinSet,
    required this.pin,
    required this.total,
    required this.seq,
    required this.acked,
    required this.pending,
  });

  /// A fresh bank profile.
  static const SimulatorProfile fresh = SimulatorProfile(
    pinSet: false,
    pin: '',
    total: 0,
    seq: 0,
    acked: 0,
    pending: <int, Denomination>{},
  );

  /// A demonstration bank profile.
  static const SimulatorProfile demo = SimulatorProfile(
    pinSet: true,
    pin: '1234',
    total: 1250,
    seq: 12,
    acked: 8,
    pending: <int, Denomination>{
      9: Denomination.php5,
      10: Denomination.php10,
      11: Denomination.php1,
      12: Denomination.php20,
    },
  );

  /// Creates a profile from its public profile name.
  factory SimulatorProfile.fromName(SimulatorProfileName name) =>
      name == SimulatorProfileName.demo ? demo : fresh;

  /// Whether a PIN is configured.
  final bool pinSet;
  /// Configured PIN.
  final String pin;
  /// Initial balance.
  final int total;
  /// Latest uint16 sequence.
  final int seq;
  /// Highest cumulatively acknowledged sequence.
  final int acked;
  /// Pending coin denominations keyed by sequence.
  final Map<int, Denomination> pending;
}
