# smartsave_backend

The SmartSave Backend is a Flutter package with no UI. It provides the public
Controller, immutable state, events, typed errors, Mock mode, and BLE mode for
the SmartSave Bank. See the repository-level
[`docs/BACKEND_API.md`](../../docs/BACKEND_API.md) for the complete UI
handoff.

```bash
flutter pub get
flutter analyze
flutter test
```

The Firmware Stub is the protocol source of truth:
[`firmware/smartsave_stub/smartsave_stub.ino`](../../firmware/smartsave_stub/smartsave_stub.ino).
