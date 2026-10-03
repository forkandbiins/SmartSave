# SmartSave — GitHub Copilot Prompt Sequence

14 prompts + one manual setup step. Each prompt is self-contained and lists exactly which files Copilot may touch.

**Order differs from the example you gave, on purpose:**
- Typed errors and `ActionResult` come in **Prompt 1** (every layer needs them); Prompt 11 is the error-*hardening* pass.
- The **mock path is finished first** (Prompts 1–9) so your groupmates get **Handoff 1** before any Bluetooth work. The real HM-10 transport is Prompt 10.
- Storage is split from the repository (Prompts 7 and 8), because the repository is the hardest logic and should not also carry persistence code.

## How to use these

1. Use **Agent mode in VS Code**. Start every prompt in a **new chat** so earlier context doesn't leak.
2. Make sure `.github/copilot-instructions.md` (provided separately) is committed; Copilot reads it automatically.
3. `git checkout -b backend/pNN-name` and **commit before** running the prompt, so `git diff` shows exactly what Copilot did.
4. Paste the text inside the fenced block. Attach the files named under *Attach* with `#file`.
5. Afterwards: review `git diff --stat`. If any file outside *Allowed files* changed, revert it.
6. Run `flutter analyze && flutter test` in `packages/smartsave_backend`. Merge only when both pass.

**Reusable follow-ups**

- Scope: `You changed files outside the allowed list. Revert those changes and explain which of your changes needed them.`
- Failing: `flutter test fails with: <paste>. Fix the code, not the test, unless the test contradicts the prompt's requirements; if so, tell me which.`
- Protocol: `That behaviour doesn't match smartsave_stub.ino. Re-read the stub, quote the relevant lines, then correct the implementation.`

---

## Step 0 — Manual setup (you, not Copilot)

```bash
mkdir smartsave && cd smartsave && git init
mkdir -p firmware/smartsave_stub firmware/bringup docs .github/workflows packages
flutter create --template=package packages/smartsave_backend
flutter create --org com.yourteam --project-name smartsave_app app

# copy in the files
cp <path>/smartsave_stub.ino            firmware/smartsave_stub/
cp <path>/copilot-instructions.md       .github/
cp <path>/SMARTSAVE_BACKEND_PLAN.md     .
cp <path>/COPILOT_PROMPTS.md            docs/

git add -A && git commit -m "chore: repo skeleton, stub, plan, copilot instructions"
git checkout -b backend/p01-foundation
```

In `app/pubspec.yaml`, add (UI members will use this):
`smartsave_backend: { path: ../packages/smartsave_backend }`

---

## Prompt 1 — Foundation: config, errors, results, clock, logger

Branch `backend/p01-foundation` · Attach: `SMARTSAVE_BACKEND_PLAN.md`, `smartsave_stub.ino`

````text
TASK: Build the foundation of the Flutter package packages/smartsave_backend. No protocol, models, or transport yet.

READ FIRST: SMARTSAVE_BACKEND_PLAN.md (sections 2.3, 2.11, 2.12) and the #define block at the top of firmware/smartsave_stub/smartsave_stub.ino.

ALLOWED FILES (create/modify only these):
- packages/smartsave_backend/pubspec.yaml, analysis_options.yaml, CHANGELOG.md
- lib/smartsave_backend.dart
- lib/src/config/smartsave_mode.dart, smartsave_config.dart, protocol_limits.dart
- lib/src/errors/smartsave_error.dart, action_result.dart
- lib/src/util/clock.dart
- lib/src/diagnostics/logger.dart
- test/config/, test/errors/, test/util/, test/diagnostics/  (new test files only)
- Delete the template lib/ and test/ files that `flutter create` generated.
DO NOT TOUCH: app/, firmware/, docs/, .github/.

REQUIREMENTS
1. pubspec: name smartsave_backend; Flutter package; dependencies: flutter only; dev_dependencies: flutter_test, flutter_lints. Do NOT add any BLE, storage, or permission packages.
2. analysis_options.yaml: include flutter_lints; enable public_member_api_docs, avoid_print, always_declare_return_types, prefer_final_fields.
3. protocol_limits.dart: a `ProtocolLimits` class of static consts mirroring the stub exactly: protoVersion=1, pinLength=4, maxTotal=99999, replayBufferSize=32, maxFailedPins=3, lockoutDuration=30 s, autoRelockDuration=30 s, maxSeq=65535, maxOutboundLineChars=19, maxBleWriteBytes=20, maxInboundLineCharsAccepted=23, validDenominations=[1,5,10,20].
4. smartsave_mode.dart: `enum SmartSaveMode { mock, ble }`.
5. smartsave_config.dart: `SmartSaveConfig` (immutable) with fields: mode, simulatorProfile (enum SimulatorProfileName { fresh, demo }, defined in this file), bleServiceUuid='FFE0', bleCharacteristicUuid='FFE1', scanNamePrefixes=['SmartSave','HMSoft'], commandTimeout=3 s, syncTimeout=6 s, lockoutDuration=ProtocolLimits.lockoutDuration, autoSyncOnConnect=true, autoReconnect=true. Constructors: `SmartSaveConfig.mock({profile})`, `SmartSaveConfig.ble()`, `SmartSaveConfig.fromEnvironment()` reading String.fromEnvironment('SMARTSAVE_MODE', defaultValue: 'mock'); unknown value -> mock. Include copyWith.
6. smartsave_error.dart: `sealed class SmartSaveError implements Exception` with `SmartSaveErrorCode code`, `String message` (developer-facing English), `Object? cause`. Subclasses (final classes), each with named factories or constructors for these codes:
   - ConnectionError: bluetoothOff, permissionDenied, permissionPermanentlyDenied, deviceNotFound, connectFailed, connectionLost, serviceNotFound
   - ProtocolError: unsupportedVersion, commandTimeout, unexpectedReply, invalidArgument   (also expose `InvalidArgumentError` as a convenience subclass)
   - AuthError: pinNotSet, wrongPin, lockedOut (carries DateTime? until), notAuthenticated, invalidPinFormat
   - DeviceError: invalidAmount, badFormat, unknownCommand
   - StorageError: readFailed, writeFailed, corrupt
   - StateError: deviceMismatch, notConnected, invalidOperation   (name it SmartSaveStateError to avoid clashing with dart:core StateError)
7. action_result.dart: `sealed class ActionResult<T>` with `ActionSuccess<T>(value)` and `ActionFailure<T>(SmartSaveError error)`; helpers isSuccess, valueOrNull, errorOrNull, and `R when<R>({required R Function(T) success, required R Function(SmartSaveError) failure})`.
8. clock.dart: abstract `Clock { DateTime now(); }`, `SystemClock`, and `FakeClock` (mutable time, `advance(Duration)`).
9. logger.dart: abstract `SmartSaveLogger` (debug/info/warn/error methods), `NoopLogger`, `PrintLogger` (uses dart:developer log, not print), and a top-level `String redactPin(String line)` that masks PINs in protocol lines:
   AUTH:1234 -> AUTH:****   |   UNLOCK:1234,500 -> UNLOCK:****,500   |   ADJ:1234,90 -> ADJ:****,90   |   SETPIN:1234 -> SETPIN:****   |   SETPIN:1234,5678 -> SETPIN:****,****   |  any other line unchanged.
10. lib/smartsave_backend.dart exports: SmartSaveConfig, SmartSaveMode, SimulatorProfileName, SmartSaveError and all subclasses + SmartSaveErrorCode, ActionResult/ActionSuccess/ActionFailure, ProtocolLimits. Do not export Clock/FakeClock/logger yet.

ACCEPTANCE CRITERIA
- `flutter analyze` reports no issues; no import of material.dart, widgets.dart, or dart:ui anywhere in lib/.
- Tests cover: every ProtocolLimits value; fromEnvironment default is mock; ActionResult.when; each error code constructible; FakeClock.advance; redactPin on all examples above plus a non-PIN line.
- Every public symbol has a dartdoc comment.

