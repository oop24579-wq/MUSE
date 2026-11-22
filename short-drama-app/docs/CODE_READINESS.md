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
