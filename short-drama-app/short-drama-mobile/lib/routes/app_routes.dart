import 'package:flutter/material.dart';

import '../presentation/app_settings/app_settings.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/legal/legal_screens.dart';
import '../presentation/maintenance/maintenance_screen.dart';
import '../presentation/onboarding/ready_to_start_screen.dart';
import '../presentation/pricing/pricing_page.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/main_tabs/main_tabs.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splash = '/splash-screen';
  static const String home = '/home';
  static const String appSettings = '/app-settings';
  static const String pricing = '/pricing';
  static const String mainTabs = '/main-tabs';
  static const String readyToStart = '/ready-to-start';
  static const String login = '/login';
  static const String maintenance = '/maintenance';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splash: (context) => const SplashScreen(),
    home: (context) => const MainTabs(),
    mainTabs: (context) => const MainTabs(),
    appSettings: (context) => const AppSettings(),
    pricing: (context) => const PricingPage(),
    readyToStart: (context) => const ReadyToStartScreen(),
    login: (context) => const LoginScreen(),
    maintenance: (context) => const MaintenanceScreen(),
    LegalRoutes.hub: (context) => const LegalHubScreen(),
    LegalRoutes.privacy: (context) => const PrivacyPolicyScreen(),
    LegalRoutes.terms: (context) => const TermsOfServiceScreen(),
    LegalRoutes.subscription: (context) => const SubscriptionTermsScreen(),
    LegalRoutes.licenses: (context) => const LicensesScreen(),
  };
}
