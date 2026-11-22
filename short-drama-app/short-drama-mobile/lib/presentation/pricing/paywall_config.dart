/// Paywall layout variants — switch with [kPaywallVariant] (hot restart required).
///
/// 1 = Current bento hero + social proof (uses [AppTheme.kColorPreset])
/// 2 = Hero preview, horizontal feature chips, red PRO accent
/// 3 = Tilted image grid, blue/cyan gradient, social proof pill
/// 4 = Gold luxury carousel plans, countdown, feature spotlight
/// 5 = Urgency countdown, fan benefit cards, magenta CTA
/// 6 = Feature showcase row, coral CTA, social proof stat
/// 7 = Full-screen portrait hero, checklist perks, peach CTA
enum PaywallVariant {
  paywall1,
  paywall2,
  paywall3,
  paywall4,
  paywall5,
  paywall6,
  paywall7,
}

class PaywallConfig {
  PaywallConfig._();

  /// ── CHANGE THIS (1–7) TO SWITCH PAYWALL LAYOUT. Hot restart required. ──
  static const int kPaywallVariant = 1;

  static PaywallVariant get active => switch (kPaywallVariant) {
        1 => PaywallVariant.paywall1,
        2 => PaywallVariant.paywall2,
        3 => PaywallVariant.paywall3,
        4 => PaywallVariant.paywall4,
        5 => PaywallVariant.paywall5,
        6 => PaywallVariant.paywall6,
        7 => PaywallVariant.paywall7,
        _ => PaywallVariant.paywall1,
      };
}