VERIFY: cd packages/smartsave_backend && flutter pub get && flutter analyze && flutter test
````

---

## Prompt 2 — Data models, state, events, test fixtures

Branch `backend/p02-models` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§2.4), P1 files

````text
TASK: Implement the immutable data models, the app state, the events, and public test fixtures. No logic beyond model invariants.

READ FIRST: SMARTSAVE_BACKEND_PLAN.md section 2.4 and 1.4 (facts 3 and 6).

ALLOWED FILES:
- lib/src/models/: denomination.dart, savings_transaction.dart, savings_goal.dart, savings_summary.dart, savings_statistics.dart, device_snapshot.dart, discovered_bank.dart, link_state.dart, auth_state.dart, lock_state.dart, smartsave_state.dart, smartsave_event.dart, sync_report.dart, transaction_query.dart
- lib/testing.dart
- lib/smartsave_backend.dart   (add exports only)
- test/models/ (new)
DO NOT TOUCH: any file from Prompt 1 except the barrel exports.

REQUIREMENTS
1. Plain Dart 3 classes: final fields, const constructors where possible, copyWith, ==, hashCode, toString written by hand. NO freezed/equatable/json_serializable.
2. Denomination: enum { php1, php5, php10, php20 } with `value`; `static Denomination? tryFromValue(int)`; `static Denomination fromValue(int)` throws InvalidArgumentError for anything not 1/5/10/20 (the new-coin set only; there is no old-coin handling).
3. SavingsTransaction: id, type (TransactionType: deposit, redemption, adjustment, openingBalance), amount (signed int pesos), denomination?, seq?, timestamp, timeAccuracy (TimeAccuracy: observedLive, syncedLate, userAction), goalId?, note?. toJson/fromJson (ISO-8601 UTC timestamps; unknown enum string -> throws FormatException).
4. SavingsGoal: id, name, targetAmount, allocatedAmount, status (GoalStatus: active, redeemed, cancelled), createdAt, redeemedAt?; getters progress (0..1 clamped; target 0 -> 0), isReached. toJson/fromJson. Invariants (assert): target > 0, allocated >= 0.
5. SavingsSummary: deviceTotal, allocatedTotal, available = max(0, total - allocated), overAllocatedBy = max(0, allocated - total). Factory `SavingsSummary.from(int? deviceTotal, List<SavingsGoal> goals)` counting only ACTIVE goals' allocations; null total is treated as 0.
6. SavingsStatistics + TransactionQuery: types only (fields for date range, types filter, goalId filter, limit; and aggregate result fields: totalDeposited, transactionCount, highestDay, averagePerDay, perDayTotals map). No computation yet.
7. DeviceSnapshot: total, locked, deviceSeq, replayedCoins (List<ReplayedCoin{Denomination denomination, int seq}>), receivedAt.
8. DiscoveredBank: id, name, rssi?.
9. LinkState {disconnected, scanning, connecting, handshaking, ready}; AuthState {unknown, pinNotSet, loggedOut, loggedIn, lockedOut}; LockState {unknown, locked, unlocked}; SyncStatus {idle, syncing, synced, failed}.
10. SmartSaveState: mode, link, auth, lockoutEndsAt?, lock, deviceTotal?, deviceSeq?, syncStatus, lastSyncedAt?, goals, transactions (newest first, unmodifiable), lastError?; getter `summary`. Static `SmartSaveState.initial(mode)`.
11. SmartSaveEvent: sealed. CoinReceived(txn), BalanceChanged(oldTotal, newTotal), LockChanged(lock), AutoRelocked, GoalReached(goal), ReconciliationApplied(delta, gapSize?), DeviceAnomaly(DeviceAnomalyKind {seqRegressed, deviceMismatch, unexpectedState}), ErrorRaised(error), LinkChanged(link).
12. SyncReport: newDeposits (int count), reconciliationDelta?, gapSize?, anomalies.
13. lib/testing.dart (PUBLIC): re-export FakeClock and add `DemoFixtures` with static `emptyState()`, `demoState()` (connected, loggedIn, total 1250, 3 goals incl. one reached, 12 mixed transactions), `sampleTransactions()`, `sampleGoals()`. Fixtures must be built only from the model classes.
14. Export all models from lib/smartsave_backend.dart.

ACCEPTANCE CRITERIA
- JSON round-trip equality for SavingsTransaction and SavingsGoal (all enum values).
- Denomination.fromValue(2) and (50) throw; (20) works.
- SavingsSummary: total 100 with active allocations 30+20 -> available 50, over 0; total 40 -> available 0, overAllocatedBy 10; redeemed/cancelled goals excluded.
- Goal progress: 0 target guarded; allocated > target clamps to 1.0.
- SmartSaveState.initial(mock) has link disconnected, auth unknown, deviceTotal null.
- No file under lib/ imports package:flutter/material.dart or widgets.dart.

VERIFY: flutter analyze && flutter test
````

*After:* tag `backend-v0.0.1-models` → **Handoff 0**: Members 2–3 can build screens from `DemoFixtures`.

---

## Prompt 3 — Protocol: inbound decoding and line assembly

Branch `backend/p03-protocol-decode` · Attach: `smartsave_stub.ino`, `SMARTSAVE_BACKEND_PLAN.md` (§1.3, §2.5)

````text
TASK: Implement decoding of Bank->App protocol lines and a byte-to-line assembler. Pure Dart, no I/O.

READ FIRST: firmware/smartsave_stub/smartsave_stub.ino — every emit(...) call. Those, and only those, are the valid inbound lines.

ALLOWED FILES:
- lib/src/protocol/device_message.dart, protocol_codec.dart (decode half only), line_assembler.dart
- lib/smartsave_backend.dart is NOT modified (protocol is internal)
- test/protocol/decode_test.dart, line_assembler_test.dart
DO NOT TOUCH: anything else.

REQUIREMENTS
1. device_message.dart: sealed class DeviceMessage with final subclasses:
   ProtoMessage(version) · AuthStatusMessage(AuthReply {newDevice, required, ok, fail, wait}) · CoinMessage(Denomination, seq) · TotalMessage(total) · LockMessage(bool locked) · SeqMessage(seq) · SyncEndMessage · PongMessage · ErrorMessage(ErrorReply {unknownCommand, badFormat, badAmount}) · MalformedMessage(String raw, MalformedReason reason).
2. ProtocolCodec.decode(String line) -> DeviceMessage. It NEVER throws. Trim surrounding whitespace and a trailing \r. Case-sensitive. Grammar (exact):
   PROTO:<int>  |  AUTH:NEW|REQ|OK|FAIL|WAIT  |  COIN:<d>,<seq> with d in {1,5,10,20}, seq 0..65535  |  TOTAL:<0..99999>  |  LOCK:0|1  |  SEQ:<0..65535>  |  SYNC:END  |  PONG  |  ERR:CMD|FMT|AMT
   Anything else -> MalformedMessage with a reason from enum MalformedReason {empty, unknownToken, badArgument, outOfRange, invalidDenomination}. Examples: "" -> empty; "COIN:2,5" -> invalidDenomination; "TOTAL:100000" -> outOfRange; "TOTAL:abc" -> badArgument; "HELLO" -> unknownToken (HELLO is a command, not a reply; decode is direction-specific); "AUTH:1234" -> unknownToken (a PIN is never inbound).
3. line_assembler.dart: `LineAssembler({int maxLineLength = 64})` with `List<String> addBytes(List<int>)`, `List<String> addString(String)`, `reset()`, and `int droppedLines`. Behaviour: lines end at \n; ignore \r; skip empty lines; chunks may split a line or contain several lines; decode bytes with utf8 allowMalformed; if a line exceeds maxLineLength discard it up to the next \n (increment droppedLines) and keep working.
4. Do not implement encoding here (Prompt 4).

