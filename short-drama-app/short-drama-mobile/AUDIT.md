# DramaNow Flutter App — Static Audit

Date: 2026-11-22
Scope: `lib/` (171 Dart files), `pubspec.yaml`, `assets/`, Firebase config files, `firebase/remote_config_initial.json`
Method: static verification only — grep, a Python import-resolution / brace-balance script (`/tmp/audit.py` during the run), and manual source reading.

> **Verification was static-only because no Flutter SDK is available in this VM** (`flutter` / `dart` are not in PATH and could not be installed). No `flutter analyze`, `dart analyze`, build, or test run was performed. Undefined-identifier / type errors that only the Dart analyzer can catch were therefore NOT checked; structural issues, missing files, broken imports, asset paths, and duplicate class definitions were.

---

## (a) Issues found

### Fixed — clear defects

1. **Broken relative import in `lib/main.dart:13`**
   `import '../l10n/app_localizations.dart';` — from `lib/`, `../` escapes the package root, resolving to `<project>/l10n/app_localizations.dart`, which does not exist. The file lives at `lib/l10n/app_localizations.dart`.

2. **Broken relative import in `lib/presentation/splash_screen/splash_screen.dart:8`**
   `import '../../../core/app_export.dart';` — three levels up from `lib/presentation/splash_screen/` escapes the package root, resolving to `<project>/core/app_export.dart`, which does not exist. Every other import in the same file correctly uses `../../…` (e.g. line 23 `../../l10n/app_localizations.dart`).

### Not fixed — needs a decision / user account (see section c)

3. **iOS bundle-ID mismatch between Xcode project and Firebase plist**
   - `ios/Runner.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER = com.shortdrama.watch`
   - `ios/Runner/GoogleService-Info.plist` and `ios/GoogleService-Info.plist`: `BUNDLE_ID = com.shortdrama.watchios`, `GOOGLE_APP_ID = 1:604333749944:ios:3b4fe45c0e045ce31e264d`
   - Android is consistent: `android/app/build.gradle` `applicationId = "com.shortdrama.watch"` matches `android/app/google-services.json` `package_name = "com.shortdrama.watch"`.
   - Not auto-fixed: fixing it means either changing the app's bundle ID or regenerating the plist in the Firebase console for the real bundle ID — a Firebase-project decision for the owner.

4. **Direct import of a transitive-only package in `lib/bootstrap.dart`**
   `import 'package:flutter_cache_manager/flutter_cache_manager.dart';` — `flutter_cache_manager` is **not** a direct dependency in `pubspec.yaml`; it is present in `pubspec.lock` only as a transitive dependency of `cached_network_image`. It resolves today, but is fragile (a `cached_network_image` upgrade could drop/change it, and lints can flag importing a non-direct dependency). Not auto-fixed: adding it to `pubspec.yaml` properly requires `flutter pub get` to regenerate `pubspec.lock`, which is impossible without an SDK.

5. **Remote Config values that must be filled in the Firebase console are empty in `firebase/remote_config_initial.json`**
   Empty-string defaults: `api_base_url` (marked "required" in its own description — `lib/bootstrap.dart` skips API auth entirely when it is empty, and `RemoteConfigService.logMissingConfigKeys()` treats it as required), `mobile_api_key`, `onesignal_app_id`, `revenuecat_ios_api_key`, `revenuecat_android_api_key`, `turnstile_site_key`, and all AdMob unit IDs (`android/ios_interstitial_ad_unit_id`, `android/ios_banner_ad_unit_id`). Also placeholder: `ios_store_url = https://apps.apple.com/app/idXXXXXXXXXX`.
   In-code defaults in `RemoteConfigService._emptyDefaults` are `''` / `false` / `0` for all keys, so none of these fall back to a usable value in the app.

6. **Leftover non-drama template surface (noted, not removed — audit instruction was do-not-delete)**
   The generated localizations (`lib/l10n/app_localizations*.dart`, 13 locale files) and parts of `RemoteConfigService` still carry a music/podcast/radio template's keys and strings (e.g. `placeholderSongDescription`, `placeholderLyrics`, `settingsPodcastAutoDownload`, section "RadioPod features", keys `feature_premium_stations`, `max_radio_presets`, `podcast_*`), and onboarding/paywall assets are named `onboarding_ai_songs.png`, `onboarding_ai_covers.png`, `onboarding_ai_music_videos.png`. These compile fine; they are dead/irrelevant surface, not blockers.

