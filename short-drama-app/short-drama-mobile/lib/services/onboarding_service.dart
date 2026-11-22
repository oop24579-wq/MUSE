import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding state and privacy preferences using SharedPreferences
class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyPrivacyAccepted = 'privacy_accepted';
  static const String _keyAnalyticsEnabled = 'analytics_enabled';
  static const String _keyProfilingEnabled = 'profiling_enabled';

  static OnboardingService? _instance;
  static OnboardingService get instance {
    _instance ??= OnboardingService._();
    return _instance!;
  }

  OnboardingService._();

  SharedPreferences? _prefs;

  /// Initialize the service - must be called before using any other methods
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if onboarding has been completed
  Future<bool> isOnboardingCompleted() async {
    await initialize();
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> setOnboardingCompleted() async {
    await initialize();
    await _prefs?.setBool(_keyOnboardingCompleted, true);
  }

  /// Check if privacy has been accepted
  Future<bool> isPrivacyAccepted() async {
    await initialize();
    return _prefs?.getBool(_keyPrivacyAccepted) ?? false;
  }

  /// Save privacy preferences
  Future<void> savePrivacyPreferences({
    required bool accepted,
    bool analyticsEnabled = false,
    bool profilingEnabled = false,
  }) async {
    await initialize();
    await _prefs?.setBool(_keyPrivacyAccepted, accepted);
    await _prefs?.setBool(_keyAnalyticsEnabled, analyticsEnabled);
    await _prefs?.setBool(_keyProfilingEnabled, profilingEnabled);
  }

  /// Accept all privacy preferences
  Future<void> acceptAllPrivacy() async {
    await savePrivacyPreferences(
      accepted: true,
      analyticsEnabled: true,
      profilingEnabled: true,
    );
  }

  /// Refuse non-essential privacy preferences (only technical enabled)
  Future<void> refuseNonEssentialPrivacy() async {
    await savePrivacyPreferences(
      accepted: true,
      analyticsEnabled: false,
      profilingEnabled: false,
    );
  }

  /// Get analytics enabled status.
  /// Returning users who completed onboarding before consent prefs existed
  /// are treated as consented (Continue = accept).
  Future<bool> isAnalyticsEnabled() async {
    await initialize();
    if (_prefs?.getBool(_keyAnalyticsEnabled) ?? false) return true;
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Get profiling enabled status
  Future<bool> isProfilingEnabled() async {
    await initialize();
    return _prefs?.getBool(_keyProfilingEnabled) ?? false;
  }

  /// Reset all onboarding data (for testing)
  Future<void> reset() async {
    await initialize();
    await _prefs?.remove(_keyOnboardingCompleted);
    await _prefs?.remove(_keyPrivacyAccepted);
    await _prefs?.remove(_keyAnalyticsEnabled);
    await _prefs?.remove(_keyProfilingEnabled);
  }
}

