import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../services/onboarding_service.dart';
import 'shared/onboarding_flow_controller.dart';

/// Privacy Settings Screen - Detailed privacy toggle settings
/// Dark theme with toggle cards for Technical, Analytics, and Profiling
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _analyticsEnabled = false;
  bool _profilingEnabled = false;
  bool _analyticsExpanded = false;
  bool _profilingExpanded = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSettings();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  Future<void> _loadSettings() async {
    final analytics = await OnboardingService.instance.isAnalyticsEnabled();
    final profiling = await OnboardingService.instance.isProfilingEnabled();
    if (mounted) {
      setState(() {
        _analyticsEnabled = analytics;
        _profilingEnabled = profiling;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onDenyNonEssential() async {
    await OnboardingService.instance.refuseNonEssentialPrivacy();
    await OnboardingService.instance.setOnboardingCompleted();
    if (mounted) {
      // Session-aware exit (see navigateOnboardingExit): '/login' when
      // there is no stored session and no Firebase user.
      navigateOnboardingExit(context, withSessionRoute: '/main-tabs');
    }
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

  Future<void> _onConfirm() async {
    await OnboardingService.instance.savePrivacyPreferences(
      accepted: true,
      analyticsEnabled: _analyticsEnabled,
      profilingEnabled: _profilingEnabled,
    );
    await OnboardingService.instance.setOnboardingCompleted();
    if (mounted) {
      // Session-aware exit (see navigateOnboardingExit): '/login' when
      // there is no stored session and no Firebase user.
      navigateOnboardingExit(context, withSessionRoute: '/main-tabs');
    }
  }

  void _onClose() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 2.h),

                      // Description
                      Text(
                        'With your consent, we and our third-party partners will use the following in-app tracking technologies. You can choose which non-technical tracking technologies we use.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFB0B0B0),
                          height: 1.6,
                        ),
                      ),

                      SizedBox(height: 2.h),

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
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),

                      SizedBox(height: 3.h),

                      // Technical Card (always enabled)
                      _buildTechnicalCard(),

                      SizedBox(height: 1.5.h),

                      // Analytics Card
                      _buildAnalyticsCard(),

                      SizedBox(height: 1.5.h),

                      // Profiling Card
                      _buildProfilingCard(),

                      SizedBox(height: 3.h),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: _onClose,
            icon: const Icon(
              Icons.close,
              color: Color(0xFFE0E0E0),
              size: 26,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          const Spacer(),

          // Title
          Text(
            'Privacy Settings',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const Spacer(),

          // Confirm button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3A3A3A),
                width: 1.5,
              ),
            ),
            child: IconButton(
              onPressed: _onConfirm,
              icon: const Icon(
                Icons.check,
                color: Color(0xFFE0E0E0),
                size: 22,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(4.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technical',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Essential for the app to function correctly or used only by us to perform aggregated statistical analysis.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF909090),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          // Always-on disabled toggle
          Switch(
            value: true,
            onChanged: null, // Disabled
            activeColor: const Color(0xFF909090),
            activeTrackColor: const Color(0xFF505050),
            inactiveThumbColor: const Color(0xFF909090),
            inactiveTrackColor: const Color(0xFF505050),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'Used to track the app\'s traffic and performance, the most and least popular features, and how you navigate the app. These trackers may be set by us or our third-party partners.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF909090),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 2.w),
                Column(
                  children: [
                    Switch(
                      value: _analyticsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _analyticsEnabled = value;
                        });
                      },
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF4CAF50),
                      inactiveThumbColor: const Color(0xFF909090),
                      inactiveTrackColor: const Color(0xFF3A3A3A),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _analyticsExpanded = !_analyticsExpanded;
                        });
                      },
                      icon: AnimatedRotation(
                        turns: _analyticsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF909090),
                          size: 24,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_analyticsExpanded)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 4.w,
                right: 4.w,
                bottom: 4.w,
              ),
              child: Text(
                'Analytics trackers help us understand how users interact with our app, identify popular features, and improve the overall user experience.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF707070),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfilingCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profiling',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'Used to provide customized services and advertising based on the data you share and your in-app behavior, and to measure the effectiveness of our ads. These trackers may be set by us or our third-party partners.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF909090),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 2.w),
                Column(
                  children: [
                    Switch(
                      value: _profilingEnabled,
                      onChanged: (value) {
                        setState(() {
                          _profilingEnabled = value;
                        });
                      },
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF4CAF50),
                      inactiveThumbColor: const Color(0xFF909090),
                      inactiveTrackColor: const Color(0xFF3A3A3A),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _profilingExpanded = !_profilingExpanded;
                        });
                      },
                      icon: AnimatedRotation(
                        turns: _profilingExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF909090),
                          size: 24,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_profilingExpanded)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 4.w,
                right: 4.w,
                bottom: 4.w,
              ),
              child: Text(
                'Profiling trackers allow us to personalize your experience and show you relevant content and advertisements based on your interests and behavior.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF707070),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Deny Non-Essential button
            Expanded(
              child: SizedBox(
                height: 6.h,
                child: OutlinedButton(
                  onPressed: _onDenyNonEssential,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    'Deny Non-Essential',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(width: 3.w),

            // Accept All button
            Expanded(
              child: SizedBox(
                height: 6.h,
                child: ElevatedButton(
                  onPressed: _onAcceptAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    'Accept All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

