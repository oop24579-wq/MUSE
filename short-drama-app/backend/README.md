# HERO DRAMA Backend

Zero-dependency Node.js (≥22, built on Node 24) API for the HERO DRAMA Flutter app.
Only built-ins: `node:http`, `node:crypto`, `node:sqlite`. No npm install needed.

## Storage choice
**`node:sqlite` (`DatabaseSync`)** — verified loading in this VM on Node v24.22.1
(`node -e "require('node:sqlite')"` succeeds). DB file: `DB_PATH` (default `data/app.db`, WAL mode).
A JSON-file store was therefore not needed.

## Run
```bash
cd backend
export PORT=8080 JWT_SECRET=change-me ADMIN_TOKEN=change-me FIREBASE_AUTH_DEV=1
npm start          # node src/server.js
curl http://localhost:8080/health
```
Env vars (see `.env.example`): `PORT` (8080), `JWT_SECRET` (dev default `dev-only-change-me-jwt-secret` — **change in production**),
`ADMIN_TOKEN` (dev default `dev-admin-token-change-me` — **change in production**), `FIREBASE_AUTH_DEV` (`1` = dev auth, see warning),
`WELCOME_COIN_BONUS` (30, from Firebase Remote Config `welcome_coin_bonus`), `EPISODE_UNLOCK_COIN_COST` (30, from `episode_unlock_coin_cost`),
`DB_PATH` (`./data/app.db`), `AD_DAILY_CAP` (5 rewarded-ad claims/day), `AD_REWARD_AMOUNT` (20).
These economy env vars only seed the **settings store** (see below) — after first boot the
admin-editable store values win.

## ⚠️ Dev auth warning
With `FIREBASE_AUTH_DEV=1`, `POST /auth/firebase` accepts **any** non-empty `idToken`: if it looks like a JWT its
`sub`/`email`/`name` claims are used, otherwise a stable user is derived from a hash of the token.
**Production must verify the Firebase ID token** via the Firebase Admin SDK or Google's public keys
(aud/iss checks) — see the `TODO(production)` comment in `src/auth.js`. Never ship dev mode.

## Pointing the Flutter app at this server
Set Firebase Remote Config **`api_base_url`** to this server's origin (e.g. `http://10.0.2.2:8080` for an Android
emulator, `http://localhost:8080` for iOS sim / web). The app calls `{api_base_url}/api/v1/...`.
For local debug you can also set `_debugApiBaseUrl` in `remote_config_service.dart`.

## Conventions
Base path `/api/v1`, `Authorization: Bearer <accessToken>`. Envelope: success `{"data":{...}}`,
error `{"error":{"code":"...","message":"..."}}` with matching HTTP status. Access JWT (HS256) 1h, refresh 30d with rotation.
Headers `X-Platform`, `X-Locale`, `X-App-Version`, `X-Device-Id` update the user row + `user_devices` upsert.
Episode list responses **never** include `videoUrl`; playback is entitlement-checked per request.

