# SmartSave Backend — Architecture & Implementation Plan

Protocol source of truth: **`smartsave_stub.ino`** (the uploaded stub). Nothing below invents a command that is not in that file.

Tags used throughout:
**[C]** confirmed in your brief, the proposal, or the stub · **[A]** assumption to verify · **[R]** my recommendation, not yet approved · **[D]** decision needed from the team.

---

# Phase 1 — Analysis

## 1.1 Terminology (use these words everywhere)

| Term | Meaning |
|---|---|
| **Bank** | The physical coin bank (Arduino + HM-10 + hardware) |
| **Firmware Stub** | `smartsave_stub.ino`, the Arduino sketch that speaks the protocol with no sensors |
| **Simulator** | A Dart port of the Firmware Stub's behaviour, used in mock mode |
| **Backend** | The Flutter package `smartsave_backend` (no UI) |
| **Mock mode / BLE mode** | The two runtime modes of the Backend |

## 1.2 Confirmed requirements [C]

- Arduino Uno R3, HM-10 (BLE), 4 IR sensors (one per size-graded hole), 16×2 I2C LCD, SG90 servo lock, active buzzer, LEDs, Anker Nano power bank. **No** push buttons, reed switch, or magnet.
- New coins only: ₱1, ₱5, ₱10, ₱20. Flutter receives only the resulting denomination.
- Arduino is the authoritative source of the balance. Flutter synchronizes, never invents it.
- No web server, REST API, or cloud. Bluetooth is the only channel.
- One user per bank; PIN login; PIN is a 4-digit number (enforced by the stub).
- Goal model **B** (decided earlier): depositing to a goal only *earmarks* money in the app; redeeming a goal unlocks the bank and deducts the amount.
- Three modes: Mock, Hardware testing, Final system. Backend identical in all.
- 3 students: you (backend/Arduino/integration), two on the Flutter UI.

## 1.3 Existing protocol (from the stub)

Newline-terminated ASCII. 9600 baud on the Arduino side. The same token can mean different things per direction, so decoding and encoding are separate.

**App → Bank**

| Line | Valid when | Replies |
|---|---|---|
| `HELLO` | always | `PROTO:1`, then `AUTH:NEW` (no PIN set) or `AUTH:REQ` |
| `AUTH:<pin>` | PIN set | `AUTH:OK` / `AUTH:FAIL` / `AUTH:WAIT`; `AUTH:NEW` if no PIN set; `ERR:FMT` if not 4 digits |
| `SETPIN:<pin>` | **no** PIN set yet | `AUTH:OK`; `ERR:FMT` if malformed |
| `SETPIN:<old>,<new>` | PIN already set | `AUTH:OK`; `AUTH:FAIL`/`AUTH:WAIT`; `ERR:FMT` |
| `SYNC` | always, no PIN needed | `TOTAL:<n>`, `LOCK:<0\|1>`, `SEQ:<n>`, then `COIN:<d>,<seq>` for each unacknowledged coin (oldest first, max 32), then `SYNC:END` |
| `ACK:<seq>` | always | **no reply**; cumulative; ignored if out of range |
| `LOCK` | always, no PIN needed | `LOCK:1` |
| `UNLOCK:<pin>,<amount>` | PIN set | success: `TOTAL:<new>` then `LOCK:0`. Failure: `AUTH:FAIL/WAIT/NEW`, `ERR:FMT`, `ERR:AMT` (amount 0, > total, or non-numeric) |
| `ADJ:<pin>,<newTotal>` | PIN set | success: `TOTAL:<new>`. Failure: as above; `ERR:AMT` if > 99999 |
| `PING` | always | `PONG` |
| anything else | | `ERR:CMD` |

**Bank → App, unsolicited**

| Line | When |
|---|---|
| `COIN:<d>,<seq>` then `TOTAL:<n>` | every coin, whether or not the phone is connected or listening |
| `LOCK:1` | automatically 30 s after an unlock |

**USB-only (not reachable from the app):** `SIM:<1\|5\|10\|20>`, `FACTORY`.

**Limits:** PIN = exactly 4 digits · total capped at 99,999 · lines from the Bank ≤ 19 chars · Bank silently drops incoming lines > 23 chars · `seq` is `uint16` and wraps · 3 wrong PINs → 30 s lockout (`AUTH:WAIT`).

## 1.4 Facts in the stub that shape the architecture

