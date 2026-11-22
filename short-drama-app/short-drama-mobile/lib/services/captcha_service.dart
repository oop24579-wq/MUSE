import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/foundation.dart';
import 'package:drama_now/services/firebase/remote_config_service.dart';

/// Solves a Cloudflare Turnstile challenge and returns a single-use token.
///
/// Auth may require this token for any auth call when CAPTCHA protection
/// is enabled in the project (Authentication → Settings → Bot and Abuse
/// Protection). The token must be passed via `captchaToken:` to the
/// matching an auth call within ~5 minutes of being issued.
///
/// Uses the invisible/headless Turnstile variant — runs an offscreen
/// WebView so no UI is shown and no [BuildContext] is required.
class CaptchaService {
  CaptchaService._();

  static Future<String?> getTurnstileToken() async {
    final rc = RemoteConfigService.instance;
    final siteKey = rc.turnstileSiteKey;
    if (siteKey.isEmpty) {
      debugPrint('⚠️ turnstile_site_key missing in Remote Config');
      return null;
    }

    final turnstile = CloudflareTurnstile.invisible(
      siteKey: siteKey,
        baseUrl: rc.appUrl
    );
    try {
      final token = await turnstile.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('❌ Turnstile returned no token');
        return null;
      }
      return token;
    } catch (e) {
      debugPrint('❌ Turnstile error: $e');
      return null;
    } finally {
      await turnstile.dispose();
    }
  }
}