## Endpoints (app)
| Method | Path | Notes |
|---|---|---|
| POST | /auth/firebase | `{idToken, deviceId?}` → `{tokens{accessToken,refreshToken}, user}`; new users get welcome bonus + welcome notification |
| POST | /auth/refresh | `{refreshToken}` → same shape, rotation (old token revoked) |
| POST | /auth/relink | `{guestUserId}` merges guest coins/history/favorites/unlocks into current user |
| GET | /auth/me | `{user}` |
| DELETE | /auth/account | deletes user |
| GET | /categories | `{genres[]}` |
| GET | /genres/:id/series?limit | `{series[]}` |
| GET | /discover?filter=popular\|latest\|ranking&limit | `{series[]}` |
| GET | /for-you?limit · /search?q&limit | `{series[]}` |
| GET | /home?locale | `{sections[]}` each `{id,slug,title,subtitle,sectionType,sortOrder,series[]}` |
| GET | /series/:id | `{series, cast[], related[], isFavorite, isFollowing, isLiked, resumeEpisodeNumber}` |
| GET | /series/:id/episodes | `{episodes[]}` (no videoUrl) |
| GET | /episodes/:id/playback?lang | `{videoUrl}`; gated by the `premium_playback_mode` setting (see Settings): default `premium_content` = free→any auth, VIP-only→VIP, coin→unlocked, else 403; `lang` returns dub track when present |
| POST | /episodes/:id/unlock | deducts coinCost; insufficient → 402 `INSUFFICIENT_COINS` |
| POST | /series/:id/like `{like}` · /favorite `{add}` · /follow `{follow}` | `{success, likeCount?}` |
| GET | /me/library/my-list · /history?limit · /continue?limit | `{series[]}` / `{history[]}` |
| POST | /me/watch-history | `{seriesId, episodeId, episodeNumber, positionSeconds, durationSeconds, completed}` |
| GET | /me/coins | `{balance}` |
| GET | /rewards | `{coinBalance, claimedToday, currentDay, days[7], tasks[]}`; check-in amounts from the settings store (seeded from `kDailyCheckinRewards` [20,50,35,30,35,20,50]); only active reward tasks are listed |
| POST | /rewards/checkin | idempotent per day → `{success, coins}` (amount from settings `checkin_amounts`) |
| POST | /rewards/ad | grants settings `ad_reward_amount`, capped at settings `ad_daily_cap`/day; no grant when settings `ads_enabled` is off |
| POST | /rewards/tasks/:slug/complete | once per user; milestone tasks require progress ≥ target |
| POST | /content/view `{type, id}` | increments viewCount |
| GET | /notifications | `{items[], unread}` |
| POST | /notifications/read | `{ids:[...]}` or empty body = mark all |

Reward task slugs (match app): `connect_email`, `rate_app`, `invite_friend`, `enable_notifications`,
`series_watch_3`, `series_watch_10`, `series_watch_25`, `series_collect_5` (targets per `series_reward_tile.dart`).

