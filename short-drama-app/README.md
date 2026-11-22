# HERO DRAMA — Short Drama Platform

A complete short-drama product: a Flutter mobile app, a zero-dependency Node.js
backend + API, and a full web admin control panel.

```
short-drama-app/
├── short-drama-mobile/   Flutter app (Android / iOS / Web) — "HERO DRAMA"
├── backend/              Node.js API + admin dashboard (zero npm dependencies)
└── logo_1024.png         Brand icon (1024×1024, icon on black)
```

---

## Quickstart

### 1. Backend + Admin Dashboard

```bash
cd backend
cp .env.example .env        # optional — sane dev defaults are built in
npm start                   # http://localhost:3000  (PORT env to change)
```

- API base: `http://localhost:3000/api/v1`
- Admin dashboard: `http://localhost:3000/admin` — log in with the admin token
  (`ADMIN_TOKEN` env; dev default `dev-admin-token-change-me` — **change it in
  production**).
- First boot seeds the database automatically (genres, series, episodes, home
  sections, reward tasks, settings). Storage is SQLite via Node's built-in
  `node:sqlite` — no installs, no services.
- Tests: `node test/run-tests.mjs` (boots a throwaway server + temp DB;
  latest results in `backend/test/LAST_RUN.txt`).

See [backend/README.md](backend/README.md) for env vars, the full endpoint
table, and the dev-auth warning.

### 2. Flutter App

```bash
cd short-drama-mobile
flutter pub get
flutter run
```

Point the app at the backend by publishing Firebase Remote Config with
`api_base_url` set to your backend origin (e.g. `https://api.example.com`) —
the app reads it at runtime; without it the app runs in local/guest mode.
Regenerate launcher icons from `assets/images/app_icon.png` with
`flutter_launcher_icons` once a Flutter SDK is available.

Static audit results and the full change log live in
[short-drama-mobile/AUDIT.md](short-drama-mobile/AUDIT.md).

---

## Architecture

| Layer | Tech | Notes |
|---|---|---|
| Mobile app | Flutter / Dart | Firebase Auth + Remote Config, RevenueCat subscriptions, AdMob |
| API | Node.js 24, `node:http` + `node:crypto` only | HS256 JWT (access 1h / refresh 30d, rotation), envelope `{data}` / `{error:{code,message}}` |
| Storage | SQLite (`node:sqlite`, built into Node 24) | Single file `backend/data/app.db`, seeded on first boot |
| Admin | Vanilla HTML/CSS/JS SPA served by the API | Token auth via `X-Admin-Token` header, no build step, no CDN |

The app talks to the API exactly as its service layer specifies
(`{api_base_url}/api/v1`, Bearer JWT). Episode **lists never contain video
URLs**; playback URLs are issued per-request by
`GET /episodes/:id/playback` after entitlement checks (free / unlocked /
VIP), including per-language dub tracks.

---

## What the dashboard controls

The admin panel at `/admin` is a full control panel for the app — everything
below is editable live, without redeploying anything:

- **Overview** — total users, new users today, series/episodes counts, total
  views, coins in circulation, VIP users, top 5 series by views, recent coin
  transactions.
- **Genres** — full CRUD (name, slug, color, icon, sort order).
- **Series** — full CRUD over every app field: metadata, cover/hero/trailer
  URLs, genre, dub languages, tags, ratings, and the publish flags
  `isFeatured / isHot / isNew / isVipOnly / isExclusive / isCompleted`,
  plus `rankScore` and `sortOrder`.
- **Episodes** — per-series manager: episode metadata, **server-side
  `videoUrl`**, dub tracks, `isFree`, `coinCost`, `isVipOnly`; plus a
  **cast manager** per series.
- **Home Sections** — create/edit/reorder all 7 section types
  (featured hero, carousels, ranking list, new releases, hot grid, vertical
  grid, genre grid) and pick/order the series inside each.
- **Rewards & Economy** — the money rules: welcome coin bonus, default
  episode unlock cost, rewarded-ad amount + daily cap, the 7 daily check-in
  coin amounts, and reward-task CRUD (slug, title, coins, target, active).
- **Users** — search, coin balance adjust (logged), VIP grant/revoke,
  per-user summary (library, history, unlocks, transactions), delete user.
- **Notifications** — broadcast to all users + history of sent broadcasts.
- **App Settings** — the server-side settings store (seeded from the app's
  Remote Config defaults, read live by the API on every request):
  - **Maintenance mode** — when on, all non-admin API calls return
    `503 {error:{code:"MAINTENANCE"}}`; the admin panel keeps working.
  - **Premium playback mode** — `disabled` (no VIP gating) ·
    `premium_content` (VIP-only content requires VIP) · `all_playback`
    (every playback, even free episodes, requires VIP).
  - **Ads enabled** flag, welcome bonus, unlock cost, ad rewards, check-in
    amounts (same store as Rewards & Economy).
- **Engagement Lab** *(Phase 2)* — the retention economy: spin-wheel segments/weights,
  free spins/day and paid-spin cost; treasure-chest milestones (episodes-watched →
  coins); watch-time reward rate/block/cap; referral bonuses; **daily missions**
  CRUD (watch/like/share/check-in metrics); **limited-time events** CRUD
  (reward multiplier + schedule).
- **Feature Flags** *(Phase 2)* — one live toggle per player-luxury feature
  (swipe nav, double-tap seek, long-press 2×, edge controls, speed/quality,
  auto-next, binge, PiP, chapters, skip-intro, lock, sleep timer, share moment,
  captions) plus wheel/chests/missions/referrals/watch-time master switches.
