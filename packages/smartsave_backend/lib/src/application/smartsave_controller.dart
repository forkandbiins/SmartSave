import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/smartsave_config.dart';
import '../device/device_client.dart';
import '../device/device_event.dart' as device;
import '../errors/action_result.dart';
import '../errors/smartsave_error.dart';
import '../models/auth_state.dart';
import '../models/discovered_bank.dart';
import '../models/link_state.dart';
import '../models/lock_state.dart';
import '../models/savings_goal.dart';
import '../models/savings_statistics.dart';
import '../models/savings_summary.dart';
import '../models/savings_transaction.dart';
import '../models/smartsave_event.dart';
import '../models/smartsave_state.dart';
import '../models/sync_report.dart';
import '../models/transaction_query.dart';
import '../repository/default_smartsave_repository.dart';
import '../repository/smartsave_repository.dart';
import '../repository/statistics.dart' as stats;
import '../transport/device_transport.dart';
import '../transport/ble/ble_readiness.dart';
import '../util/clock.dart';

/// UI-facing orchestration layer for SmartSave.
final class SmartSaveController extends ChangeNotifier {
  /// Creates a controller from the application services.
  SmartSaveController({
    required this.config,
    required this.clock,
    required this.transport,
    required this.repository,
    required this.client,
  }) {
    _state = SmartSaveState.initial(config.mode);
    _repositoryChanges = repository.changes.listen(_onRepositoryChange);
    _repositoryEvents = repository.events.listen(_events.add);
    _clientEvents = client.events.listen(_onClientEvent);
    _transportState = transport.state.listen(_onTransportState);
  }

  /// Backend configuration.
  final SmartSaveConfig config;
  /// Injected clock.
  final Clock clock;
  /// Active line transport.
  final DeviceTransport transport;
  /// Domain repository.
  final DefaultSmartSaveRepository repository;
  /// Typed device client.
  final DeviceClient client;

  late SmartSaveState _state;
  final _events = StreamController<SmartSaveEvent>.broadcast(sync: true);
  StreamSubscription<RepositorySnapshot>? _repositoryChanges;
  StreamSubscription<SmartSaveEvent>? _repositoryEvents;
  StreamSubscription<device.DeviceEvent>? _clientEvents;
  StreamSubscription<TransportState>? _transportState;
  Timer? _lockoutTimer;
  String? _pin;
  DiscoveredBank? _lastBank;
  bool _disposed = false;
  int _failedLoginAttempts = 0;

  /// Current immutable application state.
  SmartSaveState get state {
    _refreshLockout();
    return _state;
  }

  /// Domain events for the UI.
  Stream<SmartSaveEvent> get events => _events.stream;

  /// Checks Bluetooth readiness.
  Future<ActionResult<BluetoothReadiness>> ensureBluetoothReady() =>
      _safe(() async => BluetoothReadiness.ready);

  /// Scans for banks.
  Future<ActionResult<List<DiscoveredBank>>> scan() => _safe(() async {
        _setState(_state.copyWith(link: LinkState.scanning));
        final banks = <DiscoveredBank>[];
        await for (final bank in transport.scan()) {
          banks.add(bank);
        }
        _setState(_state.copyWith(link: LinkState.disconnected));
        return List.unmodifiable(banks);
      });

  /// Connects to [bank] and performs handshake/synchronization.
  Future<ActionResult<void>> connect(DiscoveredBank bank) => _safe(() async {
        _lastBank = bank;
        _setState(_state.copyWith(link: LinkState.connecting));
        await transport.connect(bank);
        _setState(_state.copyWith(link: LinkState.handshaking));
        await repository.bindDevice(bank.id);
        final handshake = await client.handshake();
        _setState(_state.copyWith(
          link: LinkState.ready,
          auth: handshake.pinSet ? AuthState.loggedOut : AuthState.pinNotSet,
        ));
        if (config.autoSyncOnConnect) {
          await sync();
        }
      });

  /// Reconnects to the most recently connected bank.
  Future<ActionResult<void>> reconnectLast() => _safe(() async {
        final bank = _lastBank;
        if (bank == null) throw const SmartSaveStateError.notConnected();
        final result = await connect(bank);
        if (result is ActionFailure<void>) throw result.error;
      });