## Phase 2 endpoints
| Method | Path | Notes |
|---|---|---|
| GET | /config | **Public, no auth, exempt from maintenance blocking.** `{maintenanceMode, premiumPlaybackMode, features{...21 booleans}, player{skipIntroWindowSeconds, skipIntroToSeconds, autoNextCountdownSeconds}, visual{defaultThemePreset, confettiEnabled, hapticsEnabled, accentColorOverride}, economy{episodeUnlockCoinCost, wheelFreeSpinsPerDay}}` — all mapped live from the settings store (player `player_*` flags, economy/visual/caption toggles) |
| GET | /discover?filter=ranking | Each series gains `rankDelta` vs the daily snapshot in `meta` key `rank_snapshot` (`prevIndex - currentIndex`, positive = moved up; first ever = all 0; a previous day's snapshot is used once, then today's order is saved) |
| GET | /episodes/:id/playback | Now also returns `qualities` (`1080p/720p/480p/360p`, all pointing at the resolved video/dub URL — real transcodes plug in there) and `captionLanguages` (ready caption langs incl. `orig`; `[]` when none or captions disabled) |
| GET | /rewards | Extended (all Phase 1 fields kept): `wheel{enabled, spinsLeft, freeSpinsPerDay, segments, extraSpinCost}`, `chests[{id, threshold, coins, claimed, unlocked}]`, `watchTime{enabled, minutesToday, coinsPerBlock, blockMinutes, claimableCoins, claimedCoinsToday, dailyCapCoins}`, `missions[{slug, title, description, coins, progress, target, completed, claimed}]` (active missions, `[]` when `missions_enabled` off), `currentStreak`, `xp`, `level`, `nextLevelXp`, `activeEvent{name, multiplier, endsAt}\|null`, `referralCode` |
| POST | /rewards/wheel/spin | 403 `FEATURE_DISABLED` when wheel off. Free spin while `freeUsed < wheel_free_spins_per_day`; else deducts `wheel_extra_spin_cost` (`coin_transactions` type `wheel_spin_cost`) or 402 `INSUFFICIENT_COINS`. Weighted random over `wheel_segments`/`wheel_weights` (uniform if lengths differ), winnings × event multiplier. +2 XP. → `{success, segmentIndex, coins, balance, spinsLeft}` |
| POST | /rewards/chests/:id/claim | `id` = `chest_<threshold>` from `chest_milestones`. 403 `CHEST_LOCKED` until distinct episodes watched today ≥ threshold; once/day (409 `ALREADY_CLAIMED`). Pays the **fixed** milestone coins — **no event multiplier on chests**. +5 XP |
| POST | /rewards/watch-time/claim | Pays `claimableCoins` (see economy below) with the event multiplier applied to the newly claimed amount; when nothing is claimable it mirrors `/rewards/ad` cap semantics: 200 `{success:false, coins:0}` |
| POST | /rewards/missions/:slug/claim | 404 unknown/inactive, 403 `MISSION_INCOMPLETE`, 409 `ALREADY_CLAIMED`. Pays mission coins (no multiplier), +10 XP |
| POST | /content/share `{seriesId}` | Increments today's `shares` daily-event counter (mission progress) |
| POST | /series/:id/like | With `like=true` also increments today's `likes` daily-event counter |
| POST | /auth/referral `{code}` | 403 when referrals off, 409 `ALREADY_REFERRED`, 400 `INVALID_CODE` (unknown or own code). Grants referrer `referral_bonus_referrer` and referee `referral_bonus_referee` (type `referral`) → `{success, coins}` (referee bonus) |
| GET | /auth/me | User object gains `referralCode`, `xp`, `level` |
| GET | /episodes/:id/captions | `{languages:[{lang, source, status}]}` — **ready tracks only**, never contains `videoUrl` |
| GET | /episodes/:id/captions/:lang | Raw WebVTT body, `Content-Type: text/vtt; charset=utf-8` (NOT the JSON envelope); 404 envelope when no ready track |
| GET/POST/PATCH/DELETE | /admin/missions[/:slug] | `{slug, title, description, metric, target, coins, sortOrder, active}`; `metric` enum: `watch_episodes\|watch_minutes\|likes\|shares\|checkin` |
| GET/POST/PATCH/DELETE | /admin/events[/:id] | `{name, multiplier, startsAt, endsAt, active}` — multiplier windows (see Events) |
| GET | /admin/captions | `{episodes:[{episodeId, seriesId, episodeNumber, title, tracks:[{id, lang, source, status}]}], jobs:[...latest 50]}` |
| POST | /admin/episodes/:id/captions/generate `{targets?}` | Enqueues a caption job → `{jobId}` |
| DELETE | /admin/captions/:trackId | Deletes one caption track |

## Phase 2 economy design
- **Watch accrual** — `POST /me/watch-history` (history upsert unchanged) also accrues
  `delta = clamp(newPosition - oldPosition, 0, durationSeconds || newPosition)` seconds into
  `watch_time_daily` for today, records distinct episodes/day in `watch_events`, and awards
  **+5 XP** the first time an episode is completed today.
- **XP & levels** — sources: check-in +10, reward-task complete +5, mission claim +10,
  chest claim +5, wheel spin +2, episode completed +5. Level thresholds:
  `xpForLevel(L) = 100*(L-1)^2` (L2 at 100 XP, L3 at 400…); `nextLevelXp = 100*level^2`.
- **Streaks** — consecutive days with `checkins` rows ending today (or yesterday if today
  is not claimed yet). Check-in payout is now
  `round((base_from_checkin_amounts + (level-1)*5 + min(streakBeforeToday,7)*2) * activeEventMultiplier)`,
  still idempotent per day with the same `{success, coins}` shape.
