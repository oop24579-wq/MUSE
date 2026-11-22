import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../l10n/app_localizations.dart';
import '../../services/onboarding_service.dart';
import 'privacy_settings_screen.dart';
import 'shared/onboarding_flow_controller.dart';

/// Privacy Consent Screen - "Customize your experience" 
/// Dark theme with Accept All, Refuse, and Customize Preferences options
class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onAcceptAll() async {
    await OnboardingService.instance.acceptAllPrivacy();
    await OnboardingService.instance.setOnboardingCompleted();
    if (mounted) {
      // Session-aware exit (see navigateOnboardingExit): '/login' when
      // there is no stored session and no Firebase user.
      navigateOnboardingExit(context, withSessionRoute: '/main-tabs');
    }
  }

  Future<void> _onRefuse() async {
    await OnboardingService.instance.refuseNonEssentialPrivacy();
    await OnboardingService.instance.setOnboardingCompleted();
    if (mounted) {
      navigateOnboardingExit(context, withSessionRoute: '/main-tabs');
    }
  }

  void _onCustomizePreferences() {
    // Wiring v2: '/privacy-settings' is not registered in
    // AppRoutes.routes, so the named push threw at runtime. Push the
    // screen directly instead.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),

                        // Welcome header
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.welcomeToAiMusicMaker,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('👋', style: TextStyle(fontSize: 16)),
                          ],
                        ),

                        SizedBox(height: 1.5.h),

                        // Main title
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Customize your experience',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('🤗', style: TextStyle(fontSize: 28)),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        // Description text
                        Text(
                          'We use tracking technologies that either are essential for the app to function correctly or are used to produce aggregated statistics. With your consent, we and our third-party partners will also use tracking technologies to improve the in-app experience, and to provide you with personalized services and targeted advertising. To give your consent, tap Accept All and Continue.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFB0B0B0),
                            height: 1.6,
                          ),
                        ),

                        SizedBox(height: 3.h),

                        Text(
                          'Alternatively, you can customize your privacy settings by tapping Customize Preferences, or by going to Privacy Settings at any time. If you don\'t want us to use non-technical tracking technologies, tap Refuse.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFB0B0B0),
                            height: 1.6,
                          ),
                        ),

                        SizedBox(height: 3.h),

                        // Privacy Policy link
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFB0B0B0),
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'For more information about how we process your personal data through tracking technologies, take a look at our ',
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () {
                                    // Open privacy policy
                                  },
                                  child: Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF4D6D),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),

                        SizedBox(height: 3.h),
                      ],
                    ),
                  ),
                ),

                // Fixed bottom buttons area
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Accept All and Continue button
                      _buildAcceptButton(),

                      SizedBox(height: 1.5.h),

                      // Refuse button
                      _buildRefuseButton(),

                      SizedBox(height: 1.5.h),

                      // Customize Preferences link
                      TextButton(
                        onPressed: _onCustomizePreferences,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.h,
                          ),
                        ),
                        child: Text(
                          'Customize Preferences',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFB0B0B0),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFB0B0B0),
                          ),
                        ),
                      ),

                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return SizedBox(
      width: double.infinity,
      height: 7.h,
      child: ElevatedButton(
        onPressed: _onAcceptAll,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF8E7),
          foregroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          'Accept All and Continue',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildRefuseButton() {
    return SizedBox(
      width: double.infinity,
      height: 7.h,
      child: OutlinedButton(
        onPressed: _onRefuse,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF8E7),
          foregroundColor: const Color(0xFF1A1A1A),
          side: BorderSide.none,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          'Refuse',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