1. **Authentication is stateless.** There is no session. Every privileged command (`UNLOCK`, `ADJ`, `SETPIN` change) carries the PIN. "Logged in" is a *client-side* state: the Backend verifies the PIN with `AUTH`, then keeps it **in memory only** to attach to later commands. `SYNC`, `LOCK`, `ACK`, `PING` need no PIN.
2. **Replies are not tagged.** `AUTH:FAIL` could answer `AUTH`, `UNLOCK`, `ADJ`, or `SETPIN`. `TOTAL:` after an `ADJ` looks identical to the `TOTAL:` after a coin. So the Backend must run **one command at a time** and match replies by an explicit table (§2.5).
3. **`COIN` never defines the balance.** `TOTAL` does. In a `SYNC` reply `TOTAL` arrives *before* the replayed `COIN`s and already includes them. Balance = last `TOTAL`; `COIN` only creates a history record.
4. **`ACK` is cumulative.** `ACK:9` means "I have everything ≤ 9". Acknowledging past a gap permanently loses the skipped coins. Only ACK contiguous sequence numbers, and only **after** persisting them.
5. **Only the last 32 unacknowledged coins are replayable.** More than 32 coins while the app is away → the older ones are gone. The `TOTAL` mismatch reveals this and the Backend records a reconciliation adjustment.
6. **The Bank has no timestamps, no history, and no identity.** Offline coins can only be timestamped at sync time (approximate). A factory-reset or different Bank looks identical to the app (see F1, §1.9).
7. **Unsolicited lines can arrive at any time**, including between a command and its reply (a coin during `AUTH`, the 30 s auto-`LOCK:1`).
8. **The lockout is global** (not per connection) and the app is never told the remaining time.
9. **The stub writes to the HM-10 even when no phone is connected.** What an unconnected HM-10 does with that data is unverified (U6).

## 1.5 Responsibility split

| Bank (Arduino) | Backend (Flutter, no UI) | UI (Flutter) |
|---|---|---|
| Coin detection and denomination | BLE connection, HM-10 framing | Screens, navigation, theming |
| Authoritative total, `seq`, 32-coin replay buffer | Handshake, sync, ACK, reconciliation | Rendering `SmartSaveState` |
| PIN storage, verification, lockout | Login state (PIN in memory only) | PIN entry screens |
| Servo lock, 30 s auto-relock | Goals/earmarks, history, statistics | Charts, lists, forms |
| LCD, buzzer, LEDs | Timestamps, duplicate/gap handling | Calling Backend methods |
| EEPROM persistence | Local persistence, typed errors, mock mode | Showing errors to users |

## 1.6 Transaction history — what the protocol supports

The Bank stores **no history**, only the denominations of unacknowledged coins. So Flutter must keep its own record. Options:

| Option | Trade-off |
|---|---|
| A. Memory only | Simplest, but history **and goals** vanish when the app closes. Your proposal shows history, statistics, and goals, so this fails the confirmed UI. |
| **B. Local persistence on the phone [R]** | Needs one storage dependency; survives restarts; history lives on one phone only. |
| C. RTC + EEPROM log on the Arduino | Accurate timestamps and phone-independent, but adds hardware and firmware you did not list. Not recommended for the prototype. |

**[D1]** Approve option B. The Backend isolates storage behind an interface, so the technology stays swappable. [R] `shared_preferences` (JSON) for the prototype. Minimum persisted data: transactions, goals, `lastAckedSeq`, `knownDeviceTotal`, bound device id.

## 1.7 Assumptions [A]

- A1. HM-10 exposes service `FFE0` / characteristic `FFE1` (notify + write-without-response). Typical default; verify on your module (clones vary).
- A2. Default HM-10 advertised name is often `HMSoft`; you will rename it. Scanning is by configurable name prefix.
- A3. One phone connects to the Bank at a time.
- A4. Amounts are whole pesos (integers).
- A5. The app runs in the **foreground**. Background BLE is out of scope.
- A6. Android and iOS both targeted; iOS builds need a Mac and a physical iPhone.
- A7. BLE writes are chunked to 20 bytes; inbound notifications may split or merge lines.

## 1.8 Unresolved issues

| # | Issue | Proposed resolution |
|---|---|---|
| D1 | Local persistence | Option B above |
| D2 | BLE package | [R] `flutter_reactive_ble` (BSD-3-Clause, maintained). `flutter_blue_plus` 2.x now uses a custom license requiring a paid license for for-profit organizations of 15+ employees; 1.x was BSD-3. A student project likely qualifies for free use, but the license is non-standard. The BLE package sits behind an interface, so switching is one file. |
| D3 | Remember the PIN across launches? | Default: **no**. PIN lives in memory; user re-enters on each launch. Optional later: `flutter_secure_storage` [R, not now]. |
| D4 | Non-goal withdrawals | Model B only unlocks through goal redemption. `DeviceClient.unlock` already supports any amount, so adding `withdraw()` later is additive. |
| D5 | LCD content | Assumed **₱ total**. Confirm. |
| U1 | No door sensor | App cannot know whether coins were removed; relies on auto-relock + `adjustBalance`. Document as a limitation. |
| U2 | Goals/earmarks live only on the phone | Lost if the app data is cleared or the phone changes. No cloud by design. |
| U3 | Offline coins have approximate timestamps | Marked `syncedLate` in the data model. |
| U4 | Lockout remaining time unknown | Backend assumes 30 s (mirrors firmware constant). |
| U5 | Wrong-bank / reset-bank detection | F1 (below); until then bind to BLE device id + `seq`-regression check. |
| U6 | HM-10 behaviour when the Arduino transmits with no phone connected | Hardware test T-3. |
| U7 | Power bank may cut output at low load | Hardware test T-9 (outside Backend scope). |

