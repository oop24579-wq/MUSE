import 'api/api_client.dart';
import 'onboarding_service.dart';

/// Round 4: best-effort sync of the local consent record to the backend
/// (PATCH /auth/me `consent` allow-list field) once a session exists, so
/// the account carries the same consent state as the device.
///
/// The local record stays the source of truth: any failure (offline,
/// guest session churn) is swallowed and the sync simply retries on the
/// next token exchange. Called from AuthService.exchangeFirebaseToken —
/// the single funnel every sign-in and session restore passes through.
class ConsentSyncService {
  ConsentSyncService._();

  static Future<void> syncIfPossible() async {
    try {
      final record = await OnboardingService.instance.consentRecord();
      if (record == null) return;
      await ApiClient.instance.patch(
        '/auth/me',
        data: {'consent': record.toSyncJson()},
      );
    } catch (_) {
      // Best-effort by design — see class doc.
    }
  }
}
