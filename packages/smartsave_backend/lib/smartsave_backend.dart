/// Public API for the SmartSave backend package.
library;

export 'src/application/smartsave_controller.dart' show SmartSaveController;
export 'src/backend.dart' show SmartSaveBackend;
export 'src/config/smartsave_config.dart'
    show SmartSaveConfig, SimulatorProfileName;
export 'src/config/smartsave_mode.dart' show SmartSaveMode;
export 'src/diagnostics/raw_traffic_log.dart' show RawTrafficEntry;
export 'src/errors/action_result.dart'
    show ActionResult, ActionSuccess, ActionFailure;
export 'src/errors/smartsave_error.dart'
    show
        SmartSaveErrorCode,
        SmartSaveError,
        ConnectionError,
        ProtocolError,
        InvalidArgumentError,
        AuthError,
        DeviceError,
        StorageError,
        SmartSaveStateError;
export 'src/models/auth_state.dart' show AuthState;
export 'src/models/denomination.dart' show Denomination;
export 'src/models/device_snapshot.dart'
    show ReplayedCoin, DeviceSnapshot;
export 'src/models/discovered_bank.dart' show DiscoveredBank;
export 'src/models/link_state.dart' show LinkState, SyncStatus;
export 'src/models/lock_state.dart' show LockState;
export 'src/models/savings_goal.dart' show GoalStatus, SavingsGoal;
export 'src/models/savings_statistics.dart' show SavingsStatistics;
export 'src/models/savings_summary.dart' show SavingsSummary;
export 'src/models/savings_transaction.dart'
    show TransactionType, TimeAccuracy, SavingsTransaction;
export 'src/models/smartsave_event.dart'
    show
        DeviceAnomalyKind,
        SmartSaveEvent,
        CoinReceived,
        BalanceChanged,
        LockChanged,
        AutoRelocked,
        GoalReached,
        ReconciliationApplied,
        DeviceAnomaly,
        ErrorRaised,
        LinkChanged;
export 'src/models/smartsave_state.dart' show SmartSaveState;
export 'src/models/sync_report.dart' show SyncReport;
export 'src/models/transaction_query.dart' show TransactionQuery;
export 'src/transport/ble/ble_readiness.dart'
    show BluetoothReadiness, BluetoothReadinessProvider;
export 'src/transport/mock/mock_controls.dart' show MockControls;