  /// Disconnects from the bank while retaining cached domain data.
  Future<ActionResult<void>> disconnect() => _safe(() async {
        await transport.disconnect();
        _clearSession();
      });

  /// Sets the first bank PIN.
  Future<ActionResult<void>> setInitialPin(String pin) => _safe(() async {
        await client.setInitialPin(pin);
        _pin = pin;
        _setState(_state.copyWith(auth: AuthState.loggedIn));
      });

  /// Logs in with [pin].
  Future<ActionResult<void>> login(String pin) => _safe(() async {
        await client.authenticate(pin);
        _pin = pin;
        _failedLoginAttempts = 0;
        _setState(_state.copyWith(
          auth: AuthState.loggedIn,
          lockoutEndsAt: null,
        ));
      }, onError: (error) {
        if (error is AuthError && error.code == SmartSaveErrorCode.lockedOut) {
          final until = error.until;
          _setState(_state.copyWith(
            auth: AuthState.lockedOut,
            lockoutEndsAt: until,
          ));
          if (until != null) _scheduleLockoutCheck(until);
        } else if (error is AuthError &&
            error.code == SmartSaveErrorCode.wrongPin) {
          _failedLoginAttempts++;
          if (_failedLoginAttempts >= 3) {
            final until = clock.now().add(config.lockoutDuration);
            _setState(_state.copyWith(
              auth: AuthState.lockedOut,
              lockoutEndsAt: until,
            ));
            _scheduleLockoutCheck(until);
          }
        }
      });

  /// Logs out and clears the in-memory PIN.
  Future<ActionResult<void>> logout() => _safe(() async => _clearSession());

  /// Changes the PIN, using the current session PIN when [oldPin] is omitted.
  Future<ActionResult<void>> changePin(String newPin, {String? oldPin}) =>
      _safe(() async {
        _requireLogin();
        final current = oldPin ?? _pin;
        if (current == null) throw const AuthError.notAuthenticated();
        await client.changePin(current, newPin);
        _pin = newPin;
      });

  /// Synchronizes with the bank.
  Future<ActionResult<SyncReport>> sync() => _safe(() async {
        _setState(_state.copyWith(syncStatus: SyncStatus.syncing));
        try {
          final report = await repository.synchronize();
          _setState(_state.copyWith(syncStatus: SyncStatus.synced));
          return report;
        } catch (_) {
          _setState(_state.copyWith(syncStatus: SyncStatus.failed));
          rethrow;
        }
      });

  /// Creates a local goal.
  Future<ActionResult<SavingsGoal>> createGoal(String name, int targetAmount) =>
      _safe(() => repository.createGoal(name, targetAmount));

  /// Updates a local goal.
  Future<ActionResult<SavingsGoal>> updateGoal(
    String goalId, {
    String? name,
    int? targetAmount,
  }) =>
      _safe(() => repository.updateGoal(
            goalId,
            name: name,
            targetAmount: targetAmount,
          ));

  /// Cancels a local goal.
  Future<ActionResult<void>> deleteGoal(String goalId) =>
      _safe(() => repository.deleteGoal(goalId));

  /// Allocates balance to a goal.
  Future<ActionResult<SavingsGoal>> allocateToGoal(String goalId, int amount) =>
      _safe(() => repository.allocateToGoal(goalId, amount));

  /// Releases balance from a goal.
  Future<ActionResult<SavingsGoal>> releaseFromGoal(String goalId, int amount) =>
      _safe(() => repository.releaseFromGoal(goalId, amount));

  /// Redeems a goal using [pin].
  Future<ActionResult<void>> redeemGoal(String goalId, String pin) =>
      _safe(() async {
        _requireLogin();
        await repository.redeemGoal(goalId, pin);
        _setState(_state.copyWith(lock: LockState.unlocked));
      });

  /// Locks the bank.
  Future<ActionResult<void>> lockBank() => _safe(() async {
        await client.lock();
        _setState(_state.copyWith(lock: LockState.locked));
      });

  /// Adjusts the authoritative balance using [pin].
  Future<ActionResult<void>> adjustBalance(
    String pin,
    int newTotal, {
    String? note,
  }) =>
      _safe(() async {
        _requireLogin();
        await repository.adjustBalance(pin, newTotal, note: note);
      });

