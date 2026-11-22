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

**`premium_playback_mode` enforcement** in `GET /episodes/:id/playback`:
- `disabled` — premium gating off: VIP-only flags do not block playback (coin-unlock rules for
  non-free episodes still apply).
- `premium_content` (default) — only premium content is gated, as before: episodes/series flagged
  VIP-only require an active VIP subscription; other episodes follow free/coin-unlock rules.
- `all_playback` — **all** playback requires an active VIP subscription, even free episodes
  (403 `VIP_REQUIRED` for non-VIP users).

## Files
`src/server.js` (entry + static /admin), `src/db.js` (sqlite schema incl. `settings` + `broadcasts`),
`src/settings.js` (settings store: defaults, validation, live reads), `src/auth.js` (JWT + dev Firebase decode),
`src/routes.js` (app + admin routes, serializers), `src/seed.js` (7 genres, 8 series × 10 episodes, cast, 7 home
sections covering all section types, reward tasks, dubs on the dubbed series). Seed runs on first boot only.
Sample videos: public Google sample MP4s (`storage.googleapis.com/gtv-videos-bucket/sample/...`);
covers: `picsum.photos/seed/<slug>/600/800`.
