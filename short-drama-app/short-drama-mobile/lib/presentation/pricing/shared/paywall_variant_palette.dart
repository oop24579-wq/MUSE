import 'package:flutter/material.dart';

/// Fixed accent palettes for paywall variants 2–7 (paywall 1 uses [AppTheme]).
abstract final class PaywallVariantPalette {
  // Paywall 2 — red PRO accent
  static const p2Accent = Color(0xFFFF3B30);
  static const p2Shell = Color(0xFF000000);
  static const p2Card = Color(0xFF1C1C1E);

  static const p2Cta = LinearGradient(
    colors: [Color(0xFFFF3B30), Color(0xFFFF6259)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Paywall 3 — emerald green
  static const p3Accent = Color(0xFF10B981);
  static const p3AccentEnd = Color(0xFF34D399);
  static const p3Shell = Color(0xFF07130E);
  static const p3Card = Color(0xFF163024);

  static const p3Cta = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const p3Social = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Paywall 4 — gold luxury
  static const p4Accent = Color(0xFFE6C49A);
  static const p4AccentDark = Color(0xFFA67C52);
  static const p4Shell = Color(0xFF000000);
  static const p4Card = Color(0xFF221A14);
  static const p4Surface = Color(0xFF14100C);

  static const p4Cta = LinearGradient(
    colors: [Color(0xFFE6C49A), Color(0xFFC5A070), Color(0xFFA67C52)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.48, 1.0],
  );

  // Paywall 5 — magenta / pink
  static const p5Accent = Color(0xFFFF2D92);
  static const p5AccentEnd = Color(0xFFFF6B35);
  static const p5Shell = Color(0xFF000000);
  static const p5Card = Color(0xFF1A1A1A);

  static const p5Cta = LinearGradient(
    colors: [Color(0xFFFF2D92), Color(0xFFFF6B35)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Paywall 6 — coral
  static const p6Accent = Color(0xFFFF6B4A);
  static const p6Shell = Color(0xFF0F1419);
  static const p6Card = Color(0xFF1A2228);

  static const p6Cta = LinearGradient(
    colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Paywall 7 — peach / gold
  static const p7Accent = Color(0xFFF5C293);
  static const p7AccentDark = Color(0xFFE8A86B);
  static const p7Shell = Color(0xFF0A0A0A);
  static const p7Card = Color(0xFF1E1E1E);

  static const p7Cta = LinearGradient(
    colors: [Color(0xFFF5C293), Color(0xFFE8A86B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
