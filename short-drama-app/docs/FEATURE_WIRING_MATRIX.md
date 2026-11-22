# HERO DRAMA — Feature Wiring Matrix

Built during the Phase-3 file-by-file review (2026-11-22). One row per
user-facing feature: UI entry → app service → API → backend handler → data →
dashboard control → automated test. Test numbers refer to
`backend/test/run-tests.mjs` (57 cases, all passing — see
`backend/test/LAST_RUN.txt`). "MISSING" in the test column means no automated
test exists; the reason is stated.

Backend handlers live in `backend/src/routes.js` unless another file is named.
App service is `lib/services/drama/drama_service.dart` unless named otherwise.

## Auth & account

| # | Feature | App UI entry (file) | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 1 | Sign-in (Firebase exchange, welcome bonus) | app_settings/widgets/email_auth_bottom_sheet.dart, sign_in_options_bottom_sheet.dart | AuthService (services/auth/auth_service.dart) | POST /auth/firebase | routes.js auth section | users, coin_transactions, notifications | none needed (bonus = Settings › welcome_coin_bonus) | 2 |
| 2 | Token refresh (rotation) | — (ApiClient interceptor, services/api/api_client.dart) | ApiClient._tryRefreshOrReExchange | POST /auth/refresh | routes.js + auth.js rotateRefresh | refresh_tokens | none needed | 3, 51 |
| 3 | Current user profile | presentation/drama/profile_content.dart | AuthService.fetchMe | GET /auth/me | routes.js | users | Users (view) | 36 (shape), 49–51 |
| 4 | Guest → account relink/merge | AuthService on sign-in | AuthService.relink | POST /auth/relink | routes.js (single tx, conflict-safe, guests only) | all user tables | none needed | 49 |
| 5 | Apply referral code | presentation/drama/rewards_content.dart (referral card) | DramaService (referral) | POST /auth/referral | routes.js | users.referredBy, coin_transactions | Engagement Lab (bonuses, enable flag) | 36, 54 |
| 6 | Delete account | app_settings (danger zone) | AuthService.deleteAccount | DELETE /auth/account | routes.js (full erasure, tx) | all user tables deleted | Users › Delete (admin equivalent) | 50 |

## Catalog & discovery

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 7 | Genre list | widgets/genre_grid.dart, discover_content.dart | DramaService.fetchGenres | GET /categories | routes.js | genres | Genres CRUD | 4, 20 |
| 8 | Series by genre | category_series_screen.dart | DramaService.fetchSeriesByGenre | GET /genres/:id/series | routes.js | series | Series CRUD | MISSING — endpoint exercised indirectly via 6/8; no dedicated case (low risk, same serializer as 8) |
| 9 | Discover (popular/latest/ranking + rankDelta) | discover_content.dart + discover_filter_tabs.dart | DramaService.fetchDiscover | GET /discover?filter= | routes.js | series, meta(rank_snapshot) | Series (rankScore field) | 6 |
| 10 | For You rail | shorts_content.dart | DramaService.fetchForYou | GET /for-you | routes.js | series | none needed | MISSING — same query family as 9; no dedicated case |
| 11 | Search | search_screen.dart | DramaService.searchSeries | GET /search?q= | routes.js | series | none needed | 7 |
| 12 | Home shelves (7 section types) | discover_content.dart + drama_section.dart | DramaService.fetchHomeSections | GET /home?locale= | routes.js (locale filter + en fallback) | home_sections, home_section_items | Home Sections CRUD | 5 |
| 13 | Series detail (cast, related, resume, flags) | series_detail_screen.dart | DramaService.fetchSeriesDetail | GET /series/:id | routes.js | series, cast_members, persons, user_series, watch_history | Series CRUD + Cast manager | 8 |
| 14 | Episode list (no videoUrl, unlock state) | series_detail_screen.dart, episode_tiles.dart | DramaService.fetchEpisodes | GET /series/:id/episodes | routes.js episodeJson | episodes, episode_unlocks | Episodes CRUD | 9 |
| 15 | View counting | discover/detail (fire-and-forget) | DramaService.incrementView | POST /content/view | routes.js | series/episodes.viewCount | Overview stats | MISSING — counter only; verified by stats case 21 shape |

