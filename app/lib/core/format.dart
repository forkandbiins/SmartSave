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

/// Formats a [time] as `22:42` (24-hour clock, zero-padded).
String formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Formats a [time] as `HH:mm, mm-dd-yy` (24-hour clock).
///
/// Always uses a fixed date format; no "Today"/"Yesterday"/weekday wordings.
String formatDateTime(DateTime time, DateTime now) {
  final local = time.toLocal();
  final clock = formatTime(local);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final year = (local.year % 100).toString().padLeft(2, '0');
  return '$clock, $month-$day-$year';
}

/// Formats a signed peso [amount] with an explicit sign for the dashboard.
/// Deposits show `+₱20`; non-positive amounts follow [formatPeso].
String formatSignedPeso(int amount) =>
    amount > 0 ? '+${formatPeso(amount)}' : formatPeso(amount);
