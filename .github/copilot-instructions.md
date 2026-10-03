# SmartSave — Copilot repository instructions

(Place this file at `.github/copilot-instructions.md`.)

## Project
SmartSave is an Arduino Uno + HM-10 (BLE) + Flutter smart coin bank for new Philippine coins (₱1, ₱5, ₱10, ₱20). This repo contains the Flutter **backend package** (`packages/smartsave_backend`), the Flutter **UI app** (`app/`), and Arduino firmware (`firmware/`).

## Sources of truth (read before coding)
1. `firmware/smartsave_stub/smartsave_stub.ino` — the exact wire protocol.
2. `docs/PROTOCOL.md`, `docs/ARCHITECTURE.md`, `SMARTSAVE_BACKEND_PLAN.md`.
Never invent protocol commands, fields, or replies. If the stub and a document disagree, the stub wins; report the discrepancy.

## Architecture rules (strict)
- Layers, top to bottom: `SmartSaveController` → `SmartSaveRepository` → `DeviceClient` → `ProtocolCodec`/`LineAssembler` → `DeviceTransport` (`MockTransport` | `Hm10BleTransport`). A layer talks only to the layer directly below it.
- The backend package contains **no UI code** (no widgets, no `BuildContext`, no `material.dart`).
- Only files under `lib/src/transport/ble/` may import a BLE plugin or `permission_handler`.
- Only `lib/smartsave_backend.dart` and `lib/testing.dart` are public. Everything else lives in `lib/src/`.
- The Arduino is the authority for the balance. **The balance is the last `TOTAL` received. `COIN` never changes the balance**; it only creates a history record.
- Privileged commands (`UNLOCK`, `ADJ`, `SETPIN` change) carry the PIN. The PIN is kept in memory only, is never persisted, and is **never logged** (redact as `****`).
- Never auto-retry `UNLOCK`.
- Only ACK contiguous sequence numbers, and only after persisting them.
- Sequence numbers are `uint16` and wrap; always use `sequence_math.dart`.

## Dart/Flutter rules
- Dart 3, null safety, `sealed`/`final` classes, immutable models with `copyWith`. **No code generation** (no freezed, json_serializable, build_runner). No `equatable`, no `mocktail`; write small fakes by hand.
- No state-management package inside the backend (no Provider/Riverpod/Bloc). Use `ChangeNotifier` and `Stream`.
- Actions exposed to the UI return `Future<ActionResult<T>>` and never throw. Lower layers throw typed `SmartSaveError` subclasses.
- Never use `DateTime.now()` or real `Future.delayed` in logic; use the injected `Clock`. Tests must not sleep.
- Malformed protocol lines are logged and ignored; they never throw and never change state.
- Do not add dependencies unless the prompt names them.

## Working rules
- **Only create or modify the files listed in the prompt.** If you believe another file must change, stop and explain why instead of changing it.
- Do not rewrite or reformat unrelated code. Do not "improve" earlier work.
- Do not implement features from later prompts.
- After every change run `flutter analyze` and `flutter test` in the package and fix what you broke.
- Add dartdoc comments to every public symbol.
- Finish each task with a short summary: files changed, tests added, anything you could not do.