## Playback & player luxury

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 16 | Playback URL + entitlement (free/VIP/coin) | episode_player_screen.dart | PlaybackService (services/drama/playback_service.dart) | GET /episodes/:id/playback | routes.js (premium_playback_mode gate) | episodes, episode_unlocks, users.isPro(+expiry) | App Settings (premium mode) | 10, 11, 13, 14, 30 |
| 17 | Dub track selection | episode_player_screen.dart (language menu) | PlaybackService (?lang=) | GET /episodes/:id/playback?lang= | routes.js episode_dubs lookup | episode_dubs | Episodes (dubs editor) | MISSING — no case asserts a dub URL is returned (seed has es/pt dubs); playback shape covered by 39 |
| 18 | Quality selector (1080/720/480/360) | widgets/player (quality chip) | PlaybackService qualities[] | GET /episodes/:id/playback | routes.js qualities ladder | episodes.videoUrl | none (placeholder ladder, documented) | 39 |
| 19 | Coin unlock | episode_player_screen.dart (unlock overlay) | DramaService.unlockEpisode | POST /episodes/:id/unlock | routes.js (VIP refusal, episode-price precedence, tx) | episode_unlocks, coin_transactions | App Settings (global cost) + Episodes (per-episode cost) | 12, 13, 24, 47 |
| 20 | Swipe next/prev episode | episode_player_screen.dart | local + fetchEpisodes | GET /series/:id/episodes | routes.js | episodes | Feature Flags › player_swipe_next_episode | 9 (data), flag via 31 |
| 21 | Double-tap seek ±10s | widgets/player/seek_ripple.dart | local | — | — | — | Feature Flags › player_double_tap_seek | MISSING — pure client gesture, no backend surface |
| 22 | Long-press 2× speed | episode_player_screen.dart | local | — | — | — | Feature Flags › player_long_press_2x | MISSING — pure client |
| 23 | Edge brightness/volume HUD | widgets/player/edge_hud.dart + player_platform_service.dart | local (MethodChannel hero_drama/media_controls, guarded) | — | — | — | Feature Flags › player_edge_brightness_volume | MISSING — native channel not implemented (documented scaffold) |
| 24 | Speed menu (persisted) | episode_player_screen.dart | local (SharedPreferences) | — | — | — | Feature Flags › player_speed_menu | MISSING — pure client |
| 25 | Auto-next countdown | widgets/player/auto_next_overlay.dart | local + /config countdown seconds | GET /config | routes.js /config | settings | Visual & Theme (countdown seconds) + Feature Flags | 31 |
| 26 | Binge mode | episode_player_screen.dart | local + flag | GET /config | routes.js /config | settings | Feature Flags › player_binge_mode | 31 (flag shape) |
| 27 | PiP | episode_player_screen.dart | PlayerPlatformService (guarded no-op) | — | — | — | Feature Flags › player_pip | MISSING — native side not implemented (documented scaffold) |
| 28 | Chapter progress bar + scrub tooltip | widgets/player/chapter_progress_bar.dart | local | — | — | — | Feature Flags › player_scrub_chapters | MISSING — pure client |
| 29 | Skip Intro | episode_player_screen.dart | /config timings | GET /config | routes.js /config | settings | Visual & Theme (window/skip-to) | 31 |
| 30 | Lock controls | widgets/player/lock_overlay.dart | local | — | — | — | Feature Flags › player_lock_controls | MISSING — pure client |
| 31 | Sleep timer | episode_player_screen.dart | local | — | — | — | Feature Flags › player_sleep_timer | MISSING — pure client |
| 32 | Share moment | episode_player_screen.dart | DramaService.shareSeries + share_plus | POST /content/share | routes.js (validated, 1/series/day for missions) | share_events, user_daily_events | none needed | MISSING — mission-side effect covered by design; no dedicated case |
| 33 | Resume banner / continue watching | widgets/continue_watching_card.dart, player resume banner | DramaService.fetchContinueWatching | GET /me/library/continue | routes.js | watch_history | none needed | 18 |
| 34 | Episode sheet polish (watched/locked badges) | episode_player_screen.dart sheet | fetchEpisodes + history | GET /series/:id/episodes, /me/library/history | routes.js | episodes, watch_history | none needed | 9, 18 |