- **Visual & Theme** *(Phase 2)* — default colour preset (1–7), confetti and
  haptics on/off, accent-colour override, auto-next countdown seconds, and the
  skip-intro window/skip-to timings.
- **Captions & Translation** *(Phase 2)* — ASR/MT provider selectors, target
  languages, auto-generate toggle, a per-episode caption-track matrix with
  Generate/delete, and the caption job list (see the captions section below).
- **Transactions** — paginated, filterable coin-transaction audit log.

Admin API: everything lives under `/api/v1/admin/*`, guarded by the
`X-Admin-Token` header. Full endpoint table in
[backend/README.md](backend/README.md).

One pricing nuance: an episode's own `coinCost` wins when set; the global
*episode unlock cost* setting prices episodes without an explicit cost.

---

## What was missing, and what was built

The uploaded project was **app-only**: the Flutter client referenced a backend
(`api_base_url`, full REST contract in its service/model layer) that did not
exist, and there was no admin tooling at all.

Built from scratch to the app's exact contract:

1. **Backend API** (`backend/src/`) — auth (Firebase-token exchange, JWT,
   refresh rotation, guest relink, account deletion), catalog (categories,
   discover, for-you, search, home sections), series detail + cast + related,
   episodes + entitled playback with dub tracks, likes/favorites/follows,
   library (my-list, history, continue-watching), coins & rewards (check-in,
   rewarded ads, tasks), episode unlocks, notifications, device/locale
   header tracking, and a coin-transaction audit log.
2. **Admin API + dashboard** — the full control surface described above.
3. **Seed content** — 7 genres, 8 series × 10 episodes (public sample MP4s,
   one VIP-only series, one series with Spanish/Portuguese dubs), cast, all
   7 home-section types, reward tasks using the app's real slugs.
4. **Test suite** — 42 end-to-end cases against a real booted server
   (auth, entitlement, economy, settings effects, maintenance mode, admin
   CRUD): **42/42 passing** (`backend/test/LAST_RUN.txt`).

---

## Phase 2 — engagement, player luxury, captions

- **Addictive coin economy** (all values tunable in the Engagement Lab):
  spin wheel with free/paid spins, treasure chests for episodes watched,
  watch-time rewards with a daily cap, auto-tracked daily missions, XP &
  levels, check-in streaks with level/streak bonuses, referrals (both sides
  paid), and limited-time multiplier events. Every grant is server-computed,
  idempotent, daily-capped and logged in `coin_transactions` with a reason
  code (`wheel`, `chest`, `watch_time`, `mission`, `referral`, …).
- **Public app config** — `GET /api/v1/config` (no auth, works even in
  maintenance mode) serves the feature flags, player timings, visual config
  and economy values the app reads at startup. Firebase Remote Config still
  owns secrets/keys; everything behavioural lives in the dashboard.
- **Luxury player** — swipe episode navigation, double-tap seek, long-press
  2×, edge brightness/volume HUDs, speed + quality menus, auto-next countdown
  ring, binge mode, chapter progress bar, skip-intro, lock controls, sleep
  timer, resume banner — each individually toggleable from Feature Flags.
  The 50-item visual inventory with honest statuses is in
  [docs/VISUAL_FEATURES_50.md](docs/VISUAL_FEATURES_50.md).
- **Auto-captions & translation** — like Facebook's system: the backend
  listens to each episode's audio (ASR), translates the transcript (MT) and
  serves timed WebVTT tracks; viewers pick Off / Original / العربية / English
  in the player. No per-video subtitle uploads. Providers are pluggable via
  settings (`asr_provider`, `mt_provider`); the built-in **demo** providers
  make the whole pipeline testable with zero keys (demo ASR invents plausible
  text, demo MT only prefixes a language tag) — plug a real
  `OPENAI_API_KEY` / `DEEPL_API_KEY` / `GOOGLE_TRANSLATE_API_KEY` /
  `WHISPER_CMD` into the server environment for production. Details in
  [backend/README.md](backend/README.md).
5. **App fixes + rebrand** — two broken imports fixed; app rebranded to
   **HERO DRAMA** (Android/iOS/web names, all 12 locales, share texts) with
   the official logo as the launcher-icon source. Details in
   [short-drama-mobile/AUDIT.md](short-drama-mobile/AUDIT.md).

---

## Known limits — needs the owner's accounts / decisions

- **Firebase ID-token verification is a documented TODO.** In dev mode
  (`FIREBASE_AUTH_DEV=1`) the backend accepts any non-empty token and derives
  the user from its claims — fine for local development, **not for
  production**. Production must verify tokens with the Firebase Admin SDK /
  Google public keys (see `backend/src/auth.js`).
- **Remote Config must be published with real values**: `api_base_url`,
  RevenueCat keys (entitlement `shortdrama_vip`), OneSignal app id, AdMob
  unit IDs, Turnstile key; `ios_store_url` still has a placeholder id.
- **iOS bundle-ID mismatch**: Xcode uses `com.shortdrama.watch` but the
  Firebase plist is registered for `com.shortdrama.watchios` — reconcile in
  the Firebase console / Xcode.
- **Android release signing**: only `key.properties.example` exists.
- **No Flutter SDK in the build environment used here** — the app was
  verified statically only (imports, assets, structure; see AUDIT.md).
  Run `flutter analyze` and a device build before release, and regenerate
  native launcher icons with `flutter_launcher_icons`.
- Seed videos/covers are public sample/placeholder URLs — replace with the
  real catalog via the dashboard.