ACCEPTANCE CRITERIA
- Table-driven decode test covering every valid line type plus at least 15 malformed inputs (including boundary values 0, 65535, 65536, 99999, 100000, negative numbers, extra spaces, lowercase "coin:5,1", "COIN:5", "COIN:5,", "COIN:,3", "LOCK:2", "ERR:XYZ").
- Assembler tests: "COIN:5," + "1\nTOTAL:5\n" in separate chunks yields two lines; "\r\n" endings; 200-char garbage then a valid line yields the valid line and droppedLines == 1; two lines in one chunk.
- decode never throws for random strings (include a loop test with 1,000 pseudo-random strings, fixed seed).

VERIFY: flutter analyze && flutter test
````

---

## Prompt 4 — Protocol: command encoding and the golden transcript

Branch `backend/p04-protocol-encode` · Attach: `smartsave_stub.ino`, P3 files

````text
TASK: Implement App->Bank command encoding with validation, and add the golden conformance transcript with a parser for it.

READ FIRST: firmware/smartsave_stub/smartsave_stub.ino, function handleLine().

ALLOWED FILES:
- lib/src/protocol/device_command.dart
- lib/src/protocol/protocol_codec.dart  (add encode; keep decode unchanged)
- test/fixtures/stub_transcript.txt
- test/support/transcript.dart   (parser only; the runner comes in Prompt 5)
- test/protocol/encode_test.dart, transcript_parser_test.dart
DO NOT TOUCH: decode logic, models, config.

REQUIREMENTS
1. device_command.dart: sealed DeviceCommand with final classes: HelloCommand, LoginCommand(pin), SetInitialPinCommand(pin), ChangePinCommand(oldPin, newPin), SyncCommand, AckCommand(seq), LockCommand, UnlockCommand(pin, amount), AdjustCommand(pin, newTotal), PingCommand. Pure data; no validation in constructors.
2. ProtocolCodec.encode(DeviceCommand) -> String WITHOUT a newline (transports add it). Output exactly:
   HELLO | AUTH:<pin> | SETPIN:<pin> | SETPIN:<old>,<new> | SYNC | ACK:<seq> | LOCK | UNLOCK:<pin>,<amount> | ADJ:<pin>,<newTotal> | PING
3. Validation, throwing InvalidArgumentError: PIN must match ^\d{4}$; UnlockCommand amount 1..99999; AdjustCommand newTotal 0..99999; AckCommand seq 0..65535; final line length must be <= ProtocolLimits.maxOutboundLineChars (19).
4. Create test/fixtures/stub_transcript.txt with EXACTLY the content in the block below. Do not "fix" or reorder it; it was derived line-by-line from the stub.
5. test/support/transcript.dart: `parseTranscript(String) -> List<TranscriptStep>` with step kinds: send(line) for '>' ; expect(line) for '<' ; usb(command, repeat) for '@usb CMD [xN]' ; wait(seconds) for '@wait N' ; drain for '@drain' ; section markers for '# S<n>' comment lines. Expand the shorthand `{a..b}` in an expect line into one expect per integer, inclusive. Ignore other '#' comments and blank lines.

TRANSCRIPT CONTENT (write verbatim):
```
# SmartSave stub conformance transcript v1
# '>' app->bank   '<' bank->app   '@usb CMD [xN]' USB-only command   '@wait N' advance N seconds   '@drain' discard pending output   '#' comment
# Preconditions: SIMULATE_COINS 0 and fresh state (the first step sends FACTORY over USB).
# Rule: before every '>' or '@' step, all previous output must have been consumed by '<' lines.

# S1 fresh bank and PIN setup
@usb FACTORY
> HELLO
< PROTO:1
< AUTH:NEW
> AUTH:1234
< AUTH:NEW
> UNLOCK:1234,5
< AUTH:NEW
> SETPIN:12
< ERR:FMT
> SETPIN:1234,5678
< ERR:FMT
> SETPIN:1234
< AUTH:OK
> HELLO
< PROTO:1
< AUTH:REQ

# S2 login
> AUTH:0000
< AUTH:FAIL
> AUTH:1234
< AUTH:OK
> AUTH:12
< ERR:FMT

# S3 coins, sync, cumulative ack
@usb SIM:5
< COIN:5,1
< TOTAL:5
@usb SIM:20
< COIN:20,2
< TOTAL:25
@usb SIM:10
< COIN:10,3
< TOTAL:35
> SYNC
< TOTAL:35
< LOCK:1
< SEQ:3
< COIN:5,1
< COIN:20,2
< COIN:10,3
< SYNC:END
> ACK:2
> SYNC
< TOTAL:35
< LOCK:1
< SEQ:3
< COIN:10,3
< SYNC:END
> ACK:3
> ACK:9
> SYNC
< TOTAL:35
< LOCK:1
< SEQ:3
< SYNC:END

# S4 unlock and lock
> UNLOCK:0000,10
< AUTH:FAIL
> UNLOCK:1234,0
< ERR:AMT
> UNLOCK:1234,36
< ERR:AMT
> UNLOCK:1234,abc
< ERR:AMT
> UNLOCK:1234
< ERR:AMT
> UNLOCK:1234,30
< TOTAL:5
< LOCK:0
> SYNC
< TOTAL:5
< LOCK:0
< SEQ:3
< SYNC:END
@wait 30
< LOCK:1
> LOCK
< LOCK:1

# S5 lockout after three wrong PINs
> AUTH:0000
< AUTH:FAIL
> AUTH:0000
< AUTH:FAIL
> AUTH:0000
< AUTH:FAIL
> AUTH:1234
< AUTH:WAIT
> UNLOCK:1234,1
< AUTH:WAIT
@wait 31
> AUTH:1234
< AUTH:OK

# S6 adjust
> ADJ:1234,100
< TOTAL:100
> ADJ:1234,100000
< ERR:AMT
> ADJ:1234,abc
< ERR:AMT
> ADJ:1234
< ERR:AMT

# S7 change PIN
> SETPIN:1234,5678
< AUTH:OK
> AUTH:1234
< AUTH:FAIL
> SETPIN:5678
< ERR:FMT
> SETPIN:5678,1234
< AUTH:OK

# S8 misc
> PING
< PONG
> FOO
< ERR:CMD
> SIM:5
< ERR:CMD
> ACK:abc
> THISLINEISWAYTOOLONGTOBEACCEPTED
> PING
< PONG

# S9 replay buffer holds only the last 32 coins
@usb FACTORY
@usb SIM:1 x40
@drain
> SYNC
< TOTAL:40
< LOCK:1
< SEQ:40
< COIN:1,{9..40}
< SYNC:END
> ACK:40
> SYNC
< TOTAL:40
< LOCK:1
< SEQ:40
< SYNC:END
```

ACCEPTANCE CRITERIA
- Encode tests for every command with valid input, matching the lines above, and a rejection test for each validation rule (PIN "12", "12345", "abcd"; amount 0, 100000, -1; seq 65536; a line that would exceed 19 chars).
- Longest valid commands: UNLOCK:1234,99999 (17 chars) and SETPIN:1234,5678 (16 chars) encode fine.
- The transcript parser returns the expected number of steps, expands {9..40} into 32 expect steps, expands "x40", and ignores comments.
- Every '<' line in the fixture decodes (Prompt 3 decoder) to a non-Malformed message.

VERIFY: flutter analyze && flutter test
````

---

## Prompt 5 — Transport abstraction, Simulator, and Mock transport (Mode 1)

Branch `backend/p05-mock-transport` · Attach: `smartsave_stub.ino` (**important**), `stub_transcript.txt`

````text
TASK: Create the DeviceTransport abstraction and a faithful Dart port of the Arduino stub ("FakeDeviceSimulator"), plus MockTransport and MockControls. The simulator must pass the golden transcript.

READ FIRST: the ENTIRE firmware/smartsave_stub/smartsave_stub.ino. Port it faithfully, including its quirks. Where the stub is silent, do not invent behaviour.

