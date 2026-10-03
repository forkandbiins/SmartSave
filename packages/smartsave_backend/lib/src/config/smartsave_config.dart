import 'protocol_limits.dart';
import 'smartsave_mode.dart';

/// Names of built-in simulator profiles.
enum SimulatorProfileName {
  /// An empty bank with default state.
  fresh,
  /// A bank pre-populated with demonstration activity.
  demo,
}

/// Immutable configuration for a SmartSave backend instance.
final class SmartSaveConfig {
  /// Creates a mock configuration using [profile].
  SmartSaveConfig.mock({SimulatorProfileName profile = SimulatorProfileName.fresh})
      : this(mode: SmartSaveMode.mock, simulatorProfile: profile);

  /// Creates a BLE configuration.
  SmartSaveConfig.ble()
      : this(
          mode: SmartSaveMode.ble,
          simulatorProfile: SimulatorProfileName.fresh,
        );

  /// Creates a configuration with explicit values.
  SmartSaveConfig({
    required this.mode,
    required this.simulatorProfile,
    this.bleServiceUuid = 'FFE0',
    this.bleCharacteristicUuid = 'FFE1',
    List<String> scanNamePrefixes = const <String>['SmartSave', 'HMSoft'],
    this.commandTimeout = const Duration(seconds: 3),
    this.syncTimeout = const Duration(seconds: 6),
    this.lockoutDuration = ProtocolLimits.lockoutDuration,
    this.autoSyncOnConnect = true,
    this.autoReconnect = true,
  }) : scanNamePrefixes = List.unmodifiable(scanNamePrefixes);

  /// Creates a configuration from `SMARTSAVE_MODE`.
  factory SmartSaveConfig.fromEnvironment() {
    const mode = String.fromEnvironment(
      'SMARTSAVE_MODE',
      defaultValue: 'mock',
    );
    return mode == 'ble' ? SmartSaveConfig.ble() : SmartSaveConfig.mock();
  }

  /// Whether the backend is in mock or BLE mode.
  final SmartSaveMode mode;
  /// Simulator data profile.
  final SimulatorProfileName simulatorProfile;
  /// BLE service UUID.
  final String bleServiceUuid;
  /// BLE characteristic UUID.
  final String bleCharacteristicUuid;
  /// Advertised-name prefixes considered during scanning.
  final List<String> scanNamePrefixes;
  /// Timeout for an individual command.
  final Duration commandTimeout;
  /// Timeout for synchronization.
  final Duration syncTimeout;
  /// Duration used when the device reports a lockout.
  final Duration lockoutDuration;
  /// Whether to synchronize after connecting.
  final bool autoSyncOnConnect;
  /// Whether to reconnect after an unexpected disconnect.
  final bool autoReconnect;

  /// Returns a copy with selected values replaced.
  SmartSaveConfig copyWith({
    SmartSaveMode? mode,
    SimulatorProfileName? simulatorProfile,
    String? bleServiceUuid,
    String? bleCharacteristicUuid,
    List<String>? scanNamePrefixes,
    Duration? commandTimeout,
    Duration? syncTimeout,
    Duration? lockoutDuration,
    bool? autoSyncOnConnect,
    bool? autoReconnect,
  }) {
    return SmartSaveConfig(
      mode: mode ?? this.mode,
      simulatorProfile: simulatorProfile ?? this.simulatorProfile,
      bleServiceUuid: bleServiceUuid ?? this.bleServiceUuid,
      bleCharacteristicUuid:
          bleCharacteristicUuid ?? this.bleCharacteristicUuid,
      scanNamePrefixes: scanNamePrefixes ?? this.scanNamePrefixes,
      commandTimeout: commandTimeout ?? this.commandTimeout,
      syncTimeout: syncTimeout ?? this.syncTimeout,
      lockoutDuration: lockoutDuration ?? this.lockoutDuration,
      autoSyncOnConnect: autoSyncOnConnect ?? this.autoSyncOnConnect,
      autoReconnect: autoReconnect ?? this.autoReconnect,
    );
  }
}
