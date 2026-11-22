import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/top_toast.dart';
import 'settings_menu_card.dart';
import 'settings_opacity_tap.dart';

enum _SocialBrand { instagram, facebook, x, tiktok }

class SettingsSocialContactCard extends StatelessWidget {
  const SettingsSocialContactCard({
    super.key,
    required this.isDark,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final bool isDark;
  final Color textColor;
  final Color secondaryTextColor;

  static const _links = <_SocialBrand, String>{
    _SocialBrand.instagram: 'https://www.instagram.com/radiopodlisten',
    _SocialBrand.facebook: 'https://www.facebook.com/radiopodlisten',
    _SocialBrand.x: 'https://x.com/radiopodlisten',
    _SocialBrand.tiktok: 'https://www.tiktok.com/@radiopodlisten',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsMenuCard(
      isDark: isDark,
      secondaryTextColor: secondaryTextColor,
      header: Row(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 16,
            color: secondaryTextColor,
          ),
          SizedBox(width: 2.w),
          Text(
            l10n.settingsContactUs,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _SocialBrand.values
                .map(
                  (brand) => _SocialCircleButton(
                    brand: brand,
                    onTap: () => _openUrl(context, _links[brand]!),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        showTopToastError(
          context,
          AppLocalizations.of(context)!.couldNotOpenLink,
        );
      }
    }
  }
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.brand,
    required this.onTap,
  });

  final _SocialBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = 11.w.clamp(40.0, 52.0);

    return SettingsOpacityTap(
      focusDebugLabel: 'settings_social_${brand.name}',
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _brandBackground(brand),
        ),
        child: Center(
          child: SvgPicture.string(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            '<path fill="#FFFFFF" d="${_brandPath(brand)}"/>'
            '</svg>',
            width: size * 0.46,
            height: size * 0.46,
          ),
        ),
      ),
    );
  }

  Color _brandBackground(_SocialBrand brand) {
    return switch (brand) {
      _SocialBrand.instagram => const Color(0xFFE1306C),
      _SocialBrand.facebook => const Color(0xFF1877F2),
      _SocialBrand.x => const Color(0xFF14171A),
      _SocialBrand.tiktok => const Color(0xFF010101),
    };
  }

  String _brandPath(_SocialBrand brand) {
    return switch (brand) {
      _SocialBrand.instagram =>
        'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z',
      _SocialBrand.facebook =>
        'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z',
      _SocialBrand.x =>
        'M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z',
      _SocialBrand.tiktok =>
        'M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z',
    };
  }
}
