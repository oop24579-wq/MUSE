import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import '../../core/app_export.dart';
import '../../bootstrap.dart';
import '../../services/marketing/marketing_analytics_service.dart';
import '../../services/marketing/marketing_event_names.dart' show PaywallTrigger;
import '../../services/marketing/marketing_funnel_events.dart';
import '../../services/firebase/remote_config_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/paywall_preload_service.dart';
import '../../services/user_provider.dart';
import '../../services/drama/drama_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/admob_service.dart';
import '../../services/force_update_service.dart';
import '../../widgets/force_update_dialog.dart';
import '../../widgets/top_toast.dart';
import '../../l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late DateTime _splashStartTime;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;

  double _initializationProgress = 0.0;

  /// TEST: Minimum splash display time (seconds) - set to 0 for production
  static const int _minSplashDisplaySeconds = 0;

  // Debug: Tap counter for resetting onboarding
  int _logoTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _splashStartTime = DateTime.now();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Logo scale animation
    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Logo fade animation
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Start logo animation
    _logoAnimationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Hide system UI for immersive experience
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      await _updateProgress(0.10);
      // Heavy core init (Firebase, Remote Config, Auth, push) runs
      // here — after the first frame — so the native splash was already
      // dismissed and the user sees this custom splash with its progress bar.
      await AppBootstrap.ensureInitialized();

      await _updateProgress(0.20);
      try {
        await RevenueCatService.initialize();
        debugPrint('✅ RevenueCat initialized successfully');
      } catch (e) {
        debugPrint('❌ RevenueCat initialization failed: $e');
      }

      // Preload paywall offerings + user pro status in parallel (non-blocking for UI)
      if (mounted) {
        final userProvider =
            Provider.of<UserProvider>(context, listen: false);
        unawaited(PaywallPreloadService.instance.preload());
        unawaited(userProvider.refreshUserInBackground(syncProStatus: true));
        // Auto-claim today's daily check-in in the background (no manual claim).
        // The RPC is a no-op if already claimed or not yet authenticated.
        unawaited(
          DramaService.instance.claimDailyCheckin().then((coins) {
            if (coins != null) userProvider.refreshUserInBackground();
          }),
        );
      }

      await _updateProgress(0.25);
      try {
        await ForceUpdateService.instance.initialize();
        final updateStatus = await ForceUpdateService.instance.checkForUpdate();
        if (updateStatus.needsUpdate && mounted) {
          await ForceUpdateDialog.show(context, updateStatus);
          if (updateStatus.isMandatory) return;
        }
      } catch (e) {
        debugPrint('❌ Force update check failed: $e');
      }

      await _updateProgress(0.30);
      try {
        await AdmobService.instance.initialize();
        debugPrint('✅ AdMob initialized successfully');
      } catch (e) {
        debugPrint('❌ AdMob initialization failed: $e');
      }

      await _updateProgress(0.40);
      await OnboardingService.instance.initialize();

      await _updateProgress(0.55);

      await _updateProgress(0.75);

      // Preload onboarding hero images on first launch
      final isOnboardingCompleted =
          await OnboardingService.instance.isOnboardingCompleted();
      if (!isOnboardingCompleted && mounted) {
        await _preloadOnboardingImages(context);
      }

      await _updateProgress(1.0);

      // TEST: Ensure minimum splash display time for visibility
      if (_minSplashDisplaySeconds > 0) {
        final elapsed = DateTime.now().difference(_splashStartTime).inSeconds;
        final remaining = _minSplashDisplaySeconds - elapsed;
        if (remaining > 0) {
          await Future.delayed(Duration(seconds: remaining));
        }
      }

      // Returning users may route to /pricing — warm caches during splash.
      if (isOnboardingCompleted) {
        await PaywallPreloadService.instance.preload();
      }

      // Navigate based on onboarding status
      await _navigateToNextScreen();
    } catch (e) {
      // Handle initialization errors gracefully
      await _handleInitializationError();
    }
  }

  static const _onboardingImages = [
    'assets/images/onboarding/onboarding_welcome.png',
    'assets/images/onboarding/onboarding_ai_covers.png',
  ];

  Future<void> _preloadOnboardingImages(BuildContext context) async {
    for (final asset in _onboardingImages) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
  }

  Future<void> _updateProgress(double progress) async {
    if (mounted) {
      setState(() {
        _initializationProgress = progress;
      });
    }
  }

  Future<void> _navigateToNextScreen() async {
    // Restore system UI before navigation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!mounted) return;

    // Check if onboarding is completed
    final isOnboardingCompleted = await OnboardingService.instance.isOnboardingCompleted();

    // Remote kill-switch: when onboarding is disabled, the first launch goes
    // straight to Home (no onboarding, no paywall). It's marked complete so the
    // NEXT launch follows the normal returning-user flow (paywall → home).
    final onboardingEnabled = RemoteConfigService.instance.showReadyToStart;
    if (!isOnboardingCompleted && !onboardingEnabled) {
      await OnboardingService.instance.setOnboardingCompleted();
      await MarketingAnalyticsService.instance.setCollectionEnabled(true);
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    if (isOnboardingCompleted) {
      await MarketingAnalyticsService.instance.setCollectionEnabled(true);
    }

    if (!isOnboardingCompleted) {
      // First time — onboarding only; paywall is shown on later app opens.
      Navigator.pushReplacementNamed(context, '/ready-to-start');
    } else {
      // Returning user — show paywall each launch until subscribed.
      try {
        final userProvider =
            Provider.of<UserProvider>(context, listen: false);
        await userProvider.waitForBackgroundRefresh();
        final isPro = userProvider.isPro;

        if (!isPro) {
          // Not pro - show paywall (offerings already preloaded during splash)
          await MarketingFunnelEvents.trackViewPaywall(
            trigger: PaywallTrigger.splashReturning,
          );
          Navigator.pushReplacementNamed(context, '/pricing');
        } else {
          // Pro user - go to home
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        // If check fails, show paywall anyway
        debugPrint('⚠️ Error checking pro status: $e');
        Navigator.pushReplacementNamed(context, '/pricing');
      }
    }
  }

  /// Debug: Handle logo tap to reset onboarding (tap 5 times within 2 seconds)
  Future<void> _handleLogoTap() async {
    final now = DateTime.now();
    
    // Reset counter if more than 2 seconds have passed since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 2) {
      _logoTapCount = 0;
    }
    
    _logoTapCount++;
    _lastTapTime = now;
    
    if (_logoTapCount >= 5) {
      // Reset onboarding
      await OnboardingService.instance.reset();
      _logoTapCount = 0;
      
      if (mounted) {
        showTopToastSuccess(context, 'Onboarding reset! Restart the app to see onboarding.');
      }
    }
  }

  Future<void> _handleInitializationError() async {
    if (mounted) {
      setState(() {});

      // Show error dialog after a delay
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            title: Text(
              l10n.splashInitErrorTitle,
              style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.error,
              ),
            ),
            content: Text(
              l10n.splashInitErrorMessage,
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeApp(); // Retry initialization
                },
                child: Text(
                  l10n.retry,
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

                    // App Logo with Animation
                    AnimatedBuilder(
                      animation: _logoAnimationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _logoFadeAnimation,
                          child: ScaleTransition(
                            scale: _logoScaleAnimation,
                            child: GestureDetector(
                              onTap: _handleLogoTap,
                              child: _buildAppLogo(),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 8.h),

                    // App Name
                    FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: Text(
                        AppLocalizations.of(context)!.appTitle,
                        style:
                            AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Tagline
                    FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: Text(
                        AppLocalizations.of(context)!.splashTagline,
                        style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Loading Section
                    _buildLoadingSection(),

                    SizedBox(height: 8.h),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Image.asset(
      'assets/images/app_icon.png',
      width: 25.w,
      height: 25.w,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      children: [
        // Progress Bar with inset/depth background
        Container(
          width: 60.w,
          height: 0.6.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _initializationProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
