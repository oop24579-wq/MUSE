import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';
import '../shared/onboarding_common_widgets.dart';
import '../shared/onboarding_flow_controller.dart';
import '../shared/onboarding_page_content.dart';
import '../widgets/onboarding_broadcast_hero.dart';
import '../widgets/onboarding_carousel_hero.dart';
import '../widgets/onboarding_hero_visual.dart';
import '../widgets/onboarding_split_hero.dart';
import '../widgets/onboarding_waveform_hero.dart';
import '../shared/onboarding_modern_pages.dart';

// ── Onboarding 1 — original 4-page legacy flow ─────────────────────────────

class _LegacyOnboardingPageData {
  const _LegacyOnboardingPageData({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.heroType,
  });

  final String title;
  final String description;
  final String imageAsset;
  final OnboardingHeroType heroType;
}

/// Onboarding 1 — original 4-page flow with legacy hero visuals.
class Onboarding1Scaffold extends StatefulWidget {
  const Onboarding1Scaffold({super.key});

  @override
  State<Onboarding1Scaffold> createState() => _Onboarding1ScaffoldState();
}

class _Onboarding1ScaffoldState extends State<Onboarding1Scaffold> {
  late final DateTime _screenOpenedAt;
  late final OnboardingFlowController _flow;
  late final PageController _pageController;
  int _currentPage = 0;

