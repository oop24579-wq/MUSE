import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/firebase/remote_config_service.dart';

/// Page progress UI — each variant uses exactly one style.
enum OnboardingIndicatorStyle {
  dots,
  line,
  hidden,
}

/// Distinct CTA design per onboarding variant (flat, no gradients/shadows).
enum OnboardingButtonStyle {
  /// V1 — classic filled pill.
  classicPill,
  /// V2 — flat bar, slight corner radius.
  flatBar,
  /// V3 — outlined accent border.
  outlined,
  /// V4 — filled with trailing arrow chip.
  iconTrailing,
  /// V5 — editorial wide bar, square corners.
  editorial,
}

/// Bottom chrome wrapper per variant (flat only).
enum OnboardingBottomChrome {
  plain,
  topDivider,
  surfaceCard,
}

class OnboardingPageIndicators extends StatelessWidget {
  const OnboardingPageIndicators({
    super.key,
    required this.count,
    required this.currentPage,
    this.activeColor,
    this.inactiveColor,
    this.style = OnboardingIndicatorStyle.dots,
  });

  final int count;
  final int currentPage;
  final Color? activeColor;
  final Color? inactiveColor;
  final OnboardingIndicatorStyle style;

  @override
  Widget build(BuildContext context) {
    if (style == OnboardingIndicatorStyle.hidden) {
      return const SizedBox.shrink();
    }

    final active = activeColor ?? AppTheme.accentBlue;
    final inactive = inactiveColor ?? AppTheme.divider;

    if (style == OnboardingIndicatorStyle.line) {
      final progress = (currentPage + 1) / count;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: inactive.withValues(alpha: 0.4),
          valueColor: AlwaysStoppedAnimation(active),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          width: isActive ? 7.w : 2.w,
          height: 2.w,
          decoration: BoxDecoration(
            color: isActive ? active : inactive,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class OnboardingActionButton extends StatelessWidget {
  const OnboardingActionButton({
    super.key,
    required this.isLastPage,
    required this.onPressed,
    required this.style,
    this.lastPageLabel,
  });

  final bool isLastPage;
  final VoidCallback onPressed;
  final OnboardingButtonStyle style;
  final String? lastPageLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isLastPage
        ? (lastPageLabel ?? l10n?.continueButton ?? 'Get Started')
        : 'Next';

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: switch (style) {
        OnboardingButtonStyle.classicPill => _ClassicPillButton(
            label: label,
            onPressed: onPressed,
          ),
        OnboardingButtonStyle.flatBar => _FlatBarButton(
            label: label,
            onPressed: onPressed,
          ),
        OnboardingButtonStyle.outlined => _OutlinedButton(
            label: label,
            onPressed: onPressed,
            isLastPage: isLastPage,
          ),
        OnboardingButtonStyle.iconTrailing => _IconTrailingButton(
            label: label,
            onPressed: onPressed,
          ),
        OnboardingButtonStyle.editorial => _EditorialButton(
            label: label,
            onPressed: onPressed,
            isLastPage: isLastPage,
          ),
      },
    );
  }

  double get _height => switch (style) {
        OnboardingButtonStyle.editorial => 6.h,
        OnboardingButtonStyle.flatBar => 6.5.h,
        _ => 7.h,
      };
}

class _ClassicPillButton extends StatelessWidget {
  const _ClassicPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FlatBarButton extends StatelessWidget {
  const _FlatBarButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.label,
    required this.onPressed,
    required this.isLastPage,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentBlue;
    final filled = isLastPage;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: filled ? accent : Colors.transparent,
        foregroundColor: filled ? Colors.white : accent,
        elevation: 0,
        shadowColor: Colors.transparent,
        side: BorderSide(color: accent, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconTrailingButton extends StatelessWidget {
  const _IconTrailingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentSecondary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 3.w),
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward_rounded, size: 16.sp),
          ),
        ],
      ),
    );
  }
}