### Checked and clean

- **TODO / FIXME / stub / mock scan** (`grep -rn` over `lib/`): **zero** strict `TODO`, `FIXME`, `XXX:`, or `HACK:` markers; **zero** `UnimplementedError` / stub implementations. The only word "Mock" hits are two explanatory comments in `lib/presentation/app_settings/widgets/theme_preview_widget.dart:55,89` ("// Mock app bar", "// Mock content") describing a visual theme-preview mockup widget — not a mock data layer. Other "placeholder" hits are legitimate Flutter/image `placeholder:` builders and generated localization getter names (see item 6).
- **Import resolution**: 943 `import`/`export` directives scanned. Before fixes: exactly the 2 broken ones above. After fixes: **0 broken**. All `package:drama_now/…` imports map to existing files under `lib/`; all relative imports and all `part` directives resolve. All other external `package:` imports correspond to direct dependencies in `pubspec.yaml` (36 distinct packages), except `flutter_cache_manager` (item 4).
- **pubspec asset paths**: all 7 declared paths exist on disk — `assets/` (35 files), `assets/fonts/` (11), `assets/images/` (18), `assets/images/onboarding/` (4), `assets/images/paywall/` (5), `assets/images/paywall/avatar/` (5), `assets/avatars/` (6). `flutter_launcher_icons.image_path: assets/images/app_icon.png` also exists. All 18 literal `assets/…` strings referenced in Dart code exist on disk.
- **`lib/core/test_flags.dart`**: all flags already `false` — `forceProForTest = false`, `testMode = false`, `useRevenueCatTestKey = false`. No change needed. (Note: `lib/services/revenuecat_service.dart` still auto-uses the RevenueCat *test* key in debug builds via `kDebugMode || TestFlags.useRevenueCatTestKey`; that is by design and does not affect release builds.)
- **Brace / paren / bracket balance**: Python script stripping `//` and `/* */` comments and single/triple-quoted strings naively, then counting `{}`, `()`, `[]` per file — **all 171 Dart files balanced, 0 unbalanced**.
- **Duplicate definitions**: no duplicate top-level class names across `lib/`; no duplicate import lines within any single file.
- **Firebase initialization**: `lib/services/firebase/firebase_service.dart` calls `Firebase.initializeApp()` with **no options**, i.e. it relies on the native config files below — there is intentionally no `lib/firebase_options.dart`, and none is referenced. That is consistent, not a defect, as long as the native files are present and match the bundle IDs (see item 3 for iOS).

---

## (b) Fixed — what and where

Every app file touched by this audit (2 files, 1 line each):

1. **`lib/main.dart`** (line 13)
   - Before: `import '../l10n/app_localizations.dart';`
   - After: `import 'l10n/app_localizations.dart';`

2. **`lib/presentation/splash_screen/splash_screen.dart`** (line 8)
   - Before: `import '../../../core/app_export.dart';`
   - After: `import '../../core/app_export.dart';`

Plus this report itself: **`AUDIT.md`** (new file, project root).

Nothing was deleted. Nothing was pushed to GitHub. `lib/core/test_flags.dart` needed no change (already all `false`). No asset paths in `pubspec.yaml` needed correction (all exist). No unbalanced-brace typos were found, so no brace fixes were made. Re-running the import/balance script after the fixes reports **0 broken imports and 0 unbalanced files**.

---

## (c) What remains — needs the user's own accounts / keys

1. **Firebase project `short-drama-c8029`** (project number `604333749944`):
   - Native config files **are present** — `android/app/google-services.json` ✅, `ios/Runner/GoogleService-Info.plist` ✅, and an identical duplicate at `ios/GoogleService-Info.plist` ✅ (the two iOS copies are byte-identical). They were **not** fabricated by this audit.
   - **Resolve the iOS bundle-ID mismatch (item 3):** in the Firebase console, either register the iOS app with bundle ID `com.shortdrama.watch` and download a fresh `GoogleService-Info.plist`, or change the Xcode bundle ID to `com.shortdrama.watchios`. Owner's choice.
   - **Publish Remote Config** from `firebase/remote_config_initial.json` and fill the empty values, above all `api_base_url` (the app skips backend auth without it).