## 1.9 Firmware changes

- **Required for v1: none.** The Backend is designed around the stub exactly as written.
- **[R] F1 — bank identity.** Generate a random 16-bit id at `FACTORY`/first boot, store in EEPROM, and send `ID:<hex>` as one extra line in the `SYNC` reply (before `SYNC:END`). Reason: detect a different or factory-reset Bank so history is not mixed. It is additive: the Backend ignores unknown lines safely and would start using `ID:` once present, so no `PROTO` version bump is needed. Record the change in `PROTOCOL.md` if you adopt it.
- [R] In the real firmware, add compile-time flags (`USE_LCD`, `USE_SERVO`, `USE_BUZZER`, `USE_IR`) so the same sketch runs with partial hardware (Mode 2).

---

# Phase 2 — Backend Architecture

## 2.1 Layers

```
UI (app/)                          ← Members 2 & 3, imports ONLY package:smartsave_backend/smartsave_backend.dart
 │  state (ChangeNotifier) + events (Stream) + typed ActionResult
SmartSaveController                ← application layer: state, auth session, orchestration
 │
SmartSaveRepository                ← domain: sync/reconcile/ACK, transactions, goals, statistics
 │            │
 │         SmartSaveStore          ← persistence interface (InMemory | SharedPrefs)
 │
DeviceClient                       ← service layer: handshake, one-command-at-a-time, reply matching, typed events
 │
ProtocolCodec + LineAssembler      ← pure: String ⇄ typed messages/commands
 │
DeviceTransport                    ← abstract line transport
 ├── MockTransport → FakeDeviceSimulator   (Mode 1)
 └── Hm10BleTransport → BleGateway → flutter_reactive_ble   (Modes 2 & 3)
```

Rules: each layer talks only to the layer directly below. UI never sees a `String` protocol line, a UUID, or a byte. Only `transport/ble/` may import a BLE plugin.

## 2.2 Repository layout

```
smartsave/
├── README.md
├── .github/
│   ├── copilot-instructions.md
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── workflows/ci.yml                     [R] analyze + test
├── docs/
│   ├── ARCHITECTURE.md  PROTOCOL.md  BACKEND_API.md  HARDWARE_TESTING.md
│   └── COPILOT_PROMPTS.md
├── firmware/
│   ├── smartsave_stub/smartsave_stub.ino    # protocol source of truth
│   └── bringup/                             # one tiny sketch per component (Member 1)
├── packages/smartsave_backend/              # Member 1 owns
└── app/                                     # Members 2 & 3 own
```

## 2.3 Backend package files

```
packages/smartsave_backend/
├── pubspec.yaml · analysis_options.yaml · CHANGELOG.md · README.md
├── lib/
│   ├── smartsave_backend.dart               PUBLIC barrel; the only import UI may use
│   ├── testing.dart                         PUBLIC test helpers: fixtures, FakeClock
│   └── src/
│       ├── backend.dart                     composition root: SmartSaveBackend.create(config)
│       ├── config/   smartsave_config.dart · smartsave_mode.dart · protocol_limits.dart
│       ├── errors/   smartsave_error.dart · action_result.dart
│       ├── models/   denomination · savings_transaction · savings_goal · savings_summary ·
│       │             savings_statistics · device_snapshot · discovered_bank · link_state ·
│       │             auth_state · lock_state · smartsave_state · smartsave_event ·
│       │             sync_report · transaction_query
│       ├── protocol/ device_message.dart · device_command.dart · protocol_codec.dart · line_assembler.dart
│       ├── transport/
│       │   ├── device_transport.dart
│       │   ├── mock/ fake_device_simulator.dart · mock_transport.dart · simulator_profile.dart · mock_controls.dart
│       │   └── ble/  ble_gateway.dart · reactive_ble_gateway.dart · hm10_ble_transport.dart ·
│       │             hm10_constants.dart · ble_permissions.dart
│       ├── device/   device_client.dart · protocol_device_client.dart · command_queue.dart · device_event.dart
│       ├── storage/  smartsave_store.dart · persisted_data.dart · in_memory_store.dart · shared_prefs_store.dart
│       ├── repository/ smartsave_repository.dart · default_smartsave_repository.dart ·
│       │              reconciliation.dart · sequence_math.dart · statistics.dart
│       ├── application/ smartsave_controller.dart · connection_supervisor.dart
│       ├── diagnostics/ raw_traffic_log.dart · logger.dart
│       └── util/     clock.dart
└── test/  (mirrors lib/src) + fixtures/stub_transcript.txt
```

