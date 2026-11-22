import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../widgets/top_toast.dart';
import 'firebase/remote_config_service.dart';

/// Opens Terms / Privacy URLs from Firebase Remote Config only.
class LegalUrlLauncher {
  LegalUrlLauncher._();

  static String termsUrl() => RemoteConfigService.instance.termsUrl.trim();

  static String privacyUrl() => RemoteConfigService.instance.privacyUrl.trim();

  static Future<void> openTerms(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await launchWithToast(
      context,
      termsUrl(),
      'Could not open ${l10n?.termsOfUse ?? 'Terms of Use'}',
    );
  }

  static Future<void> openPrivacy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await launchWithToast(
      context,
      privacyUrl(),
      'Could not open ${l10n?.privacyPolicy ?? 'Privacy Policy'}',
    );
  }

  static Future<void> launchWithToast(
    BuildContext context,
    String url,
    String failureMessage,
  ) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (context.mounted) showTopToastError(context, failureMessage);
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        showTopToastError(context, failureMessage);
      }
    } catch (_) {
      if (context.mounted) showTopToastError(context, failureMessage);
    }
  }
}
