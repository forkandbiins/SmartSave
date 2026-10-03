# SmartSave Backend Handoff Audit

Audit date: 2026-10-03  
Scope: current repository, `packages/smartsave_backend`, the Firmware Stub,
the public barrel, documentation, and the Phase 5 checklist in
`SMARTSAVE_BACKEND_PLAN.md`.

## Results

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Package build, analysis, tests, coverage | **PASS** | `flutter pub get` completed; `flutter analyze` reported no issues; `flutter test --coverage` passed. Coverage: protocol **96.5%** (139/144), device **93.8%** (213/227), repository **95.0%** (323/340). |
| 2 | Public barrel boundary | **FAIL** | The barrel exports the documented production models, controller, backend, errors, readiness types, mock controls, and diagnostics. `BACKEND_API.md` also documents `connectionSupervisor`, but its concrete `ConnectionSupervisor` type is not exported. The barrel does not export internal protocol, transport, device-client, repository, or storage implementation types. |
| 3 | Boundary and forbidden-symbol grep | **PASS** | No `flutter_reactive_ble` or `permission_handler` imports outside the two BLE implementation files; no `material.dart` or `widgets.dart` in package `lib`; no `TODO`, `FIXME`, or `UnimplementedError` in `lib/src`. UI boundary greps also returned no matches. |
| 4 | Golden transcript | **PARTIAL** | The existing simulator conformance test runs the fixture and passes. A byte comparison against the Prompt 4 transcript block found a mismatch (`expected 2047` bytes, `actual 2199` bytes); the fixture has not been proven byte-identical to the prompt source. |
| 5 | Stub protocol fidelity | **PARTIAL** | Every semantic emitted reply is represented in `PROTOCOL.md` and decoded by `ProtocolCodec.decode`. Exact C format strings such as `COIN:%u,%u`, `TOTAL:%lu`, `LOCK:%d`, `PROTO:%d`, and `SEQ:%u` cannot appear literally in the prose protocol because the document describes their rendered wire forms. Real-stub line-by-line execution was not available. |
| 6 | Public API smoke test | **PASS** | Added `test/handoff/public_api_smoke_test.dart`; it imports only the public barrel and passes the documented Mock-mode flow: connect, login, sync, drop coin, create/allocate goal, redeem, and event/history assertions. |
| 7 | Public docs and no-throw actions | **PARTIAL** | `flutter analyze` is clean and the public smoke test passes. Existing application tests cover invalid actions and the scenario suite covers table-driven invalid-state calls. A complete machine-checked audit of every public symbol's dartdoc was not available; `ConnectionSupervisor` remains an undocumented/unexported concrete type from the UI documentation perspective. |
| 8 | PIN security hygiene | **PASS** | `redactPin` tests cover `AUTH`, `UNLOCK`, `ADJ`, and both `SETPIN` forms. Resilience tests verify redaction and 200-entry traffic capacity. Controller session PIN is an in-memory private field; raw traffic stores redacted lines. |
| 9 | Phase 5 documentation completeness | **PARTIAL** | All five requested handoff documents exist, D1-D5 and U1-U7 are recorded, API usage and permissions are documented, and the issue template exists. CI status, tags, independent UI runs, and real hardware evidence are not present in this workspace. |
| 10 | Hardware assumptions and resolution tests | **FAIL / OPEN** | A1-A7 and U1-U7 still require physical verification. The mapping is listed below; no T-1..T-9 execution evidence is committed. |

## Fixes made during this audit

1. Added [public_api_smoke_test.dart](../packages/smartsave_backend/test/handoff/public_api_smoke_test.dart).
   It is a verification test, not a runtime feature, and uses only
   `package:smartsave_backend/smartsave_backend.dart`.
2. No production Dart, protocol, firmware, or dependency changes were made.
3. No existing exports, docs, or implementation symbols were changed during
   the audit because the barrel/documentation discrepancy requires an API
   decision rather than a trivial safe correction.

## Protocol emit audit

The unique `emit(...)` formats found in `smartsave_stub.ino` are:

| Stub format | Rendered protocol family | In `PROTOCOL.md` | `ProtocolCodec.decode` |
|---|---|---:|---:|
| `AUTH:NEW` | `AUTH:NEW` | Yes | Yes |
| `AUTH:FAIL` | `AUTH:FAIL` | Yes | Yes |
| `AUTH:WAIT` | `AUTH:WAIT` | Yes | Yes |
| `ERR:FMT` | `ERR:FMT` | Yes | Yes |
| `COIN:%u,%u` | `COIN:<denomination>,<seq>` | Yes | Yes |
| `TOTAL:%lu` | `TOTAL:<total>` | Yes | Yes |
| `PROTO:%d` | `PROTO:1` | Yes | Yes |
| `AUTH:OK` | `AUTH:OK` | Yes | Yes |
| `LOCK:%d` | `LOCK:0` / `LOCK:1` | Yes | Yes |
| `SEQ:%u` | `SEQ:<seq>` | Yes | Yes |
| `SYNC:END` | `SYNC:END` | Yes | Yes |
| `ERR:AMT` | `ERR:AMT` | Yes | Yes |
| `LOCK:1` | `LOCK:1` | Yes | Yes |
| `PONG` | `PONG` | Yes | Yes |
| `ERR:CMD` | `ERR:CMD` | Yes | Yes |

`FACTORY` additionally prints the USB diagnostic `State wiped.` directly
with `Serial.println`; it is not a Bank-to-App protocol line and is correctly
not decoded by `ProtocolCodec`.

## Remaining findings

### High

1. **Real hardware and Firmware Stub transcript evidence is missing.** The
   checklist requires the golden transcript to be run by hand against the
   real stub over USB and requires T-1 through T-9 evidence. This environment
   has no Arduino, HM-10, Android phone, iPhone, or physical Bank. This blocks
   Handoff 2 and the claim that BLE assumptions are verified.

2. **The golden fixture is not byte-identical to the Prompt 4 source block.**
   The simulator conformance test passes, but the acceptance requirement is
   stronger than semantic conformance. Reconcile the fixture against the
   canonical prompt block before calling the transcript exact.

### Medium

3. **Public API/documentation mismatch for `connectionSupervisor`.**
   `SmartSaveBackend` exposes a public property whose concrete type is an
   internal application class, while the main barrel intentionally does not
   export that class. Either remove the property from the UI handoff surface
   or make its intended public interface explicit in a future API change.

4. **CI green status is not evidenced locally.** The workflow exists and runs
   analysis/tests plus boundary greps, but no GitHub Actions run on `main` was
   inspected in this audit.

5. **The package API example was validated through an equivalent public smoke
   test, not by committing the documentation snippet as a temporary test
   file.** The snippet's listener usage is now valid (`addListener` returns
   `void`), but an exact copy/paste compilation check should be run before
   release.

### Low

6. **Release and team handoff evidence is absent.** The checklist asks for
   `backend-v0.1.0`/`v0.2.0` tags, both UI members to run Mock mode, and a
   green protected `main`. The repository contains the instructions but not
   evidence that those actions occurred.

## Hardware assumptions and resolution matrix

| Assumption / limitation | Meaning | Resolving test |
|---|---|---|
| A1 | HM-10 exposes service `FFE0` and characteristic `FFE1`. | T-1 |
| A2 | Advertised name/prefix is usable after module rename. | T-1 |
| A3 | One phone connects to a Bank at a time. | T-2 |
| A4 | Amounts are whole pesos. | T-2, T-7 |
| A5 | App runs in the foreground; background BLE is out of scope. | T-2 |
| A6 | Android and iOS are both target platforms. | T-2 |
| A7 | BLE writes/notifications may split or merge lines and writes use 20-byte chunks. | T-1, T-2 |
| U1 | No door sensor; physical removal can require recount. | T-5, T-8 |
| U2 | Goals/history are local to one phone. | No hardware test; documented product limitation |
| U3 | Offline timestamps are approximate. | T-3 |
| U4 | Remaining lockout time is not reported by the Bank. | T-4 |
| U5 | Wrong/reset Bank identity detection is limited. | T-2, T-6 |
| U6 | HM-10 behavior while Arduino transmits without a phone is unverified. | T-3 |
| U7 | Power bank may cut output at low load. | T-9 |

## Checklist conclusion

**NOT READY (blockers: real-stub transcript execution, byte-identical
canonical transcript reconciliation, and T-1..T-9 hardware evidence).**