ALLOWED FILES:
- lib/src/transport/device_transport.dart
- lib/src/transport/mock/fake_device_simulator.dart, simulator_profile.dart, mock_transport.dart, mock_controls.dart
- test/support/transcript_runner.dart
- test/transport/simulator_conformance_test.dart, simulator_behaviour_test.dart, mock_transport_test.dart
- lib/smartsave_backend.dart (export MockControls only)
DO NOT TOUCH: protocol files, models, config.

REQUIREMENTS
1. device_transport.dart: abstract interface class DeviceTransport { Stream<TransportState> get state; Stream<String> get lines; Stream<DiscoveredBank> scan({Duration timeout}); Future<void> connect(DiscoveredBank); Future<void> disconnect(); Future<void> writeLine(String line); Future<void> dispose(); } with enum TransportState { disconnected, connecting, connected }. `lines` yields complete lines without terminators.
2. FakeDeviceSimulator(Clock clock, Random random, SimulatorProfile profile). State mirrors the stub's Persist struct: pinSet, pin, total, seq (uint16), acked (uint16), pending[32] indexed by seq % 32, plus locked, unlockedAt, failCount, lockoutUntil.
   API: `Stream<String> output` (broadcast, sync), `void receiveLine(String line, {bool fromUsb = false})`, `void tick()` (evaluates auto-relock and lockout expiry from the Clock), `void dropCoin(int denomination)` (the stub's onCoin), `void factoryReset()`, getters total/seq/acked/locked/pinSet for tests.
   Behaviour to port exactly: HELLO, AUTH, SETPIN (first-time and old,new), SYNC (TOTAL, LOCK, SEQ, replay of at most 32 unacked coins oldest-first, SYNC:END), ACK (cumulative, range-checked, silent), LOCK, UNLOCK (amount 1..total; deducts; unlocks), ADJ (0..99999; no lock check), PING, unknown -> ERR:CMD; SIM and FACTORY only when fromUsb==true (otherwise ERR:CMD); PIN failure counting (3 failures -> 30 s lockout; during lockout even the correct PIN gets AUTH:WAIT; counter resets on success); AUTH:NEW for any PIN-bearing command when no PIN is set; total clamped at 99,999; coins other than 1/5/10/20 ignored; 30 s auto-relock emitting an unsolicited LOCK:1; incoming lines longer than 23 characters or empty lines are silently dropped; '\r' ignored; the bank always boots locked.
   Every emitted line must be <= 19 characters.
3. SimulatorProfile: `fresh` (no PIN, total 0, seq 0) and `demo` (PIN 1234, total 1250, seq 12, acked 8, pending coins for seq 9..12 = 5,10,1,20). Map from SimulatorProfileName.
4. MockTransport(simulator, {Duration latency = Duration.zero, bool autoTick = true}): scan yields one DiscoveredBank(id 'mock-bank-1', name 'SmartSave (mock)'); connect/disconnect update state; writeLine feeds simulator.receiveLine; simulator output reaches `lines` ONLY while connected (otherwise lines are discarded, but the simulator still updates its own state, like real hardware); a periodic timer (250 ms) calls simulator.tick() when autoTick; no real delays when latency is zero.
5. MockControls (wraps simulator + transport): dropCoin(Denomination), startAutoCoins(Duration interval, {int? seed}), stopAutoCoins(), simulateLinkLoss(), reconnect(), factoryResetBank(), injectRawLine(String), setLatency(Duration).
6. test/support/transcript_runner.dart: runs parsed transcript steps against a simulator with a FakeClock: '>' sends and requires the output queue to be empty beforehand; '<' consumes the next output line and asserts equality; '@usb' calls receiveLine(fromUsb:true) (x N repeats); '@wait N' advances FakeClock by N seconds then calls tick(); '@drain' clears output; fail with the transcript line number on mismatch.

ACCEPTANCE CRITERIA
- The ENTIRE stub_transcript.txt passes against the simulator (sections S1..S9). Do not edit the transcript to make it pass; fix the simulator.
- Behaviour tests: seq wraps 65535 -> 0 correctly (use a test-only way to seed seq near the limit), clamp at 99999, ACK ignored when outside range, lockout expiry, link-loss coins are replayed by a later SYNC, 33 coins offline -> only the last 32 replayed.
- Every simulator output line is <= 19 characters (assert in a test over the whole transcript).
- MockTransport delivers no lines while disconnected and works with latency zero without timers.

VERIFY: flutter analyze && flutter test
````

---

## Prompt 6 — DeviceClient (handshake, command queue, reply matching, typed events)

Branch `backend/p06-device-client` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§1.4, §2.5, §2.6), P3–P5 files

````text
TASK: Implement DeviceClient, the layer that turns the line transport into typed operations and typed events.

READ FIRST: SMARTSAVE_BACKEND_PLAN.md sections 1.4 and 2.5 (the reply-matching table) and the transcript fixture.

ALLOWED FILES:
- lib/src/device/device_client.dart, protocol_device_client.dart, command_queue.dart, device_event.dart
- test/device/ (new tests; use MockTransport + FakeDeviceSimulator + FakeClock)
DO NOT TOUCH: protocol, simulator, models (add nothing to them; define small result types in device_client.dart).

REQUIREMENTS
1. device_event.dart: sealed DeviceEvent: CoinDetected(Denomination, seq), TotalReported(total), LockChanged(bool locked, {bool unsolicited}), PinNotSetDetected, MalformedLine(raw), LinkLost.
2. device_client.dart: the abstract DeviceClient interface from the plan (handshake, authenticate, setInitialPin, changePin, sync, ack, lock, unlock, adjustTotal, ping, events) + result types HandshakeResult(protocolVersion, pinSet), UnlockOutcome(newTotal).
3. ProtocolDeviceClient(DeviceTransport, ProtocolCodec, SmartSaveConfig, Clock, SmartSaveLogger, {void Function(String direction, String line)? onTraffic}).
4. ONE command in flight at a time; others wait in a FIFO queue. Because replies are untagged, match them using EXACTLY this table:
   - handshake: send HELLO; expect PROTO then AUTH:NEW|REQ. PROTO != 1 -> ProtocolError.unsupportedVersion. No reply within commandTimeout -> retry HELLO up to 2 more times, then ProtocolError.commandTimeout.
   - authenticate/changePin/setInitialPin: success = AUTH:OK. AUTH:FAIL -> AuthError.wrongPin; AUTH:WAIT -> AuthError.lockedOut(until: now + config.lockoutDuration); AUTH:NEW -> AuthError.pinNotSet; ERR:FMT -> DeviceError.badFormat.
   - sync: send SYNC; collect TOTAL, LOCK, SEQ and COIN lines until SYNC:END; return DeviceSnapshot (replayed coins in arrival order). Timeout = syncTimeout; on timeout retry ONCE, then ProtocolError.commandTimeout.
   - lock: success = LOCK:1.
   - unlock: success = LOCK:0, whose immediately preceding TOTAL is the new balance (UnlockOutcome). Failures: AUTH:FAIL/WAIT/NEW as above, ERR:FMT -> badFormat, ERR:AMT -> DeviceError.invalidAmount. NEVER retry automatically, even on timeout.
   - adjustTotal: success = the next TOTAL; failures as for unlock. (The Repository confirms with SYNC afterwards.)
   - ping: success = PONG.
   - ack: fire-and-forget, no reply expected, never queued behind a pending command's timeout (it may be written immediately after the pending command completes).
5. Lines that do not belong to the pending command become DeviceEvents and never complete a command: COIN -> CoinDetected, TOTAL -> TotalReported, LOCK:1 -> LockChanged(unsolicited: true), AUTH:NEW at any time -> PinNotSetDetected, MalformedMessage -> MalformedLine. Exception: LOCK:1 completes a pending lock(). Inside sync(), COIN/TOTAL/LOCK/SEQ are collected, not emitted as events.
6. If the transport drops, complete the pending command with ConnectionError.connectionLost, clear the queue, and emit LinkLost. No future may hang forever.
7. Log through the logger using redactPin(); call onTraffic for every line sent/received (also redacted).
8. Never depend on UI or BLE code. Never call DateTime.now(); use Clock.