- **Events** — an event is active when `active=1 AND startsAt <= now <= endsAt` (highest
  multiplier wins when several overlap). The multiplier applies to **check-in, wheel
  winnings and watch-time claim payouts only** — chests and missions pay fixed coins.
  `GET /rewards` exposes `activeEvent` or `null`.
- **Watch-time claims** — `claimable = min(floor(minutesToday/blockMinutes)*coinsPerBlock - alreadyPaidToday, dailyCap - alreadyPaidToday)`, floored at 0; claiming marks those blocks claimed.
- **Chests** — unlocked by distinct episodes watched today (`watch_events`) reaching each
  `chest_milestones` threshold; one claim per chest per day.
- **Missions** — seeded (only when the table is empty): `watch_3_episodes` (20c),
  `watch_15_minutes` (25c), `like_3_series` (15c), `share_1_series` (15c),
  `daily_checkin` (10c). Progress is computed live per day from `watch_events`,
  `watch_time_daily`, `user_daily_events` (likes/shares) and `checkins`.
- **Referrals** — every user has a stable `referralCode` (`HD` + 6 chars from a hash of
  the user id); one referral per account, no self-referrals.
- **Anti-abuse** — every payout is idempotent or capped: check-in/mission/chest claims are
  once-per-day primary keys, wheel free spins are counted per day with paid spins charged
  up-front, watch-time is capped daily and blocks can only be claimed once, referral is
  one-shot per account, and unlocks/tasks keep their Phase 1 guards. Every coin movement
  is a `coin_transactions` row with a reason `type`: Phase 1 types (`welcome_bonus`,
  `checkin`, `ad_reward`, `reward_task`, `episode_unlock`, `admin_adjust`, `relink_merge`)
  plus Phase 2 types **`wheel`** (winnings), **`wheel_spin_cost`** (paid spin, negative),
  **`chest`**, **`watch_time`**, **`mission`**, **`referral`**.

## Captions & translation (audio-based, like Facebook auto-translate)
Pipeline: **video audio → ASR → original-language timed segments → MT → translated
segments → WebVTT**, generated in-process by a sequential worker (`src/captions.js`);
there are no per-video subtitle uploads. The original track is stored as lang `orig`
(source `asr`), translations as source `mt`. When an admin creates an episode with a
`videoUrl` and `captions_auto_generate && captions_enabled` are on, a job is enqueued
automatically. The seed runs the demo pipeline synchronously for the first 2 episodes
of the first series, so ready `orig`+`ar`+`en` tracks exist out of the box.

Provider settings: `asr_provider` (`demo|openai|local-whisper`), `mt_provider`
(`demo|deepl|google`), `caption_target_languages` (default `['ar','en']`).
Env keys for the real providers: `OPENAI_API_KEY` (Whisper `whisper-1`,
`verbose_json`), `DEEPL_API_KEY`, `GOOGLE_TRANSLATE_API_KEY`, `WHISPER_CMD`
(e.g. `whisper {file} --output_format json`). A provider selected without its key
fails the job with a clear error — the worker never crashes the server.

> **⚠️ DEMO MODE warning: with the default `demo` providers, the ASR invents
> plausible-but-fake caption text from the episode title/description (it does not
> listen to the audio), and the demo MT only prefixes each cue with a `[<lang>] `
> tag without translating. Plug in real provider keys and switch the provider
> settings for production captions.**

## Admin API — full control panel (`/api/v1/admin/*`, header `X-Admin-Token: <ADMIN_TOKEN>`)
Demo/dev token: `dev-admin-token-change-me` (env `ADMIN_TOKEN`). The dashboard at **`/admin`**
(`public/admin/index.html`, vanilla JS, no build step/CDN) covers every endpoint below:
Overview · Genres · Series · Episodes (+ Cast) · Home Sections · Rewards & Economy ·
Users · Notifications · App Settings · Transactions.

