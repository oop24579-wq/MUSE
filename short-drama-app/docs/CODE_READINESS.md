# HERO DRAMA — Code Readiness (2026-11-22)

Zero-cost, code-only pass: everything below works with free/self-hosted
mechanisms and is switchable by env var, server setting, or config flag.
No paid services, no API keys, no APK/Gradle build, no GitHub push.

## Verification totals

- Backend: **115/115 checks pass** — suite 1: 57/57 (`test/LAST_RUN.txt`),
  suite 2: 36/36, new suite 3: 22/22 (`test/LAST_RUN_3.txt`).
  - Note: 5 suite-2 expectations (cases 112–115, 119) were updated because
    items 4–5 intentionally changed seeded payouts and streak semantics;
    each update is commented in `test/run-tests-2.mjs`. The old case 114
    ("1 missed day breaks the streak") now asserts the NEW grace behavior;
    the true reset case lives in suite 3 (case 221, 2-day gap).
- Flutter: `flutter analyze` **0 errors** (6 pre-existing warnings in files
  untouched by this pass, ~142 infos). `flutter test` **51/51** (36 existing
  + 15 new in `test/code_readiness_test.dart`).

## 1. Real Firebase token verification (backend)

- NEW `backend/src/firebase.js`: RS256 verification of Firebase ID tokens
  against Google's public JWKS, fetched with node:http/https and cached per
  the response Cache-Control (capped at 24h, refetched on unknown `kid`).
  Verifies signature (node:crypto), `alg`, `iss`
  (`https://securetoken.firebaseio.com/<project>`), `aud` (= project),
  `exp`/`iat`, and a non-empty `sub`.
- `POST /api/v1/auth/firebase` mode selection (`backend/src/auth.js`
  `firebaseAuthMode()`):
  - `FIREBASE_PROJECT_ID` set → **real verification** (401 `INVALID_TOKEN`
    on any failure).
  - else `AUTH_DEV_MODE=1` (or legacy `FIREBASE_AUTH_DEV=1`) → dev
    accept-anything decode (local development only).
  - else → **501 `AUTH_NOT_CONFIGURED`** (production-shaped default).
- Env: `FIREBASE_PROJECT_ID`, optional `FIREBASE_JWKS_URL` override,
  `AUTH_DEV_MODE`. Tests inject the JWKS fetch / use a local stub JWKS
  server with a self-generated RSA keypair — no network (suite 3, cases
  201–211).
- **Human step later:** create the Firebase project (free tier) and set
  `FIREBASE_PROJECT_ID` in the server's environment. Nothing else changes.

## 2. Rate limiting (backend)

- NEW `backend/src/ratelimit.js`: in-memory sliding-window limiter wired in
  `server.js` before routing. Buckets:
  - `POST /api/v1/auth/*`: **60/hour/IP** default. Deliberately above the
    suggested 30 because the backend's own suites make ~43 auth calls;
    tighten to ~30 (`RATE_LIMIT_AUTH_MAX`) on a real deployment where one
    IP = one user.
  - General API: **600/10min/IP**.
- Env: `RATE_LIMIT_AUTH_MAX`, `RATE_LIMIT_AUTH_WINDOW_MS`,
  `RATE_LIMIT_API_MAX`, `RATE_LIMIT_API_WINDOW_MS`.
- Over limit → 429 `{error:{code:'RATE_LIMITED'}}` + `Retry-After` header.
  Tests: suite 3 cases 212–213 lower the limits via env and prove blocking.

## 3. Signed playback URLs (backend)

- When env `PLAYBACK_SIGNING_SECRET` is set, the playback response gains
  `playbackToken {exp, sig}` and `signedVideoUrl`
  (`<videoUrl>?exp=&sig=`). `sig` = base64url HMAC-SHA256 over
  `episodeId.userId.exp`; TTL env `PLAYBACK_URL_TTL_SECONDS` (default 3600).
- NEW public `GET /api/v1/playback/verify?episodeId=&userId=&exp=&sig=` →
  200 `{valid:true}` / 403 (bad or expired) / 404 when signing is disabled.
- When the secret is unset, behavior is byte-for-byte the old behavior.
- **Enforcement note (also in backend/README.md):** the API only *issues*
  tokens. A CDN or reverse proxy in front of the video files must enforce
  the same HMAC (or call `/playback/verify`) for the URLs to actually be
  protected. That proxy is deployment infrastructure, not app code.

## 4. Economy rebalance (backend seeds/settings + one Dart constant)

Day-1 deterministic total (D1) = welcome bonus + day-1 check-in + all 5
daily missions + all 4 one-shot starter tasks + chests at 3 & 7 episodes +
watch-time for 20 minutes (2 blocks). Excludes referrals (needs a second
person), ads (honor-system), the wheel (random; EV/spin ≈ 13.3, noted), and
deep watch milestones (10/25 episodes are not realistic day-1 for most
users; the 3-episode milestone IS included via the chest line — see table).