ACCEPTANCE CRITERIA (tests use the simulator; use fakeAsync from flutter_test for timeouts)
- handshake against fresh -> pinSet false; against demo -> pinSet true.
- authenticate: correct PIN ok; wrong PIN -> wrongPin; 3 wrong -> lockedOut with until == clock.now()+30 s.
- A coin dropped while an authenticate() is pending produces CoinDetected AND does not break the AUTH match.
- sync on demo returns total 1250, 4 replayed coins (seq 9..12), seq 12.
- unlock success returns the new total; ERR:AMT maps to invalidAmount; timeout does NOT resend the command (assert the simulator received it once).
- Three commands issued at once execute strictly in order.
- Link loss mid-sync completes with connectionLost.
- PIN never appears in logger output or onTraffic.

VERIFY: flutter analyze && flutter test
````

---

## Prompt 7 — Local storage

Branch `backend/p07-storage` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§1.6, §2.7) · **Requires decision D1**

````text
TASK: Implement local persistence behind an interface. The repository (Prompt 8) will depend only on the interface.

ALLOWED FILES:
- packages/smartsave_backend/pubspec.yaml  (add dependency: shared_preferences — nothing else)
- lib/src/storage/smartsave_store.dart, persisted_data.dart, in_memory_store.dart, shared_prefs_store.dart
- test/storage/ (new)
DO NOT TOUCH: everything else.

REQUIREMENTS
1. persisted_data.dart: PersistedData { int schemaVersion (=1), String? boundDeviceId, int? lastAckedSeq, int? knownDeviceTotal, DateTime? lastSyncedAt, List<SavingsTransaction> transactions, List<SavingsGoal> goals } with copyWith, empty(), toJson/fromJson. fromJson must reject unknown schemaVersion with StorageError.corrupt and contain a documented migration hook (a switch on schemaVersion).
2. smartsave_store.dart: abstract interface class SmartSaveStore { Future<PersistedData> load(); Future<void> save(PersistedData data); Future<void> clear(); }  Saving writes the WHOLE object in one operation (atomic from the caller's view).
3. InMemoryStore: default store for mock mode and tests; supports `failNextSave` / `failNextLoad` flags for failure-path tests.
4. SharedPrefsStore(SharedPreferences prefs, {String key = 'smartsave.v1'}): JSON string under one key. Missing key -> PersistedData.empty(). Invalid JSON or schema -> throws StorageError.corrupt. Platform failures -> StorageError.readFailed / writeFailed.
5. Document in dartdoc: prototype-scale storage (thousands of transactions are fine, tens of thousands are not); swapping to sqflite/drift later means implementing SmartSaveStore only.

ACCEPTANCE CRITERIA
- Round-trip a PersistedData with 500 transactions and 5 goals through both stores (use SharedPreferences.setMockInitialValues).
- Corrupt JSON throws StorageError.corrupt and does not crash; empty store returns empty().
- clear() empties; a later load returns empty().
- No other package added to pubspec.

VERIFY: flutter pub get && flutter analyze && flutter test
````

---

## Prompt 8 — Repository: sync, reconciliation, history, goals, statistics

Branch `backend/p08-repository` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§1.4, §2.7), P2, P6, P7 files · **The most important prompt: review the diff carefully.**

````text
TASK: Implement SmartSaveRepository: the domain logic between DeviceClient and the store. Follow the algorithms below exactly.

READ FIRST: SMARTSAVE_BACKEND_PLAN.md sections 1.4 (all nine facts) and 2.7.

ALLOWED FILES:
- lib/src/repository/smartsave_repository.dart, default_smartsave_repository.dart, reconciliation.dart, sequence_math.dart, statistics.dart
- test/repository/ (new)
DO NOT TOUCH: device client, storage, models (if a model needs a new field, STOP and tell me).

REQUIREMENTS
1. sequence_math.dart: uint16 helpers: next(s), distance(from,to) = (to-from)&0xFFFF, isAtOrBefore(a, reference) (true when distance(a, reference) < 32768), plus `contiguous(prev, next)`.
2. reconciliation.dart: a PURE function `Reconciliation reconcile({int? knownTotal, required int reportedTotal, required int newCoinsSum})` returning: openingBalance (when knownTotal is null: reportedTotal - newCoinsSum), or delta = reportedTotal - (knownTotal + newCoinsSum). No I/O.
3. DefaultSmartSaveRepository(DeviceClient, SmartSaveStore, Clock, SmartSaveLogger). `initialize()` loads the store (on StorageError.corrupt: start empty and emit ErrorRaised). It exposes: a `changes` stream of an immutable domain snapshot (transactions newest-first, goals, deviceTotal, lock, lastSyncedAt), an `events` stream of SmartSaveEvent, and the methods below. It never holds the PIN; privileged methods receive it as a parameter.
4. synchronize() -> SyncReport:
   a. snapshot = client.sync().
   b. Remove replayed coins that are already acknowledged (sequence_math.isAtOrBefore(seq, lastAckedSeq)) or already stored.
   c. Gap check: if lastAckedSeq is known and the first remaining coin's seq != next(lastAckedSeq) -> gapSize = distance(next(lastAckedSeq), firstSeq).
   d. Anomaly check: if lastAckedSeq is known and snapshot.deviceSeq is BEHIND lastAckedSeq -> emit DeviceAnomaly(seqRegressed), do NOT ack, reconcile by total only.
   e. Create `deposit` transactions with timeAccuracy = syncedLate, id unique and deterministic (e.g. "dep-<boundDeviceId or 'dev'>-<seq>-<timestampMillis>"), amount = denomination value.
   f. reconcile(): if knownDeviceTotal is null create an `openingBalance` transaction (only if the amount != 0); otherwise if delta != 0 create an `adjustment` transaction (note mentions gapSize if any) and emit ReconciliationApplied. Set knownDeviceTotal = reported total.
   g. PERSIST everything (transactions, known total, lastAckedSeq, lastSyncedAt) in ONE store.save(). ONLY AFTER that succeeds call client.ack(lastNewSeq). If save fails: raise StorageError, do NOT ack.
   h. Update lock and total from the snapshot; emit BalanceChanged / LockChanged as appropriate.
5. Live events (subscribe to client.events):
   - CoinDetected(d, seq): accept ONLY if seq == next(lastAckedSeq). Then: store a deposit (observedLive), knownDeviceTotal += d, persist, then ack(seq), emit CoinReceived. Otherwise (gap, duplicate, or no baseline yet) ignore it and schedule ONE synchronize() (debounce concurrent requests).
   - TotalReported(T): if knownDeviceTotal != null and T != knownDeviceTotal and no sync is running -> reconciliation adjustment; update deviceTotal.
   - LockChanged(unsolicited) -> update lock; emit AutoRelocked when locked.
   - PinNotSetDetected -> surface through the changes stream so the controller can update auth state.
   - MalformedLine: count consecutive; at 3 in a row schedule synchronize(); reset the counter on any valid line.
6. redeemGoal(goalId, pin): preconditions: goal active, 0 < allocatedAmount <= deviceTotal (else the proper SmartSaveError). Remember K0 = knownDeviceTotal. client.unlock(pin, allocatedAmount). On success: negative `redemption` transaction (goalId set, userAction), goal -> redeemed (redeemedAt), knownDeviceTotal = K0 - amount, persist. On ProtocolError.commandTimeout: run synchronize(); if the reported total == K0 - amount treat as success; if == K0 treat as "not executed" and rethrow the timeout; otherwise emit DeviceAnomaly(unexpectedState). NEVER call unlock twice.
7. adjustBalance(pin, newTotal, note): client.adjustTotal, create `adjustment` (amount = newTotal - K0, userAction), knownDeviceTotal = newTotal, persist, then synchronize() to confirm.
8. Goals: createGoal, updateGoal(name/target; target may not drop below allocated), deleteGoal (cancels; releases allocation), allocateToGoal (amount <= available; positive), releaseFromGoal. Emit GoalReached when allocated crosses target. Persist after every change. Goals never touch the device.
9. device binding: `bindDevice(id)`: first connect stores boundDeviceId; a different id throws SmartSaveStateError.deviceMismatch until resetLocalData() is called.
10. statistics.dart: pure functions over a transaction list: perDayTotals, weekly, monthly, highestDay, averagePerDay, count; only `deposit` transactions count as savings.
11. getTransactions(TransactionQuery): in-memory filtering, newest first.

