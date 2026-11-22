import 'package:shared_preferences/shared_preferences.dart';

/// A recorded consent decision (round 4): the version of the consent flow
/// the user answered, when, and the granular choices. Written by every
/// savePrivacyPreferences call; read by the splash ConsentGate and synced
/// to the backend (PATCH /auth/me) for signed-in users.
class ConsentRecord {
  const ConsentRecord({
    required this.version,
    required this.acceptedAt,
    required this.analyticsEnabled,
    required this.profilingEnabled,
  });

  final int version;

  /// ISO-8601 UTC timestamp of the decision; null for records written by
  /// builds that predate the timestamp key.
  final String? acceptedAt;
  final bool analyticsEnabled;
  final bool profilingEnabled;

  /// The PATCH /auth/me `consent` body shape (backend allow-list field).
  Map<String, dynamic> toSyncJson() => {
        'version': version,
        'analytics': analyticsEnabled,
        'profiling': profilingEnabled,
        if (acceptedAt != null) 'updatedAt': acceptedAt,
      };
}

/// Service to manage onboarding state and privacy preferences using SharedPreferences
class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyPrivacyAccepted = 'privacy_accepted';
  static const String _keyAnalyticsEnabled = 'analytics_enabled';
  static const String _keyProfilingEnabled = 'profiling_enabled';
  static const String _keyConsentVersion = 'consent_version';
  static const String _keyConsentTimestamp = 'consent_timestamp';

  /// Bumped when the consent flow's terms materially change; a record with
  /// an older version still counts as "has consented" for the splash gate.
  static const int currentConsentVersion = 1;

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
    // Round 4: every save IS a consent decision — stamp the record
    // (version + timestamp) the splash gate and the backend sync read.
    await _prefs?.setInt(_keyConsentVersion, currentConsentVersion);
    await _prefs?.setString(
      _keyConsentTimestamp,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// The stored consent record, or null when the user has never made a
  /// consent decision on this device.
  Future<ConsentRecord?> consentRecord() async {
    await initialize();
    if (!(_prefs?.getBool(_keyPrivacyAccepted) ?? false)) return null;
    return ConsentRecord(
      version: _prefs?.getInt(_keyConsentVersion) ?? currentConsentVersion,
      acceptedAt: _prefs?.getString(_keyConsentTimestamp),
      analyticsEnabled: _prefs?.getBool(_keyAnalyticsEnabled) ?? false,
      profilingEnabled: _prefs?.getBool(_keyProfilingEnabled) ?? false,
    );
  }

  /// True once any consent decision has been recorded on this device.
  Future<bool> hasConsentRecord() async => (await consentRecord()) != null;

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
    await _prefs?.remove(_keyConsentVersion);
    await _prefs?.remove(_keyConsentTimestamp);
  }
}