- **Stats** — `GET /admin/stats`: `users, series, episodes, views, coinsGranted` plus
  `newUsersToday`, `coinsInCirculation` (sum of all balances), `vipUsers`,
  `topSeries` (top 5 by `viewCount`: id/title/viewCount), `recentTransactions` (latest 10).
- **Catalog CRUD** — `GET/POST/PATCH/DELETE /admin/genres|series|episodes` (episodes include server-side
  `videoUrl` + `dubs[]`) · CRUD `/admin/home-sections` (`seriesIds` = ordered items).
- **Cast** — `GET/POST/PATCH/DELETE /admin/series/:id/cast[/:castId]` over `persons` + `cast_members`:
  `{name, characterName, photoUrl, sortOrder}` (POST creates/reuses a person; PATCH also updates the person).
- **Users** — `GET /admin/users?q=` (search by email/name) · `GET /admin/users/:id/summary`
  (favorites/following/liked counts, history entries, unlocks, coin balance, recent transactions) ·
  `POST /admin/users/:id/coins {amount}` (logged in `coin_transactions`) ·
  `POST /admin/users/:id/vip {isVip}` · `DELETE /admin/users/:id` (deletes the user and all their data).
- **Notifications** — `POST /admin/notifications/broadcast {title, body}` (also recorded in the
  `broadcasts` table) · `GET /admin/notifications` (sent broadcasts, newest first).
- **Reward tasks** — CRUD `GET/POST/PATCH/DELETE /admin/reward-tasks[/:slug]`:
  `{slug, title, description, coins, actionType, target, sortOrder, active}`. Inactive tasks are
  hidden from `GET /rewards` and cannot be completed.
- **Transactions** — `GET /admin/transactions?limit&offset&type&userId` → `{items[], total, limit, offset}`,
  each item joined with the user's email/name (`type, amount, balanceAfter, createdAt`).

## Settings store (`settings` table, `src/settings.js`)
Server-side key/value store seeded on boot from the app defaults
(`firebase/remote_config_initial.json`, `remote_config_service.dart`, `kDailyCheckinRewards`),
with env vars as pre-store fallback. `GET/PATCH /api/v1/admin/settings` (PATCH is partial and
validated; unknown keys → 400). **The runtime reads the store live on every request** — edits
take effect immediately, no restart:

| Key | Default | Runtime effect |
|---|---|---|
| `maintenance_mode` (bool) | `false` | ON → every non-admin `/api/v1/*` call returns **503** `{"error":{"code":"MAINTENANCE",…}}`; the admin API and `/admin` dashboard keep working |
| `premium_playback_mode` | `premium_content` | See playback enforcement below |
| `ads_enabled` (bool) | `true` | OFF → `POST /rewards/ad` grants nothing (`reason: ADS_DISABLED`) |
| `welcome_coin_bonus` | 30 | Coins granted on new-user creation |
| `episode_unlock_coin_cost` | 30 | Default unlock cost when an episode's own `coinCost` is 0 |
| `ad_reward_amount` | 20 | Coins per rewarded-ad claim (server value is authoritative) |
| `ad_daily_cap` | 5 | Max rewarded-ad claims per user per day |
| `checkin_amounts` (int[7]) | `[20,50,35,30,35,20,50]` | Daily check-in rewards shown by `GET /rewards` and granted by `POST /rewards/checkin` |
| `wheel_enabled` (bool) / `wheel_segments` (int[]) / `wheel_weights` (int[]) | `true` / `[5,10,15,20,30,50,100,0]` / `[20,18,15,14,12,10,6,5]` | Reward wheel on/off, segment payouts and their weights |
| `wheel_free_spins_per_day` / `wheel_extra_spin_cost` (int) | `3` / `20` | Free spins per day; coin cost of each extra spin |
| `chests_enabled` (bool) / `chest_milestones` | `true` / `[{3,15},{7,30},{12,50},{20,100}]` | Watch chests: `{threshold: distinct episodes today, coins}` |
| `watch_time_enabled` (bool) / `watch_time_coins_per_block` / `watch_time_block_minutes` / `watch_time_daily_cap_coins` | `true` / `10` / `10` / `100` | Watch-time rewards: coins per full block of minutes watched, daily cap |
| `missions_enabled` / `referrals_enabled` (bool) | `true` / `true` | Daily missions / referral program on/off |
| `referral_bonus_referrer` / `referral_bonus_referee` (int) | `50` / `50` | Referral payouts to the referrer / the new user |
| `player_*` (bool ×14) | all `true` | Player feature flags surfaced in `GET /config` `features`: `player_swipe_next_episode`, `player_double_tap_seek`, `player_long_press_2x`, `player_edge_brightness_volume`, `player_speed_menu`, `player_quality_selector`, `player_auto_next`, `player_binge_mode`, `player_pip`, `player_scrub_chapters`, `player_skip_intro`, `player_lock_controls`, `player_sleep_timer`, `player_share_moment` |
| `skip_intro_window_seconds` / `skip_intro_to_seconds` / `auto_next_countdown_seconds` (int) | `90` / `75` / `5` | Player numbers in `GET /config` `player` |
| `default_theme_preset` (int 1..7) | `6` | Default visual theme preset in `GET /config` `visual` |
| `confetti_enabled` / `haptics_enabled` (bool) | `true` / `true` | Celebration confetti / haptic feedback toggles |
| `accent_color_override` (string) | `''` | `''` or `#RRGGBB` (validated) accent color override |
| `captions_enabled` / `captions_auto_generate` (bool) | `true` / `true` | Captions on/off; auto-enqueue a caption job when an admin creates an episode with a `videoUrl` |
| `caption_target_languages` (string[]) | `['ar','en']` | Languages generated by the MT step |
| `asr_provider` / `mt_provider` (enum) | `demo` / `demo` | `demo\|openai\|local-whisper` / `demo\|deepl\|google` — see Captions section (demo is a placeholder, see warning there) |

**`GET /config`** (public, maintenance-exempt) is the app's runtime view of these settings:
`features` maps the `player_*` flags (renamed without the prefix) plus `captions`, `wheel`,
`chests`, `missions`, `referrals`, `watch_time` and `ads`; `player`, `visual` and `economy`
carry the numbers/visual/economy values listed above.

**`premium_playback_mode` enforcement** in `GET /episodes/:id/playback`:
- `disabled` — premium gating off: VIP-only flags do not block playback (coin-unlock rules for
  non-free episodes still apply).
- `premium_content` (default) — only premium content is gated, as before: episodes/series flagged
  VIP-only require an active VIP subscription; other episodes follow free/coin-unlock rules.
- `all_playback` — **all** playback requires an active VIP subscription, even free episodes
  (403 `VIP_REQUIRED` for non-VIP users).

## Files
`src/server.js` (entry + static /admin), `src/db.js` (sqlite schema incl. `settings` + `broadcasts`, Phase 2
economy/caption tables + `users.xp/referralCode/referredBy` migrations), `src/captions.js` (ASR→MT→WebVTT
caption pipeline + in-process job worker),
`src/settings.js` (settings store: defaults, validation, live reads), `src/auth.js` (JWT + dev Firebase decode),
`src/routes.js` (app + admin routes, serializers), `src/seed.js` (7 genres, 8 series × 10 episodes, cast, 7 home
sections covering all section types, reward tasks, Phase 2 missions, demo caption tracks for the first
2 episodes of the first series, dubs on the dubbed series). Catalog seed runs on first boot only.
Sample videos: public Google sample MP4s (`storage.googleapis.com/gtv-videos-bucket/sample/...`);
covers: `picsum.photos/seed/<slug>/600/800`.