ACCEPTANCE CRITERIA (tests use the simulator + ProtocolDeviceClient + InMemoryStore + FakeClock)
- First-ever sync on demo profile: 4 deposits for seq 9..12 + an openingBalance transaction of 1250 - (5+10+1+20) = 1214; lastAckedSeq == 12; the simulator's acked == 12.
- Offline: drop 3 coins with the link down, reconnect, synchronize -> 3 deposits (syncedLate), no adjustment, ack sent.
- 40 coins offline (> 32): synchronize records 32 deposits plus one adjustment equal to the value of the 8 lost coins, gapSize == 8.
- seq wrap: coin seq 65535 then 0 handled as contiguous.
- Duplicate live coin (same seq twice) stored once.
- Live coin with a skipped seq triggers a sync, and the skipped coin ends up stored exactly once.
- Store save failure -> no ACK sent (assert simulator.acked unchanged).
- redeem success; redeem with timeout where the simulator DID apply the unlock -> inferred success; where it did NOT -> timeout rethrown; unlock called exactly once in both cases.
- adjustBalance records the delta; total clamp at 99999 produces a reconciliation adjustment.
- Allocation rules: cannot allocate more than available; overAllocatedBy appears after an adjustBalance lowers the total.
- Statistics: known fixture gives exact per-day totals, highest day, and average.

VERIFY: flutter analyze && flutter test --coverage   (repository/ coverage >= 85%)
````

---

## Prompt 9 — Controller, composition root, public API (completes Mock mode)

Branch `backend/p09-controller` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§2.8, §2.12, §2.13), all prior files

````text
TASK: Implement the UI-facing SmartSaveController, the composition root SmartSaveBackend, and finalize the public barrel. After this prompt the whole backend must work in MOCK mode end to end.

ALLOWED FILES:
- lib/src/backend.dart
- lib/src/application/smartsave_controller.dart
- lib/src/transport/ble/ble_readiness.dart  (ONLY the abstract `BluetoothReadiness` enum and `BluetoothReadinessProvider` interface + a `MockReadinessProvider`; no plugin imports)
- lib/smartsave_backend.dart  (final public exports)
- test/application/ (new)
DO NOT TOUCH: anything else. BLE mode must throw SmartSaveStateError.invalidOperation('BLE mode arrives in Prompt 10') for now.

REQUIREMENTS
1. SmartSaveBackend.create(SmartSaveConfig, {Clock? clock, SmartSaveStore? store, SmartSaveLogger? logger}) wires: Clock, logger, FakeDeviceSimulator(profile from config), MockTransport, ProtocolCodec, ProtocolDeviceClient, store (InMemoryStore if none), DefaultSmartSaveRepository, SmartSaveController. Exposes `initialize()`, `controller`, `mockControls` (null outside mock mode), `dispose()`.
2. SmartSaveController extends ChangeNotifier. It holds ONE immutable SmartSaveState and exposes `state`, `Stream<SmartSaveEvent> events`, and these methods, ALL returning Future<ActionResult<T>> and NEVER throwing (catch SmartSaveError; set state.lastError; emit ErrorRaised; return ActionFailure):
   ensureBluetoothReady, scan, connect(bank), reconnectLast, disconnect, setInitialPin, login, logout, changePin, sync, createGoal, updateGoal, deleteGoal, allocateToGoal, releaseFromGoal, redeemGoal, lockBank, adjustBalance, resetLocalData; plus sync getters/methods: getTransactions(query), summary, statistics(range).
3. State machine:
   - connect: link connecting -> transport.connect -> handshaking -> client.handshake -> ready; after handshake auth = pinNotSet (if the Bank has no PIN) or loggedOut. If config.autoSyncOnConnect, synchronize() automatically.
   - login(pin): client.authenticate; success -> auth loggedIn and keep the PIN in a private in-memory field; AuthError.lockedOut -> auth lockedOut with lockoutEndsAt, and flip back to loggedOut when the Clock passes it (provide a lightweight check on read or a timer).
   - setInitialPin(pin): client.setInitialPin; success -> loggedIn.
   - changePin: uses the stored session PIN as old PIN if not supplied; on success replace the stored PIN.
   - logout, disconnect, link loss: CLEAR the stored PIN; auth -> loggedOut; keep cached balance/history.
   - Privileged actions (redeemGoal, adjustBalance, changePin) return ActionFailure(AuthError.notAuthenticated) unless auth == loggedIn. lockBank needs no login. Goal CRUD/allocate needs no login.
   - PinNotSetDetected (e.g. bank factory-reset) -> auth pinNotSet and clear the stored PIN.
   - First successful connect binds the device id; a different id -> ActionFailure(deviceMismatch).
   - Rebuild state from the repository `changes` stream and client link events; notify listeners on every change; forward repository events to `events`.
4. ensureBluetoothReady in mock mode returns ready.
5. Public barrel exports (and nothing else): SmartSaveBackend, SmartSaveController, SmartSaveConfig/Mode/SimulatorProfileName, SmartSaveState, SmartSaveEvent subclasses, all models, ActionResult*, SmartSaveError*, BluetoothReadiness, MockControls, DiscoveredBank, TransactionQuery, SavingsStatistics. NOT exported: protocol, transport internals, device client, repository, store implementations.
6. dispose() cancels every subscription and timer.

ACCEPTANCE CRITERIA (use mock mode, FakeClock, InMemoryStore)
- End-to-end test: create backend (demo profile) -> scan -> connect -> state ready & loggedOut & deviceTotal 1250 -> login("1234") -> loggedIn -> mockControls.dropCoin(php5) -> deviceTotal 1255 and a CoinReceived event -> createGoal(300) -> allocateToGoal(300) -> redeemGoal -> state.lock unlocked, deviceTotal 955, goal redeemed, a negative transaction in history -> AutoRelocked event after advancing the clock 30 s.
- Fresh profile: connect -> pinNotSet -> setInitialPin("4321") -> loggedIn.
- redeemGoal before login -> ActionFailure(notAuthenticated) with NO command sent to the simulator.
- Wrong PIN x3 -> auth lockedOut with lockoutEndsAt = now + 30 s.
- simulateLinkLoss -> link disconnected, auth loggedOut, PIN cleared (assert a later redeem fails notAuthenticated), cached balance still readable.
- No public method throws (add a test that calls each one in an invalid state).
- `grep -R "package:smartsave_backend/src" test/` is not required, but lib/smartsave_backend.dart must contain only the exports listed above.

VERIFY: flutter analyze && flutter test
````

*After:* update `CHANGELOG.md`, tag **`backend-v0.1.0`** → **Handoff 1**. Members 2–3: `flutter run --dart-define=SMARTSAVE_MODE=mock`.

---

## Prompt 10 — Real HM-10 BLE transport (Modes 2 & 3)

Branch `backend/p10-ble-transport` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (§1.8 D2, §2.10), `device_transport.dart`, `line_assembler.dart` · **Requires decision D2**

````text
TASK: Implement the real Bluetooth transport for the HM-10 and wire BLE mode into the composition root. Hardware is not available to you; structure the code so all logic is unit-testable with a fake gateway.

