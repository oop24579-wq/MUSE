# Firebase — DramaNow

Use a **new Firebase project** for DramaNow (do not reuse AI Music Maker).

## Remote Config import

1. Create project in [Firebase Console](https://console.firebase.google.com/)
2. Add iOS app: bundle ID `com.shortdrama.watch`
3. Add Android app: package `com.shortdrama.watch`
4. Download `GoogleService-Info.plist` → `ios/Runner/`
5. Download `google-services.json` → `android/app/`
6. **Remote Config → ⋮ → Publish from file / Import** (or use REST API) with:

   `firebase/remote_config_initial.json`

7. Fill **required** parameter values in Console before shipping:

| Key | Required | Notes |
|-----|----------|-------|
| `api_base_url` | Yes | DramaNow web API origin (e.g. `https://your-domain.com`) |
| `revenuecat_ios_api_key` | Yes (iOS) | RevenueCat public key |
| `revenuecat_android_api_key` | Yes (Android) | RevenueCat public key |
| `revenuecat_pro_entitlement_id` | Yes | Default `shortdrama_vip` |
| `onesignal_app_id` | Recommended | Push |
| `terms_url` / `privacy_url` | Recommended | Legal links |
| Ad unit IDs | If `is_ad_enabled` | AdMob units |

## Feature flags

| Key | Default | Purpose |
|-----|---------|---------|
| `show_ready_to_start` | true | Onboarding on first launch |
| `premium_playback_mode` | premium_content | Playback gating for non-VIP |
| `feature_vip_only_series` | true | Gate VIP-only series |
| `feature_offline_downloads` | true | Gate episode downloads behind VIP |
| `feature_hd_streaming` | true | Gate HD streaming behind VIP |
| `home_default_locale` | en | Home feed fallback locale |

## Removed (legacy)

Do **not** add these to the new project:

- `generate_music_api_key`
- `topup_product_ids`, `pro_daily_song_limit`, `music_cards_count`
- `world_cup_26_header_badge_enabled`
