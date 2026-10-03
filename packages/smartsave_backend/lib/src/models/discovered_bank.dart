/// A bank discovered during BLE scanning.
final class DiscoveredBank {
  /// Creates a discovered bank.
  const DiscoveredBank({required this.id, required this.name, this.rssi});

  /// Platform device identifier.
  final String id;
  /// Advertised device name.
  final String name;
  /// Received signal strength, when available.
  final int? rssi;

  /// Returns a copy with selected values replaced.
  DiscoveredBank copyWith({String? id, String? name, int? rssi}) =>
      DiscoveredBank(id: id ?? this.id, name: name ?? this.name, rssi: rssi ?? this.rssi);

  @override
  bool operator ==(Object other) =>
      other is DiscoveredBank && id == other.id && name == other.name && rssi == other.rssi;

  @override
  int get hashCode => Object.hash(id, name, rssi);

  @override
  String toString() => 'DiscoveredBank(id: $id, name: $name)';
}