  /// Clears local persistence and cached domain state.
  Future<ActionResult<void>> resetLocalData() => _safe(() async {
        await repository.resetLocalData();
        _setState(SmartSaveState.initial(config.mode).copyWith(
          link: _state.link,
          auth: _state.auth,
          lock: _state.lock,
        ));
      });

  /// Returns filtered transactions.
  List<SavingsTransaction> getTransactions(TransactionQuery query) =>
      repository.getTransactions(query);

  /// Returns the current summary.
  SavingsSummary get summary => state.summary;

  /// Calculates statistics over the current history.
  SavingsStatistics statistics({DateTime? from, DateTime? to}) {
    final transactions = from == null && to == null
        ? state.transactions
        : getTransactions(TransactionQuery(
            from: from,
            to: to,
          ));
    return stats.statistics(transactions);
  }

  void _requireLogin() {
    _refreshLockout();
    if (_state.auth != AuthState.loggedIn) {
      throw const AuthError.notAuthenticated();
    }
  }

  Future<ActionResult<T>> _safe<T>(
    Future<T> Function() action, {
    void Function(SmartSaveError error)? onError,
  }) async {
    try {
      return ActionSuccess(await action());
    } on SmartSaveError catch (error) {
      onError?.call(error);
      _setState(_state.copyWith(lastError: error));
      _events.add(ErrorRaised(error));
      return ActionFailure(error);
    } catch (_) {
      const error = ProtocolError.invalidArgument();
      _setState(_state.copyWith(lastError: error));
      _events.add(const ErrorRaised(error));
      return const ActionFailure(error);
    }
  }

  void _onRepositoryChange(RepositorySnapshot snapshot) {
    _setState(_state.copyWith(
      deviceTotal: snapshot.deviceTotal,
      goals: snapshot.goals,
      transactions: snapshot.transactions,
      lock: snapshot.lock,
      lastSyncedAt: snapshot.lastSyncedAt,
      auth: snapshot.pinNotSet ? AuthState.pinNotSet : null,
    ));
  }

  void _onClientEvent(device.DeviceEvent event) {
    if (event is device.PinNotSetDetected) {
      _clearSession();
    } else if (event is device.LockChanged) {
      _setState(_state.copyWith(
        lock: event.locked ? LockState.locked : LockState.unlocked,
      ));
    }
  }

  void _onTransportState(TransportState transportState) {
    if (transportState == TransportState.connecting) {
      _setState(_state.copyWith(link: LinkState.connecting));
    } else if (transportState == TransportState.connected) {
      if (_state.link != LinkState.handshaking) {
        _setState(_state.copyWith(link: LinkState.ready));
      }
    } else {
      _clearSession();
      _setState(_state.copyWith(link: LinkState.disconnected));
    }
  }

  void _clearSession() {
    _pin = null;
    _setState(_state.copyWith(
      auth: _state.auth == AuthState.pinNotSet
          ? AuthState.pinNotSet
          : AuthState.loggedOut,
      lockoutEndsAt: null,
    ));
  }

  void _refreshLockout() {
    final ends = _state.lockoutEndsAt;
    if (_state.auth == AuthState.lockedOut &&
        ends != null &&
        !clock.now().isBefore(ends)) {
      _setState(_state.copyWith(
        auth: AuthState.loggedOut,
        lockoutEndsAt: null,
      ));
    }
  }

  void _scheduleLockoutCheck(DateTime until) {
    _lockoutTimer?.cancel();
    final delay = until.difference(clock.now());
    _lockoutTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _refreshLockout,
    );
  }

  void _setState(SmartSaveState next) {
    if (_disposed || next == _state) return;
    _state = next;
    notifyListeners();
  }

  /// Releases subscriptions and timers.
  @override
  Future<void> dispose() async {
    _disposed = true;
    _lockoutTimer?.cancel();
    await _repositoryChanges?.cancel();
    await _repositoryEvents?.cancel();
    await _clientEvents?.cancel();
    await _transportState?.cancel();
    await _events.close();
    super.dispose();
  }
}