| Source | Before | After |
|---|---|---|
| Welcome bonus | 30 | 30 (kept — exactly one episode unlock) |
| Check-in day 1 (ladder) | 10 (of 10/20/30/40/50/60/100) | 10 (ladder now 10/20/15/15/20/10/30) |
| Daily missions (5) | 20+10+10+10+10 = 60 | 20+5+5+5+10 = 45 |
| Starter tasks (4) | 15+10+20+10 = 55 | 5+5+10+5 = 25 |
| Chests @3/@7 episodes | 25+50 = 75 | 15+10 = 25 |
| Milestone task watch_3 | 50 | 15 |
| Watch-time (20 min) | 60 (30/10 min) | 20 (10/10 min — test-locked value) |
| **D1 total** | **340** | **155** ✅ (target 120–160) |

- Unlock cost unchanged: 30/episode, full 8-episode series = 240. Day 1 now
  funds ~5 episodes instead of ~11 (a full series plus change).
- Files: `backend/src/settings.js` (check-in ladder default),
  `backend/src/seed.js` (missions, tasks, chests), and the mirrored Dart
  constant `kDailyCheckinRewards` in
  `short-drama-mobile/lib/models/drama/reward_models.dart`. All values remain
  admin-editable via the settings store / dashboard.
- Test-locked values deliberately NOT changed: welcome 30, chest@3 = 15,
  watch-time 10 coins/block (cap 100), referral 50/50, ad reward 20,
  extra-spin cost 20, 8 wheel segments (values trimmed to
  2/5/10/15/20/30/50/0, weights unchanged).

## 5. Streak grace day (backend)

- `backend/src/routes.js`: a streak survives a **1-day gap** (the missed day
  does not count and does not break the ladder); a **2+ day gap resets** it.
  A gap only consumes grace if a claimed day exists on its far side.
- Rewards state now exposes `graceAvailable`, `streakAtRisk` (last claim was
  yesterday-missed / gap day), and `daysSinceLastClaim` so the app can warn
  before the streak dies.
- Tests: suite 3 cases 219–222 (on-time / 1-day gap preserved / 2-day gap
  resets / gap inside the run) + updated suite-2 case 114.

## 6. Template leftovers purge (Flutter)

- Artwork: `onboarding_ai_songs.png` / `onboarding_ai_music_videos.png`
  references replaced with the existing drama artwork
  (`onboarding_welcome.png`) in splash precache, onboarding variants, and
  the modern onboarding pages; splash precache list deduplicated. The two
  music PNG files still exist in `assets/` but are no longer referenced.
- Deleted `lib/presentation/onboarding/music_onboarding_screen.dart`
  (verified unreferenced anywhere).
- Strings: 147 value changes across all 12 ARB files (keys unchanged). The
  user-visible set — profile balance hint, paywall explainer, Pro help
  title + 3 bullets, top-up balance hint (now "Balance: {count} coins"),
  FAQ answers 1/2/11 — was replaced with authored drama wording in every
  locale. English additionally got FAQ Q3/A3/Q4/A4/A5/Q9/A9/A10, the
  long-press toast (ICU structure preserved), and all `@`-descriptions that
  mentioned songs.
- **Honest residue:** the template's legacy skeleton still contains ~70
  music/radio-era keys (an unreachable "RadioPod"-shaped settings/paywall
  legacy surface). The remaining non-English FAQ answers (Q3–Q10 range) and
  legacy-screen strings still carry the old wording in non-English locales;
  those screens are not reachable from the drama navigation. Full cleanup =
  delete the legacy screens in a dedicated pass, or translate the residue.

## 7. Paywall frequency cap (Flutter + backend flag)

- Backend: new setting `paywall_daily_cap` (default **true**, admin-toggleable)
  surfaced by `GET /config` as top-level `paywallDailyCap` and
  `features.paywall_daily_cap` (verified live).
- Flutter: NEW `lib/services/paywall_frequency.dart` — pure decision
  `PaywallFrequency.shouldShow(...)` + SharedPreferences persistence
  (`paywall_last_shown_at`, `paywall_ever_shown`). `PaywallGate` skips the
  launch paywall for non-Pro users when it was shown < 24h ago and the cap
  is on; local default is ON when config has not loaded
  (`AppConfigService.paywallDailyCap`).
- Close-delay: the 2-second hidden close button now applies **only to the
  first-ever show**; every repeat show gets an immediately visible close
  button (all 6 paywall scaffolds: custom + variants 2/3/5/6/7).