2. **Backend / API origin**: a real deployed DramaNow web API URL for `api_base_url` (and `mobile_api_key` if the API expects one). Placeholder `https://shortdrama.app` is used for `app_url` / `terms_url` / `privacy_url` in the Remote Config template.
3. **RevenueCat**: production iOS/Android public API keys (`revenuecat_ios_api_key`, `revenuecat_android_api_key` in Remote Config) and the VIP entitlement — the template's entitlement ID is `shortdrama_vip`, and the discount product is `shortdrama_vip_yearly_discount:yearly-discount`. Until real keys are set, only the debug/test-store key path works.
4. **OneSignal**: `onesignal_app_id` (empty in the template) for push notifications.
5. **AdMob**: real Android/iOS interstitial + banner (+ rewarded, referenced in code) ad unit IDs; all are empty in the template while `is_ad_enabled` defaults to `true`.
6. **Cloudflare Turnstile**: `turnstile_site_key` if `captcha_enabled` is turned on (currently `false`, key empty).
7. **App-store listings**: replace the placeholder iOS store URL (`idXXXXXXXXXX`) once the App Store listing exists; Android store URL in the template already assumes package `com.shortdrama.watch`.
8. **Android signing**: `android/key.properties` (only `key.properties.example` is present) with the owner's release keystore, before a Play release build.

---

## Contract confirmations (for the backend team)

Verified directly from source; "the brief" = the shapes the backend was asked to implement.

### POST /auth/firebase — CONFIRMED (`lib/services/auth/auth_service.dart`, `exchangeFirebaseToken`, ~lines 145–175; `lib/services/api/api_client.dart`)
- Client base URL is built as `{api_base_url}/api/v1` (trailing slash stripped from the Remote Config `api_base_url`), so the full path is **`POST /api/v1/auth/firebase`**, sent unauthenticated via `postUnauthenticated`.
- **Request JSON:** `{ "idToken": <Firebase ID token string>, "deviceId": <string, omitted if unavailable> }`. No other fields.
- **Response JSON (envelope-unwrapped `data`) must contain:**
  - `data.tokens.accessToken` (String, required — cast, will throw if absent/wrong type)
  - `data.tokens.refreshToken` (String, required)
  - `data.user` (object, required) with `data.user.id` (String, required) used as the web user ID.
  - `data.user` is parsed by `UserModel.fromApi` (see user shape below).
- Related follow-on the backend must also support: `POST /auth/relink` with `{ "guestUserId": <old web user id> }` (authenticated) after a guest upgrades to a non-anonymous account, and `POST /auth/refresh` (used by `ApiClient` on token expiry).

### Genre — CONFIRMED (`lib/models/drama/genre_model.dart`)
`GenreModel.fromJson` fields: `id` (String, **required** — bare cast), `slug` (String, default `''`), `name` (String, default `''`), `description` (String?), `iconUrl` (String?, passed through `rewriteMediaUrl`), `colorHex` (String?, e.g. `#E63A6E`), `sortOrder` (int, default 0).
Genre slugs the UI special-cases for icons (`genre_grid.dart`): `romance`, `ceo`, `revenge`, `werewolf`, `rebirth`, `marriage`, `secret`, `mafia`, `historical`, `campus`, `thriller`, `fantasy` (anything else gets a generic movie icon).

### Series — CONFIRMED (`lib/models/drama/series_model.dart`)
`SeriesModel.fromJson` fields: `id` (String, **required**), `slug`, `title` (both default `''`), `synopsis`, `tagline`, `coverImageUrl`, `heroImageUrl`, `trailerUrl` (all media-rewritten), `gradientStart`, `gradientEnd`, `genreId`, `releaseYear` (int?), `totalEpisodes` (int, 0), `totalSeasons` (int, 1), `language` (String, `'en'`), `dubLanguages` (List<String>), booleans `isVipOnly`, `isExclusive`, `isNew`, `isHot`, `isCompleted` (default **true**), `isDubbed`, counts `viewCount`, `likeCount`, `ratingCount`, `rankScore` (num→int), `ratingAvg` (num→double), `isFeatured`, `sortOrder`, `tags`.
Two flexible input shapes the backend may use: genre name may arrive nested as `Genre: {name}` / `genre: {name}` **or** flat as `genreName`; tags may arrive as `SeriesTag: [{tag: …}]` / list of strings **or** flat `tags`.

