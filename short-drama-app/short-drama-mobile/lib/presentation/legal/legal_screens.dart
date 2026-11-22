/// Legal screens for HERO DRAMA.
///
/// Self-contained: imports only Flutter's material library and
/// [legal_texts.dart]. The parent app wires [LegalRoutes] into its router;
/// no route registration is performed here.
library;

import 'package:flutter/material.dart';

import 'legal_texts.dart';

/// Named routes for the legal section.
class LegalRoutes {
  const LegalRoutes._();

  static const String hub = '/legal';
  static const String privacy = '/legal/privacy';
  static const String terms = '/legal/terms';
  static const String subscription = '/legal/subscription';
  static const String licenses = '/legal/licenses';
}

const String _kLastUpdated = 'Last updated: November 22, 2026';

/// Hub listing every legal document and the licenses/about screen.
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'HERO DRAMA',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Legal documents and information about the app.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          _LegalRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'What data we collect and how we use it',
            onTap: () =>
                Navigator.of(context).pushNamed(LegalRoutes.privacy),
          ),
          _LegalRow(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'The rules for using HERO DRAMA',
            onTap: () => Navigator.of(context).pushNamed(LegalRoutes.terms),
          ),
          _LegalRow(
            icon: Icons.subscriptions_outlined,
            title: 'Subscription & Purchases',
            subtitle: 'Billing, renewal, cancellation and refunds',
            onTap: () =>
                Navigator.of(context).pushNamed(LegalRoutes.subscription),
          ),
          _LegalRow(
            icon: Icons.info_outline,
            title: 'Licenses & About',
            subtitle: 'Open source licenses and app information',
            onTap: () =>
                Navigator.of(context).pushNamed(LegalRoutes.licenses),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _kLastUpdated,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Shared scrollable, selectable full-text document screen.
class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(height: 1.6, fontSize: 15);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kLastUpdated,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(text, style: bodyStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full Privacy Policy screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      text: privacyPolicy,
    );
  }
}

/// Full Terms of Service screen.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms of Service',
      text: termsOfService,
    );
  }
}

/// Full Subscription & Purchases terms screen.
class SubscriptionTermsScreen extends StatelessWidget {
  const SubscriptionTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Subscription & Purchases',
      text: subscriptionTerms,
    );
  }
}

/// Open source licenses + About screen.
///
/// [version] is displayed in the About block; the parent app may pass the
/// live package version. Defaults to the current release version.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key, this.version = '1.0.4'});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Licenses & About')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              'HERO DRAMA',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Short dramas. Big stories.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Version $version',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('Open source licenses'),
            subtitle: const Text(
              'Licenses for the open source software used in this app',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'HERO DRAMA',
              applicationVersion: version,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _kLastUpdated,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