| File | Responsibility |
|---|---|
| `protocol_limits.dart` | Constants copied from the stub: PIN length 4, max total 99,999, replay buffer 32, line ≤ 19 chars, lockout 30 s, auto-relock 30 s, protocol version 1 |
| `device_message.dart` | Sealed inbound messages (`ProtoMessage`, `AuthStatusMessage`, `CoinMessage`, `TotalMessage`, `LockMessage`, `SeqMessage`, `SyncEndMessage`, `PongMessage`, `ErrorMessage`, `MalformedMessage`) |
| `device_command.dart` | Sealed outbound commands, one class per command |
| `protocol_codec.dart` | `decode(String)` never throws; `encode(command)` validates and throws on invalid input |
| `line_assembler.dart` | Turns arbitrary byte chunks into complete lines; guards against runaway garbage |
| `device_transport.dart` | Abstract line transport (scan, connect, `lines`, `writeLine`) |
| `fake_device_simulator.dart` | Dart port of the stub, including its quirks (§2.9) |
| `protocol_device_client.dart` | Handshake, single-flight queue, reply matching, timeouts, typed events |
| `reconciliation.dart` | Pure function: deposits + reported total → adjustment; no I/O, trivially testable |
| `sequence_math.dart` | `uint16` modular arithmetic (`next`, `distance`, `isAtOrBefore`) |
| `default_smartsave_repository.dart` | Sync algorithm, live coin handling, redeem, adjust, goals |
| `smartsave_controller.dart` | The single facade the UI uses |
| `connection_supervisor.dart` | Optional auto-reconnect with backoff |
| `raw_traffic_log.dart` | Ring buffer of raw TX/RX lines (PIN redacted) for diagnostics and hardware debugging |

## 2.4 Data models (immutable; plain Dart 3; no code generation)

- **`Denomination`** — enum `{php1, php5, php10, php20}` with `value`; `fromValue(int)` rejects anything else.
- **`SavingsTransaction`** — `id`, `type` (`deposit` | `redemption` | `adjustment` | `openingBalance`), `amount` (signed pesos), `denomination?`, `seq?`, `timestamp`, `timeAccuracy` (`observedLive` | `syncedLate` | `userAction`), `goalId?`, `note?`. JSON round-trip.
- **`SavingsGoal`** — `id`, `name`, `targetAmount`, `allocatedAmount` (the earmark), `status` (`active` | `redeemed` | `cancelled`), `createdAt`, `redeemedAt?`; derived `progress` (0–1, clamped), `isReached`.
- **`SavingsSummary`** — `deviceTotal`, `allocatedTotal`, `available = max(0, total − allocated)`, `overAllocatedBy`.
- **`SavingsStatistics`** — pure aggregates over transactions (per day/week/month totals, highest day, average per day, count) for the Statistics screen.
- **`DeviceSnapshot`** — `total`, `locked`, `deviceSeq`, `replayedCoins`, `receivedAt`.
- **States** — `LinkState {disconnected, scanning, connecting, handshaking, ready}` · `AuthState {unknown, pinNotSet, loggedOut, loggedIn, lockedOut}` · `LockState {unknown, locked, unlocked}`.
- **`SmartSaveState`** — `mode`, `link`, `auth`, `lockoutEndsAt?`, `lock`, `deviceTotal?`, `sync` (`idle/syncing/synced/failed` + `lastSyncedAt`), `goals`, `transactions` (newest first), `summary`, `lastError?`. Prototype-scale: full history in memory.
- **`SmartSaveEvent`** (one-shot, for animations and toasts) — `CoinReceived(txn)`, `BalanceChanged`, `LockChanged`, `AutoRelocked`, `GoalReached(goal)`, `ReconciliationApplied(delta, gapSize?)`, `DeviceAnomaly(kind)`, `ErrorRaised(error)`.

## 2.5 Protocol architecture

**Codec.** `decode` accepts exactly the inbound grammar of §1.3 (trimmed, case-sensitive). Anything else → `MalformedMessage(raw, reason)`; it never throws and never mutates state. `encode` validates (4-digit PIN, amount ranges, `seq` 0–65535, total length ≤ 19 chars) and throws `InvalidArgumentError`.

