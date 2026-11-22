/// Marketing event name constants — RadioPod mobile catalog.
abstract final class MarketingEventNames {
  // Onboarding funnel
  static const onboardingStarted = 'onboarding_started';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingClick = 'onboarding_click';
  static const inputFilled = 'input_filled';

  // Auth
  static const login = 'login';
  static const signUp = 'sign_up';
  static const signOut = 'sign_out';
  static const accountLinked = 'account_linked';
  static const anonymousSessionStarted = 'anonymous_session_started';

  // Monetization
  static const viewPaywall = 'view_paywall';
  static const beginCheckout = 'begin_checkout';
  static const checkoutStarted = 'checkout_started';
  static const purchase = 'purchase';
  static const restorePurchases = 'restore_purchases';

  // Engagement
  static const clickCta = 'click_cta';
  static const quickActionView = 'quick_action_view';
  static const quickActionUsed = 'quick_action_used';
  static const screenView = 'screen_view';
  static const sessionStart = 'session_start';
  static const errorOccurred = 'error_occurred';

  // Branded aliases (GTM / Amplitude)
  static const ammSignupComplete = 'amm_signup_complete';
  static const ammLogin = 'amm_login';
  static const purchaseConversion = 'purchase_conversion';
}

/// Dedup keys stored in SharedPreferences.
abstract final class MarketingDedupKeys {
  static const sessionStart = 'amm_marketing_session_started';
  static const onboardingStarted = 'amm_onboarding_started';
  static String purchaseSent(String transactionId) =>
      'amm_purchase_sent_$transactionId';
  static String quickActionView(String feature) => 'amm_qav_$feature';
  static const inputFilledPrompt = 'amm_input_filled_prompt';
  static const onboardingClickSubmit = 'amm_onboarding_click_submit';
}

/// Paywall entry-point triggers for [MarketingEventNames.viewPaywall].
abstract final class PaywallTrigger {
  static const splashReturning = 'splash_returning';
  static const pricingPage = 'pricing_page';
  static const discountOffer = 'discount_offer';
  static const topUp = 'top_up';
  static const generationWaiting = 'generation_waiting';
  static const settings = 'settings';
  static const header = 'header';
  static const rewards = 'rewards';
  static const home = 'home';
  static const library = 'library';
  static const premiumRadio = 'premium_radio';
  static const premiumPodcast = 'premium_podcast';
  static const allPlayback = 'all_playback';
}
