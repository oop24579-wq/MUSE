import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All theme colors, presets, and ThemeData for the app.
/// Change [kColorPreset] (1–7) to switch the active palette. Hot restart required.
class AppTheme {
  AppTheme._();

  /// ── CHANGE THIS (1–7) TO SWITCH COLOR PRESET. Hot restart required. ──
  /// 1 = Ember Aurora    2 = Emerald Pulse   3 = Sunset Vinyl
  /// 4 = Midnight Gold   5 = Neon Coral      6 = Drama Crimson
  /// 7 = Bronze Luxury
  static const int kColorPreset = 6;

  static _PresetColors get _c => switch (kColorPreset) {
        1 => _PresetColors.emberAurora,
        2 => _PresetColors.emeraldPulse,
        3 => _PresetColors.sunsetVinyl,
        4 => _PresetColors.midnightGold,
        5 => _PresetColors.neonCoral,
        6 => _PresetColors.dramaCrimson,
        7 => _PresetColors.bronzeLuxury,
        _ => _PresetColors.emberAurora,
      };

  /// Bundled fonts in [assets/fonts] — disable CDN fetches so typography works offline.
  static final bool _googleFontsConfigured = () {
    GoogleFonts.config.allowRuntimeFetching = false;
    return true;
  }();

  // ── Accent palette (preset-driven; legacy names kept for call sites) ──
  static Color get accentBlue => _c.accentStart;
  static Color get accentBlueDark => _c.accentDark;
  static Color get accentBlueLight => _c.accentEnd;
  static Color get accentBlueMuted => _c.accentMuted;
  static Color get createBlueStart => _c.accentStart;
  static Color get createBlueEnd => _c.accentEnd;

  // ── Backgrounds & surfaces ──
  static Color get backgroundDarkBlue => _c.backgroundDark;
  static Color get backgroundDarkBlueSecondary => _c.backgroundDarkSecondary;
  static Color get backgroundDarkSecondary => _c.backgroundDarkSecondary;
  static Color get surfaceDarkBlue => _c.surfaceDark;
  static Color get cardDarkBlue => _c.cardDark;

  static Color get backgroundDark => _c.backgroundDark;
  static Color get surfaceDark => _c.surfaceDark;
  static Color get textPrimaryDark => _c.textPrimaryDark;
  static Color get textSecondaryDark => _c.textSecondaryDark;
  static Color get dividerDark => _c.dividerDark;

  static Color get backgroundLight => _c.backgroundLight;
  static Color get surfaceLight => _c.surfaceLight;
  static Color get cardLight => _c.cardLight;
  static Color get textPrimaryLight => _c.textPrimaryLight;
  static Color get textSecondaryLight => _c.textSecondaryLight;
  static Color get dividerLight => _c.dividerLight;

  static Color get primaryRed => _c.accentStart;
  static Color get primaryRedDark => _c.accentDark;
  static Color get primaryRedLight => _c.accentEnd;
  static Color get accentPink => _c.accentSecondary;
  static Color get accentSecondary => _c.accentSecondary;
  static Color get paywallShell => _c.paywallShell;

  // ── Gradients ──
  static LinearGradient get createTitleGradient => _c.ctaGradient;
  static LinearGradient get proGradient => _c.ctaGradient;