**Reply matching (implemented in `DeviceClient`).** One command in flight; others queue.

| Command | Completes successfully on | Completes with failure on |
|---|---|---|
| `HELLO` | `AUTH:NEW` / `AUTH:REQ` (after `PROTO:1`) | timeout; `PROTO` ≠ 1 → `UnsupportedProtocolVersion` |
| `AUTH` | `AUTH:OK` | `AUTH:FAIL` / `WAIT` / `NEW`, `ERR:FMT` |
| `SETPIN` | `AUTH:OK` | `AUTH:FAIL` / `WAIT`, `ERR:FMT` |
| `SYNC` | `SYNC:END` (collects `TOTAL`, `LOCK`, `SEQ`, `COIN`s) | timeout |
| `LOCK` | `LOCK:1` | timeout |
| `UNLOCK` | `LOCK:0` (the `TOTAL` just before it is the new balance) | `AUTH:FAIL/WAIT/NEW`, `ERR:FMT`, `ERR:AMT` |
| `ADJ` | next `TOTAL` — **ambiguous with a coin's `TOTAL`**, so the Repository always follows with `SYNC` to confirm | same as `UNLOCK` |
| `PING` | `PONG` | timeout |
| `ACK` | fire-and-forget | n/a |

Lines that don't answer the current command (a live `COIN` + `TOTAL`, an auto `LOCK:1`) are emitted as typed `DeviceEvent`s and never complete a command, with one exception: `LOCK:1` completes a pending `LOCK`. `AUTH:NEW` arriving at any time means the Bank has no PIN (e.g. it was factory-reset).

**Never retry `UNLOCK` automatically** (not idempotent: a retry could deduct twice). On timeout, `SYNC` and compare totals (§2.7).

## 2.6 Service interfaces (sketches; Copilot may refine names, not responsibilities)

```dart
abstract interface class DeviceTransport {
  Stream<TransportState> get state;           // disconnected | connecting | connected
  Stream<String> get lines;                   // complete inbound lines, terminator stripped
  Stream<DiscoveredBank> scan({Duration timeout});
  Future<void> connect(DiscoveredBank bank);
  Future<void> disconnect();
  Future<void> writeLine(String line);        // appends '\n'; BLE impl chunks to 20 bytes
  Future<void> dispose();
}

abstract interface class DeviceClient {
  Stream<DeviceEvent> get events;             // CoinDetected, TotalReported, LockChanged, AuthNewDetected, Malformed
  Future<HandshakeResult> handshake();        // HELLO → protocol version + pinSet
  Future<void> authenticate(String pin);
  Future<void> setInitialPin(String pin);
  Future<void> changePin(String oldPin, String newPin);
  Future<DeviceSnapshot> sync();
  void ack(int seq);
  Future<void> lock();
  Future<UnlockOutcome> unlock(String pin, int amount);
  Future<int> adjustTotal(String pin, int newTotal);
  Future<void> ping();
}
```

## 2.7 Repository responsibilities (the core logic)

Persisted: `lastAckedSeq`, `knownDeviceTotal` (K), transactions, goals, bound device id.

**`synchronize()`**
1. `snapshot = client.sync()`.
2. Drop replayed coins already acknowledged (`isAtOrBefore(seq, lastAckedSeq)`) or already stored.
3. Gap check: if `lastAckedSeq` is known and the first replayed `seq` ≠ `lastAckedSeq + 1`, coins were lost → remember `gapSize`.
4. Anomaly check: `deviceSeq` *behind* `lastAckedSeq` → emit `DeviceAnomaly(seqRegressed)`, **do not ACK**, reconcile by total only.
5. Create `deposit` transactions (`timeAccuracy = syncedLate`).
6. Reconcile: if K unknown → `openingBalance = T − Σnew`. Else `delta = T − (K + Σnew)`; if ≠ 0 → `adjustment` (note records `gapSize`). Set `K = T`.
7. **Persist everything in one write, then** `ack(lastNewSeq)`.

**Live coin.** Accept only if `seq == lastAckedSeq + 1`: store, persist, then ACK. Otherwise (gap, duplicate, or no baseline) ignore it and trigger `synchronize()`. A live `TOTAL` that differs from K after the coin is applied → reconciliation adjustment.

**`redeemGoal`.** Requires logged in, goal active, `0 < allocated ≤ deviceTotal`. Sends `UNLOCK:<pin>,<allocated>`. On success: `redemption` transaction (negative), goal → `redeemed`, `K −= amount`. On timeout: `SYNC`; if `T == K − amount` → success inferred; if `T == K` → not executed; else anomaly. Never auto-retry.

**`adjustBalance(newTotal)`**: `ADJ`, `adjustment` (user action), `K = new`, then `SYNC` to confirm.

