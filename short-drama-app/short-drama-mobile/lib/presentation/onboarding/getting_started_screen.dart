import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'dart:math' as math;

import 'privacy_consent_screen.dart';

/// Getting Started Screen - First screen shown after splash
/// Light theme with hands holding polaroid photos aesthetic
class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  State<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends State<GettingStartedScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Floating animation for decorative elements
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Fade and slide in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Main illustration area
            Expanded(
              flex: 6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative elements
                  ..._buildDecorativeElements(),

                  // Main photo collage illustration
                  _buildPhotoCollage(),
                ],
              ),
            ),

            // Bottom content area
            Expanded(
              flex: 4,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2.h),

                        // Headline
                        Text(
                          'Take your photos to\nnew heights',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const Spacer(),

                        // Get Started button
                        _buildGetStartedButton(),

                        SizedBox(height: 2.5.h),

                        // Terms and Privacy text
                        _buildLegalText(),

                        SizedBox(height: 3.h),
                      ],
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

  List<Widget> _buildDecorativeElements() {
    return [
      // X mark top left
      Positioned(
        top: 22.h,
        left: 10.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, math.sin(_floatController.value * math.pi) * 5),
              child: child,
            );
          },
          child: Text(
            '×',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ),

      // Circle top left
      Positioned(
        top: 28.h,
        left: 6.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  math.cos(_floatController.value * math.pi) * 3,
                  math.sin(_floatController.value * math.pi * 0.5) * 4),
              child: child,
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF333333), width: 1.5),
            ),
          ),
        ),
      ),

      // X mark center top
      Positioned(
        top: 18.h,
        right: 38.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  0, math.sin(_floatController.value * math.pi * 1.5) * 4),
              child: child,
            );
          },
          child: Text(
            '×',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ),

      // Dash top right
      Positioned(
        top: 25.h,
        right: 8.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.rotate(
              angle:
                  math.pi / 4 + (math.sin(_floatController.value * math.pi) * 0.1),
              child: child,
            );
          },
          child: Container(
            width: 12,
            height: 2,
            color: const Color(0xFF333333),
          ),
        ),
      ),

      // Dash middle right
      Positioned(
        top: 40.h,
        right: 6.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.rotate(
              angle: -math.pi / 4 +
                  (math.cos(_floatController.value * math.pi) * 0.1),
              child: child,
            );
          },
          child: Container(
            width: 10,
            height: 2,
            color: const Color(0xFF333333),
          ),
        ),
      ),

      // Circle bottom center
      Positioned(
        bottom: 48.h,
        left: 42.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  math.sin(_floatController.value * math.pi) * 3,
                  math.cos(_floatController.value * math.pi * 0.7) * 5),
              child: child,
            );
          },
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF333333), width: 1.5),
            ),
          ),
        ),
      ),

      // X mark bottom
      Positioned(
        bottom: 45.h,
        right: 35.w,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset:
                  Offset(0, math.sin(_floatController.value * math.pi * 2) * 3),
              child: child,
            );
          },
          child: Text(
            '×',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPhotoCollage() {
    return SizedBox(
      width: 100.w,
      height: 45.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left hand with photo
          Positioned(
            left: -10.w,
            top: 8.h,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    math.sin(_floatController.value * math.pi) * 8,
                  ),
                );
              },
              child: Transform.rotate(
                angle: -0.15,
                child: _buildPolaroidPhoto(
                  gradientColors: [
                    const Color(0xFFFFB5C2),
                    const Color(0xFFFF8FA3),
                  ],
                  size: 32.w,
                ),
              ),
            ),
          ),

          // Right hand with photo
          Positioned(
            right: -5.w,
            top: 12.h,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    math.sin((_floatController.value + 0.5) * math.pi) * 8,
                  ),
                );
              },
              child: Transform.rotate(
                angle: 0.12,
                child: _buildPolaroidPhoto(
                  gradientColors: [
                    const Color(0xFFFFCDD2),
                    const Color(0xFFFFABB8),
                  ],
                  size: 30.w,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolaroidPhoto({
    required List<Color> gradientColors,
    required double size,
  }) {
    return Container(
      width: size,
      height: size * 1.15,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  size: size * 0.35,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
          SizedBox(height: size * 0.08),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      height: 7.h,
      child: ElevatedButton(
        onPressed: () {
          // Wiring v2: '/privacy-consent' is not registered in
          // AppRoutes.routes, so the named push threw at runtime. Push the
          // screen directly instead (same replacement semantics).
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PrivacyConsentScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 2.w),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF666666),
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing, you accept our '),
          TextSpan(
            text: 'Terms of Service',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF1A1A1A),
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' and acknowledge\nreceipt of our '),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF1A1A1A),
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

