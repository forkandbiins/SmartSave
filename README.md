# SmartSave

SmartSave is a Philippine coin bank for ₱1, ₱5, ₱10, and ₱20 coins. A
physical **Bank** uses an Arduino and HM-10 Bluetooth module; the Flutter
**Backend** connects to it, synchronizes the authoritative balance, records
history, and manages app-local savings goals. The **Firmware Stub** and
**Simulator** provide the same wire behavior before the finished hardware is
available.

## Repository layout

```text
app/                                  Flutter UI
packages/smartsave_backend/           Flutter Backend package
firmware/smartsave_stub/              Arduino Firmware Stub
docs/                                 Architecture, protocol, API, hardware
SMARTSAVE_BACKEND_PLAN.md             Project plan and ownership rules
```

Start with:

- [Architecture](docs/ARCHITECTURE.md)
- [Protocol](docs/PROTOCOL.md)
- [Backend API](docs/BACKEND_API.md)
- [Hardware testing](docs/HARDWARE_TESTING.md)

## Quick start for UI developers

From `app/`:

```bash
flutter pub get
flutter run --dart-define=SMARTSAVE_MODE=mock
```

The app depends on the Backend through the local path
`../packages/smartsave_backend`. UI code imports only
`package:smartsave_backend/smartsave_backend.dart`; tests may also import
`package:smartsave_backend/testing.dart`.

## Operating modes

The Backend has two runtime modes:

1. **Mock mode** (`SMARTSAVE_MODE=mock`, the default) uses the Dart Simulator.
2. **BLE mode** (`SMARTSAVE_MODE=ble`) uses the HM-10 transport.

The plan calls the BLE deployment stages **Mode 2: Hardware testing** and
**Mode 3: Final system**. They use the same Backend and BLE mode; the
difference is the Bank firmware and hardware maturity, not a third Dart
runtime mode.

## Ownership

Per `SMARTSAVE_BACKEND_PLAN.md`, Member 1 owns the Backend, Arduino integration,
Firmware Stub, and hardware bring-up. Member 2 owns dashboard, balance, goals,
and statistics UI. Member 3 owns history, authentication/PIN, settings,
connection/scan, and shared UI. UI developers request Backend changes through a
`backend-request` issue rather than editing `packages/smartsave_backend`.
