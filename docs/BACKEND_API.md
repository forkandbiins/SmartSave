# Backend API for UI developers

Import the production API:

```dart
import 'package:smartsave_backend/smartsave_backend.dart';
```

Tests may also import `package:smartsave_backend/testing.dart` for
`FakeClock`, fixtures, `InMemoryStore`, and mock-bank helpers.

## Setup

`SmartSaveMode` is `mock` or `ble`. `SmartSaveConfig.mock()` accepts the
`fresh` or `demo` `SimulatorProfileName`; `SmartSaveConfig.ble()` selects BLE.
`SmartSaveConfig.fromEnvironment()` reads `SMARTSAVE_MODE` and defaults to
Mock mode. `SmartSaveBackend.create(config, {clock, store, logger})` creates
the composition root. Call `initialize()`, use `controller`, then call
`dispose()`. The Backend also exposes `controller`, nullable `mockControls`,
`readinessProvider`, and `connectionSupervisor`.

`SmartSaveController` methods return `Future<ActionResult<T>>`; callers should
not expect them to throw. `ActionSuccess.valueOrNull` contains success data;
`ActionFailure.errorOrNull` contains a typed `SmartSaveError`.

## Connection and readiness

`ensureBluetoothReady()` returns `BluetoothReadiness`: `ready`,
`bluetoothOff`, `permissionDenied`, `permanentlyDenied`, or `unsupported`.
`scan()` returns `List<DiscoveredBank>`. Pass a discovered bank to `connect()`.
`reconnectLast()` reconnects the remembered bank; `disconnect()` clears the
in-memory PIN while retaining cached history and balance. BLE readiness types
are `BluetoothReadiness` and `BluetoothReadinessProvider`.

## Authentication

`setInitialPin(pin)` configures a fresh Bank and logs in. `login(pin)` verifies
the PIN. `logout()` clears the in-memory PIN. `changePin(newPin, {oldPin})`
uses the current session PIN when `oldPin` is omitted. PINs are never
persisted or logged. `AuthState` is `unknown`, `pinNotSet`, `loggedOut`,
`loggedIn`, or `lockedOut`.

## Synchronization and data

`sync()` returns `SyncReport`. `getTransactions(TransactionQuery)` filters
history. `summary` returns `SavingsSummary`; `statistics({from, to})` returns
`SavingsStatistics`. Public models include `Denomination`,
`SavingsTransaction` (`TransactionType`, `TimeAccuracy`),
`SavingsGoal` (`GoalStatus`), `SavingsSummary`, `SavingsStatistics`,
`DeviceSnapshot` (`ReplayedCoin`), `DiscoveredBank`, `TransactionQuery`, and
`SyncReport`.

The complete Controller action surface is `ensureBluetoothReady`, `scan`,
`connect`, `reconnectLast`, `disconnect`, `setInitialPin`, `login`, `logout`,
`changePin`, `sync`, `createGoal`, `updateGoal`, `deleteGoal`,
`allocateToGoal`, `releaseFromGoal`, `redeemGoal`, `lockBank`,
`adjustBalance`, and `resetLocalData`. Read APIs are `state`, `events`,
`rawTraffic`, `recentTraffic`, `getTransactions`, `summary`, and
`statistics`.

## Goals and Bank control

`createGoal(name, targetAmount)`, `updateGoal`, `deleteGoal`,
`allocateToGoal`, and `releaseFromGoal` manage app-local earmarks.
`redeemGoal(goalId, pin)` unlocks the Bank and deducts the goal amount.
`lockBank()` needs no login. `adjustBalance(pin, newTotal, {note})` changes the
authoritative Bank total after a recount. `resetLocalData()` clears local
history, goals, and binding.

In Mock mode, `backend.mockControls` is a `MockControls` instance; use
`dropCoin(Denomination.php5)` in developer/test tooling. It is `null` in BLE
mode. Its other controls are `startAutoCoins`, `stopAutoCoins`,
`simulateLinkLoss`, `reconnect`, `factoryResetBank`, `injectRawLine`,
`setLatency`, and `dispose`. UI production screens should not depend on mock
controls.

## State and events

`SmartSaveState` exposes `mode`, `link` (`LinkState`), `auth`,
`lockoutEndsAt`, `lock` (`LockState`), `deviceTotal`, `deviceSeq`,
`syncStatus` (`SyncStatus`), `lastSyncedAt`, newest-first `transactions`,
`goals`, `summary`, and `lastError`. Listen to the Controller as a
`ChangeNotifier`.

