# DramaNow — Flutter Short-Drama Streaming App

**DramaNow** is a complete, production-ready Flutter app (iOS & Android) for streaming **short vertical dramas** — a ReelShort / DramaBox–style experience for AI-generated episodic video. It ships with a **Next.js / Postgres web API** backend, Firebase Auth + Remote Config–driven settings, RevenueCat VIP subscriptions, a coin/rewards economy, multi-language dubbing, OneSignal push, optional AdMob ads, and full white-label branding.

It also includes **content-generation scripts** that create the demo catalog for you: cinematic posters/heroes via **fal.ai** and episode videos/trailers via **Wiro**, uploaded straight to **Cloudflare R2**.

---

## Table of Contents

1. [What's Included](#whats-included)
2. [Key Features](#key-features)
3. [Content Model](#content-model)
4. [Architecture Overview](#architecture-overview)
5. [Requirements & Prerequisites](#requirements--prerequisites)
6. [Quick Start](#quick-start)
7. [Backend Setup](#backend-setup)
8. [Generating the Demo Catalog (images & video)](#generating-the-demo-catalog-images--video)
9. [Firebase Remote Config](#firebase-remote-config)
10. [Branding & Customization](#branding--customization)
11. [Environment & Security](#environment--security)
12. [Releasing to the Stores](#releasing-to-the-stores)
13. [Troubleshooting](#troubleshooting)
14. [FAQ](#faq)

---

## What's Included

- Full Flutter app source (`drama_now`, Flutter SDK ^3.6.0)
- **Content generators** (`scripts/generate-drama-images/`): posters/heroes (fal.ai `openai/gpt-image-2`) + episode videos/trailers (Wiro `pruna/p-video`) → Cloudflare R2
- 7 color themes · 5 onboarding layouts · 7 paywall layouts
- 13-language localization (ar, de, en, es, fr, it, ja, ko, pt, ru, tr, zh + base)
- Android & iOS store release checklists

**Default identifiers:** Package / Bundle ID `com.shortdrama.watch` · OAuth deep link `com.shortdrama.watch://login-callback` · Dart package `drama_now`

> ⚠️ **Not included:** backend service accounts. You create your own (free-tier) Firebase, DramaNow web API / Postgres, RevenueCat, and optionally OneSignal / AdMob / fal.ai / Wiro / Cloudflare R2 accounts and connect them with your own keys.

## Key Features

| Area | What users get |
|---|---|
| **Discover** | Search, filter tabs (Popular / New / Ranking / Categories), and CMS-driven shelves: Featured hero pager, **What's Hot** (3-row horizontal grid), Trending, New Releases, **You'll Love** (2-col grid), **Top 10** ranking, and per-genre rails |
| **Categories** | 2-column gradient category grid → per-genre catalog |
| **Shorts** | A "For You" browse feed of spotlight cards |
| **Series detail** | Hero, synopsis, **season selector**, episode grid, My List / Like / Share, "More Like This", skeleton loading |
| **Player** | Full-screen `video_player`, prev/next, coin/VIP unlock gate, **in-player dubbing switcher** (Original + language tracks), rich Episodes sheet (VIP banner, series header, range tabs, 6-col grid), share, +My List |
| **Dubbing** | Language flags on covers; per-episode video tracks; switch language mid-episode at the current timestamp |
| **Rewards** | Coin balance, 7-day daily check-in (auto-claimed at launch), starter tasks, rewarded-ad bonus, series-milestone rewards |
| **My List** | Recently Watched (continue watching) + My Collection |
| **Profile** | Avatar (app icon for anonymous users), VIP badge, coins, quick links, settings |
| **Accounts** | Anonymous start; Google, Apple, and email sign-in with data migration |
| **Monetization** | RevenueCat weekly/monthly/yearly **VIP** plans, discount offers, VIP/coin gating, AdMob |
| **Personalization** | Light/dark theme, 13 languages, remote onboarding kill-switch |

## Content Model

```
Genre ──< Series ──< Season ──< Episode ──< EpisodeDub (per-language video track)
                       │
                       └── trailerUrl (fragman) · coverImageUrl · heroImageUrl · dubLanguages[]
User library:  UserFavorite (My List) · UserSeriesLike · FollowSeries · WatchHistory · EpisodeProgress · UserEpisodeUnlock
Rewards:       User.coinBalance · UserCheckin · RewardTask/UserRewardTask · CoinTransaction
Home feed:     HomeSection (featured_hero | series_carousel | ranking_list | new_releases | hot_grid | vertical_grid | genre_grid) ──< HomeSectionItem
```

**Security:** episode stream URLs are never exposed to clients in catalog responses. Clients fetch the playable URL only via the entitled playback API, which enforces free / VIP / coin-unlock entitlement server-side. Coin/reward/like operations run through authenticated API endpoints.

## Architecture Overview

```
Flutter app (iOS / Android)  — tabs: Discover · Shorts · Rewards · My List · Profile
 ├── Firebase     → Auth (anon/Google/Apple/email), Remote Config, Analytics, Crashlytics
 ├── Web API       → Next.js + Postgres catalog, entitlements, coins/rewards, account relink
 ├── Cloudflare R2 → series covers / heroes / episode videos (CDN via MEDIA_CDN_BASE_URL)
 ├── RevenueCat   → VIP subscriptions & entitlement (default: shortdrama_vip)
 ├── OneSignal    → push notifications (optional)
 └── AdMob        → ads + rewarded bonus coins (optional)
Video streams from CDN / episode URLs via video_player.
```

Startup order: **Firebase → Remote Config → OneSignal → Auth + web API session.** Remote Config must be filled in and published (`api_base_url`) before API auth initializes.

## Requirements & Prerequisites

**Tools:** Flutter SDK 3.6+, Android Studio + Android SDK (API 34+), Xcode 15+ with CocoaPods (for iOS), Node 18+ (for the content scripts), Git.

**Accounts:** [Firebase](https://console.firebase.google.com) (required), DramaNow web API / Postgres host (required), [RevenueCat](https://app.revenuecat.com) (for VIP), [OneSignal](https://onesignal.com) (optional push), [AdMob](https://admob.google.com) (optional ads), [Cloudflare R2](https://www.cloudflare.com/developer-platform/r2/) + [fal.ai](https://fal.ai) + [Wiro](https://wiro.ai) (optional — only to generate demo art/video).

```bash
flutter doctor -v
```

## Quick Start

1. **Install tools & fetch deps** — `flutter pub get`.
2. **Create accounts** — Firebase + web API backend (required); others optional.
3. **Backend** — deploy / seed the DramaNow Next.js API + Postgres catalog (see the web project).
4. **Keys** — paste service keys into **Firebase Remote Config** and click **Publish** (import `firebase/remote_config_initial.json` as a starting point). Set `api_base_url` to your API origin.
5. **Run** — `flutter run`.
6. **Brand & release** — name, icon, colors, then publish.

> ⚠️ **Most common mistake:** forgetting to **Publish** in Firebase Remote Config. If the app hangs on splash / skips API auth, that's almost always why.

## Backend Setup

The mobile app talks to the **DramaNow web API** (Next.js + Prisma / Postgres). Point Remote Config `api_base_url` at that origin (e.g. `https://your-domain.com`).

Typical backend responsibilities:

| Area | Notes |
|------|--------|
| Catalog | Genres, series, seasons, episodes, dubs, home shelves |
| Auth bridge | Firebase ID tokens → app user / session |
| Entitlements | VIP / coin unlock → playable episode URLs |
| Webhooks | RevenueCat → VIP / coin grants |
| Media | Public URLs under `MEDIA_CDN_BASE_URL` (Cloudflare R2) |

Seed and migrate the database from the web project's Prisma seed (`prisma/seed` / `db:seed`). Media URLs follow:

```
{MEDIA_CDN_BASE_URL}/series-covers/<slug>.jpg
{MEDIA_CDN_BASE_URL}/series-heroes/<slug>.jpg
{MEDIA_CDN_BASE_URL}/episode-videos/<slug>.mp4
```

**Auth:** enable Firebase Anonymous (required), Email, Google, and Apple. Add OAuth redirect URL `com.shortdrama.watch://login-callback` where your providers require it.

**R2 buckets / prefixes:** `series-covers`, `series-heroes`, `episode-videos`, `person-photos` (plus any app-specific assets such as avatars / onboarding).

## Generating the Demo Catalog (images & video)

The catalog can ship with placeholder art so the app works immediately. To generate real drama art & video into **Cloudflare R2**, use the scripts in `scripts/generate-drama-images/`:

```bash
cd scripts/generate-drama-images
npm install
cp .env.example .env    # FAL_KEY + WIRO_API_KEY + R2_* + MEDIA_CDN_BASE_URL

# Posters (3:4) + featured heroes (16:9) → fal.ai → R2
npm run dry-run         # preview prompts, no API calls
npm run generate
npm run retry           # retry only failures

# One cinematic clip per series (image-to-video from the cover) → Wiro → R2
npm run videos:dry-run
npm run videos          # reused for every episode + as the series trailer (fragman)
```

Both write results to `output/*.json` (safe to stop/resume). After upload, set `MEDIA_CDN_BASE_URL` and re-seed the web DB (`npm run db:seed`). Prompts live in `prompts.mjs` (edit + `--retry-failed` for any that trip content moderation). See that folder's `README.md` and the top-level `DRAMA_IMAGE_PROMPTS.md`.

## Firebase Remote Config

Remote Config is the single source of truth for runtime keys. Import `firebase/remote_config_initial.json`, then set at minimum:

| Key | Value |
|---|---|
| `api_base_url` | DramaNow web API origin (e.g. `https://your-domain.com`) — required |
| `revenuecat_pro_entitlement_id` | e.g. `shortdrama_vip` |
| `revenuecat_android_api_key` / `revenuecat_ios_api_key` | RevenueCat public SDK keys |
| `onesignal_app_id` | OneSignal App ID (optional) |
| `app_url` / `terms_url` / `privacy_url` | Marketing / legal URLs |

Useful flags: `show_ready_to_start` (`false` → **skip onboarding, first open goes straight Home**; paywall still shows from the 2nd open), `premium_playback_mode` (`disabled` / `premium_content` / `all_playback`), `is_ad_enabled`, `welcome_coin_bonus`, `episode_unlock_coin_cost`, `discount_offer_*`, force-update gates. **Publish after every change.**

## Branding & Customization

- **App name:** `AndroidManifest.xml` → `android:label`; `Info.plist` → `CFBundleDisplayName`; header brand string in `lib/widgets/app_header.dart`.
- **App title / splash tagline / paywall & onboarding copy:** `lib/l10n/app_en.arb` (`appTitle`, `paywall*`, `splashTagline`) + `lib/presentation/onboarding/…`.
- **Logo / launcher icon:** replace `assets/images/app_icon.png` (1024×1024), then `dart run flutter_launcher_icons`.
- **Color themes (7 presets):** `lib/theme/app_theme.dart` → `kColorPreset` (1–7). Copy a `_PresetColors` block for a fully custom brand; light/dark are generated.
- **Onboarding / paywall layouts:** `onboarding_config.dart` → `kOnboardingVariant` (1–5); `paywall_config.dart` → `kPaywallVariant` (1–7).
- **Catalog content:** seed via the web Prisma seed, or generate media with the scripts above.
- **Bundle ID (full re-brand):** update Android `applicationId`, iOS bundle id, Firebase apps, Google OAuth clients, OAuth redirect URL, RevenueCat apps, store listings — all must match.

## Environment & Security

There is **no `.env` in the app** — config is layered so no secret is hard-coded:

| Layer | Location | Holds |
|---|---|---|
| Firebase Remote Config | Firebase Console | All runtime keys & flags (`api_base_url`, RevenueCat, ads, …) |
| Native Firebase files | `google-services.json`, `GoogleService-Info.plist` | Firebase identity |
| Web API / server env | Hosting platform (e.g. Vercel) | DB URL, RevenueCat webhook token, Firebase Admin, R2 keys |
| Script `.env` | `scripts/generate-drama-images/.env` | `FAL_KEY`, `WIRO_API_KEY`, R2 credentials (dev-only, gitignored) |
| Dev flags | `lib/core/test_flags.dart` | Must all be `false` for release |

**Security rule:** the app only ever holds *public* keys. Server secrets, fal/Wiro keys, and webhook tokens are server/dev-side only. Episode video URLs are gated by the entitled playback API and never sent to the client in plaintext catalog payloads.

## Releasing to the Stores

Full checklists in `ANDROID_RELEASE_CHECKLIST.md` / `IOS_RELEASE_CHECKLIST.md`. Critical blockers:

**Android:** upload keystore + `android/key.properties`, release signing, real AdMob App ID, production RevenueCat & ad-unit keys in Remote Config, `TestFlags` all `false`, release SHA-1/256 in Firebase & Google OAuth:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

**iOS:** Apple Developer membership, App ID with Push / Sign in with Apple / IAP, real AdMob App ID in `Info.plist`, Sign in with Apple enabled (mandatory alongside Google):

```bash
flutter build ipa --release --obfuscate --split-debug-info=build/ios/symbols
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| **App stuck on splash / `⚠️ Skipping API auth`** | Set `api_base_url` in Remote Config and **Publish** |
| **No data on any tab** | Seed the web DB; verify Series / Episode / HomeSectionItem have rows; confirm API is reachable |
| **Detail loads but no episodes** | Check season / episode seed data and API responses for the series |
| **Video won't play / locked** | Playback API gates by free/VIP/coins; check the episode's `isFree`/`coinCost`/`isVipOnly` and the user's entitlement |
| **`package:drama_now/...` unresolved** | Run `flutter pub get` (regenerates the package map after the rename) |
| **Paywall empty** | Entitlement ID + platform API key in Remote Config; products exist & are linked in RevenueCat |
| **Image/video script fails** | `npm install` first; check `.env` keys (R2 + fal/Wiro); `--retry-failed`. Content-moderation flags → soften the prompt in `prompts.mjs` |
| **Google/Apple Sign-In fails** | SHA-1 in Firebase + Google OAuth (Android); `REVERSED_CLIENT_ID` URL scheme (iOS); Apple provider fully configured in Firebase |
| **General build weirdness** | `flutter clean && flutter pub get` (+ `pod install` on iOS) |

## FAQ

**Do I need a `.env`?** Not for the app — runtime config is in Firebase Remote Config. The content-generation scripts use their own dev-only `.env`.

**Minimum services to run?** Firebase + DramaNow web API (Postgres). RevenueCat only if you sell VIP; OneSignal, AdMob, fal.ai, Wiro, and R2 are optional for a full media pipeline.

**Can I launch without ads or a paywall?** Yes: `is_ad_enabled = false` and `premium_playback_mode = disabled` in Remote Config.

**How do seasons / dubbing work?** Episodes belong to a `Season`; multi-season series show a season selector. Dubbed series list `dubLanguages` (flags on the cover) and store per-language video tracks in `EpisodeDub`; the player switches language at the current timestamp.

**How does anonymous auth work?** The app creates an anonymous Firebase session on first launch; signing in later migrates My List, likes, follows, history, coins, and VIP to the real account via the web API.