class _EditorialButton extends StatelessWidget {
  const _EditorialButton({
    required this.label,
    required this.onPressed,
    required this.isLastPage,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isLastPage ? AppTheme.accentBlue : AppTheme.surface,
        foregroundColor: isLastPage ? Colors.white : AppTheme.textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: isLastPage
              ? BorderSide.none
              : BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Bottom section: indicators, CTA, legal — wrapped per variant chrome.
class OnboardingBottomSection extends StatelessWidget {
  const OnboardingBottomSection({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.isLastPage,
    required this.onPressed,
    required this.indicatorStyle,
    required this.buttonStyle,
    required this.chrome,
    this.indicatorSpacing = 3.0,
    this.lastPageLabel,
  });

  final int pageCount;
  final int currentPage;
  final bool isLastPage;
  final VoidCallback onPressed;
  final OnboardingIndicatorStyle indicatorStyle;
  final OnboardingButtonStyle buttonStyle;
  final OnboardingBottomChrome chrome;
  final double indicatorSpacing;
  final String? lastPageLabel;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (indicatorStyle != OnboardingIndicatorStyle.hidden) ...[
          OnboardingPageIndicators(
            count: pageCount,
            currentPage: currentPage,
            activeColor: AppTheme.accentBlue,
            style: indicatorStyle,
          ),
          SizedBox(height: indicatorSpacing.h),
        ],
        OnboardingActionButton(
          isLastPage: isLastPage,
          onPressed: onPressed,
          style: buttonStyle,
          lastPageLabel: lastPageLabel,
        ),
        if (isLastPage) ...[
          SizedBox(height: 1.5.h),
          const OnboardingLegalText(),
        ],
      ],
    );

    final padding = EdgeInsets.fromLTRB(6.w, 0, 6.w, 3.h);

    return switch (chrome) {
      OnboardingBottomChrome.plain => Padding(padding: padding, child: content),
      OnboardingBottomChrome.topDivider => Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.divider, width: 1),
            ),
          ),
          child: content,
        ),
      OnboardingBottomChrome.surfaceCard => Container(
          padding: padding.copyWith(top: 2.5.h),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppTheme.divider, width: 1),
            ),
          ),
          child: content,
        ),
    };
  }
}

class OnboardingLegalText extends StatefulWidget {
  const OnboardingLegalText({super.key});

  @override
  State<OnboardingLegalText> createState() => _OnboardingLegalTextState();
}

class _OnboardingLegalTextState extends State<OnboardingLegalText> {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL(RemoteConfigService.instance.termsUrl);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL(RemoteConfigService.instance.privacyUrl);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final termsText = l10n?.termsOfUse ?? 'Terms of Use';
    final privacyText = l10n?.privacyPolicy ?? 'Privacy Policy';
    const fontSize = 10.0;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: fontSize,
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
          height: 1.4,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: termsText,
            recognizer: _termsRecognizer,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              color: AppTheme.textPrimary.withValues(alpha: 0.85),
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' and confirm you\'ve read our '),
          TextSpan(
            text: privacyText,
            recognizer: _privacyRecognizer,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              color: AppTheme.textPrimary.withValues(alpha: 0.85),
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

/// Staggered word-by-word title reveal.
class OnboardingStaggeredTitle extends StatelessWidget {
  const OnboardingStaggeredTitle({
    super.key,
    required this.text,
    required this.pageKey,
    this.fontSize,
    this.subtitle,
  });

  final String text;
  final int pageKey;
  final double? fontSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    return Column(
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.accentBlue,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 1.5.w,
          runSpacing: 0.5.h,
          children: List.generate(words.length, (i) {
            return TweenAnimationBuilder<double>(
              key: ValueKey('${pageKey}_$i'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + i * 60),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 12),
                    child: child,
                  ),
                );
              },
              child: Text(
                i < words.length - 1 ? '${words[i]} ' : words[i],
                style: GoogleFonts.inter(
                  fontSize: fontSize ?? 26.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