## Captions & translation

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 35 | CC language picker (Off/Original/ar/en/…) | widgets/player/caption_overlay.dart | PlaybackService captionLanguages + raw VTT fetch | GET /episodes/:id/playback (captionLanguages), GET /episodes/:id/captions/:lang | routes.js (entitlement-gated like playback) | caption_tracks | Captions & Translation | 38, 39, 48 |
| 36 | Caption language list | caption_overlay.dart | DramaService (captions list) | GET /episodes/:id/captions | routes.js (entitled users only) | caption_tracks | Captions & Translation | 38, 48 |
| 37 | Auto-generate on episode create / videoUrl change | — (server-side) | — | POST /admin/episodes, PATCH /admin/episodes/:id | routes.js → captions.enqueueCaptionJob | caption_jobs, caption_tracks | Captions & Translation (auto-generate toggle) | 41 |
| 38 | Manual generate / delete track | — (dashboard) | — | POST /admin/episodes/:id/captions/generate, DELETE /admin/captions/:trackId | routes.js → captions.js worker | caption_jobs, caption_tracks | Captions & Translation (matrix) | 38, 40 |
| 39 | ASR→MT pipeline (demo/openai/local-whisper × demo/deepl/google) | — (server-side) | — | — (job worker) | backend/src/captions.js | caption_tracks.vtt | Captions & Translation (providers, target languages) | 38 (demo path end-to-end); real providers MISSING — no API keys in this environment (documented) |

## Social & library

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 40 | Like / unlike (count + mission) | series_detail_screen.dart | DramaService.toggleLike | POST /series/:id/like | routes.js (transition-only) | user_series, series.likeCount, user_daily_events | none needed | 44 |
| 41 | Favorite → My List | series_detail_screen.dart, my_list_content.dart | DramaService.toggleFavorite / fetchFavorites | POST /series/:id/favorite, GET /me/library/my-list | routes.js | user_series | none needed | 17 |
| 42 | Follow series | series_detail_screen.dart | DramaService.toggleFollow | POST /series/:id/follow | routes.js | user_series | none needed | MISSING — same handler loop as like/favorite (44/17 cover the mechanism); no dedicated case |
| 43 | Watch history list | my_list_content.dart | DramaService.fetchWatchHistory | GET /me/library/history | routes.js | watch_history | Users › Summary | 18 |
| 44 | Watch progress reporting (accrual) | episode_player_screen.dart (periodic) | DramaService.recordWatch | POST /me/watch-history | routes.js (server-verified, high-water mark) | watch_history, watch_progress, watch_time_daily, watch_events | none needed | 18, 34, 45 |

## Coins & addictive economy

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 45 | Coin balance header (count-up) | widgets/coin_balance_header.dart | DramaService.fetchCoinBalance | GET /me/coins | routes.js | users.coinBalance | Users (adjust) | 13, 43–57 (throughout) |
| 46 | Daily check-in (streak ladder + level/streak bonuses) | widgets/daily_checkin_strip.dart | DramaService.claimDailyCheckin | POST /rewards/checkin | routes.js (streak-based dayIndex, tx) | checkins, coin_transactions | Rewards & Economy (amounts, bonus keys via API) | 15, 37, 55, 56 |
| 47 | Rewarded-ad bonus | rewards_content.dart | DramaService.claimAdReward | POST /rewards/ad | routes.js (settings amount, daily cap, tx) | ad_rewards, coin_transactions | App Settings (amount, cap, ads_enabled) | 43 |
| 48 | Starter tasks (one-shot + milestones) | widgets/reward_task_tile.dart, series_reward_tile.dart | DramaService.completeRewardTask | POST /rewards/tasks/:slug/complete | routes.js (milestone progress server-checked, tx) | reward_tasks, user_reward_tasks | Rewards & Economy (tasks CRUD) | 16, 27 |
| 49 | Spin wheel | widgets/wheel_widget.dart | DramaService (wheel spin) | POST /rewards/wheel/spin | routes.js (weighted, tx) | wheel_spins, coin_transactions | Engagement Lab (segments/weights/free spins/cost) | 32 |
| 50 | Treasure chests | widgets/chest_row.dart | DramaService (chest claim) | POST /rewards/chests/:id/claim | routes.js (fixed coins, tx) | chest_claims, watch_events | Engagement Lab (milestones) | 33, 45 |
| 51 | Watch-time rewards | rewards_content.dart (watch-time card) | DramaService (watch-time claim) | POST /rewards/watch-time/claim | routes.js (cap on paid coins, tx) | watch_time_daily | Engagement Lab (rate, block, cap) | 34, 57 |
| 52 | Daily missions | widgets/missions_section.dart | DramaService (mission claim) | POST /rewards/missions/:slug/claim | routes.js (enabled guard, progress server-checked, tx) | missions, mission_claims, user_daily_events | Engagement Lab (missions CRUD) | 35, 46 |
| 53 | Streak / XP / level display | widgets/streak_level_header.dart | DramaService.fetchRewardsState | GET /rewards | routes.js rewardsState | checkins, users.xp | none needed (bonus tuning keys in settings) | 36, 55 |
| 54 | Multiplier events | rewards_content.dart (event banner) | fetchRewardsState.activeEvent | GET /rewards (+ admin CRUD) | routes.js activeEvent (null bounds = open) | events | Engagement Lab (events CRUD) | 37, 56, 57 |
| 55 | Referral program | rewards_content.dart (referral card) | DramaService (referral code in /rewards + /auth/me) | POST /auth/referral | routes.js (24h window, case-insensitive, tx) | users.referralCode/referredBy | Engagement Lab (bonuses, flag) | 36, 54 |
| 56 | Rewards state aggregate | rewards_content.dart | DramaService.fetchRewardsState | GET /rewards | routes.js rewardsState | all economy tables | — | 15–57 (asserted in most economy cases) |