ALLOWED FILES:
- packages/smartsave_backend/pubspec.yaml  (add ONLY: flutter_reactive_ble, permission_handler)
- lib/src/transport/ble/ble_gateway.dart, reactive_ble_gateway.dart, hm10_ble_transport.dart, hm10_constants.dart, ble_permissions.dart
- lib/src/transport/ble/ble_readiness.dart  (extend with the real provider if needed)
- lib/src/backend.dart  (replace the BLE-mode placeholder with real wiring)
- app/android/app/src/main/AndroidManifest.xml  (permissions block only)
- app/ios/Runner/Info.plist  (one key only)
- test/transport/ble/ (new, uses a hand-written FakeBleGateway)
DO NOT TOUCH: protocol, device client, repository, controller (except nothing), models.

REQUIREMENTS
1. ble_gateway.dart: a thin abstract interface over the plugin: statusStream (poweredOff/unauthorized/unsupported/ready), scan(namePrefixes, timeout), connect(deviceId, timeout) -> connection-state stream, discover & verify service/characteristic, notifications stream of List<int>, writeWithoutResponse(List<int>), disconnect. ONLY reactive_ble_gateway.dart and ble_permissions.dart may import flutter_reactive_ble / permission_handler.
2. hm10_constants.dart: service FFE0, characteristic FFE1 (taken from SmartSaveConfig), write chunk size = ProtocolLimits.maxBleWriteBytes (20), inter-chunk delay 20 ms, connect timeout 10 s.
3. Hm10BleTransport implements DeviceTransport: scan by configurable name prefixes (default 'SmartSave','HMSoft') returning DiscoveredBank; connect -> verify FFE0/FFE1 (else ConnectionError.serviceNotFound) -> subscribe to notifications -> feed bytes to LineAssembler -> `lines`; writeLine appends '\n', splits into <=20-byte chunks, writes them sequentially with the inter-chunk delay, never concurrently; map disconnects to TransportState.disconnected and ConnectionError.connectionLost; dispose releases everything.
4. ble_permissions.dart: BluetoothReadinessProvider implementation: request bluetoothScan, bluetoothConnect and locationWhenInUse via permission_handler; treat denied location as non-fatal when bluetoothScan is granted (it is only needed on Android 11 and below); combine with the gateway's adapter status to return BluetoothReadiness {ready, bluetoothOff, permissionDenied, permanentlyDenied, unsupported}. Do not add any other package for SDK-version detection.
5. Android manifest (inside <manifest>): BLUETOOTH_SCAN with android:usesPermissionFlags="neverForLocation"; BLUETOOTH_CONNECT; BLUETOOTH, BLUETOOTH_ADMIN and ACCESS_FINE_LOCATION each with android:maxSdkVersion="30". iOS Info.plist: NSBluetoothAlwaysUsageDescription with a short explanation string.
6. backend.dart: BLE mode wires Hm10BleTransport + ReactiveBleGateway + the real readiness provider; remove the temporary placeholder error. Mock mode must be unchanged.
7. Note in dartdoc and in a comment in hm10_constants.dart that FFE0/FFE1 and the advertised name are assumptions to verify on the real module (HM-10 clones vary).

ACCEPTANCE CRITERIA (with FakeBleGateway)
- A 45-byte line is written as 20+20+5-byte chunks in order, newline included, and chunks never interleave when two writeLine calls are issued concurrently.
- Notification chunks "COIN:5," then "1\nTOT" then "AL:5\n" produce lines "COIN:5,1" and "TOTAL:5".
- Missing FFE1 -> ConnectionError.serviceNotFound.
- Gateway disconnect -> transport state disconnected and `lines` stops; no unhandled exceptions.
- Adapter off -> readiness bluetoothOff; denied -> permissionDenied; permanently denied -> permanentlyDenied.
- `grep -R "flutter_reactive_ble\|permission_handler" packages/smartsave_backend/lib` matches only the two allowed files.
- flutter analyze passes in BOTH packages/smartsave_backend and app/.

VERIFY: flutter pub get && flutter analyze && flutter test   (then a debug build of app/ compiles: `cd app && flutter build apk --debug`)
````

*After (you, manual):* hardware test T-1, T-2 from the checklist.

---

## Prompt 11 — Resilience and error handling pass

Branch `backend/p11-resilience` · Attach: P6, P8, P9 files, `SMARTSAVE_BACKEND_PLAN.md` (§2.11)

````text
TASK: Harden failure handling across the backend. Do not add features; make existing behaviour robust and observable.

ALLOWED FILES:
- lib/src/diagnostics/raw_traffic_log.dart
- lib/src/application/connection_supervisor.dart
- lib/src/application/smartsave_controller.dart, lib/src/device/protocol_device_client.dart, lib/src/repository/default_smartsave_repository.dart  (targeted fixes only; list each change in your summary)
- lib/src/backend.dart  (wiring only)
- lib/smartsave_backend.dart  (export RawTrafficEntry only)
- test/resilience/ (new)

REQUIREMENTS
1. RawTrafficLog: ring buffer of the last 200 entries {timestamp, direction (tx/rx), line}, PIN-redacted with redactPin(); a broadcast Stream and a `snapshot()`. Wire ProtocolDeviceClient.onTraffic into it; expose `controller.rawTraffic` and `controller.recentTraffic()`.
2. ConnectionSupervisor: if config.autoReconnect and the link drops unexpectedly (not via disconnect()), retry connecting to the last bank with exponential backoff 1, 2, 4, 8, then every 30 s, stopping after 10 attempts or when disconnect() is called. Expose pause()/resume() so the UI can call them on app lifecycle changes. After a reconnect: handshake, then synchronize(); the user must log in again (PIN was cleared).
3. Audit every await in the controller: each SmartSaveError becomes an ActionFailure; any unexpected exception is wrapped as a SmartSaveError (use ProtocolError.unexpectedReply or SmartSaveStateError.invalidOperation with `cause`) and never escapes.
4. No hanging futures: disposing the backend or losing the link completes or cancels every pending operation; verify with tests that dispose() during a pending sync() does not leak timers (use fakeAsync and assert no pending timers).
5. Storage failure: a failed save keeps in-memory state, raises ErrorRaised(StorageError), and does NOT send ACK. Next successful synchronize persists the backlog.
6. Malformed-line policy per the repository requirements (3 consecutive -> one resync); verify it is debounced.
7. Duplicate protection: replaying the same transcript of live COIN lines twice stores each seq once.
8. The lockout flip-back (lockedOut -> loggedOut after lockoutEndsAt) is verified with FakeClock.

ACCEPTANCE CRITERIA
- Tests for: supervisor backoff schedule (fakeAsync), pause/resume, manual disconnect cancels retries; RawTrafficLog redaction and capacity; failed-save-no-ACK; dispose with pending commands; malformed flood leads to exactly one resync.
- `flutter analyze` clean; previous tests still pass; no unrelated refactors (summarize each targeted fix).

VERIFY: flutter analyze && flutter test
````

---

## Prompt 12 — Scenario tests and coverage

Branch `backend/p12-scenario-tests` · Attach: all backend files

````text
TASK: Add end-to-end scenario tests that exercise the whole stack in mock mode through the PUBLIC API only, and close coverage gaps. Do not change production code unless a test exposes a real bug; if so, make the smallest fix and list it.

