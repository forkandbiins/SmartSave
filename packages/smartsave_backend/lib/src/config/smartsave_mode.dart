/// Selects whether the backend uses the simulator or a BLE bank.
enum SmartSaveMode {
  /// Use the in-memory simulator.
  mock,
  /// Use a physical bank over Bluetooth Low Energy.
  ble,
}