### Episode — CONFIRMED (`lib/models/drama/episode_model.dart`)
`EpisodeModel.fromJson` fields: `id` (String, **required**), `seriesId` (String, **required**), `seasonId` (String?), `seasonNumber` (int, 1), `episodeNumber` (int, 0), `title`, `description`, `videoUrl` (media-rewritten; comment in source says the list view does **not** expose it — it is fetched separately), `thumbnailUrl`, `durationSeconds` (int?), `isFree` (bool, default **true**), `coinCost` (int, 0), `isVipOnly` (bool, false), `isUnlocked` (bool, defaults to the value of `isFree` when absent), `publishedAt` (ISO-8601 string, `DateTime.tryParse`), `viewCount` (num→int), `sortOrder` (int).

### Rewards / tasks — CONFIRMED (`lib/models/drama/reward_models.dart`, `lib/services/drama/drama_service.dart`)
- `RewardTaskModel.fromJson` fields: `slug` (String, default `''`), `title` (String, default `''`), `description` (String?), `coins` (num→int, 0), `actionType` (String?), `sortOrder` (num→int, 0), plus server-computed `progress` (num→int, 0), `target` (num→int, default **1**), `eligible` (bool, false); `completed` is supplied by the caller, not read from the task JSON itself. `GET /rewards` supplies the state; claims go to **`POST /rewards/tasks/{slug}/complete`**. Source explicitly requires the server to send `progress`/`target`/`eligible` — the client renders the server's numbers and the server must reject non-eligible claims.
- Concrete slugs hard-coded in the client (`series_reward_tile.dart`, `kSeriesMilestoneTargets`, all `actionType` family "series_milestone"): **`series_watch_3` → 3, `series_watch_10` → 10, `series_watch_25` → 25, `series_collect_5` → 5** (`series_collect_*` counts My List entries; `series_watch_*` counts watched dramas). The backend must seed tasks with exactly these slugs or the Series Rewards rows will not match.
- Daily check-in: client constant `kDailyCheckinRewards = [20, 50, 35, 30, 35, 20, 50]` (days 1–7), stated in source to mirror the backend `claim_daily_checkin()` logic; claim endpoint `POST /rewards/checkin`; rewarded-ad credit `POST /rewards/ad` with `{ "amount": <int> }`; balance via `GET /me/coins` / rewards state field `coinBalance`.

### User & subscription — CONFIRMED (`lib/models/user/user_model.dart`, `subscription_model.dart`)
- `UserModel.fromApi` (the `/auth/firebase` + `/auth/me` shape): `id` (String, **required**), `firebaseUid` (String?, falls back to `id`), `email` (String?), display name from **`name`** (fallback `displayName`), photo from **`image`** (fallback `photoUrl`), `deviceId`, `subscriptionExpirationDate` (String?), guest flag from **`isGuest`** (fallback `isAnonymous`, default true), `isPro` (bool, false), `coinBalance` (num→int, 0), `autoplayNext` (bool, true), `videoQuality` (String, `'auto'`), `createdAt` (ISO string; falls back to now), updated-at proxy from **`linkedAt`** (falls back to now). `isVip` is a client alias of `isPro`.
- `SubscriptionModel.fromJson` accepts camelCase **or** snake_case for every field: `id` (required), `userId`, `paymentProvider` (default `'revenuecat'`), `planId`, `status`, `currentPeriodStart`, `currentPeriodEnd`, `cancelAtPeriodEnd`, `email`, `paymentMethod`, `revenueCatTransactionId`, `createdAt`, `updatedAt`. Active statuses recognised: `active`, `trialing`, `past_due` — and only while `currentPeriodEnd` is in the future. Period type is inferred from `planId` containing `weekly` / `monthly` / `yearly`.

### Remote Config defaults — CONFIRMED (`firebase/remote_config_initial.json`)
- **`welcome_coin_bonus` = 30** (NUMBER) — "Coins granted to a new user on first launch".
- **`episode_unlock_coin_cost` = 30** (NUMBER) — "Default coin cost to unlock a locked episode".
- Caveat for the backend team: **no Dart code in `lib/` reads either key** (grep finds them only in the JSON template; there is no getter in `RemoteConfigService`, and its in-code defaults are empty). Per-episode cost actually used by the client is the per-episode `coinCost` field from the API (see Episode above). So these two values are effectively **server-side / console-side defaults** — the backend should apply `welcome_coin_bonus` at account creation and `episode_unlock_coin_cost` when assigning episode `coinCost`, or tell the mobile team if the app is expected to read them.

---

## (d) Verification note