The `events` stream emits `CoinReceived`, `BalanceChanged`, `LockChanged`,
`AutoRelocked`, `GoalReached`, `ReconciliationApplied`, `DeviceAnomaly`,
`ErrorRaised`, and `LinkChanged`, all subclasses of `SmartSaveEvent`.
`RawTrafficEntry` and `recentTraffic()` provide redacted diagnostic traffic;
the Controller also exposes the `rawTraffic` stream.

The public model enums and helper types are `SmartSaveMode`,
`SimulatorProfileName`, `LinkState`, `AuthState`, `LockState`, `SyncStatus`,
`BluetoothReadiness`, `GoalStatus`, `TransactionType`, `TimeAccuracy`, and
`DeviceAnomalyKind`. `ActionResult<T>` has the public result types
`ActionSuccess<T>` and `ActionFailure<T>`, plus `isSuccess`, `valueOrNull`,
`errorOrNull`, and `when`.

`SmartSaveError` exposes `code`, `message`, and optional `cause`. Its public
subclasses are `ConnectionError`, `ProtocolError`, `InvalidArgumentError`,
`AuthError`, `DeviceError`, `StorageError`, and `SmartSaveStateError`.
`RawTrafficEntry` contains `timestamp`, `direction`, and redacted `line`.

## Errors and UI handling

Every failure is an `ActionFailure` with one of these codes:

| Group | Codes | Suggested UI handling |
|---|---|---|
| Connection | `bluetoothOff`, `permissionDenied`, `permissionPermanentlyDenied`, `deviceNotFound`, `connectFailed`, `connectionLost`, `serviceNotFound` | Explain readiness/connection, offer settings or rescan. |
| Protocol | `unsupportedVersion`, `commandTimeout`, `unexpectedReply`, `invalidArgument` | Show retry/support diagnostics; do not expose raw protocol text. |
| Auth | `pinNotSet`, `wrongPin`, `lockedOut`, `notAuthenticated`, `invalidPinFormat` | Show setup, retry, lockout countdown, or PIN validation. |
| Device | `invalidAmount`, `badFormat`, `unknownCommand` | Show the operation was rejected and preserve state. |
| Storage | `readFailed`, `writeFailed`, `corrupt` | Explain local data trouble and offer recovery/support. |
| State | `deviceMismatch`, `notConnected`, `invalidOperation` | Ask the user to reconnect, reset local data, or change flow. |

## Complete Mock-mode example

```dart
import 'dart:async';
import 'package:smartsave_backend/smartsave_backend.dart';

Future<void> main() async {
  final backend = SmartSaveBackend.create(
    SmartSaveConfig.mock(profile: SimulatorProfileName.demo),
  );
  final controller = backend.controller;
  void onState() {
    print('state: ${controller.state}');
  }
  controller.addListener(onState);
  final eventSubscription = controller.events.listen(print);

  await backend.initialize();
  final banks = await controller.scan();
  final bank = banks.valueOrNull!.single;
  await controller.connect(bank);
  await controller.login('1234');
  await controller.sync();

  final goal = (await controller.createGoal('Trip', 5)).valueOrNull!;
  await controller.allocateToGoal(goal.id, 5);
  backend.mockControls!.dropCoin(Denomination.php5);
  await Future<void>.delayed(Duration.zero);
  await controller.redeemGoal(goal.id, '1234');

  await eventSubscription.cancel();
  controller.removeListener(onState);
  await backend.dispose();
}
```

`ChangeNotifier.addListener` returns `void`; retain the callback and pass that
same callback to `removeListener`.

## UI state guidance

| State | UI should do |
|---|---|
| `link == disconnected` | Show Connect/Scan and cached data; do not issue device commands. |
| `link == scanning` | Show scanning progress and allow cancellation in the screen layer. |
| `link == handshaking` | Show connection progress; wait for the result. |
| `link == ready`, `auth == pinNotSet` | Show first-time PIN setup. |
| `link == ready`, `auth == loggedOut` | Show login; cached history remains readable. |
| `auth == lockedOut` | Disable PIN attempts until `lockoutEndsAt`. |
| `syncStatus == syncing` | Show synchronization progress and avoid duplicate sync buttons. |
| `syncStatus == failed` | Show `lastError` and offer a retry. |
| `lock == unlocked` | Show the Bank as unlocked and the auto-relock expectation. |

## BLE setup

Use `SmartSaveConfig.ble()` or
`--dart-define=SMARTSAVE_MODE=ble`. The UI still calls only the Controller.
Android requires `BLUETOOTH_SCAN` with `neverForLocation` and
`BLUETOOTH_CONNECT` on Android 12+, plus legacy Bluetooth and fine-location
permissions through SDK 30. iOS requires
`NSBluetoothAlwaysUsageDescription`. These are already represented in the
app platform configuration; UI code must not request permissions directly.

The UI never touches Bluetooth, a BLE plugin, UUIDs, bytes, or protocol
strings.