**Goals.** CRUD; `allocate` needs `amount ≤ available`; `release`; emits `GoalReached` when allocated ≥ target. `available` can go negative-clamped after an adjustment; `overAllocatedBy` exposes it.

## 2.8 Controller / state design

`SmartSaveController` is a `ChangeNotifier` holding one immutable `SmartSaveState`, plus an `events` stream for one-shot occurrences. State = "what is"; events = "what just happened". The UI picks any state-management it likes (`ListenableBuilder` works with zero extra packages).

Every action returns `Future<ActionResult<T>>` (`ActionSuccess` | `ActionFailure(error)`), **never throws**, so UI code needs no try/catch. Privileged actions fail with `NotAuthenticated` unless `auth == loggedIn`.

```dart
// Composition root
final backend = SmartSaveBackend.create(SmartSaveConfig.mock());   // or .ble()
await backend.initialize();
final c = backend.controller;

c.state; c.events;
// connection
c.ensureBluetoothReady(); c.scan(); c.connect(bank); c.reconnectLast(); c.disconnect();
// auth
c.setInitialPin(pin); c.login(pin); c.logout(); c.changePin(oldPin:, newPin:);
// data
c.sync(); c.getTransactions(query); c.summary; c.statistics(range);
// goals
c.createGoal(...); c.updateGoal(...); c.deleteGoal(id);
c.allocateToGoal(id, amt); c.releaseFromGoal(id, amt); c.redeemGoal(id);
// bank
c.lockBank(); c.adjustBalance(newTotal);
// diagnostics / dev
c.rawTraffic; c.resetLocalData(); backend.mockControls; // null outside mock mode
```

Your list (`connect/disconnect/sync/getBalance/getTransactions/lock/unlock/authenticate/listenForEvents`) maps to: `connect`, `disconnect`, `sync`, `state.deviceTotal`/`summary`, `getTransactions`, `lockBank`, `redeemGoal` (the model-B form of unlock), `login`, `events`.

## 2.9 Mock architecture (Mode 1)

`FakeDeviceSimulator` reproduces the stub's behaviour **including quirks**: `AUTH:NEW` replies to PIN-bearing commands when no PIN is set; global 3-fail / 30 s lockout; cumulative `ACK` with range check; 32-slot replay ring; total clamp at 99,999; 30 s auto-relock with unsolicited `LOCK:1`; lines > 23 chars silently dropped; `SIM`/`FACTORY` rejected from the BLE side. Time comes from an injected `Clock` and `tick()`, so tests never sleep.

`MockControls` (dev menu, tests): `dropCoin(denom)`, `startAutoCoins(interval, seed)`, `stopAutoCoins()`, `simulateLinkLoss()`, `reconnect()`, `factoryResetBank()`, `injectRawLine(String)`, `setLatency(Duration)`. Coins dropped while the link is down still update the simulated Bank (pending ring) but their lines are discarded, like real hardware.

Profiles: `fresh` (no PIN, ₱0) and `demo` (PIN `1234`, total ₱1,250, a few unacknowledged coins).

**Conformance transcript** (`test/fixtures/stub_transcript.txt`, in `COPILOT_PROMPTS.md`): scripted `>`/`<` lines taken directly from the stub. It is run against the Simulator in unit tests and pasted into the Serial Monitor to check the real stub. One artifact, two uses.

## 2.10 Real Bluetooth architecture (Modes 2 and 3)

`Hm10BleTransport` → `BleGateway` (thin wrapper, fakeable) → `flutter_reactive_ble`. Scans by configurable name prefix; connects; discovers `FFE0`/`FFE1`; subscribes to notifications; writes without response in ≤ 20-byte chunks with a small inter-chunk delay; feeds notifications into `LineAssembler`. `ble_permissions.dart` wraps `permission_handler` and returns a typed `BluetoothReadiness` (`ready`, `bluetoothOff`, `permissionDenied`, `permanentlyDenied`, `unsupported`).

Required platform config (applied in `app/`): Android 12+ `BLUETOOTH_SCAN` (`neverForLocation`) and `BLUETOOTH_CONNECT`; Android ≤ 11 legacy `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION` (`maxSdkVersion="30"`); iOS `NSBluetoothAlwaysUsageDescription`.

**Mode mapping:** Mode 1 = `SmartSaveMode.mock`. Modes 2 and 3 are both `SmartSaveMode.ble`; the *firmware* differs, not the Backend. Partial hardware works because the firmware always speaks the protocol (component bring-up is described in `HARDWARE_TESTING.md`). A desktop USB-serial transport is **not** needed [R]; use the Serial Monitor for component tests.

## 2.11 Error model

