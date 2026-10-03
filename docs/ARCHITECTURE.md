# SmartSave architecture

## Layers

```text
SmartSaveController
        ↓
SmartSaveRepository
        ↓
DeviceClient
        ↓
ProtocolCodec / LineAssembler
        ↓
DeviceTransport
   ├── MockTransport → Simulator
   └── Hm10BleTransport → BleGateway → flutter_reactive_ble
```

Each layer talks only to the layer immediately below it. The Backend package
contains no UI. The UI consumes the public barrel and never imports `src/`,
BLE plugins, or protocol strings.

The Controller exposes immutable `SmartSaveState` through `ChangeNotifier` and
one-shot `SmartSaveEvent` values through a stream. State is the durable,
renderable snapshot; events describe transitions such as a coin, goal reached,
reconciliation, link change, error, or auto-relock.

## Responsibilities

- **Bank/Firmware Stub:** coin denomination, authoritative total, sequence,
  replay buffer, PIN verification and lockout, physical lock, LCD, and EEPROM.
- **Backend:** BLE framing, handshake, synchronization, persistence, replay and
  duplicate handling, reconciliation, goals, statistics, typed errors, and
  in-memory session PIN.
- **UI:** screens, navigation, localized messages, forms, and rendering state.

The Bank is authoritative for balance: balance is the last received `TOTAL`.
`COIN` creates history only and never changes balance. A replayed coin is
persisted before its contiguous ACK is sent. More than 32 offline coins causes
the missing value to be represented by a reconciliation adjustment.

## Decisions

- **D1 — local persistence:** JSON persistence behind `SmartSaveStore`; the
  current implementation includes shared preferences and an in-memory test
  store.
- **D2 — BLE package:** `flutter_reactive_ble`, behind a fakeable gateway.
- **D3 — PIN lifetime:** never persisted; the user logs in again after a new
  app/backend session or link loss.
- **D4 — withdrawals:** the current goal model redeems earmarked money; a
  general withdrawal API is out of scope.
- **D5 — LCD:** the stub displays the peso total; finished hardware should
  confirm the final LCD layout.

## Current limitations

- **U1:** There is no door sensor; physical removal is reconciled with
  `adjustBalance`.
- **U2:** Goals and history are local to the phone and disappear if its data is
  cleared or the phone changes.
- **U3:** Offline coins receive approximate `syncedLate` timestamps.
- **U4:** The Bank does not report remaining lockout time; the Backend mirrors
  the 30-second firmware constant.
- **U5:** A reset or wrong Bank has no protocol identity; the Backend binds the
  first device id and detects mismatches/regressions where possible.
- **U6:** HM-10 behavior when the Arduino transmits without a connected phone
  must be verified by hardware test T-3.
- **U7:** A power bank may cut output at low load; this is tested by T-9.

## Frontend/backend boundary

The UI imports only `package:smartsave_backend/smartsave_backend.dart`.
Testing code may additionally import `testing.dart`. UI code does not touch
Bluetooth, UUIDs, byte packets, protocol strings, storage implementations, or
balance arithmetic. It reads `SmartSaveState`, `summary`, transactions,
statistics, and events, and handles `ActionResult` failures.

## Dependencies

The Backend uses Flutter, `flutter_reactive_ble`, `permission_handler`, and
`shared_preferences`. `flutter_lints` and `flutter_test` are development
dependencies. It intentionally does not use code generation, `equatable`,
`mocktail`, Provider, Riverpod, Bloc, or a BLE plugin outside the BLE transport
directory.