- Tests: `test/code_readiness_test.dart` (cap on/off, 23h vs 24h boundary,
  stored-state round-trips).

## 8. Gesture coach marks (Flutter)

- NEW `lib/services/player_tutorial.dart` (pref `player_tutorial_seen`,
  replay flag `player_tutorial_replay`) and
  `lib/presentation/drama/widgets/player_tutorial_overlay.dart`: one overlay
  on first player open teaching swipe (next/prev episode), double-tap
  (±10s), long-press (2×), and edge drags (brightness/volume), with a
  "Got it" button. Shown once; replayable.
- Settings → "Player tutorial" row (app_settings) sets the replay flag and
  confirms with a toast; the next player open shows the overlay again.
  New l10n keys `playerTutorialRow` / `playerTutorialReplayHint` (English;
  other locales fall back until translated).
- Tests: shouldShow matrix + prefs round-trip + overlay widget test.

## 9. Honest quality selector (Flutter)

- `qualityMenuVisible(qualities)` in
  `lib/models/drama/playback_model.dart`: the player only shows the quality
  chip/menu when the playback response contains **≥ 2 distinct non-empty
  URLs**. With the current backend (one real URL repeated under 4 labels)
  the menu is now hidden instead of offering fake choices.
- Tests: empty / single / all-identical / two-distinct cases.

## 10. iOS bundle-ID alignment

- Canonical = Xcode project value **`com.shortdrama.watch`**
  (`Runner.xcodeproj/project.pbxproj`, already matched by `Info.plist`).
- Fixed the mismatch: `BUNDLE_ID` in both `ios/GoogleService-Info.plist`
  and `ios/Runner/GoogleService-Info.plist` changed from
  `com.shortdrama.watchios` → `com.shortdrama.watch`. `watchios` no longer
  appears anywhere under `ios/`. Android signing untouched.
- **Human step later:** if the real Firebase iOS app was registered under a
  different bundle ID, re-download GoogleService-Info.plist from the
  Firebase console after creating the project (see item 1).

## 11. Catalog import script (automation)

- NEW `backend/scripts/import-catalog.mjs` (zero dependencies):
  - `--dry-run <csv>`: prints counts only.
  - `--out <seed.json> <csv>`: writes a seed JSON (posters + series with
    episode Drive IDs). Downloads nothing, never touches the DB.
- Verified against the real library catalog
  (`~/workspace/herodrama/HeroDrama_library_catalog.csv`): **57 posters;
  Series_01: 50, Series_02: 48, Series_03: 50, Series_04: 50 episodes = 198
  videos; statuses: Published 4 / Not yet 251.**
- **Human/content step later:** the CSV carries no real titles (items are
  numbered), so the seed marks every series `titleIsPlaceholder: true`.
  Real series titles/metadata must be supplied by the content owner before
  this seed is loaded into a production DB.

## Round 2 (2026-11-22) — critic suspects, API shape, residue sweep, consistency audit

Verdicts use FIXED / CLEARED (proven not a bug) / LEFT (with reason).
Verification after this round: **backend 123/123** (57 + 36 + 22 + 8 new),
**Flutter tests 58/58** (51 + 7 new), **`flutter analyze` 0 errors**.

### R2-1. Critic-1 suspects S1–S6 (S7 was round 1 item 8)

- **S1 — per-tick full-tree `setState` in the player: FIXED.**
  `episode_player_screen.dart::_onTick` rebuilt the whole player subtree on
  every controller notification. Both progress bars listen to the controller
  themselves, so the rebuild only feeds the time label (1s granularity),
  skip-intro visibility, play/buffering flags and the caption line. The tick
  now rebuilds only when one of those changed (cached in `_tickSecond /
  _tickPlaying / _tickBuffering / _tickCaption`, reset per episode load).
- **S2 — LockOverlay long-press arena: CLEARED with a test.**
  A widget test (long-press gesture on the lock button, held past the 500ms
  deadline) proves `onUnlock` fires: the inner button's recognizer wins the
  arena despite the outer detector's empty `onLongPressStart`. No code
  change; the test stays as a regression guard
  (`test/round2_test.dart`).
- **S3 — hero Play button ignored the resume episode: FIXED.**
  Root cause was API shape: the detail payload's `resumeEpisodeNumber`
  cannot identify an episode in a multi-season series (numbers repeat).
  Backend detail payload now also sends `resumeEpisodeId` (the watch-history
  row already stored it). Client: `SeriesDetailData.resumeEpisodeId`, pure
  helper `resolvePlayerStartIndex` (id → unique-number → 0; ambiguous number
  never guesses), hero button opens the player at the resume episode and
  reads "Continue · EP N" when resuming. Unit-tested (4 cases).