Verification was **static-only because no Flutter SDK is available** in this environment: import resolution, asset existence, flag values, config-file presence, and brace/paren/bracket balance were checked with grep and a Python script, and contract shapes were read from source. A follow-up `flutter analyze` + a debug build on a machine with the SDK is still required before release — in particular to catch analyzer-only issues (undefined identifiers, type errors) and to confirm the `flutter_cache_manager` transitive import and the iOS Firebase bundle-ID mismatch at build/run time.

---

## Rebrand to HERO DRAMA (2026-11-22)

App rebranded from "DramaNow" to **HERO DRAMA**. Scope: `short-drama-mobile/` only (backend untouched, nothing pushed to GitHub, nothing deleted).

### Files changed

- `android/app/src/main/AndroidManifest.xml` — `android:label` "DramaNow" → "HERO DRAMA".
- `ios/Runner/Info.plist` — added `CFBundleDisplayName` = "HERO DRAMA" (key was absent); `CFBundleName` "DramaNow" → "HERO DRAMA"; `NSUserTrackingUsageDescription` brand mention "DramaNow" → "HERO DRAMA" (user-visible permission-prompt text).
- `lib/l10n/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_ja.arb`, `app_ko.arb`, `app_pt.arb`, `app_ru.arb`, `app_tr.arb`, `app_zh.arb` (all 12 locales) — `appTitle` "DramaNow" → "HERO DRAMA" in every file (every locale held the plain brand string, none held a translated tagline, so all were changed); also `welcomeToAiMusicMaker` "Welcome to DramaNow!" → "Welcome to HERO DRAMA!" in every file (the string was the untranslated English brand string in all locales; shown on the privacy-consent screen).
- `lib/l10n/app_localizations.dart` and `app_localizations_{ar,de,en,es,fr,it,ja,ko,pt,ru,tr,zh}.dart` (13 generated files, checked in; `generate: true` in pubspec) — `appTitle` and `welcomeToAiMusicMaker` values (plus doc comments in `app_localizations.dart`) synced to match the ARB sources so the checked-in generated code does not drift until the next `flutter gen-l10n` / build regenerates them identically.
- `lib/main.dart` — `MaterialApp(title:)` 'DramaNow' → 'HERO DRAMA' (app title shown in the OS task switcher).
- `lib/presentation/onboarding/variants/onboarding_variants.dart` (2 occurrences) and `lib/presentation/onboarding/shared/onboarding_modern_pages.dart` (2 occurrences) — hardcoded fallback brand string `?? 'DramaNow'` → `?? 'HERO DRAMA'` (used as the displayed app name when localizations are unavailable).
- `lib/presentation/drama/episode_player_screen.dart` — share text "…on DramaNow" → "…on HERO DRAMA".
- `lib/presentation/drama/series_detail_screen.dart` — share text "…on DramaNow" → "…on HERO DRAMA".
- `web/index.html` — `<title>` "AI Music Maker" → "HERO DRAMA"; `apple-mobile-web-app-title` meta "AI Music Maker" → "HERO DRAMA".
- `web/manifest.json` — `name` and `short_name` "DramaNow" → "HERO DRAMA".
- `assets/images/app_icon.png` — placeholder icon (512×512) overwritten with the new HERO DRAMA logo at 1024×1024 (see Logo below). This is the path `flutter_launcher_icons` points to in `pubspec.yaml` (`image_path` / `adaptive_icon_foreground`, confirmed unchanged).

### Logo

- Source: `~/workspace/user/media_library/image/HOXBOX_logo_transparent.png` — **1100×1159 px, RGBA, transparent background** (red play-button "H" icon), measured with `ffprobe`/`file`.
- Because the source was not 1024×1024, it was composited with ffmpeg: scaled to fit within 1024×1024 keeping aspect ratio (≈972×1024), centered and overlaid on a solid **black** 1024×1024 canvas, flattened to RGB.
- Outputs verified 1024×1024 PNG: `assets/images/app_icon.png` (in-app / launcher-icon source) and an identical copy at `~/workspace/short-drama-app/logo_1024.png` (for later dashboard use).
- Note: native launcher icons (Android mipmaps, iOS AppIcon set, web icons) are NOT regenerated by this change — that requires running `flutter_launcher_icons` with a Flutter SDK, which is not available in this environment.

### Deliberately left unchanged