  /// Gold "PRO" identity gradient — the single source of truth for the PRO
  /// badges and the active tab underline, so they always match.
  static const LinearGradient proBadgeGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
  );

  static LinearGradient get socialProofGradient => LinearGradient(
        colors: [_c.socialProofStart, _c.socialProofEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static Color pageBackground(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;

  /// Bottom fade over paywall hero image only.
  static LinearGradient paywallHeroFadeGradient() {
    final shell = _c.paywallShell;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.transparent,
        shell.withValues(alpha: 0.06),
        shell.withValues(alpha: 0.45),
        shell,
      ],
      stops: const [0.0, 0.68, 0.84, 0.94, 1.0],
    );
  }

  @Deprecated('Use pageBackground(isDark) — solid preset background, no gradient overlay')
  static RadialGradient get darkBlueBackgroundGradient => RadialGradient(
        center: const Alignment(0.0, -0.8),
        radius: 1.5,
        colors: [
          _c.accentDark.withValues(alpha: 0.12),
          _c.backgroundDark,
          _c.backgroundDarkSecondary,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static ImageFilter get backgroundBlurFilter =>
      ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0);

  static List<BoxShadow> blueGlow({double opacity = 0.18}) =>
      accentGlow(opacity: opacity);

  static List<BoxShadow> accentGlow({double opacity = 0.18}) => [
        BoxShadow(
          color: _c.accentStart.withValues(alpha: opacity),
          blurRadius: 22,
          spreadRadius: 1,
          offset: const Offset(0, 10),
        ),
      ];
  // Create Mode button style
  static ButtonStyle createOutlinedButtonStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: onPrimary,
      side: BorderSide(color: accentBlue.withValues(alpha: 0.85), width: 1.8),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).copyWith(
      backgroundColor: WidgetStateProperty.all(
        accentBlue.withValues(alpha: 0.08),
      ),
      shadowColor: WidgetStateProperty.all(
        accentBlue.withValues(alpha: 0.25),
      ),
    );
  }



  // Semantic colors (mode-independent)
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  // Legacy aliases for backward compatibility
  static Color get primary => primaryRed;
  static Color get secondary => accentPink;
  static Color get background => backgroundDark;
  static Color get surface => surfaceDark;
  static Color get textPrimary => textPrimaryDark;
  static Color get textSecondary => textSecondaryDark;
  static Color get divider => dividerDark;

  /// Settings profile card and settings modals: blend page background toward surface.
  static Color elevatedPanelBackground(bool isDark) => Color.lerp(
        isDark ? backgroundDark : backgroundLight,
        isDark ? surfaceDark : surfaceLight,
        0.32,
      )!;

  /// Rounded top for settings sign-in / rewards / email sheets (match modal route shape).
  static const RoundedRectangleBorder settingsSheetShape =
      RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  );

  /// Same fill and hairline border as settings menu cards.
  static BoxDecoration settingsSheetDecoration({
    required bool isDark,
    required Color secondaryTextColor,
  }) {
    return BoxDecoration(
      color: elevatedPanelBackground(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      border: Border.all(
        color: secondaryTextColor.withValues(alpha: isDark ? 0.09 : 0.11),
      ),
    );
  }

  // On-color variants
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static Color get onBackground => textPrimaryDark;
  static Color get onSurface => textPrimaryDark;
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onWarning = Color(0xFF000000);

  // Shadow and overlay colors
  static const Color shadow = Color(0x33000000);
  static const Color scrim = Color(0x80000000);
  static const Color overlay = Color(0x14FFFFFF);

  /// Professional dark theme optimized for audio recording applications
  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    assert(_googleFontsConfigured);
    return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: 0.2),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondary.withValues(alpha: 0.2),
      onSecondaryContainer: secondary,
      tertiary: success,
      onTertiary: onSuccess,
      tertiaryContainer: success.withValues(alpha: 0.2),
      onTertiaryContainer: success,
      error: error,
      onError: onError,
      errorContainer: error.withValues(alpha: 0.2),
      onErrorContainer: error,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: textSecondary,
      outline: divider,
      outlineVariant: divider.withValues(alpha: 0.5),
      shadow: shadow,
      scrim: scrim,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: primary,
      surfaceTint: primary,
    ),
    scaffoldBackgroundColor: background,
    cardColor: surface,
    dividerColor: divider,

    // AppBar theme for professional audio interface
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.15,
      ),
      iconTheme: IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: textPrimary,
        size: 24,
      ),
    ),

    // Card theme for audio file cards and information panels
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Bottom navigation for main app navigation
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
    ),

    // Floating Action Button for primary recording action
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Button themes for consistent interaction design
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: onPrimary,
        backgroundColor: primary,
        disabledForegroundColor: textSecondary,
        disabledBackgroundColor: divider,
        elevation: 2,
        shadowColor: shadow,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    // Typography system using Inter font family
    textTheme: _buildTextTheme(),

    // Input decoration for forms and search
    inputDecorationTheme: InputDecorationTheme(
      fillColor: surface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: divider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: divider.withValues(alpha: 0.5), width: 1),
      ),
      labelStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: GoogleFonts.inter(
        color: textSecondary.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      helperStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: GoogleFonts.inter(
        color: error,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Switch theme for settings toggles
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        if (states.contains(WidgetState.disabled)) {
          return textSecondary;
        }
        return surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.5);
        }
        if (states.contains(WidgetState.disabled)) {
          return divider;
        }
        return divider.withValues(alpha: 0.7);
      }),
      overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.2)),
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        if (states.contains(WidgetState.disabled)) {
          return divider;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(onPrimary),
      overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.2)),
      side: BorderSide(color: divider, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        if (states.contains(WidgetState.disabled)) {
          return divider;
        }
        return divider;
      }),
      overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.2)),
    ),

    // Progress indicators for loading states
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accentBlue,
      linearTrackColor: divider,
      circularTrackColor: divider,
    ),

    // Slider theme for audio controls
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: divider,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.2),
      valueIndicatorColor: primary,
      valueIndicatorTextStyle: GoogleFonts.inter(
        color: onPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),

    // Tab bar theme for category navigation
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      ),
      overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
    ),

    // Tooltip theme for help and information
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.all(8),
    ),

    // Snackbar theme for notifications
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      actionTextColor: primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 6,
    ),

    // Dialog theme for modals and confirmations
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      contentTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
    ),

    // Bottom sheet theme (use elevated panel — not raw surface — so sheets match settings card)
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: elevatedPanelBackground(true),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: shadow,
      shape: settingsSheetShape,
      modalBackgroundColor: elevatedPanelBackground(true),
      modalElevation: 8,
    ),

    // List tile theme for audio file lists
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: primary.withValues(alpha: 0.1),
      iconColor: textSecondary,
      selectedColor: primary,
      textColor: textPrimary,
      titleTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      subtitleTextStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      leadingAndTrailingTextStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // Chip theme for tags and categories
    chipTheme: ChipThemeData(
      backgroundColor: divider,
      selectedColor: primary.withValues(alpha: 0.2),
      disabledColor: divider.withValues(alpha: 0.5),
      deleteIconColor: textSecondary,
      labelStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      pressElevation: 2,
    ),

    // Icon theme
    iconTheme: IconThemeData(
      color: textSecondary,
      size: 24,
    ),
    primaryIconTheme: IconThemeData(
      color: primary,
      size: 24,
    ),

    dividerTheme: DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),
  );
  }

  /// Professional light theme for daytime use
  static ThemeData get lightTheme => _buildLightTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primaryRed,
      onPrimary: onPrimary,
      primaryContainer: primaryRedLight,
      onPrimaryContainer: textPrimaryLight,
      secondary: accentPink,
      onSecondary: onSecondary,
      secondaryContainer: accentPink.withValues(alpha: 0.2),
      onSecondaryContainer: textPrimaryLight,
      tertiary: success,
      onTertiary: onSuccess,
      tertiaryContainer: success.withValues(alpha: 0.2),
      onTertiaryContainer: textPrimaryLight,
      error: error,
      onError: onError,
      errorContainer: error.withValues(alpha: 0.1),
      onErrorContainer: error,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      onSurfaceVariant: textSecondaryLight,
      outline: dividerLight,
      outlineVariant: dividerLight.withValues(alpha: 0.5),
      shadow: shadow,
      scrim: scrim,
      inverseSurface: textPrimaryLight,
      onInverseSurface: backgroundLight,
      inversePrimary: primaryRed,
      surfaceTint: primaryRed,
    ),
    scaffoldBackgroundColor: backgroundLight,
    cardColor: surfaceLight,
    dividerColor: dividerLight,

    // AppBar theme
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundLight,
      foregroundColor: textPrimaryLight,
      elevation: 0,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryLight,
        letterSpacing: 0.15,
      ),
      iconTheme: IconThemeData(
        color: textPrimaryLight,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: textPrimaryLight,
        size: 24,
      ),
    ),

    // Card theme
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 1,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: onPrimary,
        backgroundColor: primaryRed,
        disabledForegroundColor: textSecondaryLight,
        disabledBackgroundColor: dividerLight,
        elevation: 1,
        shadowColor: shadow,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryRed,
        disabledForegroundColor: textSecondaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: primaryRed, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryRed,
        disabledForegroundColor: textSecondaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    // Typography
    textTheme: _buildTextTheme(isLight: true),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      fillColor: surfaceLight,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: dividerLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: dividerLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: dividerLight.withValues(alpha: 0.5), width: 1),
      ),
      labelStyle: GoogleFonts.inter(
        color: textSecondaryLight,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: GoogleFonts.inter(
        color: textSecondaryLight.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryRed;
        }
        if (states.contains(WidgetState.disabled)) {
          return textSecondaryLight;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryRed.withValues(alpha: 0.5);
        }
        if (states.contains(WidgetState.disabled)) {
          return dividerLight;
        }
        return dividerLight.withValues(alpha: 0.7);
      }),
      overlayColor: WidgetStateProperty.all(primaryRed.withValues(alpha: 0.2)),
    ),

    // Progress indicators
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accentBlue,
      linearTrackColor: dividerLight,
      circularTrackColor: dividerLight,
    ),

    // Icon theme
    iconTheme: IconThemeData(
      color: textSecondaryLight,
      size: 24,
    ),
    primaryIconTheme: IconThemeData(
      color: primaryRed,
      size: 24,
    ),

    dividerTheme: DividerThemeData(
      color: dividerLight,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: elevatedPanelBackground(false),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: shadow,
      shape: settingsSheetShape,
      modalBackgroundColor: elevatedPanelBackground(false),
      modalElevation: 8,
    ),
  );
  }


  /// Build typography system using Inter font family
  /// Implements professional hierarchy for photo editing interface
  static TextTheme _buildTextTheme({bool isLight = false}) {
    final Color textColor = isLight ? textPrimaryLight : textPrimaryDark;
    final Color secondaryTextColor = isLight ? textSecondaryLight : textSecondaryDark;
    
    return TextTheme(
      // Display styles for large headings
      displayLarge: GoogleFonts.inter(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textColor,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
        letterSpacing: 0,
        height: 1.22,
      ),

      // Headline styles for section headers
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
        height: 1.33,
      ),

      // Title styles for cards and dialogs
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.15,
        height: 1.50,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.1,
        height: 1.43,
      ),

      // Body text for main content
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        letterSpacing: 0.5,
        height: 1.50,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        letterSpacing: 0.4,
        height: 1.33,
      ),

      // Label styles for buttons and form elements
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 1.25,
        height: 1.43,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  /// Data text style using JetBrains Mono for technical information
  static TextStyle dataTextStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textSecondary,
      letterSpacing: 0,
      height: 1.4,
    );
  }

  /// Get shadow for elevation levels (2dp and 4dp)
  static List<BoxShadow> getElevationShadow(int elevation) {
    switch (elevation) {
      case 2:
        return [
          BoxShadow(
            color: shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      case 4:
        return [
          BoxShadow(
            color: shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      default:
        return [];
    }
  }
}

// ── Preset palettes (edit kColorPreset above to switch) ──

class _PresetColors {
  const _PresetColors({
    required this.accentStart,
    required this.accentDark,
    required this.accentEnd,
    required this.accentMuted,
    required this.accentSecondary,
    required this.backgroundDark,
    required this.backgroundDarkSecondary,
    required this.surfaceDark,
    required this.cardDark,
    required this.dividerDark,
    required this.textPrimaryDark,
    required this.textSecondaryDark,
    required this.backgroundLight,
    required this.surfaceLight,
    required this.cardLight,
    required this.dividerLight,
    required this.textPrimaryLight,
    required this.textSecondaryLight,
    required this.paywallShell,
    required this.socialProofStart,
    required this.socialProofEnd,
    required this.ctaGradient,
  });

  final Color accentStart;
  final Color accentDark;
  final Color accentEnd;
  final Color accentMuted;
  final Color accentSecondary;
  final Color backgroundDark;
  final Color backgroundDarkSecondary;
  final Color surfaceDark;
  final Color cardDark;
  final Color dividerDark;
  final Color textPrimaryDark;
  final Color textSecondaryDark;
  final Color backgroundLight;
  final Color surfaceLight;
  final Color cardLight;
  final Color dividerLight;
  final Color textPrimaryLight;
  final Color textSecondaryLight;
  final Color paywallShell;
  final Color socialProofStart;
  final Color socialProofEnd;
  final LinearGradient ctaGradient;

  static const emberAurora = _PresetColors(
    accentStart: Color(0xFFFF6B4A),
    accentDark: Color(0xFFE04E2F),
    accentEnd: Color(0xFFFFB347),
    accentMuted: Color(0xFFFF8A65),
    accentSecondary: Color(0xFFF5A623),
    backgroundDark: Color(0xFF121010),
    backgroundDarkSecondary: Color(0xFF1A1412),
    surfaceDark: Color(0xFF1E1816),
    cardDark: Color(0xFF2A2220),
    dividerDark: Color(0xFF3A302E),
    textPrimaryDark: Color(0xFFF5F0EE),
    textSecondaryDark: Color(0xFFA89890),
    backgroundLight: Color(0xFFFFF8F5),
    surfaceLight: Color(0xFFFFF0EB),
    cardLight: Color(0xFFFFE8E0),
    dividerLight: Color(0xFFE8D8D0),
    textPrimaryLight: Color(0xFF1A1210),
    textSecondaryLight: Color(0xFF6B5A52),
    paywallShell: Color(0xFF121010),
    socialProofStart: Color(0xFFFF6B4A),
    socialProofEnd: Color(0xFFFFB347),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFFF6B4A), Color(0xFFFFB347)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  /// Emerald pulse — deep green shell, emerald CTA, gold accents (no blue).
  static const emeraldPulse = _PresetColors(
    accentStart: Color(0xFF10B981),
    accentDark: Color(0xFF047857),
    accentEnd: Color(0xFF34D399),
    accentMuted: Color(0xFF6EE7B7),
    accentSecondary: Color(0xFFF5A623),
    backgroundDark: Color(0xFF07130E),
    backgroundDarkSecondary: Color(0xFF0B1B14),
    surfaceDark: Color(0xFF10241B),
    cardDark: Color(0xFF163024),
    dividerDark: Color(0xFF1F4030),
    textPrimaryDark: Color(0xFFE8F8F0),
    textSecondaryDark: Color(0xFF8AB8A4),
    backgroundLight: Color(0xFFF0FAF5),
    surfaceLight: Color(0xFFE0F5EC),
    cardLight: Color(0xFFD0EDDF),
    dividerLight: Color(0xFFB8DDCB),
    textPrimaryLight: Color(0xFF08180F),
    textSecondaryLight: Color(0xFF4A6858),
    paywallShell: Color(0xFF07130E),
    socialProofStart: Color(0xFF10B981),
    socialProofEnd: Color(0xFF34D399),
    ctaGradient: LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF34D399)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  static const sunsetVinyl = _PresetColors(
    accentStart: Color(0xFFF59E0B),
    accentDark: Color(0xFFD97706),
    accentEnd: Color(0xFFFBBF24),
    accentMuted: Color(0xFFFCD34D),
    accentSecondary: Color(0xFFE879A9),
    backgroundDark: Color(0xFF14100E),
    backgroundDarkSecondary: Color(0xFF1A1512),
    surfaceDark: Color(0xFF221C18),
    cardDark: Color(0xFF2E2620),
    dividerDark: Color(0xFF3E342C),
    textPrimaryDark: Color(0xFFF5F0E8),
    textSecondaryDark: Color(0xFFA89880),
    backgroundLight: Color(0xFFFBF6F0),
    surfaceLight: Color(0xFFF5EDE0),
    cardLight: Color(0xFFEDE0D0),
    dividerLight: Color(0xFFD8C8B0),
    textPrimaryLight: Color(0xFF1A1408),
    textSecondaryLight: Color(0xFF6B5A40),
    paywallShell: Color(0xFF14100E),
    socialProofStart: Color(0xFFF59E0B),
    socialProofEnd: Color(0xFFE879A9),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFE879A9)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  static const midnightGold = _PresetColors(
    accentStart: Color(0xFFD4AF37),
    accentDark: Color(0xFFB8960C),
    accentEnd: Color(0xFFF5DEB3),
    accentMuted: Color(0xFFE8C860),
    accentSecondary: Color(0xFF8B7355),
    backgroundDark: Color(0xFF0C0C0C),
    backgroundDarkSecondary: Color(0xFF121212),
    surfaceDark: Color(0xFF161616),
    cardDark: Color(0xFF222222),
    dividerDark: Color(0xFF333333),
    textPrimaryDark: Color(0xFFF0ECE0),
    textSecondaryDark: Color(0xFF989080),
    backgroundLight: Color(0xFFFAF8F4),
    surfaceLight: Color(0xFFF0ECE0),
    cardLight: Color(0xFFE8E0D0),
    dividerLight: Color(0xFFD0C8B0),
    textPrimaryLight: Color(0xFF1A1408),
    textSecondaryLight: Color(0xFF6B6050),
    paywallShell: Color(0xFF0C0C0C),
    socialProofStart: Color(0xFFD4AF37),
    socialProofEnd: Color(0xFFF5DEB3),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFD4AF37), Color(0xFFF5DEB3)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  static const neonCoral = _PresetColors(
    accentStart: Color(0xFFFF6B6B),
    accentDark: Color(0xFFE04545),
    accentEnd: Color(0xFFFF8E8E),
    accentMuted: Color(0xFFFFAAAA),
    accentSecondary: Color(0xFFF5A623),
    backgroundDark: Color(0xFF160F0F),
    backgroundDarkSecondary: Color(0xFF1E1414),
    surfaceDark: Color(0xFF261A1A),
    cardDark: Color(0xFF322323),
    dividerDark: Color(0xFF422E2E),
    textPrimaryDark: Color(0xFFF8F0F0),
    textSecondaryDark: Color(0xFFA88E8E),
    backgroundLight: Color(0xFFFFF5F2),
    surfaceLight: Color(0xFFFFEBE8),
    cardLight: Color(0xFFFFE0DC),
    dividerLight: Color(0xFFE8D0CC),
    textPrimaryLight: Color(0xFF29191A),
    textSecondaryLight: Color(0xFF806665),
    paywallShell: Color(0xFF160F0F),
    socialProofStart: Color(0xFFFF6B6B),
    socialProofEnd: Color(0xFFFF8E8E),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  /// Drama crimson — deep red→black shell, vivid red→orange CTA, gold accents.
  /// Matches the ReelShort / DramaBox / ShortMax short-drama aesthetic.
  static const dramaCrimson = _PresetColors(
    accentStart: Color(0xFFE50914),
    accentDark: Color(0xFFB00610),
    accentEnd: Color(0xFFFF5E3A),
    accentMuted: Color(0xFFFF8A6B),
    accentSecondary: Color(0xFFF5A623),
    backgroundDark: Color(0xFF130305),
    backgroundDarkSecondary: Color(0xFF1C0709),
    surfaceDark: Color(0xFF230A0C),
    cardDark: Color(0xFF2E1013),
    dividerDark: Color(0xFF43201F),
    textPrimaryDark: Color(0xFFFCF4F2),
    textSecondaryDark: Color(0xFFC7A9A6),
    backgroundLight: Color(0xFFFFF6F4),
    surfaceLight: Color(0xFFFFECE8),
    cardLight: Color(0xFFFFE0DA),
    dividerLight: Color(0xFFF0CFC8),
    textPrimaryLight: Color(0xFF20090A),
    textSecondaryLight: Color(0xFF7A5450),
    paywallShell: Color(0xFF130305),
    socialProofStart: Color(0xFFFF5E3A),
    socialProofEnd: Color(0xFFE50914),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFE50914), Color(0xFFFF5E3A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  /// Luxury dark — true black shell, chocolate surfaces, champagne→bronze metal.
  static const bronzeLuxury = _PresetColors(
    accentStart: Color(0xFFE6C49A),
    accentDark: Color(0xFFA67C52),
    accentEnd: Color(0xFFC5A070),
    accentMuted: Color(0xFFB89468),
    accentSecondary: Color(0xFF8B6340),
    backgroundDark: Color(0xFF000000),
    backgroundDarkSecondary: Color(0xFF1A120B),
    surfaceDark: Color(0xFF14100C),
    cardDark: Color(0xFF221A14),
    dividerDark: Color(0xFF3D3228),
    textPrimaryDark: Color(0xFFF2E8DC),
    textSecondaryDark: Color(0xFFBDBDBD),
    backgroundLight: Color(0xFFFAF6F0),
    surfaceLight: Color(0xFFF5EDE0),
    cardLight: Color(0xFFEDE4D4),
    dividerLight: Color(0xFFD8C8B0),
    textPrimaryLight: Color(0xFF1A120B),
    textSecondaryLight: Color(0xFF6B5A48),
    paywallShell: Color(0xFF000000),
    socialProofStart: Color(0xFFE6C49A),
    socialProofEnd: Color(0xFFC5A070),
    ctaGradient: LinearGradient(
      colors: [Color(0xFFE6C49A), Color(0xFFC5A070), Color(0xFFA67C52)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: [0.0, 0.48, 1.0],
    ),
  );
}