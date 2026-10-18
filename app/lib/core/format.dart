/// Formats a whole-peso amount as `₱1,250`. Negatives are `-₱100`.
String formatPeso(int amount) {
  final isNegative = amount < 0;
  final digits = (isNegative ? -amount : amount).toString();
  final withSeparators = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      withSeparators.write(',');
    }
    withSeparators.write(digits[i]);
  }
  final formatted = '₱$withSeparators';
  return isNegative ? '-$formatted' : formatted;
}