- **S4 — season-filtered episode list handed to the player: FIXED.**
  Episode tiles passed the season sublist, trapping swipe/auto-next inside
  one season and shrinking the player's episode sheet. Tiles now pass the
  full series list with the tapped episode's global index. Single-season
  series (all current content) are unaffected.
- **S5 — watched checkmarks limited to one episode per series: FIXED**
  (API-shape fix, see R2-2).
- **S6 — sleep-timer fade racing an episode switch: FIXED.**
  `_expireSleepTimer` captured the controller and faded for ~2.2s with no
  staleness guard, and restored volume to a hard-coded `1.0` instead of the
  user's edge-HUD volume. It now captures the load generation, aborts if the
  controller changed, restores `_volumeLevel`, and only toasts when it
  actually paused the current episode.

### R2-2. API shape: per-episode watch progress (S5 backend + client)

- New table `episode_progress` (PK userId+episodeId) in `db.js`; the
  watch-history POST upserts it (validated episode, server-clamped position,
  sticky `completed`). New endpoint `GET /me/library/history/series/:seriesId`
  returns every watched episode of the series. The relink merge carries the
  rows to the primary account; account deletion covers the table.
- Client: `EpisodeProgress` model + `DramaService.fetchSeriesEpisodeProgress`;
  the player's `_loadHistory` merges it over the one-row-per-series history,
  so checkmarks and per-episode resume now cover the whole series.
- Tests: new backend suite `test/run-tests-4.mjs` (8 cases: completeness,
  sticky completed, clamping, per-user isolation, mismatched episode/series
  → 400, relink merge, `resumeEpisodeId`, referral window fields).

### R2-3. Round-1 wiring gaps found and fixed

