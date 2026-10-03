/// Supplies the current time to backend logic.
abstract interface class Clock {
  /// Returns the current time.
  DateTime now();
}

/// A clock backed by the system time.
final class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A controllable clock for tests and simulations.
final class FakeClock implements Clock {
  /// Creates a fake clock starting at [initialTime].
  FakeClock(this._time);

  DateTime _time;

  @override
  DateTime now() => _time;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) {
    _time = _time.add(duration);
  }
}
