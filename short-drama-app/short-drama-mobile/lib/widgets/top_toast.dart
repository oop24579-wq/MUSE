import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_export.dart';

/// App-styled top toast: a frosted card (surface + accent border + status icon
/// chip), matching the app's card language rather than a flat coloured pill.
void showTopToast(
  BuildContext context, {
  required String message,
  Color? backgroundColor,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
  bool useOverlay = false,
}) {
  final accent = backgroundColor ?? AppTheme.accentBlue;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (useOverlay) {
    _showOverlayToast(context,
        message: message, accent: accent, icon: icon, duration: duration, isDark: isDark);
    return;
  }

  final screenHeight = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: _ToastCard(message: message, accent: accent, icon: icon, isDark: isDark),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: screenHeight - 160, left: 16, right: 16),
        duration: duration,
      ),
    );
}

void showTopToastSuccess(BuildContext context, String message, {bool useOverlay = false}) {
  showTopToast(context,
      message: message,
      backgroundColor: AppTheme.success,
      icon: Icons.check_circle_rounded,
      useOverlay: useOverlay);
}

void showTopToastError(BuildContext context, String message, {bool useOverlay = false}) {
  showTopToast(context,
      message: message,
      backgroundColor: AppTheme.error,
      icon: Icons.error_rounded,
      useOverlay: useOverlay);
}

void showTopToastInfo(BuildContext context, String message,
    {Duration? duration, bool useOverlay = false}) {
  showTopToast(context,
      message: message,
      backgroundColor: AppTheme.accentBlue,
      icon: Icons.info_rounded,
      duration: duration ?? const Duration(seconds: 3),
      useOverlay: useOverlay);
}

/// Shared toast body used by both the SnackBar and Overlay variants.
class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.accent,
    required this.isDark,
    this.icon,
  });

  final String message;
  final Color accent;
  final bool isDark;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.cardDarkBlue : Colors.white;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon ?? Icons.info_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-aligned hint (e.g. double-back-to-exit), above the main tab bar.
void showBottomToastWarning(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  double aboveBottomNav = 72,
}) {
  showBottomToast(context, message,
      icon: Icons.info_outline, duration: duration, aboveBottomNav: aboveBottomNav);
}

/// Bottom floating toast — same shell as [showBottomToastWarning].
void showBottomToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline,
  Duration duration = const Duration(seconds: 2),
  double aboveBottomNav = 72,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bottomInset = MediaQuery.of(context).padding.bottom;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon,
                color: isDark ? AppTheme.accentBlueLight : Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textPrimaryDark : Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark
            ? AppTheme.cardDarkBlue.withValues(alpha: 0.96)
            : AppTheme.textPrimaryLight.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(left: 16, right: 16, bottom: aboveBottomNav + bottomInset),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: duration,
      ),
    );
}

void _showOverlayToast(
  BuildContext context, {
  required String message,
  required Color accent,
  IconData? icon,
  required Duration duration,
  required bool isDark,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _OverlayToast(
      message: message,
      accent: accent,
      icon: icon,
      duration: duration,
      isDark: isDark,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _OverlayToast extends StatefulWidget {
  final String message;
  final Color accent;
  final IconData? icon;
  final Duration duration;
  final bool isDark;
  final VoidCallback onDismiss;

  const _OverlayToast({
    required this.message,
    required this.accent,
    this.icon,
    required this.duration,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, () {
      if (mounted) _controller.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: _ToastCard(
            message: widget.message,
            accent: widget.accent,
            icon: widget.icon,
            isDark: widget.isDark,
          ),
        ),
      ),
    );
  }
}
