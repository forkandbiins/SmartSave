# SmartSave protocol v1

The Firmware Stub at
[`firmware/smartsave_stub/smartsave_stub.ino`](../firmware/smartsave_stub/smartsave_stub.ino)
is the protocol authority. Lines are ASCII and newline terminated. The Arduino
USB Serial Monitor runs at **115200 baud**; the HM-10 SoftwareSerial link runs
at **9600 baud**. `\r` is ignored.

## App-to-Bank commands

| Inbound line | Result |
|---|---|
| `HELLO` | `PROTO:1`, then `AUTH:NEW` when no PIN exists or `AUTH:REQ` otherwise. |
| `AUTH:<pin>` | `AUTH:OK`, `AUTH:FAIL`, `AUTH:WAIT`, `AUTH:NEW`, or `ERR:FMT`. |
| `SETPIN:<pin>` | First-time PIN setup; replies `AUTH:OK` or `ERR:FMT`. |
| `SETPIN:<old>,<new>` | Authenticated PIN change; replies `AUTH:OK`, `AUTH:FAIL`, `AUTH:WAIT`, or `ERR:FMT`. |
| `SYNC` | `TOTAL`, `LOCK`, `SEQ`, replayed `COIN` lines, and `SYNC:END`. |
| `ACK:<seq>` | No protocol reply. A valid value advances the cumulative acknowledgement. |
| `LOCK` | Locks the Bank and replies `LOCK:1`. |
| `UNLOCK:<pin>,<amount>` | On success, `TOTAL:<new>` then `LOCK:0`; otherwise an auth, format, or amount error. |
| `ADJ:<pin>,<newTotal>` | On success, `TOTAL:<new>`; otherwise an auth, format, or amount error. |
| `PING` | `PONG`. |
| Any other BLE line | `ERR:CMD`. |

`SIM:<1|5|10|20>` and `FACTORY` are USB-only test helpers. The BLE command
path rejects them with `ERR:CMD`; `SIM` creates a coin and `FACTORY` wipes
EEPROM state when entered through USB.

## Bank-to-App lines

The Bank emits `COIN:<denomination>,<seq>` followed by `TOTAL:<total>` for
each coin. It emits `TOTAL`, `LOCK`, and `SEQ` during `SYNC`, followed by
replayable `COIN` lines and `SYNC:END`. An automatic 30-second relock emits
`LOCK:1`. Successful unlock emits `TOTAL:<new>` and `LOCK:0`; adjustment
emits `TOTAL:<new>`. Authentication and command failures use the replies
listed above.

The USB monitor also mirrors received and transmitted lines as `RX< ...` and
`TX> ...`, plus hardware-stub messages such as `[SERVO]` and `[LCD]`; those
are diagnostics, not BLE protocol payloads. Startup prints
`SmartSave stub ready (protocol v1)`.

## Limits and authentication

- Protocol version: `1`.
- PIN: exactly four decimal digits.
- Total: `0..99999`.
- Sequence: `uint16`, wrapping from `65535` to `0`.
- At most 32 unacknowledged coins are replayable.
- Three failed PIN checks cause a 30-second lockout and `AUTH:WAIT`.
- Outbound Bank payloads are at most 19 characters plus newline.
- The reader accepts content up to 23 characters; longer input is discarded
  until its newline.
- Valid denominations are `1`, `5`, `10`, and `20`.

Authentication is stateless. The Bank does not establish a session: every
privileged command (`UNLOCK`, `ADJ`, and PIN change) carries the PIN. The
Backend keeps a verified PIN only in memory to issue later commands; it never
persists or logs it.

`ACK` is cumulative and has no reply. `ACK:9` means all contiguous sequence
numbers through 9 are persisted and acknowledged. The Backend sends ACK only
after persistence and only through a contiguous sequence. Coins older than
the final 32 unacknowledged entries are lost from the replay buffer; the
authoritative `TOTAL` remains available for reconciliation.

## Golden transcript

[`test/fixtures/stub_transcript.txt`](../packages/smartsave_backend/test/fixtures/stub_transcript.txt)
is the executable conformance transcript. `>` means App-to-Bank, `<` means
Bank-to-App, `@usb` is a USB-only helper, `@wait` advances time, `@drain`
discards output, and `xN` repeats a command. It covers fresh PIN setup,
authentication, coin replay and cumulative ACK, unlock/lockout, adjustment,
PIN change, malformed/unknown input, and the 32-coin replay limit.

## Assumptions

The stub verifies the line protocol but not the physical BLE module. Service
`FFE0`, characteristic `FFE1`, HM-10 advertised names, and BLE notification /
write-without-response behavior are hardware assumptions that must be verified
on the real module; HM-10 clones vary.
