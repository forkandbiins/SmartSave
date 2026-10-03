# Hardware testing

## Modes

1. **Mock mode:** the Backend uses the Dart Simulator and needs no hardware.
2. **Hardware testing:** the Backend uses BLE mode with the Firmware Stub and
   a partially assembled Bank.
3. **Final system:** the same BLE mode talks to the finished Bank with IR
   sensors, LCD, servo, buzzer, and power bank.

## Bring-up order

Bring up one component at a time: HM-10 first, then IR sensors, LCD, servo,
buzzer, and finally the complete Bank. The Firmware Stub needs only the HM-10;
its hardware functions are diagnostic seams.

## Firmware Stub and golden transcript

Upload `firmware/smartsave_stub/smartsave_stub.ino`. Open Arduino Serial
Monitor at **115200 baud** with **newline** line ending. Type the golden
transcript steps manually from
`packages/smartsave_backend/test/fixtures/stub_transcript.txt`, or run the
equivalent sections in order. The stub mirrors BLE traffic to USB as
`TX> ...` for Bank-to-phone output and `RX< ...` for received input. USB-only
`SIM:<1|5|10|20>` creates a coin and `FACTORY` resets EEPROM state.

Expect `PROTO:1` and `AUTH:NEW` after `HELLO` on a fresh Bank, `COIN` then
`TOTAL` for coins, `SYNC` replay in sequence order, no reply to valid `ACK`,
`AUTH:WAIT` after three wrong PINs, and `LOCK:1` after the 30-second
auto-relock.

## HM-10 verification

With a generic BLE app:

1. Rename the module to a SmartSave-prefixed name.
2. Confirm service `FFE0` and characteristic `FFE1`.
3. Enable notifications on `FFE1`.
4. Write a newline-terminated `HELLO`.
5. Confirm `PROTO:1` and `AUTH:NEW` or `AUTH:REQ`.

HM-10 clones vary; treat these UUIDs and advertised names as assumptions until
the actual module is verified.

## Hardware test matrix

For each test, record the result in the box.

### T-1 — HM-10 identity and characteristics

**Steps:** Rename the HM-10, scan from a generic BLE app, inspect services,
and confirm `FFE0`/`FFE1` with notifications enabled.

**Expected:** The module advertises the configured name and accepts a
newline-terminated write while notifications deliver replies.

**Result:** [ ] Pass  [ ] Fail

### T-2 — mobile connection and live operation

**Steps:** Connect from Android and iPhone, complete handshake and sync, then
drop coins while each phone is connected.

**Expected:** Both platforms connect, show the authoritative total, and
receive live denomination/history events.

**Result:** [ ] Pass  [ ] Fail

### T-3 — offline replay

**Steps:** Disconnect the phone, drop a coin, reconnect, and synchronize.

**Expected:** The offline coin is replayed on the next sync exactly once.

**Result:** [ ] Pass  [ ] Fail

### T-4 — PIN lockout

**Steps:** Enter three wrong PINs, attempt the correct PIN during lockout, wait
30 seconds, and try again.

**Expected:** The Bank returns `AUTH:WAIT`; the correct PIN works after the
lockout expires.

**Result:** [ ] Pass  [ ] Fail

### T-5 — redemption and auto-relock

**Steps:** Allocate a goal, redeem it, observe the servo, then wait 30 seconds.

**Expected:** The servo unlocks, `TOTAL` decreases, and unsolicited `LOCK:1`
arrives after auto-relock.

**Result:** [ ] Pass  [ ] Fail

### T-6 — link loss during sync

**Steps:** Interrupt the BLE link during synchronization, reconnect, and sync
again.

**Expected:** The Controller reports a disconnected link, retains cached data,
and the next sync completes without duplicate transactions.

**Result:** [ ] Pass  [ ] Fail

### T-7 — denomination sensing

**Steps:** Drop 50 samples through each denomination hole.

**Expected:** Every sample is reported as the correct denomination.

**Result:** [ ] Pass  [ ] Fail

### T-8 — LCD balance

**Steps:** Compare the LCD after every coin, redemption, and adjustment with
the app's `state.deviceTotal`.

**Expected:** LCD and app balance match after every event.

**Result:** [ ] Pass  [ ] Fail

### T-9 — idle power

**Steps:** Leave the Bank idle on the Anker Nano power bank and observe it
through a representative idle interval.

**Expected:** The power bank keeps the Bank alive and the next BLE connection
still handshakes.

**Result:** [ ] Pass  [ ] Fail

## Debugging traffic

The Controller exposes `recentTraffic()` and the `rawTraffic` stream. Entries
contain timestamp, direction, and PIN-redacted line text. Capture the snapshot
after a failed test, but never log or share the original PIN.
