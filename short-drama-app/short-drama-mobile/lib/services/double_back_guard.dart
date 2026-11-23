/// "Press back again to exit" window logic (round 5, item 5b),
/// extracted as a pure, clock-injected helper so it is unit-testable.
///
/// Used by the main tab shell: the first back press at the root arms
/// the guard (and the shell shows the hint toast); a second press
/// within [window] confirms the exit.
class DoubleBackGuard {
  DoubleBackGuard({this.window = const Duration(seconds: 2)});

  final Duration window;

  DateTime? _lastPressAt;

  /// Register a back press at [now]. Returns true when this press
  /// should actually exit (i.e. it is the second press inside the
  /// window); false when it merely arms the guard.
  bool registerPress(DateTime now) {
    final last = _lastPressAt;
    if (last == null || now.difference(last) > window) {
      _lastPressAt = now;
      return false;
    }
    _lastPressAt = null;
    return true;
  }

  /// Forget any armed press (e.g. after navigating to another tab).
  void reset() => _lastPressAt = null;

  /// Whether the next press inside the window would exit.
  bool get isArmed => _lastPressAt != null;
}