`SmartSaveError` (sealed, stable `code`, no UI text): `ConnectionError` (bluetoothOff, permissionDenied, deviceNotFound, connectFailed, connectionLost, serviceNotFound) · `ProtocolError` (unsupportedVersion, commandTimeout, unexpectedReply, invalidArgument) · `AuthError` (pinNotSet, wrongPin, lockedOut, notAuthenticated, invalidPinFormat) · `DeviceError` (invalidAmount, badFormat, unknownCommand) · `StorageError` · `StateError` (deviceMismatch, notConnected). Malformed lines are **not** errors: they are logged, counted, and ignored; three in a row trigger a resync. Duplicates are dropped silently. The UI maps `code` to localized text.

## 2.12 Configuration

`SmartSaveConfig`: `mode`, `simulatorProfile`, `bleServiceUuid` (`FFE0`), `bleCharacteristicUuid` (`FFE1`), `scanNamePrefixes` (`SmartSave`, `HMSoft`), `commandTimeout` (3 s), `syncTimeout` (6 s), `lockoutDuration` (30 s), `autoSyncOnConnect`, `autoReconnect`, `storeFactory`. App chooses the mode with `--dart-define=SMARTSAVE_MODE=mock|ble` (default `mock`).

## 2.13 Frontend/backend boundary rules

1. UI imports only `package:smartsave_backend/smartsave_backend.dart` (and `testing.dart` in tests).
2. UI never imports `src/`, any BLE package, or `permission_handler`.
3. UI never builds or parses a protocol string.
4. UI never computes balances; it reads `state`/`summary`.
5. Any backend change after a handoff tag is additive; breaking changes need a version bump + CHANGELOG entry + notice to Members 2–3.
6. Enforced by `analysis_options.yaml` (`implementation_imports`) and a CI grep.

## 2.14 Dependencies (all [R] unless noted)

| Package | Why | Status |
|---|---|---|
| `flutter_reactive_ble` | BLE (Android + iOS), BSD-3 | [D2] |
| `permission_handler` | Android runtime BLE permissions | needed for BLE mode |
| `shared_preferences` | local persistence | [D1] |
| `flutter_lints`, `flutter_test` | analysis/testing | standard |
| *(none)* | no `freezed`, `equatable`, `mocktail`, `build_runner`, Provider/Riverpod/Bloc inside the Backend | keeps Copilot output simple |

---

# Phase 3 — GitHub Workflow

## 3.1 Branches

Trunk-based; `main` is protected (PR + passing checks + one review).

| Pattern | Used for |
|---|---|
| `backend/p01-foundation` … `backend/p14-handoff-audit` | one branch per Copilot prompt |
| `ui/<member>/<feature>` | UI work, e.g. `ui/m2/dashboard` |
| `firmware/<topic>` | Arduino work |
| `docs/<topic>` | documentation only |

Tags: `backend-v0.1.0` (Handoff 1: mock mode complete), `backend-v0.2.0` (Handoff 2: BLE verified on hardware), `backend-v1.0.0` (final).

## 3.2 Commits and PRs

- Conventional Commits with scope: `feat(protocol): add decoder`, `test(repository): cover seq wrap`, `docs(api): add redeem example`.
- **One Copilot prompt = one branch = one PR.** Commit before running a prompt so `git diff` shows exactly what Copilot changed; revert freely.
- Before each commit: `flutter analyze && flutter test` inside the package. PR description lists the prompt number and the files Copilot touched; reject changes outside the prompt's allowed-file list.
- `.github/CODEOWNERS`: `/packages/smartsave_backend/` and `/firmware/` → Member 1. `/app/lib/features/dashboard`, `/goals`, `/statistics` → Member 2. `/app/lib/features/history`, `/settings`, `/auth`, `/connection`, `/app/lib/shared` → Member 3.

## 3.3 Handoff to the UI developers

**Handoff 0 (day 1–2):** after Prompts 1–2, tag `backend-v0.0.1-models`. Members 2–3 can build every screen as a pure function of `SmartSaveState` using `testing.dart` fixtures, before any logic exists.
**Handoff 1 (after Prompt 9):** tag `backend-v0.1.0`. Whole app runs in mock mode with drop-a-coin controls. UI members: clone → `flutter pub get` → `flutter run --dart-define=SMARTSAVE_MODE=mock` → read `docs/BACKEND_API.md`.
**Handoff 2 (after Prompts 10–14 and hardware test):** tag `backend-v0.2.0`; switch to `ble`.

UI members consume the Backend as a path dependency (`smartsave_backend: {path: ../packages/smartsave_backend}`), so a `git pull` is the whole update.

## 3.4 Avoiding merge conflicts

