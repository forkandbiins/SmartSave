# Changelog

## backend-v0.1.0 — Handoff 1

### Added
- UI-facing SmartSaveController
- SmartSaveBackend composition root
- Complete Mock-mode end-to-end workflow
- Mock Bluetooth readiness provider
- Public SmartSave backend API
- Controller state and event propagation
- Authentication and session handling
- Goal management and redemption
- Synchronization and transaction/history access
- Mock-mode integration tests

### Backend Foundation
- Device protocol and command handling
- Mock transport and simulator
- Device client and command queue
- Local persistence
- Repository synchronization and reconciliation
- Statistics and transaction management

### Verification
- flutter analyze passes with no issues
- 55 backend tests passing
- Mock-mode controller workflow verified end-to-end