- **Launch paywall cap was wired into dead code.** Round 1 item 7 put the
  frequency check in `lib/widgets/paywall_gate.dart` (`PaywallGate`), which
  is mounted NOWHERE; the real launch path (splash → `/pricing`) never
  consulted it, so the "paywall on every cold start" complaint (user
  evaluation #1) persisted. Splash's returning-user branch now checks
  `PaywallFrequency.shouldShowLaunchPaywall()` / `markShown()` and goes
  straight to `/home` when capped. The dead `PaywallGate` file is deleted.
- **Streak-grace fields were never parsed by the app.** `RewardsState` now
  carries `graceAvailable / streakAtRisk / daysSinceLastClaim`, and the
  rewards screen shows a "Your streak ends today" warning banner when
  `streakAtRisk && !claimedToday` (round 1 item 5 made visible at last).
- **Referral 24h window was invisible until it failed.** `rewardsState` now
  also returns `referralApplyBy` (sign-up + 24h) and `hasReferred`; the
  referral card shows the deadline (or that the window has closed).

### R2-4. Legacy residue sweep (round 1 item 6 follow-up)

- Removed **77 music/radio-era l10n keys** (AI-cover, songs, radio,
  podcasts, music-video template strings) from all 12 ARB files, with their
  `@key` metadata; `flutter gen-l10n` re-run (en 434 → 357 keys). Deadness
  was proven by whole-corpus word search over hand-written Dart (excluding
  generated localizations); the two era-named keys that ARE referenced
  (`paywallFeatureCreateMusic`, `welcomeToAiMusicMaker` — values already
  rebranded in round 1) were kept.
- **LEFT:** ~200 further dead keys with no era connection (generic template
  skeleton) and the unreachable-legacy-screen question. Screen reachability
  could not be proven safely (router/function-based navigation defeats the
  available static checks), so no screens were deleted this round; the
  remaining dead keys are inert data, not user-visible copy.

### R2-5. Consistency audit (config ↔ app ↔ dashboard)

- **/config:** every feature key the Flutter app reads exists in the backend
  payload — 0 client orphans; all 22 `features` keys + `player` / `visual` /
  `economy` blocks are consumed by `AppConfigService`. No changes needed.
- **Backend settings:** every settings key is referenced in backend code —
  0 orphans.
- **Dashboard:** no dead controls (every control maps to a real setting).
  Coverage gap FIXED: five real settings had no control — `paywall_daily_cap`
  (round 1 claimed it was "admin-toggleable"; it was not) added to the
  economy flags, `referral_daily_reward_cap` added to the Referrals form,
  and `checkin_level_bonus / checkin_streak_bonus / checkin_streak_cap`
  added to the Economy form (load + save wired).
- **User-evaluation spot checks:** search already matches title OR synopsis
  OR tags (the "titles only" note is outdated — CLEARED). LEFT as product
  decisions, not code defects: watch-mission completion semantics, wheel
  odds disclosure, onboarding genre picking, scheduled notifications, real
  caption providers (needs keys — outside the zero-cost code-only scope).

### Files changed in round 2

- Backend: `src/db.js`, `src/routes.js`, `public/admin/index.html`,
  `test/run-tests-4.mjs` (new), `test/LAST_RUN_4.txt` (new).
- Flutter: `lib/presentation/drama/episode_player_screen.dart`,
  `lib/presentation/drama/series_detail_screen.dart`,
  `lib/presentation/drama/rewards_content.dart`,
  `lib/presentation/splash_screen/splash_screen.dart`,
  `lib/services/drama/drama_service.dart`,
  `lib/models/drama/watch_history_model.dart`,
  `lib/models/drama/reward_models.dart`,
  `lib/l10n/app_*.arb` (×12) + regenerated `lib/l10n/app_localizations*.dart`,
  `test/round2_test.dart` (new). Deleted: `lib/widgets/paywall_gate.dart`.

## What still needs a human with an account/key (nothing else)

1. Create the Firebase project (free) → set `FIREBASE_PROJECT_ID` (+ refresh
   the iOS `GoogleService-Info.plist` / Android `google-services.json`).
2. Put a CDN/reverse proxy in front of video files to enforce the playback
   HMAC (item 3) when hosting is chosen.
3. Optionally tighten `RATE_LIMIT_AUTH_MAX` to ~30 on real deployments.
4. Supply real series titles for the catalog seed (item 11).
5. Translate the two new tutorial l10n keys + the legacy-residue strings
   (item 6) beyond English, or delete the legacy template screens.

## Round 3 (2026-11-22) — nuclear wiring review + auth/account/legal

Verification after this round: **backend 134/134** (57 + 36 + 22 + 8 + 11
new suite 5), **security probes 54: 49 BLOCKED / 0 CONFIRMED / 2
ACCEPTED-RISK / 3 INFO** (unchanged), **Flutter tests 70/70** (58 + 4 auth
flow + 8 account), **`flutter analyze` 0 errors**.

### R3-1. Nuclear wiring audit → docs/WIRING_MATRIX_V2.md

Per-control matrix (not per-feature): **170 verdict rows** traced control →
handler → service → endpoint → backend handler → table/setting → UI state:
128 WIRED · 28 WIRED-WITH-NOTE · 8 GAP-FIXED · 6 GAP-OPEN. Fixes inside the
audit territory:

- **Follow button existed nowhere**: `toggleFollow` + `POST /series/:id/follow`
  + `isFollowing` parsing were all built but no control called them (v1 row
  42's claimed UI entry was wrong). Bell-icon Follow/Following action added
  to the series detail screen.
- **Onboarding session-exit**: `completeOnboarding()` and the privacy
  consent/settings completion paths navigated straight home session-less;
  new guarded `navigateOnboardingExit()` routes to `/login` when there is no
  stored session and no Firebase user (see R3-2).
- **Broken named routes** in the (orphaned) consent chain:
  `'/privacy-consent'` / `'/privacy-settings'` were pushed but never
  registered; replaced with direct page routes.
- `api_client.dart` verified against the backend envelope — no change needed.

GAP-OPEN (need product/backend decisions, documented in the matrix):
purchase-history screen calls `GET /user/orders`, which has no backend
handler or table, and the screen itself is orphaned; series-detail Download
action is a toast-only dead end (no offline pipeline exists); maintenance
mode has no app screen (backend 503s, flag parsed, nothing renders it); the
GettingStarted/PrivacyConsent screens are unreachable in the active flow
(their legal text spans also lack tap recognizers) — activating the consent
chain is a legal/product call.

### R3-2. Splash → auth flow

- **Bootstrap**: the unconditional `ensureAuthenticated()` (silent guest on
  every cold start) is now gated on an existing Firebase user or a stored
  refresh token — a fresh install reaches splash with NO session.
- **Splash**: returning launches now run `AuthService.restoreSession()`
  (fetchMe; ApiClient refreshes on 401 once; failure clears the token
  store) and route to the new `/login` when no session restores. The
  paywall-cap returning flow is unchanged after a successful restore.
- **AuthService additions** (append-only; existing `signOut()` untouched):
  `hasStoredSession`, `restoreSession()`, `signInAsGuest()`,
  `signOutToLogin()` (best-effort `POST /auth/logout`, clears secure
  storage, Firebase sign-out, NO anonymous re-sign-in). Note: the social
  methods return `false` for real errors as well as user cancellation, so
  the login UI treats `false` as "cancelled" — surfacing social error
  banners would require those methods to rethrow.
- **Login screen** (`lib/presentation/auth/login_screen.dart`, route
  `/login`): email+password sign-in; register mode (name/email/password)
  gated by a terms checkbox — "I agree to the Terms of Service and Privacy
  Policy and confirm I am 13 or older" with tappable legal spans; Google
  and Apple buttons through the existing Firebase ID-token → backend
  exchange (incl. guest link/relink); Guest button with a "link later"
  caption; forgot-password via Firebase reset email; plain-language errors
  via `getAuthErrorMessage`; loading states; footer legal links. Built
  behind an injectable `AuthActions` seam (production impl delegates to
  AuthService; tests use a fake — rendering never initializes Firebase).
  Tokens were already in flutter_secure_storage (TokenStore) — no change.
- Tests: `test/auth_flow_test.dart` (renders all four entry methods,
  register blocked without the checkbox, guest tap navigates, error banner).

### R3-3. Backend account endpoints (new suite 5, 11 cases)

- **POST /auth/logout** — revokes ALL of the caller's refresh tokens
  (family revocation across sessions/devices).
- **PATCH /auth/me** — strict allow-list (name 1–60, image ≤500,
  autoplayNext, videoQuality enum, locale, notificationsEnabled); unknown
  key → 400 BAD_FIELD; caller-only. New `notificationsEnabled` column
  (db.js ALTER pattern) surfaced in userJson.
- **GET /me/transactions** — caller's coin_transactions only, newest first,
  limit/offset paging, `{items, total}`.
- Probes disclosure: the probes harness now sets a high
  `RATE_LIMIT_AUTH_MAX` for its spawned server only (the burst of 100+
  probe logins exhausted the production default bucket; suite 3 covers the
  limiter itself). Production defaults untouched.

### R3-4. Professional account page

- **ProfileContent rewritten as the account hub**: avatar (bundled asset /
  network / initials), display name, email or "Guest account", provider
  badge (Guest/Google/Apple/Email from Firebase providerData with model
  fallback), VIP chip + expiry. Rows: Edit profile, My coins, Subscription
  (store-managed note for Pro), Link account (guests — reuses the existing
  sign-in sheets + relink), Settings, Legal, Log out (→ `/login`).
- **New screens** (`lib/presentation/account/`, behind an injectable
  AccountService seam): EditProfileScreen (name 1–60 validation, 6-avatar
  picker, persists via PATCH /auth/me), CoinHistoryScreen (balance header,
  paginated history, empty + error/retry states), DeleteAccountDialog
  (type DELETE to enable, optional password for email users).
- **AppSettings completed**: Playback section added (autoplay-next +
  video-quality, persisted via PATCH /auth/me with optimistic revert);
  Clear cache is real (image cache + temp-dir sweep with freed-count
  toast); About shows real package version; notifications toggle now also
  persists to the backend; language choice syncs locale to the backend;
  sign-out goes through `signOutToLogin()` → `/login`; delete account
  upgraded to the type-to-confirm dialog. `UserModel` additively gained
  `notificationsEnabled` and `locale`.
- Tests: `test/account_page_test.dart` (model parsing, provider label,
  edit-profile save flow, coin history states, delete-dialog gating).
- Integration fixes by the lead: registered the five LegalRoutes in
  app_routes.dart; fixed a `Provider` symbol clash (riverpod vs provider)
  in profile_content.dart; removed two dead declarations in app_settings.

### R3-5. Legal (store-compliant texts + screens)

- Full English texts in `lib/presentation/legal/legal_texts.dart`: Privacy
  Policy (2,730 words — data collected, purposes, named processors:
  Firebase/Google, Apple, RevenueCat, AdMob, OneSignal; retention; rights
  incl. the in-app deletion path; under-13 exclusion; security; transfers;
  changes; contact), Terms of Service (2,597 words — 13+ eligibility,
  guest accounts, content licence/IP, virtual coins: no cash value,
  non-transferable, refunds only where law/store policy requires; VIP
  auto-renew via the stores; acceptable use; liability; termination),
  Subscription & Purchases terms (1,037 words — per-store billing,
  24-hour renewal, iOS/Android cancel steps, restore, price changes,
  store-handled refunds).
- Screens (`legal_screens.dart`): Legal hub + the three text screens
  (scrollable, selectable) + Licenses/About (showLicensePage), reachable
  from Login (footer + register links), Profile and AppSettings; routes
  `/legal`, `/legal/privacy`, `/legal/terms`, `/legal/subscription`,
  `/legal/licenses`.
- Docs: `docs/PRIVACY_POLICY.md` + `docs/TERMS_OF_SERVICE.md` (standalone,
  identical text, for hosting as the store-listing URLs) and
  `docs/LEGAL.md` (console steps + Google Play Data Safety mapping, 15
  rows, + Apple nutrition-label mapping, 12 rows, + account-deletion URL
  note).
- **Owner steps that remain** (in LEGAL.md): replace the placeholder
  contact email `support@herodrama.app` and the `[Your Jurisdiction]`
  governing-law placeholder; host the two policy docs and paste the URLs
  into Play Console / App Store Connect; complete the Data Safety form
  from the mapping; confirm whether AdMob ships personalised or
  non-personalised ads (decides Apple's tracking label + ATT prompt).

### Still needs the user's real accounts/keys (Round 3 delta)

- Firebase project + native config files (google-services.json /
  GoogleService-Info.plist) so Firebase Auth (email/Google/Apple/reset)
  actually runs — until then the login screen's Firebase paths report
  their not-configured errors honestly and the backend stays in dev mode.
- Store consoles: privacy-policy URL fields, Data Safety / App Privacy
  forms, and the real support email + jurisdiction in the legal texts.
- Product decisions on the GAP-OPEN items above (purchase-history backend,
  downloads, maintenance screen, consent-chain activation).

## Round 4 (2026-11-22) — the five remaining code gaps, built; downloads removed

The user made the product decisions the Round 3 list was waiting on:
build all five code gaps, and — explicitly — **no offline downloads**
(the toast-only Download action is removed, not built). Zero cost, code
only: no real keys, no content, no APK build, no GitHub push (packaging
is a separate step). All six WIRING_MATRIX_V2.md rows are updated; no
GAP-OPEN rows remain.

### 1. Purchase history backend (orders + RevenueCat webhook)
- New `orders` table (`db.js`): id, userId, provider
  ('revenuecat'|'manual'), productId, kind ('vip'|'coins'), amountCents,
  currency, status, revenueCatTransactionId (UNIQUE), createdAt. Added to
  USER_TABLES (account deletion/relink hygiene).
- `POST /webhooks/revenuecat` (routes.js, exempt from the maintenance
  gate): RevenueCat-shaped events create orders AND apply entitlements
  through the single shared path `recordOrder`/`applyOrderEntitlement` —
  VIP sets `users.isPro` + `subscriptionExpirationDate` (event
  `expiration_at_ms` when present, else +30d); coins go through
  `grantCoins(..., 'purchase', orderId)` with the amount parsed from the
  product id (`coins_500`). No duplicate economy logic. EXPIRATION
  records an 'expired' order and lapses VIP; CANCELLATION records only
  (access runs to expiry). Unknown user / missing product → 200
  `applied:false` (RevenueCat must not retry-storm). Transaction-id
  idempotency: a redelivery returns `duplicate:true` and grants nothing
  twice.
- Signature gate: with `REVENUECAT_WEBHOOK_SECRET` set, the caller must
  present it as `Authorization: Bearer <secret>` (RevenueCat's scheme)
  or as hex HMAC-SHA256 of the raw body in `x-webhook-signature`
  (timing-safe compares; server.js now preserves `req.rawBody`). With
  the secret UNSET the endpoint accepts only in dev auth mode
  (AUTH_DEV_MODE=1 / FIREBASE_AUTH_DEV=1); otherwise 503
  WEBHOOK_NOT_CONFIGURED — production can never run it open by accident.
- `GET /user/orders`: caller-only, newest-first, limit/offset paged,
  `{orders, total}` with `orderJson` emitting exactly the shape
  PurchaseHistoryScreen parses (paymentProvider; subscriptionPlanId for
  VIP / coinPackageId for coins — `type` deliberately omitted because
  the screen's planId fallback chain would shadow coinPackageId).
- `POST /admin/orders` (+ GET list): manual support orders through the
  same recordOrder path, provider 'manual', X-Admin-Token enforced.
- Client: 'Purchase history' row added to the Account hub
  (`profile_content.dart`) — the screen is no longer orphaned.

### 2. Maintenance-mode screen
- New `MaintenanceScreen` (branded; message from /config
  `maintenanceMessage` ← new settings key `maintenance_message`,
  admin-editable, ≤200 chars; default text otherwise). Retry re-fetches
  /config (the exempt endpoint); on clear it exits — pop when pushed,
  restart-from-splash when root — and clears the ApiClient latch.
- Routing, single global handling, no loops: splash checks
  `AppConfigService.maintenanceMode` before any other routing; mid-session,
  ApiClient's `_fromDio` funnel invokes a latched `onMaintenance` hook on
  503 MAINTENANCE (set in bootstrap to push '/maintenance' via the new
  `appNavigatorKey`). The latch fires once per maintenance episode.
- Widget tests: renders with Retry; retry-still-down stays + explains;
  retry-cleared proceeds.

### 3. Real Shorts feed
- Backend `GET /shorts` (public, optional auth): one item per episode —
  episodeJson (so `isUnlocked` mirrors the playback gate exactly) plus
  seriesTitle, posterUrl, likeCount, videoUrl (stored media ref).
  Ordered by series rankScore → episode viewCount → id, with an opaque
  base64 offset cursor (`{items, nextCursor}`). Behind
  settings.shorts_enabled (default ON; /config features.shorts; off →
  empty feed).
- Client: `ShortsContent` is now a stateful vertical PageView
  (`ShortItem`/`parseShortsPage` model + `DramaService.fetchShorts`).
  Each page owns a VideoPlayerController (lazy on activation, looping,
  disposed with the page), resolving its stream through the same
  entitlement-checked playback endpoint as the full player; locked
  episodes render poster + lock and never fetch a stream. Tap =
  play/pause, like button → POST /series/:id/like (optimistic, server
  count wins), mute toggle, "Watch full episode" → full player at that
  episode. Page changes pause; MainTabs passes `isTabActive` so tab
  switches pause too. Flag off → 'Shorts are unavailable right now'.

### 4. Personalized "For You" recommendations
- `forYouSeries(user, limit)` in routes.js: genre affinity from
  episode_progress (progress + completed weighting), watch_history, and
  user_series favorites/follows/likes; ranking = affinity DESC, then
  rankScore, then viewCount. Series the user completed (every episode
  has a completed progress row) are excluded. No signals — or
  guest/anonymous — falls back to the current trending order.
- GET /home fills the `for_you` section with it: the seeded `sec-foryou`
  row (seed.js, items intentionally empty) gets computed items; catalogs
  seeded earlier get a synthetic section spliced after the hero, so the
  section always arrives. Client: `SectionType.forYou('for_you')` added
  + explicit case in `discover_content._section` → standard carousel.

### 5. Consent chain activation
- Splash gate (first launch ONLY): `ConsentGate.shouldShowChain`
  (pure, matrix-tested) = !onboardingCompleted && !hasConsentRecord &&
  !hasSession → GettingStarted → PrivacyConsent → (PrivacySettings via
  Customize) → session-aware exit to '/login'. Returning users skip it
  entirely; the variant onboarding flow still serves launches that
  already hold a record or a session.
- Working legal links: GettingStarted's Terms/Privacy spans now carry
  TapGestureRecognizers opening the round-3 legal screens (disposed
  with the State); the dead "Privacy Policy" GestureDetectors in
  PrivacyConsent and PrivacySettings (empty onTap) open
  LegalRoutes.privacy.
- Consent record: every `OnboardingService.savePrivacyPreferences`
  (the store acceptAllPrivacy/refuse/granular all funnel through)
  stamps version + UTC timestamp + choices (`ConsentRecord`). Sync:
  new backend allow-list field `consent` on PATCH /auth/me (strictly
  validated, stored as users.consentJson, echoed in userJson) and
  `ConsentSyncService.syncIfPossible()` fired from
  AuthService.exchangeFirebaseToken — the funnel every sign-in/restore
  passes through; best-effort, local record stays authoritative.
- Widget test drives the real chain: GettingStarted renders → Terms
  span tap opens the legal route → Get Started → PrivacyConsent →
  Accept All → '/login' (session-less env) + record persisted.

### 6. Downloads — RESOLVED-BY-REMOVAL
- The Download `_action` in `series_detail_screen.dart` (toast-only
  dead end) is deleted, per the user's explicit decision against
  offline downloads. No download/offline code exists in the app.
- Flagged, not silently rewritten: paywall help-dialog copy
  (`paywallHelpFeature4` = "Download episodes for offline viewing",
  music-template residue across 13 l10n files) still mentions
  downloads. It is marketing copy, not a control; a copy pass should
  decide its replacement text.

### Verification (Round 4)
- Backend: suites 1–5 unchanged-green (57+36+22+8+11; suite 1 case 5's
  section-type enumeration gained 'for_you') + new suite 6
  (`test/run-tests-6.mjs`, cases 501–512: webhook VIP/coins/idempotency/
  signature/expiration, orders isolation+paging, admin manual orders,
  /shorts shape+pagination+flag, For You affinity/fallback/exclusion,
  consent PATCH, /config) = **146/146**.
- Security probes re-run (webhook/auth-adjacent changes): **54 probes,
  0 CONFIRMED** (49 BLOCKED, 2 ACCEPTED-RISK, 3 INFO — unchanged profile).
- Flutter: analyze **0 errors**; tests **84/84** (70 prior + 14 new in
  `test/round4_test.dart`: ConsentGate matrix, consent-record lifecycle,
  ShortItem/parseShortsPage mapping, SectionType.forYou, MaintenanceScreen
  ×3, ShortFeedCard, full consent-chain navigation).

### Still needs the user's real accounts/keys (Round 4 delta)
- `REVENUECAT_WEBHOOK_SECRET` in the backend env + the webhook URL
  configured in the RevenueCat dashboard (until then the webhook runs
  dev-mode-only, by design).
- Everything from the Round 3 delta list (Firebase project, store
  consoles, legal placeholders) is unchanged.