- Directory ownership (above); UI members never edit the package; they open a `backend-request` issue instead.
- Hotspot files: `app/lib/main.dart`, router, theme, `pubspec.yaml`. Member 2 owns `main.dart`/router/theme; Member 3 owns `shared/`. Changes there go through small PRs; rebase on `main` daily.
- No generated code is committed (no codegen), which removes the usual source of conflicts. On a `pubspec.lock` conflict: accept `main`'s version and re-run `flutter pub get`.
- Each UI feature lives in its own folder with its own widgets; shared widgets only via `shared/` PRs by Member 3.

## 3.5 Team division and parallel timeline

| | Member 1 | Member 2 | Member 3 |
|---|---|---|---|
| Role | Backend, Arduino, hardware, integration tests | Dashboard, balance, goals, statistics charts | History, auth/PIN, settings, connection/scan, shared widgets, UI integration tests |
| Days 1–2 | Repo skeleton, Prompts 1–2, firmware stub into repo | App scaffold, theme, navigation; screens from fixtures | Shared widgets; screens from fixtures |
| Days 3–10 | Prompts 3–9 (protocol → controller), HM-10 bring-up (T-1) | Build against mock mode after Handoff 1 | Same; dev menu using `mockControls` |
| Days 11–20 | Prompts 10–14; IR/LCD/servo/buzzer bring-up; final firmware | Polish, goal flows | Auth flows, widget/integration tests |
| After | Hardware integration, Handoff 2 | Switch to BLE, test on phone | Same |

Nobody blocks anyone: Members 2–3 depend only on models (day 2) and the controller (Handoff 1); Member 1's hardware work never touches their files.

---

# Phase 4 — Prompts

See **`COPILOT_PROMPTS.md`** (14 prompts, plus the global `copilot-instructions.md`).

---

# Phase 5 — Backend Handoff Checklist

Complete before saying *"The backend is ready. Clone the repository, read BACKEND_API.md, and build the UI against these interfaces."*

**Build and quality**
- [ ] `flutter pub get && flutter analyze` is clean in `packages/smartsave_backend`.
- [ ] `flutter test` passes; coverage ≥ 85% for `protocol/`, `device/`, `repository/`.
- [ ] CI is green on `main`.
- [ ] No `TODO`/`UnimplementedError` in `lib/src`.

**Boundary**
- [ ] `grep -R "flutter_reactive_ble\|permission_handler" app/lib` returns nothing.
- [ ] `grep -R "package:smartsave_backend/src" app/` returns nothing.
- [ ] `smartsave_backend.dart` exports exactly what `BACKEND_API.md` documents.
- [ ] No UI code (widgets, `BuildContext`) inside the package.

**Mock mode (Handoff 1)**
- [ ] A fresh clone runs in mock mode with no hardware.
- [ ] Full flow works in mock: connect → set PIN → login → sync → drop coin → balance updates → create goal → allocate → redeem → history shows all of it.
- [ ] Conformance transcript passes against the Simulator.
- [ ] Offline-coin replay, lockout, and unlock-timeout scenarios pass.

**Protocol fidelity**
- [ ] The transcript was also run by hand against the **real Firmware Stub** over USB and matches.
- [ ] `PROTOCOL.md` matches the `.ino` line by line; any firmware change (e.g. F1) is recorded there.

**Hardware (Handoff 2)**
- [ ] T-1: HM-10 renamed, `FFE0`/`FFE1` confirmed (A1), phone sees notifications from the stub.
- [ ] T-2: Android and iPhone each connect, handshake, sync, and receive live coins.
- [ ] T-3: coin dropped while no phone connected → replayed on next sync (resolves U6).
- [ ] T-4: wrong PIN ×3 → `WAIT`, recovers after 30 s.
- [ ] T-5: redeem → servo unlocks, balance drops, auto-relock arrives.
- [ ] T-6: link loss mid-sync recovers.
- [ ] T-7: IR sensors produce correct `COIN` denominations for 50 drops each.
- [ ] T-8: LCD matches the app's balance after every event.
- [ ] T-9: power bank keeps the Bank alive when idle (resolves U7).

**Documentation**
- [ ] `README.md`, `ARCHITECTURE.md`, `PROTOCOL.md`, `BACKEND_API.md`, `HARDWARE_TESTING.md` exist and are current.
- [ ] `BACKEND_API.md` has a copy-paste usage example that compiles.
- [ ] Decisions D1–D5 are recorded in `ARCHITECTURE.md`; limitations U1–U7 are listed.
- [ ] Android and iOS permission setup is documented and applied in `app/`.

**Release**
- [ ] CHANGELOG updated; tag `backend-v0.1.0` (then `v0.2.0`) pushed.
- [ ] Members 2–3 each ran the app in mock mode on their own machine.
- [ ] A `backend-request` issue template exists for API change requests.
