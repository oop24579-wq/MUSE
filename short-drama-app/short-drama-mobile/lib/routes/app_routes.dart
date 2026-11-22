import 'package:flutter/material.dart';

import '../presentation/app_settings/app_settings.dart';
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

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splash: (context) => const SplashScreen(),
    home: (context) => const MainTabs(),
    mainTabs: (context) => const MainTabs(),
    appSettings: (context) => const AppSettings(),
    pricing: (context) => const PricingPage(),
    readyToStart: (context) => const ReadyToStartScreen(),
  };
}