## Notifications

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 57 | Inbox + unread count | presentation/notifications/notifications_screen.dart | DramaService.fetchNotifications / fetchUnreadNotificationCount | GET /notifications | routes.js | notifications | Notifications (broadcast) | 19 |
| 58 | Mark read (one / all) | notifications_screen.dart | DramaService.markNotificationRead / markAll | POST /notifications/read | routes.js | notifications.readAt | none needed | 19 (all); explicit-ids variant MISSING — same handler branch |
| 59 | Admin broadcast | — (dashboard) | — | POST /admin/notifications/broadcast | routes.js adminHandle | notifications, broadcasts | Notifications | 19, 28 |

## Settings, config & admin

| # | Feature | App UI entry | App service call | API endpoint | Backend handler | Data / store | Dashboard control | Automated test |
|---|---|---|---|---|---|---|---|---|
| 60 | Public app config (flags/player/visual/economy) | — (AppConfigService at startup, services/app_config_service.dart) | AppConfigService.load | GET /config | routes.js (maintenance-exempt) | settings | Feature Flags / Visual & Theme | 31, 42 |
| 61 | Maintenance mode | — (app calls fail empty; config reports it) | AppConfigService.maintenanceMode (parsed, no dedicated UI — flagged) | all app endpoints → 503 | routes.js gate | settings | App Settings | 26, 42 |
| 62 | Premium playback mode | drama_entitlement_service.dart (now reads backend mode) | AppConfigService.premiumPlaybackMode | GET /config + playback gate | routes.js | settings | App Settings | 30 |
| 63 | Theme preset from server | theme_provider.dart (applies /config preset) | AppConfigService | GET /config | routes.js | settings.default_theme_preset | Visual & Theme | 31 (value), application is client-side |
| 64 | Admin stats overview | — (dashboard) | — | GET /admin/stats | routes.js adminHandle | all tables (aggregates) | Overview | 21 |
| 65 | Admin content CRUD (genres/series/episodes/home sections/cast) | — (dashboard) | — | /admin/genres, /admin/series(+/cast), /admin/episodes, /admin/home-sections | routes.js adminHandle (404 on missing rows) | content tables | Genres / Series / Episodes / Home Sections | 20, 27, 41, 53 |
| 66 | Admin users (search, summary, coins, VIP, delete) | — (dashboard) | — | /admin/users… | routes.js adminHandle | users + all user tables | Users | 13, 14, 29, 48, 51 |
| 67 | Admin transactions log | — (dashboard) | — | GET /admin/transactions | routes.js adminHandle | coin_transactions | Transactions | 29 |
| 68 | Admin settings (48 keys) | — (dashboard) | — | GET/PATCH /admin/settings | settings.js updateSettings (validated) | settings | All settings sections | 23–26, 31, 52 |
| 69 | Paywall / VIP purchase (RevenueCat) | presentation/pricing/* (7 variants, paywall_router.dart) | RevenueCatService | — (RevenueCat SDK, no backend endpoint) | — (client + RevenueCat cloud) | RevenueCat + users.isPro via admin/webhook (not built) | none | MISSING — external service, needs the user's RevenueCat keys; documented Phase-1 limitation |

## Known gaps flagged by the review (not wiring defects)

- `features.ads`, `visual.accentColorOverride`, `economy.wheelFreeSpinsPerDay` are delivered by /config but have no app consumer yet; `maintenanceMode` is parsed but has no dedicated app screen (calls fail empty during maintenance).
- One-shot starter tasks (connect_email, rate_app, invite_friend, enable_notifications) are honor-system by design — the server cannot verify the off-platform action; milestone tasks are server-verified.
- Reward "today" is the server-local day (set `TZ` in production); per-user timezone is not sent by the app.
- Double-claim response convention is mixed by design: check-in/ad/tasks/watch-time return `200 {success:false}` (app tolerance), chest/mission/referral return `409`.
