/// Centralized test/debug flags for development.
/// Set to false before production release.
class TestFlags {
  TestFlags._();

  /// Set to true to quickly test the pro badge design (green, PRO X/Y, no icon)
  static const bool forceProForTest = false;

  /// Set to true to use sample songs instead of real generation.
  /// Uses public sample audio URLs which may not always be available.
  static const bool testMode = false;

  /// Force RevenueCat test store API key (also auto-enabled in debug builds).
  /// Use for profile builds when testing purchases without production keys.
  static const bool useRevenueCatTestKey = false;
}