- `lib/widgets/app_header.dart` — **no change**: the header contains no displayed brand text at all; its only brand element is `Image.asset('assets/images/app_icon.png')`, which now renders the new logo automatically. No text was added, to avoid changing the header layout unasked.
- `ios/Runner/Info.plist` `FacebookDisplayName` = "DramaNow" — Facebook SDK registration value tied to the Facebook app configuration; treated as a project/Facebook identifier, not bundle branding.
- `pubspec.yaml` — package `name: drama_now` (code identifier) and `description: "DramaNow — short drama streaming app."` (store/metadata description, not in-app UI) left as-is per rebrand instructions.
- Code comments / debug output in `lib/services/firebase/remote_config_service.dart` (incl. a `debugPrint` banner), `lib/services/api/api_client.dart`, `lib/services/drama/drama_service.dart`, `lib/services/drama/drama_entitlement_service.dart` — "DramaNow" appears only in doc comments and a debug log line; not user-visible UI text.
- `web/manifest.json` `description` ("DramaNow — Live radio and podcasts worldwide.") and `web/index.html` meta `description` ("AI Music Maker — Create songs & music videos with AI.") — both are stale full taglines from earlier templates, not bare brand names; left for the owner to rewrite rather than guessing new copy. Flagged as follow-ups.
- `README.md` — documentation prose referring to the "DramaNow web API" backend; not app UI or config.
- All package/class identifiers, bundle IDs (`com.shortdrama.watch`), URL schemes, and Firebase/project identifiers — untouched.

---

## Phase 2 (2026-11-22) — player luxury, engagement visuals, captions client

Scope additions: luxury video player, rewards/engagement UI, app-config client,
caption playback. Verification re-run by the coordinator after all Phase 2 work:

- **Dart files: 187** (was 171), **import/export directives scanned: 1007**.
- **Broken imports: 0.** (The audit script flags one line —
  `lib/l10n/app_localizations.dart:31` — which is a doc-comment usage example,
  `/// import 'l10n/app_localizations.dart';`, not a real directive. Verified by hand.)
- **Brace/paren/bracket balance: all 187 files balanced, 0 unbalanced.**
- **Backend test suite re-run by the coordinator: 42/42 ALL PASS**
  (`backend/test/LAST_RUN.txt`) — the 30 Phase 1 cases untouched plus 12 new
  Phase 2 cases (config, wheel, chests, watch-time, missions, referrals, event
  multiplier, captions pipeline, maintenance + config exemption).

New app files: `lib/services/app_config_service.dart`,
`lib/models/drama/playback_model.dart`, `lib/services/drama/playback_service.dart`,
`lib/presentation/drama/widgets/player/` (seek ripple, edge HUD, platform
service, auto-next overlay, chapter progress bar, lock overlay, caption overlay
with a pure-Dart WebVTT parser), `lib/presentation/drama/widgets/wheel_widget.dart`,
`chest_row.dart`, `missions_section.dart`, `streak_level_header.dart`,
`lib/services/haptics_service.dart`, `lib/widgets/confetti_burst.dart`.
`lib/theme/app_theme.dart`: `kColorPreset` is now a mutable static, set from
`/config` by `ThemeProvider` (guarded 1..7).

Known Phase 2 scaffolds (honest list, also in `docs/VISUAL_FEATURES_50.md`):
- The `hero_drama/media_controls` MethodChannel has **no native Android/iOS
  implementation** — system brightness/volume and PiP need native code; the
  Dart side degrades gracefully (dim overlay, player volume, "not supported" toast).
- The accent-colour override from `/config` is not applied to the app
  ColorSchemes yet (no single safe override point inside the preset palettes).
- Ranking `rankDelta` is served by the API but the ranking tile does not
  render movement arrows yet.
- Still static-only verification: no Flutter SDK in this environment, so no
  `flutter analyze`/build was run for Phase 2 either.

---

# Phase 3 — Full file-by-file review (2026-11-22)

Four parallel reviewers + coordinator consolidation. **Files read in full:
129** (backend core 7, captions/economy 8, dashboard 4, Flutter 110) plus the
coordinator's own full reads of routes.js/settings.js/auth.js/db.js/
captions.js/server.js/seed.js and the test suite. Wiring matrix:
`docs/FEATURE_WIRING_MATRIX.md` (69 features).

## Verification
- Backend suite extended 42 → **57 cases, ALL PASS** (`backend/test/LAST_RUN.txt`).
  Case 34 was rewritten to accrue watch-time honestly (the old version relied
  on the forgery that is now blocked).
