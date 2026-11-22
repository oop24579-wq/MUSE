/// Round 4: decides whether the explicit consent chain
/// (GettingStarted → PrivacyConsent → PrivacySettings → Login) must run.
///
/// The chain is a FIRST-launch-only gate: it shows when onboarding has not
/// completed, no consent decision has ever been recorded on this device,
/// and there is no session to restore. Anyone else — returning users,
/// users who consented through any completion path, users with a stored
/// session — skips it entirely.
///
/// Pure and side-effect free so the full matrix is unit-testable;
/// SplashScreen feeds it the three live signals.
class ConsentGate {
  const ConsentGate._();

  static bool shouldShowChain({
    required bool onboardingCompleted,
    required bool hasConsentRecord,
    required bool hasSession,
  }) =>
      !onboardingCompleted && !hasConsentRecord && !hasSession;
}