  List<_LegacyOnboardingPageData> _pages(BuildContext context) {
    final appName = AppLocalizations.of(context)?.appTitle ?? 'HERO DRAMA';
    return [
      _LegacyOnboardingPageData(
        title: 'Welcome to $appName',
        description: 'Thousands of short dramas, ready to binge anytime.',
        imageAsset: 'assets/images/onboarding/onboarding_welcome.png',
        heroType: OnboardingHeroType.welcome,
      ),
      const _LegacyOnboardingPageData(
        title: 'Bite-Sized Drama',
        description: 'Addictive stories told in fast, vertical episodes.',
        imageAsset: 'assets/images/onboarding/onboarding_welcome.png',
        heroType: OnboardingHeroType.liveRadio,
      ),
      const _LegacyOnboardingPageData(
        title: 'Never Miss an Episode',
        description:
            'Follow your favorites and pick up right where you left off.',
        imageAsset: 'assets/images/onboarding/onboarding_ai_covers.png',
        heroType: OnboardingHeroType.podcasts,
      ),
      const _LegacyOnboardingPageData(
        title: 'Earn & Unlock',
        description: 'Collect daily coins and unlock premium episodes.',
        imageAsset: 'assets/images/onboarding/onboarding_welcome.png',
        heroType: OnboardingHeroType.library,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _screenOpenedAt = DateTime.now();
    _pageController = PageController();
    _flow = OnboardingFlowController(
      context: context,
      screenOpenedAt: _screenOpenedAt,
    );
    _flow.preloadPaywall();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    final pages = _pages(context);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _flow.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);
    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: pages.length,
                itemBuilder: (context, index) => _buildPage(pages[index], index),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 3.h),
              child: Column(
                children: [
                  OnboardingPageIndicators(
                    count: pages.length,
                    currentPage: _currentPage,
                  ),
                  SizedBox(height: 3.h),
                  OnboardingActionButton(
                    isLastPage: isLastPage,
                    onPressed: _onNext,
                    style: OnboardingButtonStyle.classicPill,
                  ),
                  if (isLastPage) ...[
                    SizedBox(height: 1.5.h),
                    const OnboardingLegalText(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_LegacyOnboardingPageData page, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          SizedBox(height: 2.h),
          OnboardingHeroVisual(
            key: ValueKey(index),
            type: page.heroType,
            imageAsset: page.imageAsset,
            pageKey: index,
          ),
          SizedBox(height: 3.h),
          if (index == 0) ...[
            Text(
              'Welcome to',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 0.8.h),
            Text(
              AppLocalizations.of(context)?.appTitle ?? 'HERO DRAMA',
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              page.title,
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: 1.5.h),
          Text(
            page.description,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Shared modern 4-page scaffold base ─────────────────────────────────────

abstract class ModernOnboardingScaffold extends StatefulWidget {
  const ModernOnboardingScaffold({super.key});
}

abstract class ModernOnboardingScaffoldState<T extends ModernOnboardingScaffold>
    extends State<T> {
  late final DateTime screenOpenedAt;
  late OnboardingFlowController flow;
  late PageController pageController;
  int currentPage = 0;

  List<OnboardingPageContent> get pages => modernOnboardingPages(context);

  @override
  void initState() {
    super.initState();
    screenOpenedAt = DateTime.now();
    pageController = PageController();
    flow = OnboardingFlowController(
      context: context,
      screenOpenedAt: screenOpenedAt,
    );
    flow.preloadPaywall();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onNext() {
    if (currentPage < pages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      flow.completeOnboarding();
    }
  }

  Widget buildHero(int index, OnboardingPageContent page);

  OnboardingButtonStyle get buttonStyle => OnboardingButtonStyle.classicPill;
  OnboardingBottomChrome get bottomChrome => OnboardingBottomChrome.plain;
  OnboardingIndicatorStyle get indicatorStyle => OnboardingIndicatorStyle.dots;
  bool get showWelcomeSubtitle => false;
  bool get embedTextInHero => false;
  double get bottomIndicatorSpacing => 3.0;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            if (showSkipButton && currentPage > 0)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: flow.completeOnboarding,
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (i) => setState(() => currentPage = i),
                itemCount: pages.length,
                clipBehavior: Clip.hardEdge,
                itemBuilder: (context, index) {
                  if (embedTextInHero) {
                    return buildHero(index, pages[index]);
                  }
                  return _buildStandardPage(index, pages[index]);
                },
              ),
            ),
            OnboardingBottomSection(
              pageCount: pages.length,
              currentPage: currentPage,
              isLastPage: isLastPage,
              onPressed: onNext,
              indicatorStyle: indicatorStyle,
              buttonStyle: buttonStyle,
              chrome: bottomChrome,
              indicatorSpacing: bottomIndicatorSpacing,
              lastPageLabel: 'Start Watching',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardPage(int index, OnboardingPageContent page) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          SizedBox(height: 1.h),
          if (showWelcomeSubtitle && index == 0)
            Text(
              onboardingWelcomeSubtitle(context),
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: AppTheme.accentBlue,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          if (showWelcomeSubtitle && index == 0) SizedBox(height: 1.h),
          buildHero(index, page),
          SizedBox(height: 3.h),
          OnboardingStaggeredTitle(
            text: page.title,
            pageKey: index,
            subtitle: page.titlePrefix,
          ),
          SizedBox(height: 1.5.h),
          TweenAnimationBuilder<double>(
            key: ValueKey('desc_$index'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, v, child) {
              return Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 16),
                  child: child,
                ),
              );
            },
            child: Text(
              page.description,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  bool get showSkipButton => true;
}

// ── Onboarding 2 — Broadcast Signal ────────────────────────────────────────

class Onboarding2Scaffold extends ModernOnboardingScaffold {
  const Onboarding2Scaffold({super.key});

  @override
  State<Onboarding2Scaffold> createState() => _Onboarding2ScaffoldState();
}

class _Onboarding2ScaffoldState
    extends ModernOnboardingScaffoldState<Onboarding2Scaffold> {
  @override
  OnboardingIndicatorStyle get indicatorStyle =>
      OnboardingIndicatorStyle.line;

  @override
  OnboardingButtonStyle get buttonStyle => OnboardingButtonStyle.flatBar;

  @override
  OnboardingBottomChrome get bottomChrome => OnboardingBottomChrome.topDivider;

  @override
  Widget buildHero(int index, OnboardingPageContent page) {
    return OnboardingBroadcastHero(page: page, pageKey: index);
  }
}

// ── Onboarding 3 — Living Waveform ─────────────────────────────────────────

class Onboarding3Scaffold extends ModernOnboardingScaffold {
  const Onboarding3Scaffold({super.key});

  @override
  State<Onboarding3Scaffold> createState() => _Onboarding3ScaffoldState();
}

class _Onboarding3ScaffoldState
    extends ModernOnboardingScaffoldState<Onboarding3Scaffold> {
  @override
  OnboardingIndicatorStyle get indicatorStyle =>
      OnboardingIndicatorStyle.hidden;

  @override
  OnboardingButtonStyle get buttonStyle => OnboardingButtonStyle.outlined;

  @override
  Widget buildHero(int index, OnboardingPageContent page) {
    return OnboardingWaveformHero(
      page: page,
      pageKey: index,
      totalPages: pages.length,
    );
  }
}

// ── Onboarding 4 — Card Carousel ───────────────────────────────────────────

class Onboarding4Scaffold extends ModernOnboardingScaffold {
  const Onboarding4Scaffold({super.key});

  @override
  State<Onboarding4Scaffold> createState() => _Onboarding4ScaffoldState();
}

class _Onboarding4ScaffoldState
    extends ModernOnboardingScaffoldState<Onboarding4Scaffold> {
  @override
  OnboardingButtonStyle get buttonStyle => OnboardingButtonStyle.iconTrailing;

  @override
  OnboardingBottomChrome get bottomChrome => OnboardingBottomChrome.surfaceCard;

  @override
  Widget buildHero(int index, OnboardingPageContent page) {
    return OnboardingCarouselHero(page: page, pageKey: index);
  }
}

// ── Onboarding 5 — Split Story ─────────────────────────────────────────────

class Onboarding5Scaffold extends ModernOnboardingScaffold {
  const Onboarding5Scaffold({super.key});

  @override
  State<Onboarding5Scaffold> createState() => _Onboarding5ScaffoldState();
}

class _Onboarding5ScaffoldState
    extends ModernOnboardingScaffoldState<Onboarding5Scaffold> {
  @override
  bool get embedTextInHero => true;

  @override
  bool get showSkipButton => false;

  @override
  OnboardingButtonStyle get buttonStyle => OnboardingButtonStyle.editorial;

  @override
  double get bottomIndicatorSpacing => 2.0;

  @override
  Widget buildHero(int index, OnboardingPageContent page) {
    return OnboardingSplitHero(
      page: page,
      pageKey: index,
      stepNumber: index + 1,
    );
  }
}