ALLOWED FILES: test/scenarios/ (new), test/support/ (helpers), and minimal fixes in lib/src/** only if a scenario exposes a bug (list each).

Every scenario imports ONLY package:smartsave_backend/smartsave_backend.dart and testing.dart, uses FakeClock + fakeAsync + InMemoryStore + MockControls, and has a descriptive name:
 A. First run, fresh bank: scan, connect, setInitialPin, sync, drop coins of each denomination, history and balance match.
 B. App closed while coins are dropped: restart the backend with the SAME store, reconnect, offline coins appear exactly once.
 C. More than 32 offline coins: reconciliation adjustment equals the lost value; ReconciliationApplied event emitted.
 D. Sequence wrap at 65535 -> 0 across a restart.
 E. Wrong PIN lockout then recovery after 30 s.
 F. Goal lifecycle: create, allocate, reach target (GoalReached), redeem, history shows redemption, balance drops, auto-relock event.
 G. Redeem when the link drops mid-command: balance inferred correctly after reconnect; unlock was sent exactly once.
 H. adjustBalance after a manual recount; allocations over the new total show overAllocatedBy.
 I. PIN change, then login with the old PIN fails and the new one works.
 J. Factory-reset bank while the app thinks a PIN exists: AUTH:NEW detected, auth becomes pinNotSet, no crash, DeviceAnomaly or reconciliation surfaced.
 K. Malformed lines injected via mockControls.injectRawLine never change state or throw.
 L. Total clamp at 99,999.
 M. Switching banks: a different device id returns deviceMismatch until resetLocalData().
 N. Controller methods never throw in any state (table-driven over all methods x states).

ACCEPTANCE CRITERIA
- All scenarios pass deterministically (no real sleeps; run the suite 3 times).
- `flutter test --coverage` -> protocol/, device/, repository/ each >= 85% line coverage; report the numbers.
- Summarize any production fixes.

VERIFY: flutter analyze && flutter test --coverage
````

---

## Prompt 13 — Documentation and repo hygiene

Branch `docs/p13-documentation` · Attach: everything

````text
TASK: Write the handoff documentation and repository hygiene files. Documentation must describe what the code ACTUALLY does; read the code and the stub before writing. Do not change any code.

ALLOWED FILES:
- README.md (repo root)
- docs/ARCHITECTURE.md, PROTOCOL.md, BACKEND_API.md, HARDWARE_TESTING.md
- packages/smartsave_backend/README.md, CHANGELOG.md
- .github/CODEOWNERS, .github/pull_request_template.md, .github/ISSUE_TEMPLATE/backend_request.md, .github/workflows/ci.yml
DO NOT TOUCH: any .dart, .ino, or pubspec file.

REQUIREMENTS
1. README.md: what SmartSave is, repo layout, quick start for UI developers (`flutter pub get`, `flutter run --dart-define=SMARTSAVE_MODE=mock`), links to the four docs, the three operating modes, team ownership.
2. docs/PROTOCOL.md: generated from smartsave_stub.ino: every inbound and outbound line, replies, unsolicited lines, limits, auth model (stateless; PIN on every privileged command), ACK semantics, replay buffer size, USB-only commands, and the golden transcript explained. Mark any statement not verifiable from the stub as an assumption.
3. docs/ARCHITECTURE.md: layer diagram, responsibilities, state vs events, reconciliation rules (balance = last TOTAL; COIN never changes balance; ACK contiguous after persist), decisions D1-D5, limitations U1-U7, frontend/backend boundary rules, dependency list.
4. docs/BACKEND_API.md (the file UI developers read): every public symbol exported from lib/smartsave_backend.dart, grouped (setup, connection, auth, sync/data, goals, bank control, state fields, events, errors with their codes and suggested UI handling). Include: a complete copy-paste example that creates the backend in mock mode, listens to state and events, logs in, drops a coin via mockControls and redeems a goal; a table "UI should do X when state is Y"; how to switch to BLE; Android/iOS permission setup; the rule that UI never touches Bluetooth or protocol strings.
5. docs/HARDWARE_TESTING.md: Mode 1/2/3 explained; component bring-up order (HM-10 first, then IR sensors, LCD, servo, buzzer); how to run the golden transcript on the real stub through the Arduino Serial Monitor (115200 baud, newline) and what to expect (the stub mirrors lines as "TX> ..." / "RX< ..."); HM-10 verification with a generic BLE app (rename module, confirm FFE0/FFE1, notify on, write a line); the hardware test matrix T-1..T-9: T-1 HM-10 renamed and FFE0/FFE1 confirmed; T-2 Android and iPhone connect, handshake, sync, live coins; T-3 coin dropped with no phone connected is replayed on next sync; T-4 three wrong PINs -> WAIT then recovery; T-5 redeem -> servo unlocks, balance drops, auto-relock arrives; T-6 link loss mid-sync recovers; T-7 IR sensors give correct denominations for 50 drops each; T-8 LCD equals app balance after every event; T-9 power bank keeps the bank alive when idle. Each with steps, expected result, and a pass/fail box. Explain how to use controller.recentTraffic() for debugging.
6. .github files: CODEOWNERS per SMARTSAVE_BACKEND_PLAN.md section 3.2 (use placeholder @member1, @member2, @member3); PR template with prompt number, files changed, checklist (analyze, tests, boundary greps); issue template for backend API requests; ci.yml running flutter analyze and flutter test for packages/smartsave_backend and app/, plus a step that fails if `grep -R "package:smartsave_backend/src" app/lib` or a BLE-plugin import in app/lib matches.
7. Keep terminology exactly as in the plan: Bank, Firmware Stub, Simulator, Backend, Mock mode, BLE mode.

ACCEPTANCE CRITERIA
- Every public export is documented in BACKEND_API.md; every protocol line in the stub appears in PROTOCOL.md.
- The BACKEND_API.md example compiles when pasted into a test file (verify by actually adding it temporarily as a test, running it, then deleting it).
- No documentation claims a feature the code does not have.

VERIFY: flutter analyze && flutter test (unchanged), and run the CI grep commands locally.
````

---

## Prompt 14 — Backend handoff verification (audit)

Branch `backend/p14-handoff-audit` · Attach: `SMARTSAVE_BACKEND_PLAN.md` (Phase 5), everything

````text
TASK: Audit the backend against the Handoff Checklist and produce a report. Do not add features. Fix only trivial issues (typos, missing exports, missing dartdoc, docs mismatches) and list every fix. Report everything else as findings.

ALLOWED FILES:
- docs/HANDOFF_AUDIT.md (new)
- packages/smartsave_backend/lib/smartsave_backend.dart (exports only)
- test/handoff/public_api_smoke_test.dart (new)
- docs/*.md (corrections only)
- trivial dartdoc additions in lib/src/**

CHECKS (report PASS/FAIL with evidence for each)
1. flutter pub get, flutter analyze, flutter test --coverage in the package: paste summaries and coverage for protocol/, device/, repository/.
2. Boundary: UI-facing barrel exports exactly what BACKEND_API.md documents (diff the two lists). No lib/src symbol that UI needs is missing; no internal symbol is exported.
3. grep: no flutter_reactive_ble/permission_handler outside the two allowed files; no `package:flutter/material.dart` or widgets.dart in the package; no `UnimplementedError`/TODO/FIXME in lib/src.
4. The golden transcript test runs and passes; confirm the fixture is byte-identical to the one in docs/COPILOT_PROMPTS.md Prompt 4.
5. PROTOCOL.md versus smartsave_stub.ino: list every emit(...) format string in the stub and confirm each appears in PROTOCOL.md and is decoded by ProtocolCodec.decode.
6. Public API smoke test (test/handoff/public_api_smoke_test.dart): imports ONLY the public barrel; runs the full mock flow from BACKEND_API.md; passes.
7. Every public symbol has dartdoc. Every controller method returns ActionResult and never throws (point to the test).
8. Security hygiene: the PIN is never stored, logged, or present in RawTrafficLog entries (point to tests).
9. Documentation completeness versus the Handoff Checklist in SMARTSAVE_BACKEND_PLAN.md Phase 5, section by section.
10. List open risks that need HARDWARE verification (assumptions A1-A7, unresolved U1-U7) and which hardware test (T-1..T-9) resolves each.

OUTPUT: docs/HANDOFF_AUDIT.md with a results table, the list of fixes you made, remaining findings ranked by severity, and a final line: READY FOR HANDOFF or NOT READY (with blockers).

VERIFY: flutter analyze && flutter test
````

*After:* you run hardware tests T-1…T-9, fix findings, tag `backend-v0.2.0`, and use the checklist in `SMARTSAVE_BACKEND_PLAN.md` Phase 5.
