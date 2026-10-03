import '../errors/smartsave_error.dart';

/// A coin denomination supported by the SmartSave firmware.
enum Denomination {
  /// One peso.
  php1(1),
  /// Five pesos.
  php5(5),
  /// Ten pesos.
  php10(10),
  /// Twenty pesos.
  php20(20);

  const Denomination(this.value);

  /// The denomination in pesos.
  final int value;

  /// Returns the denomination for [value], or null when unsupported.
  static Denomination? tryFromValue(int value) {
    for (final denomination in Denomination.values) {
      if (denomination.value == value) return denomination;
    }
    return null;
  }

  /// Returns the denomination for [value], or throws for unsupported values.
  static Denomination fromValue(int value) =>
      tryFromValue(value) ?? (throw InvalidArgumentError());
}
