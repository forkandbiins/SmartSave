import '../../config/protocol_limits.dart';

/// HM-10 transport constants.
///
/// FFE0/FFE1 and the advertised names are assumptions based on common HM-10
/// modules; they must be verified on the real module because clones vary.
abstract final class Hm10Constants {
  /// Typical HM-10 service UUID.
  static const serviceUuid = 'FFE0';

  /// Typical HM-10 characteristic UUID.
  static const characteristicUuid = 'FFE1';

  /// Maximum BLE write payload.
  static const writeChunkSize = ProtocolLimits.maxBleWriteBytes;

  /// Delay between BLE write chunks.
  static const interChunkDelay = Duration(milliseconds: 20);

  /// Maximum connection attempt duration.
  static const connectTimeout = Duration(seconds: 10);
}