- Manual smoke on a fresh DB: register → browse → free playback → admin
  PATCH settings (unlock cost 7, wheel off) → `/config` reflects both → wheel
  spin returns 403 FEATURE_DISABLED.
- Dart static audit re-run after all Flutter edits: **187 files, 1,008
  imports, 0 unresolved, 0 unbalanced** (plus a targeted balance check on
  `reward_models.dart` after the coordinator's levelProgress fix).

## Blockers fixed
- **Relink coin-mint + crash** (routes.js): coin grant ran before an
  unguarded watch_history UPDATE that throws on PK conflict → retry granted
  again. Whole merge is now one transaction, conflict-safe, and carries XP,
  VIP, check-ins, tasks, notifications and daily progress.
- **Relink account takeover**: any logged-in user could merge/delete ANY
  account by id. Now only `isGuest` accounts can be merged (403 otherwise).
  Residual: guest-id knowledge still suffices for guests — see security list.
- **Watch-history forgery** (routes.js): client-supplied duration/position
  and invented episode ids farmed chests, missions and watch-time coins.
  Now: series/episode validated, positions clamped to the episode's real
  duration, per-episode daily high-water mark (`watch_progress`), and
  `watch_events` only recorded when real progress (delta > 0) was made.

## Majors fixed (backend)
- Account deletion now erases all 18 user tables (was: 2).
- VIP expiry (`subscriptionExpirationDate`) is enforced via an `isPro()`
  helper in serializers and all playback/unlock/caption gates.
- Unlock refuses VIP-gated episodes for non-VIPs (was: charged coins,
  playback still 403); episode price precedence fixed (`coinCost=0` means
  "unset" → global setting, not free-at-global-price ambiguity).
- Caption VTT/list endpoints are entitlement-gated like playback (locked
  episodes' full dialogue no longer readable by any logged-in user).
- Mission claim now checks `missions_enabled` (was the only claim without).
- Like counts/mission progress move only on real transitions; share mission
  progress is validated + once per series per day.
- Check-in ladder follows the consecutive streak (a missed day restarts at
  Day 1) in both payout and `/rewards` state; bonuses are settings keys
  (`checkin_level_bonus/streak_bonus/streak_cap`).
- Watch-time cap is enforced on actual coins paid (`paidCoins`), so a 2×
  event can no longer pay 200 against a 100 cap.
- Events with NULL dates now fire (open-ended); admin event dates are
  normalized/validated; overlapping events still resolve to max multiplier.
- Referral codes widened to 10 hex chars + UNIQUE index; codes are
  case-insensitive on entry; applying is limited to accounts ≤ 24h old.
- Refresh: user-existence checked before rotation (was a 500); DB-side
  token expiry honored; revoked-token reuse revokes the whole family;
  expired rows pruned on issue.
- Server: malformed JSON → 400 BAD_JSON (was silent `{}`), oversized body
  → 413 (was a hang), 500s no longer leak internal messages, admin token no
  longer printed at startup, production refuses dev-default secrets, admin
  static path check hardened (`ADMIN_DIR + sep`).
- Admin CRUD: PATCH/DELETE on missing genres/series/episodes now 404 (was
  500/false success); negative episode `coinCost` rejected (would mint
  coins on unlock); cast `characterName` can be cleared again.
- Captions: fetch timeouts + 200 MB download cap (a hung provider wedged
  the whole queue); startup recovery re-queues `processing` jobs; failed
  regeneration restores previously-ready tracks; duplicate jobs suppressed
  and targets persisted on the job row; `renderVtt` escapes markup,
  flattens newlines, sorts and clamps cues; manual generate respects
  `captions_enabled`; episode `videoUrl` change re-enqueues generation.
- Economy mutations (check-in, wheel, chest, mission, task, ad, watch-time,
  unlock, referral, relink, deletions) are wrapped in DB transactions.
- Settings: single-query `getSettings()`; wheel segments/weights
  cross-validated; duplicate chest thresholds rejected;
  `watch_time_block_minutes=0` rejected; task progress for `watch_episodes`
  counts distinct episodes (was series — and made the seeded
  series_watch_10/25 tasks unreachable).
- `/home` honors `?locale=` with an `en` fallback; negative `limit` clamped
  (SQLite `LIMIT -5` meant "no limit"); `today()` is the server-local day
  (set `TZ` in production); seed runs in one transaction (crash-safe);
  returning-user Firebase exchange refreshes profile claims.

## Majors fixed (Flutter — by the Flutter reviewer)
- Client VIP gating now reads the backend `premiumPlaybackMode` from
  `/config` (was: Firebase defaults → always `disabled`, so the app offered
  playback the backend then refused).
- Theme preset from `/config` is now actually applied (provider re-checks
  after config loads; was stuck on the pre-config default).

## Minors fixed
- Unlock failure toast keys off the error `code` (`INSUFFICIENT_COINS`) —
  the "Not enough coins" message was unreachable; coin/rewards providers
  invalidated after unlock; double-submit guards on chest/mission/task/
  watch-time claims; `shareSeries()` is now actually called from the
  detail/player share actions (shares missions could never progress);
  wheel spin `TickerCanceled` guarded; VTT parser handles lone-`\r`;
  `RewardsState.levelProgress` measures progress within the current level.
- Dashboard: captions Generate was unreachable for episodes without tracks
  (admin endpoint INNER JOIN) — matrix now merges the episode list;
  transaction type filter no longer limited to page-1 types; caption track
  delete button available for failed/queued tracks too.

## Not fixed (deliberate, with reason)
- Per-user timezone for reward days: the app sends no timezone; reward day
  is the server-local day (documented, set `TZ` in production).
- One-shot starter tasks remain honor-system (the actions happen off-platform
  and cannot be verified server-side); milestone tasks are verified.
- Double-claim convention stays mixed (200 `{success:false}` for
  check-in/ad/tasks/watch-time — the app keys off `success`; 409 for
  chest/mission/referral).
- `/config` keys `features.ads`, `visual.accentColorOverride`,
  `economy.wheelFreeSpinsPerDay` have no app consumer yet; `maintenanceMode`
  is parsed but has no dedicated app screen.
- Player nits needing redesign, not minimal edits: overlapping `_load()`
  race, caption fetch applying to a previous episode after a mid-fetch
  switch, `user_provider` subscriptions never cancelled (app-lifetime
  singleton).

## Security audit — exposed Firebase API keys (GitHub secret scanning, 2026-11-22)

**Finding (Medium).** GitHub secret scanning flagged valid Google API keys in
repo `oop24579-wq/MUSE` at commit `4e3c8d7` (the Phase 1 app upload), and the
same files were re-committed in `ec9ff1e` (Phase 2):
- `android/app/google-services.json` line 31 — Android Firebase API key
- `ios/Runner/GoogleService-Info.plist` line 12 — iOS Firebase API key
- `ios/GoogleService-Info.plist` line 12 — byte-identical copy of the iOS file

Two distinct keys, both for Firebase project `short-drama-c8029`. The files
came with the user's original app zip; a workspace-wide scan found no other
exposed secrets (no private keys, no `sk-`/`ghp_`/`AKIA` tokens;
`backend/.env.example` holds placeholders only).

**Honest severity framing.** Firebase client API keys (`AIza…`) are embedded
in every shipped Android/iOS app by design — they are not server secrets and
alone grant no admin access; Firebase Auth/Firestore/Storage are protected by
Security Rules, not by the key. The real risk depends entirely on the keys'
restrictions in Google Cloud Console, which only the user can see: if a key is
unrestricted (no Android/iOS app restriction, no API restriction), anyone
holding it can call the project's enabled Google APIs against its quota and
billing, and can hit Firebase endpoints. That is why this is rated Medium,
not Critical — and not Low either, because the keys are now in public git
history (if the repo is public) or at least in the repo's history.

**Hygiene done locally (no push).**
- The three real filenames were added to `short-drama-mobile/.gitignore`.
- Placeholder templates were added next to them:
  `android/app/google-services.json.example` and
  `ios/Runner/GoogleService-Info.plist.example` (verified to contain no
  real key, project number, or client id).
- The real files stay on disk — the app cannot build without them.

**Still owed by the user (in order).**
1. In Google Cloud Console → APIs & Services → Credentials, inspect both
   keys: add the Android package / iOS bundle-id restriction and restrict
   the key to only the APIs the app needs — or rotate the keys outright.
2. If rotated, replace the three local files with the new values.
3. Only AFTER rotation does a history purge make sense
   (`git filter-repo` / BFG on the repo) — purging first would leave the
   live key still valid and exposed in the meantime. History purge is a
   separate, user-approved operation; it was not attempted here.
