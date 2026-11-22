import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/test_flags.dart';
import '../../models/drama/episode_model.dart';
import '../../models/drama/series_model.dart';
import '../../services/firebase/remote_config_service.dart';
import '../../services/marketing/marketing_event_names.dart';
import '../../services/user_provider.dart';
import '../../widgets/discount_offer.dart';

/// How strictly playback is gated for non-VIP users (Firebase RC driven).
enum PremiumPlaybackMode {
  /// No paywall gate beyond per-episode VIP/coin locks.
  disabled,

  /// Only `isVipOnly` content requires VIP.
  premiumContentOnly,

  /// Every play action requires VIP.
  allPlayback,
}

/// The action needed to watch a locked episode.
enum EpisodeAccess {
  /// Playable now (free, unlocked, or VIP user).
  playable,

  /// Requires a VIP subscription (paywall).
  vipRequired,

  /// Can be unlocked by spending coins.
  coinLocked,
}

/// Central entitlement rules for DramaNow — toggled via Firebase Remote Config.
class DramaEntitlementService {
  DramaEntitlementService._();
  static final DramaEntitlementService instance = DramaEntitlementService._();

  PremiumPlaybackMode get playbackMode {
    final raw =
        RemoteConfigService.instance.premiumPlaybackMode.trim().toLowerCase();
    return switch (raw) {
      'all' || 'all_playback' => PremiumPlaybackMode.allPlayback,
      'premium' ||
      'premium_content' ||
      'premium_only' =>
        PremiumPlaybackMode.premiumContentOnly,
      _ => PremiumPlaybackMode.disabled,
    };
  }

  bool get showVipBadges => RemoteConfigService.instance.premiumShowProBadges;

  bool isEffectivelyVip(bool isVip) => TestFlags.forceProForTest || isVip;

  /// Whole-series VIP gate (used before opening a VIP-only series).
  bool requiresVipForSeries(SeriesModel series, bool isVip) {
    if (isEffectivelyVip(isVip)) return false;
    if (playbackMode == PremiumPlaybackMode.allPlayback) return true;
    return series.isVipOnly;
  }

  /// What is needed to watch [episode].
  EpisodeAccess accessFor(EpisodeModel episode, bool isVip) {
    if (isEffectivelyVip(isVip)) return EpisodeAccess.playable;
    if (episode.isUnlocked && playbackMode != PremiumPlaybackMode.allPlayback) {
      return EpisodeAccess.playable;
    }
    if (playbackMode == PremiumPlaybackMode.allPlayback) {
      return EpisodeAccess.vipRequired;
    }
    if (episode.isVipOnly) return EpisodeAccess.vipRequired;
    if (episode.coinCost > 0 && !episode.isUnlocked) {
      return EpisodeAccess.coinLocked;
    }
    return EpisodeAccess.playable;
  }

  bool shouldShowVipBadge({required bool isVipOnly, required bool isVip}) {
    if (!showVipBadges) return false;
    if (isEffectivelyVip(isVip)) return false;
    return isVipOnly;
  }

  /// Present the paywall for a VIP-gated action; returns true if the user is
  /// now VIP.
  Future<bool> presentPaywall(
    BuildContext context, {
    String trigger = PaywallTrigger.allPlayback,
  }) async {
    await presentPaywallWithDiscount(context, trigger: trigger);
    if (!context.mounted) return false;
    return isEffectivelyVip(context.read<UserProvider>().isPro);
  }

  bool hasPlayableVideo(EpisodeModel episode) =>
      (episode.videoUrl ?? '').trim().isNotEmpty;
}
