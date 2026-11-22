# HERO DRAMA — Wiring Matrix v2 (per-control, "nuclear pipes pass")

- **Date:** 2026-11-22 · **Scope:** every interactive control in MainTabs, Discover/Home,
  Search, Category, Series detail, Episode player, Shorts, My List, Rewards, Notifications,
  Onboarding, Pricing/paywalls, Purchase history, shared Widgets, the admin dashboard, and the
  backend-only surface. Auth/session, account/settings and legal internals are Round 3 stubs
  (end of file) — except the onboarding session-exit fix, which lives in onboarding territory.
- **Method:** each control traced control → handler → provider/service → API endpoint →
  handler in `backend/src/routes.js` (grep-verified to exist, response shape checked against
  the client's parsing) → DB table/setting → response path back to UI state. v1's 69 feature
  rows were re-verified against current code first; v2 goes per-control.
- **Verdict legend:** `WIRED` = end-to-end pipe verified · `WIRED-WITH-NOTE` = works, with a
  caveat worth knowing · `GAP-FIXED` = was broken, fixed in this pass (file named) ·
  `GAP-OPEN` = broken/missing, not fixed (reason named; outside territory or not code-only).
- **Round 4 addendum (2026-11-22):** all six remaining GAP-OPEN items are closed — purchase
  history backend, maintenance screen, real Shorts feed, personalized "For You", and the
  consent chain are built (rows marked "round 4"), and the Download action is
  RESOLVED-BY-REMOVAL per the user's explicit no-offline-downloads decision. No GAP-OPEN
  rows remain in this matrix. Verification: backend 146/146 (suites 1–6), security probes
  54 with 0 CONFIRMED, Flutter 84/84, analyze 0 errors. See CODE_READINESS.md "Round 4".

Backend handlers are in `backend/src/routes.js` unless another file is named. Client service is
`DramaService` (`lib/services/drama/drama_service.dart`) unless named otherwise.

## MainTabs & navigation

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Bottom tab bar ×5 (Discover/Shorts/Rewards/My List/Profile) | `MainTabs._onTabTapped` → IndexedStack switch (local) | — local only | — | WIRED |
| Android back on non-Home tab | `PopScope._onWillPop` → jump to Home tab | — local | — | WIRED |
| Android back ×2 on Home (2 s window) | `_onWillPop` → `SystemNavigator.pop` | — local | — | WIRED |
| Header coin chip (display) | `AppHeader` ← `UserProvider.user.coinBalance` (refreshed after claims/unlocks) | GET /auth/me (via UserProvider) | routes.js → users.coinBalance | WIRED-WITH-NOTE — reads UserProvider, not `coinBalanceProvider`; stays fresh because every claim/unlock path calls `refreshUserInBackground()` |
| Header PRO chip (non-Pro) | `presentPaywallWithDiscount(trigger: header)` → RevenueCat flow, then `refreshUser(syncProStatus)` | — RevenueCat (no backend endpoint) | — | WIRED-WITH-NOTE — entitlement is RevenueCat-side; backend `users.isPro` only changes via admin/webhook (v1 row 69 caveat stands) |
| Header bell + unread badge | push `NotificationsScreen`; badge ← `DramaService.fetchUnreadNotificationCount` (reloads on return) | GET /notifications | routes.js → notifications (unread = readAt IS NULL) | WIRED |
| Header settings gear | push `AppSettings` (MaterialPageRoute) | — navigation | — | WIRED (settings internals = Round 3) |
| `DramaNav.openSeries / openSeriesById` | push `SeriesDetailScreen` | — navigation | — | WIRED |
| `DramaNav.openPlayer` | push `EpisodePlayerScreen(series, episodes, startIndex)` | — navigation | — | WIRED |
| `DramaNav.openCategory` | push `CategorySeriesScreen` | — navigation | — | WIRED |
| `DramaNav.openSearch` | push `SearchScreen` | — navigation | — | WIRED |
| `TabRouter` jump-to-tab (player unlock failure paths) | registered callback → `_onTabTapped` | — local | — | WIRED |

## Home / Discover

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Search bar (fake field) | tap → `DramaNav.openSearch` | — navigation | — | WIRED |
| Filter tab: Popular | `discoverFilterProvider` → `homeFeedProvider` | GET /home?locale= | routes.js → home_sections + home_section_items (locale filter + en fallback) | WIRED |
| "For You" home section (round 4) | rendered by `discover_content._section` — new `SectionType.forYou('for_you')` case → standard carousel shelf | GET /home | routes.js `forYouSeries()` — per-user genre affinity from episode_progress + watch_history + user_series (favorite/follow/like), ranked affinity → rankScore → viewCount, completed series excluded; guest/no-signal → trending order. Seeded `sec-foryou` row or a synthetic section spliced after the hero | WIRED — backend suite 6 case 510 (affinity first, guest fallback, completed excluded); client parse covered by SectionType test |
| Filter tab: Categories | `discoverFilterProvider` → `dramaGenresProvider` + GenreGrid | GET /categories | routes.js → genres | WIRED |
| Filter tab: Latest | `discoverListProvider` | GET /discover?filter=latest | routes.js → series ORDER BY releaseYear/createdAt | WIRED |
| Filter tab: Ranking | `discoverListProvider` | GET /discover?filter=ranking | routes.js → series ORDER BY rankScore (rankDelta in serializer) | WIRED |
| Featured hero pager cards | tap → `openSeries` | (data via GET /home) | home_sections type featuredHero | WIRED |
| Ranking list tiles | tap → `openSeries` | (data via GET /home) | home_sections type rankingList | WIRED |
| Genre grid (inline section + Categories tab) | chip/card tap → `openCategory` | GET /categories | genres | WIRED |
| Vertical grid / hot grid / carousel / new-releases cards | tap → `openSeries` | (data via GET /home) | home_sections types verticalGrid/hotGrid/seriesCarousel/newReleases | WIRED |
| Continue-watching home section type | rendered as generic carousel → tap → `openSeries` (not straight to player) | (data via GET /home) | home_sections type continueWatching | WIRED-WITH-NOTE — section items are series, so it opens detail; the resume-to-player card lives in the dedicated widget (see Widgets) |
| Pull-to-refresh | `AsyncRefreshBuilder.onRefresh` → `ref.refresh(homeFeedProvider)` | GET /home | as above | WIRED |
| Section header chevron | `DramaSectionHeader.onSeeMore` | — | — | WIRED-WITH-NOTE — no caller passes `onSeeMore`/`showChevron`, so the chevron never renders; no dead tap target exists in practice |

## Search

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Text field (350 ms debounce) | `_onChanged` → `searchQueryProvider` → `searchResultsProvider` → `searchSeries` | GET /search?q=&limit= | routes.js → series title/synopsis match | WIRED |
| Clear (×) button | clears controller + query provider | — local | — | WIRED |
| Result poster tap | `openSeries` | — navigation | — | WIRED |
| Back button | `maybePop` | — local | — | WIRED |

## Category

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Series card tap | `openSeries` | (data via `categorySeriesProvider`) | GET /genres/:id/series → series WHERE genreId | WIRED |
| Pull-to-refresh | `ref.refresh(categorySeriesProvider)` | GET /genres/:id/series | as above | WIRED |

## Series detail

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Back button | `maybePop` | — local | — | WIRED |
| Play / Continue button | resolves resume target (`resumeEpisodeId` preferred, else number) → `openPlayer(startIndex)` | GET /series/:id (+episodes) | routes.js → series, user_series, watch_history/episode_progress (resume fields) | WIRED |
| My List action | optimistic `_favOverride` → `toggleFavorite` (add-path failure rolls back + error toast) | POST /series/:id/favorite | routes.js → user_series.favorite | WIRED |
| Like action | optimistic count → `toggleLike`, server count wins, failure reverts | POST /series/:id/like | routes.js → user_series.liked, series.likeCount, user_daily_events | WIRED |
| **Follow action** | **NEW button** (bell icon, Following state) → optimistic `_followOverride` → `toggleFollow`, add-path failure rolls back | POST /series/:id/follow | routes.js → user_series.following; state read back via GET /series/:id `isFollowing` | **GAP-FIXED** — `series_detail_screen.dart`: service method, backend handler and `isFollowing` parsing all existed but no control ever called them (v1 row 42's claimed UI entry did not exist) |
| Share action | `shareSeries` (fire-and-forget mission credit) + share_plus sheet | POST /content/share | routes.js → share_events, user_daily_events (1/series/day) | WIRED |
| Download action | **REMOVED** (round 4, user decision) | — | — | RESOLVED-BY-REMOVAL — the user explicitly does not want offline downloads; the toast-only `_action` (download icon + "Downloads are a VIP feature") was deleted from `series_detail_screen.dart` and no download/offline code exists anywhere. Leftover note: paywall help-dialog copy (`paywallHelpFeature4`, "Download episodes for offline viewing", music-template residue in 13 l10n files) still mentions downloads — flagged for a copy pass, not silently rewritten |
| Synopsis expand/collapse | local `setState` | — local | — | WIRED |
| Season chips | local filter of episode grid | — local (episodes already fetched) | — | WIRED |
| Episode tile tap | `openPlayer` at tapped index (lock state from `episodeJson.isUnlocked`, mirrors playback gate) | GET /series/:id/episodes | routes.js → episodes, episode_unlocks, users.isPro | WIRED |
| Related ("More Like This") card tap | `openSeries` | (data via GET /series/:id `related`) | routes.js → series same-genre | WIRED |
| Pull-to-refresh | `ref.refresh(seriesDetailProvider)` | GET /series/:id | as above | WIRED |
| View counting (on open) | `incrementView('series', id)` fire-and-forget | POST /content/view | routes.js → series.viewCount | WIRED |

## Episode player

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Back button | `maybePop` (progress recorded on dispose/switch via `recordWatch`) | POST /me/watch-history | routes.js → watch_history, episode_progress, watch_progress, watch_time_daily, watch_events | WIRED |
| Tap video | toggle controls visibility | — local | — | WIRED |
| Center play/pause | controller play/pause | — local | — | WIRED |
| Double-tap left/right (±10 s seek + ripple) | `_onDoubleTap`, flag `double_tap_seek` via GET /config | GET /config | routes.js /config → settings.player_double_tap_seek | WIRED |
| Long-press 2× speed | `_onLongPressStart/End`, flag `long_press_2x` | GET /config | settings.player_long_press_2x | WIRED |
| Vertical drag (left brightness / right volume + HUD) | `_onVerticalDrag*` → `PlayerPlatformService` (guarded MethodChannel), flag `edge_brightness_volume` | GET /config | settings.player_edge_brightness_volume | WIRED-WITH-NOTE — native channel is a guarded scaffold (v1 row 23); volume side works via controller, brightness is best-effort |
| Vertical swipe next/prev episode | `_onVerticalDragEnd` → `_goToEpisode(viaSwipe)`, flag `swipe_next_episode` | GET /config + GET /series/:id/episodes | settings.player_swipe_next_episode | WIRED |
| Skip Intro chip | seek to `skipIntroToSeconds` when position < `skipIntroWindowSeconds`, flag `skip_intro` | GET /config player.* | settings.skip_intro_window_seconds / skip_intro_to_seconds | WIRED |
| Resume banner (dismiss/seek) | shows saved position from GET /me/library/history/series/:id progress | GET /me/library/history/series/:id | routes.js → episode_progress | WIRED |
| Scrubber / chapter bar | `ChapterProgressBar` (flag `scrub_chapters`) or `VideoProgressIndicator` fallback | GET /config | settings.player_scrub_chapters | WIRED |
| Quality chip + sheet (Auto/1080/720/480/360) | `_showQualitySheet` → `playback.urlForLabel`, hidden unless ≥2 distinct URLs (`qualityMenuVisible`), flag `quality_selector` | GET /episodes/:id/playback | routes.js → qualities ladder (all labels currently map to the same URL — documented placeholder, hence the distinct-URL gate) | WIRED-WITH-NOTE |
| PiP button | `_enterPip` → `PlayerPlatformService` guarded; toast "PiP not supported here" on failure, flag `pip` | GET /config | settings.player_pip | WIRED-WITH-NOTE — native PiP not implemented (documented scaffold, v1 row 27); button honestly reports failure |
| Lock controls button | `_controlsLocked = true`, flag `lock_controls` | GET /config | settings.player_lock_controls | WIRED |
| Lock overlay unlock tap | `LockOverlay` tap → unlock controls | — local | — | WIRED |
| Dub/language rail button + sheet | `_showLanguageSheet` → reload playback with `?lang=` | GET /episodes/:id/playback?lang= | routes.js → episode_dubs | WIRED-WITH-NOTE — sheet only appears when the series has dubs (`_hasDubs`); no dedicated backend test for dub URL selection (v1 row 17) |
| Episodes rail button + sheet: episode tap | `_playAt(gi)` → `_goToEpisode` + close sheet | GET /series/:id/episodes | episodes + watched badges from episode_progress | WIRED |
| Episode sheet: range chips (1–20, 21–40…) | local `rangeStart` filter | — local | — | WIRED |
| Episode sheet: My List toggle | `toggleFavorite` with server state from detail; failure reverts | POST /series/:id/favorite | user_series.favorite | WIRED |
| Episode sheet: VIP banner tap | `DramaEntitlementService.presentPaywall(trigger: episodes_sheet)` → reload at same position if now VIP | — RevenueCat | — | WIRED-WITH-NOTE — same RevenueCat caveat as header PRO chip |
| CC rail button + caption sheet: Off / language list | `_applyCaptionLang` → `PlaybackService.fetchCaptionVtt` (raw VTT, entitlement-gated server-side), flag `captions` | GET /episodes/:id/playback (captionLanguages) + GET /episodes/:id/captions/:lang | routes.js → caption_tracks (ready only, playback entitlement) | WIRED |
| Caption sheet: font-size choices | persisted `caption_font_size` (SharedPreferences) + applied to overlay | — local | — | WIRED |
| Share rail button | `_shareEpisode` → `shareSeries` credit + share_plus (with timestamp when flag `share_moment` on) | POST /content/share | share_events | WIRED |
| Settings sheet: speed options | controller `setPlaybackSpeed` + persisted pref | — local | — | WIRED |
| Settings sheet: Binge mode switch | persisted `player_binge`; end-of-episode skips countdown, flag `binge_mode` | GET /config | settings.player_binge_mode | WIRED |
| Settings sheet: Background audio switch | persisted `player_bg_audio`; consumed in `didChangeAppLifecycleState` (ON = keep playing, OFF = pause on background) | — local | — | WIRED |
| Settings sheet: Sleep timer options (off / minutes / end of episode) | deadline/`_sleepAtEpisodeEnd` → fade-out pause, flag `sleep_timer` | GET /config | settings.player_sleep_timer | WIRED |
| Next / Replay rail button | `_playNext` or seek-to-zero + play on last episode | — local | — | WIRED |
| Auto-next overlay: Play now / Cancel | countdown from `autoNextCountdownSeconds`, flag `auto_next` | GET /config player.autoNextCountdownSeconds | settings.auto_next_countdown_seconds | WIRED |
| Locked overlay: coin Unlock button | `_handleUnlock` (double-tap guarded) → `unlockEpisode`; success refreshes episode + caches; `INSUFFICIENT_COINS` opens shortfall dialog | POST /episodes/:id/unlock | routes.js → episode_unlocks, coin_transactions (episode price precedes global `episode_unlock_coin_cost`) | WIRED |
| Locked overlay: VIP required state | `_handleUnlock` → `presentPaywall(trigger: drama_episode)` → reload if now VIP | — RevenueCat | playback gate reads settings.premium_playback_mode | WIRED-WITH-NOTE — RevenueCat caveat as above |
| Insufficient-coins dialog: Earn coins | pops player, `TabRouter` → Rewards tab | — local navigation | — | WIRED |
| Load-failed state: Retry / Back | `_load()` retry / `maybePop` | GET /episodes/:id/playback | routes.js playback handler | WIRED |
| Player tutorial overlay (first run) | coach marks, replayable; dismiss persists seen flag | — local (SharedPreferences via PlayerTutorial) | — | WIRED |
| Watch progress reporting (periodic + switch + dispose) | `recordWatch` (completed is sticky-OR'd client-side; server high-water-mark verifies) | POST /me/watch-history | watch_history, episode_progress, watch_time_daily, watch_events, XP | WIRED |

## Shorts

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Vertical pager (round 4) | `ShortsContent` (stateful) → `DramaService.fetchShorts` → PageView.builder (vertical), cursor pagination (loads more 3 pages from the end) | GET /shorts?limit=&cursor= | routes.js → episodes JOIN series (rankScore, viewCount order), episodeJson + seriesTitle/posterUrl/likeCount/videoUrl; opaque offset cursor | WIRED — replaces the old /for-you poster grid (the grid rows that stood here before round 4). Backend suite 6 case 509 (shape + full 80-episode cursor walk); `ShortItem`/`parseShortsPage` mapping unit-tested |
| Clip playback | per-page `VideoPlayerController` (lazy on activation, looping, disposed with the page); stream resolved via `getEpisodeVideoUrl` | GET /episodes/:id/playback | routes.js playback gate (same entitlement as the full player) | WIRED — locked episodes (`isUnlocked=false`) never fetch a stream; poster + lock state renders instead. Tap toggles play/pause; page change and tab switch (`MainTabs` passes `isTabActive`) pause |
| Like button | optimistic count → `toggleLike`, server count wins, failure reverts | POST /series/:id/like | routes.js → user_series.liked, series.likeCount | WIRED (series-level like, same endpoint as Series detail) |
| Mute toggle | local state → controller `setVolume(0/1)` | — local | — | WIRED |
| "Watch full episode" button | `fetchSeriesDetail` → `DramaNav.openPlayer` at the tapped episode's index | GET /series/:id (+ /episodes) | routes.js series detail | WIRED |
| Feature flag | `AppConfigService.shortsEnabled` gates the tab body ('Shorts are unavailable right now' when off) | GET /config features.shorts | settings.shorts_enabled (default ON); backend also returns an empty feed when off | WIRED |
| Empty state + Retry | `_loadFirst` re-fetch | GET /shorts | as above | WIRED — the old pull-to-refresh is gone with the grid; Retry covers the failure case |

## My List / Library

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Tab: Recently Watched | local tab switch → `watchHistoryProvider` | GET /me/library/history | routes.js → watch_history joined to series | WIRED |
| Tab: My Collection | local tab switch → `myListProvider` | GET /me/library/my-list | routes.js → user_series WHERE favorite=1 | WIRED |
| History row tap | `openSeries` | — navigation | — | WIRED |
| Collection card tap | `openSeries` | — navigation | — | WIRED |
| Pull-to-refresh (both tabs) | `ref.refresh(...)` | as above | as above | WIRED |

## Rewards

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Whole-tab state | `rewardsProvider` → `fetchRewardsState`; every claim below refreshes it + `UserProvider` | GET /rewards | routes.js `rewardsState()` → checkins, reward_tasks, wheel_spins, chest_claims, watch_time_daily, missions/mission_claims, events, users (xp/streak/referral) — client parsing in reward_models.dart matches field-for-field | WIRED |
| Check-in day strip (display) | auto-claim fires from splash (`claimDailyCheckin`, out of this territory); strip renders ladder/claimed state from GET /rewards | POST /rewards/checkin | routes.js → checkins, coin_transactions (streak-grace ladder, level/streak bonuses × event multiplier) | WIRED-WITH-NOTE — by design there is no manual claim button ("no manual claim" in splash); if the splash claim is missed, the strip is display-only until next launch |
| "+N Bonus Coins" (rewarded ad) button | `AdmobService.showRewardedAd` → on earn `claimAdReward(amount)`; cap → "Daily bonus limit reached" | POST /rewards/ad | routes.js → ad_rewards, coin_transactions (settings.ad_reward_amount / ad_daily_cap) | WIRED-WITH-NOTE — amount originates from Remote Config (`rewardAdCoins`) while the server also has `ad_reward_amount`; server enforces the cap, client amount is honoured — values can drift if dashboard and Remote Config disagree |
| Starter task tiles (Complete) | `completeRewardTask(slug)` → coins or "Already completed" | POST /rewards/tasks/:slug/complete | routes.js → reward_tasks, user_reward_tasks, coin_transactions (one-shot tasks honor-system by design) | WIRED |
| Series Reward tiles (Claim) | `completeRewardTask(slug)`; split from starter tasks by `isMilestone` (target > 1) | POST /rewards/tasks/:slug/complete | routes.js → server-checked milestone progress (watch_events / user_series) | WIRED |
| Lucky Wheel: Spin | `WheelWidget` → `spinWheel`; result animates to server `segmentIndex`; free spins then paid cost from state | POST /rewards/wheel/spin | routes.js → wheel_spins, coin_transactions (settings wheel_segments/weights/free spins/extra cost; 402 on insufficient coins) | WIRED |
| Treasure Chests: Claim | `claimChest(chest.id)` (`chest_<threshold>`) → coins or "Chest not ready yet" | POST /rewards/chests/:id/claim | routes.js → chest_claims, coin_transactions (settings.chest_milestones; unlocked by distinct episodes watched today) | WIRED |
| Watch Time: Claim button | `claimWatchTime`; disabled at 0 claimable | POST /rewards/watch-time/claim | routes.js → watch_time_daily (paidCoins cap) | WIRED |
| Daily Missions: Claim | `claimMission(slug)` → coins or "Mission not completed yet" | POST /rewards/missions/:slug/claim | routes.js → mission_claims, user_daily_events progress | WIRED |
| Referral: copy own code | tap → Clipboard + haptic + toast | — local (code from GET /rewards) | users.referralCode | WIRED |
| Referral: Apply button | `applyReferral(code)` (busy-guarded) → bonus or "Invalid referral code"; 24 h deadline text shown from `referralApplyBy` | POST /auth/referral | routes.js → users.referredBy, coin_transactions (24 h window, daily cap) | WIRED |
| Streak-at-risk banner (display) | from GET /rewards `streakAtRisk && !claimedToday` | GET /rewards | streakStatus() grace fields | WIRED |
| Event banner (display) | from GET /rewards `activeEvent` | GET /rewards | events (null bounds = open) | WIRED |
| Premium banner (non-Pro) | `presentPaywallWithDiscount` | — RevenueCat | — | WIRED-WITH-NOTE — RevenueCat caveat as above |
| Pull-to-refresh | `ref.refresh(rewardsProvider)` | GET /rewards | as above | WIRED |

## Notifications

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Screen load / pull-to-refresh | `fetchNotifications` | GET /notifications | routes.js → notifications for user (Today/This Week/Earlier grouping is client-side) | WIRED |
| Row tap | `_markRead` → `markNotificationRead(id)` (unread only), local readAt update | POST /notifications/read {ids:[id]} | routes.js → notifications.readAt | WIRED-WITH-NOTE — tapping a row only marks it read; notification payloads carry no deep-link target, so there is nothing further to navigate to |
| "Mark all read" (AppBar, unread only) | `_markAllRead` → `markAllNotificationsRead` | POST /notifications/read (no ids = all) | routes.js → notifications.readAt | WIRED |
| Close (×) | `Navigator.pop` | — local | — | WIRED |
| Unread badge (header) | `fetchUnreadNotificationCount` (counts unread from same list endpoint) | GET /notifications | notifications | WIRED |

## Onboarding

Active flow: splash → `/ready-to-start` → `ReadyToStartScreen` → `OnboardingRouter` →
variant scaffold (kOnboardingVariant = 1) → `OnboardingFlowController.completeOnboarding`.
There is **no genre-picker page and no notification-permission page** in the flow; notification
opt-in happens inside completion via `OneSignalService.optInAfterOnboarding()`.

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Page swipe (PageView ×4 pages) | `onPageChanged` → indicator state | — local | — | WIRED |
| Next / Start Watching button (all 5 variants share the flow controller) | `_onNext`/`onNext` → next page, last page → `completeOnboarding()`: acceptAllPrivacy + setOnboardingCompleted (SharedPreferences via OnboardingService) + OneSignal opt-in + marketing/rating hooks | — local only (no backend onboarding endpoint exists or is needed) | — | WIRED |
| "Not now" skip (modern variants 2–4; variant 5 hides it, variant 1 has none) | `flow.completeOnboarding` (same path as finishing) | — local | — | WIRED-WITH-NOTE — skip and finish are the same action, including accept-all privacy; see consent-chain note below |
| **Completion exit navigation** | **`navigateOnboardingExit()` (new shared helper in `shared/onboarding_flow_controller.dart`)**: stored session (`AuthService.hasStoredSession`, TokenStore fallback) OR Firebase `currentUser` → keep '/home'; neither → '/login'. All probes try/catch-guarded | — local navigation | — | **GAP-FIXED** — `onboarding_flow_controller.dart`: completion previously pushed '/home' assuming a session; bootstrap no longer creates guest sessions and splash gates returning users on a restored session, so first-run users landed on Home session-less |
| GettingStarted "Get Started" button | push PrivacyConsentScreen | — navigation | — | GAP-FIXED — `getting_started_screen.dart`: was `pushReplacementNamed('/privacy-consent')`, a route that is **not registered** in AppRoutes (would throw); now a direct MaterialPageRoute with the same replacement semantics |
| PrivacyConsent: Accept All | acceptAllPrivacy + setOnboardingCompleted → session-aware exit to '/main-tabs' or '/login' | — local | — | GAP-FIXED — `privacy_consent_screen.dart`: exit now goes through `navigateOnboardingExit` (same session-less-Home gap as the flow controller) |
| PrivacyConsent: Refuse non-essential | refuseNonEssentialPrivacy + setOnboardingCompleted → session-aware exit | — local | — | GAP-FIXED — `privacy_consent_screen.dart` (same fix) |
| PrivacyConsent: Customize Preferences | push PrivacySettingsScreen | — navigation | — | GAP-FIXED — `privacy_consent_screen.dart`: was `pushNamed('/privacy-settings')`, also unregistered; now a direct MaterialPageRoute |
| PrivacySettings: Analytics toggle / Profiling toggle (+ expand rows) | local state → persisted on Confirm via `savePrivacyPreferences` (OnboardingService → SharedPreferences); Technical row is locked-on (essential) | — local | — | WIRED |
| PrivacySettings: Confirm | savePrivacyPreferences + setOnboardingCompleted → session-aware exit to '/main-tabs' or '/login' | — local | — | GAP-FIXED — `privacy_settings_screen.dart`: exit now through `navigateOnboardingExit` |
| PrivacySettings: Accept All / Deny non-essential | acceptAllPrivacy / refuseNonEssentialPrivacy + setOnboardingCompleted → session-aware exit | — local | — | GAP-FIXED — `privacy_settings_screen.dart` (same fix, all three completion methods) |
| PrivacySettings: Close (×) | `Navigator.pop` back to consent screen | — local | — | WIRED |
| Consent chain reachability | **Splash `_navigateToNextScreen`** routes FIRST launch only (no onboarding completion + no consent record + no session — pure `ConsentGate.shouldShowChain`, unit-tested) → `GettingStartedScreen` → PrivacyConsent → (PrivacySettings via Customize) → session-aware exit to '/login' | — local navigation + SharedPreferences consent record | — | **GAP-FIXED (round 4)** — `splash_screen.dart`, `services/consent_gate.dart`: the chain is the first-launch path; every completion stamps a consent record (version + timestamp + choices via `OnboardingService.savePrivacyPreferences`), so returning users skip it entirely. The variant onboarding flow remains for launches that already hold a record/session. Consent syncs to the account via PATCH /auth/me `consent` (allow-list field) from `ConsentSyncService` on every token exchange |
| GettingStarted legal text (Terms / Privacy spans) | RichText spans carry **TapGestureRecognizers** → `LegalRoutes.terms` / `LegalRoutes.privacy` (round-3 legal screens); recognizers disposed with the State | — navigation | — | **GAP-FIXED (round 4)** — `getting_started_screen.dart`; the previously dead "Privacy Policy" GestureDetectors in `privacy_consent_screen.dart` and `privacy_settings_screen.dart` (empty onTap) now open `LegalRoutes.privacy` too. Widget-tested end-to-end (span tap → terms marker route) |

## Pricing / paywalls

Entry: `/pricing` route → `PricingPage` → `RevenueCatPaywallView`; in-app entries use
`DramaEntitlementService.presentPaywall` / `presentPaywallWithDiscount` → `PaywallRouter` →
variant 1–7 scaffold (kPaywallVariant). All purchases are RevenueCat SDK calls — there is no
backend purchase endpoint (v1 row 69); `users.isPro` reaches the backend only via admin action.

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Variant 1 (CustomPaywallScaffold): package cards select | local selection state | — RevenueCat offering data | — | WIRED |
| Variant 1: Subscribe/Continue | scaffold purchase path → `Purchases.purchasePackage`, success → onPurchaseCompleted + dismiss | — RevenueCat | — | WIRED-WITH-NOTE — RevenueCat keys/entitlement sync are external (documented Phase-1 limitation) |
| Variant 1: Restore | scaffold restore → `Purchases.restorePurchases`, success/none toasts | — RevenueCat | — | WIRED |
| Variant 1: Close (×) | onDismiss | — local | — | WIRED |
| Variants 2–7: plan/option selectors | local `setState` selection | — local | — | WIRED |
| Variants 2–7: Subscribe | `PaywallPurchaseHandler.subscribe` → RevenueCat purchase, error toasts | — RevenueCat | — | WIRED-WITH-NOTE — same external caveat |
| Variants 2–7: Restore (in legal/footer row) | `PaywallPurchaseHandler.restore` via `PaywallLegalRow` | — RevenueCat | — | WIRED |
| Variants 2–7: Terms / Privacy links | `PaywallLegalRow` → `LegalUrlLauncher.openTerms/openPrivacy` | — external URL | — | WIRED (legal content itself = Round 3) |
| Variants 2–7: Close (×) | onDismiss; variants with delayed close reveal it after 2 s (repeat shows skip the delay via PaywallFrequency) | — local | — | WIRED-WITH-NOTE — the 2 s close delay is a deliberate, config-shaped pattern, not a dead button; it always becomes tappable |
| RevenueCatPaywallView: purchase-complete callback | saves pro state via UserProvider, pops / returns purchased=true from `presentCustomPaywall` | — local + RevenueCat | — | WIRED |
| RevenueCatPaywallView: error/retry + Terms/Privacy buttons | retry reloads offering; legal via LegalUrlLauncher | — RevenueCat / external URL | — | WIRED |
| Launch paywall frequency cap | splash-side gate reads GET /config `paywallDailyCap` (`AppConfigService.paywallDailyCap` ← features.paywall_daily_cap) | GET /config | settings.paywall_daily_cap | WIRED |

## Purchase history

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Screen load / Retry / pull-to-refresh | `_loadPurchaseHistory` → `ApiClient.get('/user/orders')`, maps orders → SubscriptionModel | GET /user/orders | routes.js → `orders` table (caller-only, newest-first, limit/offset paged); `orderJson` emits exactly the parsed shape (`orders[]`, paymentProvider, subscriptionPlanId/coinPackageId by kind, status 'paid', revenueCatTransactionId, createdAt) | **GAP-FIXED (round 4)** — backend suite 6 cases 501–508; orders are written by POST /webhooks/revenuecat and POST /admin/orders through the single `recordOrder`/`applyOrderEntitlement` path |
| Account hub row (round 4) | Profile tab → 'Purchase history' `_MenuItem` → push `PurchaseHistoryScreen` | — navigation | — | **GAP-FIXED (round 4)** — `profile_content.dart`: the screen previously had no caller (orphaned) |
| Row tap (expand/collapse detail) | local `setState` | — local | — | WIRED (local behaviour only; unreachable until the load gap above is resolved) |
| Back button | `Navigator.pop` | — local | — | WIRED |

## Widgets with their own actions

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| CoinBalanceHeader (Rewards) | display only, count-up animation from GET /rewards coinBalance | GET /rewards | users.coinBalance | WIRED |
| ContinueWatchingCard | tap callback → supplied by parent (opens player/detail flow) | GET /me/library/continue (provider-fed) | watch_history (in-progress only) | WIRED |
| GenreGrid / GenreChip / GenreCard | tap → parent `onSelected(genre)` → `openCategory` | GET /categories | genres | WIRED |
| SeriesPosterCard / RankingListTile / FeaturedHeroCard | tap → parent `onTap` → `openSeries` | — (parent-fed data) | — | WIRED |
| DiscoverFilterTabs | tap → parent `onSelected(filter)` | — local state | — | WIRED |
| EpisodeTiles (detail + player sheet) | tap → parent callback; watched/locked badges from episode data | GET /series/:id/episodes | episodes, episode_progress | WIRED |
| DailyCheckinStrip | display + ad-bonus button (see Rewards) | POST /rewards/ad | ad_rewards | WIRED |
| WheelWidget spin button | parent `onWin/onRefresh` around `spinWheel`; disabled at 0 spins & no balance for paid spin | POST /rewards/wheel/spin | wheel_spins | WIRED |
| ChestRow claim buttons | parent `onClaim(chest)`; gated by claimed/unlocked state | POST /rewards/chests/:id/claim | chest_claims | WIRED |
| MissionsSection claim buttons | parent `onClaim(mission)`; gated by completed/claimed | POST /rewards/missions/:slug/claim | mission_claims | WIRED |
| RewardTaskTile / SeriesRewardTile action buttons | parent `onAction/onClaim`; gated by completed/eligible | POST /rewards/tasks/:slug/complete | user_reward_tasks | WIRED |
| StreakLevelHeader | display only (streak/level/XP progress) | GET /rewards | users.xp, checkins | WIRED |
| RewardsPremiumBanner / FreeUpgradeBanner | tap → `presentPaywallWithDiscount` | — RevenueCat | — | WIRED-WITH-NOTE — RevenueCat caveat; FreeUpgradeBanner currently has no caller outside settings surfaces |
| AdBannerWidget | AdMob banner (non-Pro only); no tap action of its own | — AdMob | settings.ads_enabled via /config features.ads | WIRED-WITH-NOTE — `features.ads` is delivered by /config and read by AppConfigService, but the banner's visibility is driven by isPro + AdMob init, not by the flag — toggling ads off in the dashboard does not hide it |
| DiscountOffer / OptionsBottomSheet / WorldCup26Badge (lib/widgets) | — | — | — | WIRED-WITH-NOTE — DiscountOffer & OptionsBottomSheet are only referenced from app_settings surfaces (Round 3 territory); WorldCup26Badge has no caller in this territory. No drama/rewards/onboarding/pricing screen depends on them |
| AsyncRefreshBuilder retry | error-state retry → parent refresh callback | — local | — | WIRED |
| ForceUpdateDialog buttons | store link / dismiss — bootstrap-owned, out of this territory | — | — | WIRED-WITH-NOTE — noted for completeness; owned by the splash/bootstrap pass |

## Dashboard (backend/public/admin/index.html)

Read-only audit (backend/dashboard edits are not this pass's territory). Every control group
was mapped to its admin endpoint in `routes.js adminHandle` (X-Admin-Token auth) and its
settings key in `backend/src/settings.js`.

| Control group | Endpoint(s) | Backend handler → data | Verdict |
|---|---|---|---|
| Sign in / Logout / Refresh stats | GET /admin/stats | aggregates over all tables | WIRED |
| Genres CRUD (save/clear/edit/delete) | GET/POST/PATCH/DELETE /admin/genres | genres | WIRED |
| Series CRUD + rankScore + cast manager | /admin/series, /admin/series/:id/cast… | series, cast_members, persons | WIRED |
| Episodes CRUD + dubs editor | /admin/episodes (+?seriesId=) | episodes, episode_dubs; videoUrl change enqueues caption jobs | WIRED |
| Home Sections CRUD + series picker | /admin/home-sections | home_sections, home_section_items | WIRED |
| Users: search/list, summary, coin adjust, VIP toggle, delete | /admin/users, /:id/summary, /:id/coins, /:id/vip, DELETE /:id | users + all user tables | WIRED |
| Rewards & Economy: check-in amounts, unlock cost, welcome bonus, ad amount/cap, tasks CRUD | PATCH /admin/settings + /admin/reward-tasks CRUD | settings (validated in settings.js), reward_tasks | WIRED |
| Engagement Lab: wheel, chests, watch-time, referrals, missions CRUD, events CRUD | PATCH /admin/settings + /admin/missions + /admin/events CRUD | settings, missions, events | WIRED |
| App Settings: maintenance, premium playback mode, welcome bonus | PATCH /admin/settings | settings.maintenance_mode / premium_playback_mode (validated enums) | WIRED |
| Feature Flags: all player_* + captions/wheel/chests/missions/referrals/ads toggles | PATCH /admin/settings → surfaced via GET /config features.* | settings (BOOL_KEYS incl. PLAYER_FLAGS) | WIRED-WITH-NOTE — every flag reaches /config and every /config feature key has a client consumer **except** `ads` (see AdBannerWidget note) |
| Visual & Theme: theme preset, accent override, confetti, haptics, player timings, auto-next seconds | PATCH /admin/settings → GET /config visual.* / player.* | settings.default_theme_preset (1–7 validated), accent_color_override (#RRGGBB validated), skip_intro_*, auto_next_countdown_seconds | WIRED — client consumes all of them (theme preset via ThemeProvider, timings via player) |
| Captions & Translation: enable, auto-generate, providers, target languages, per-episode generate, track delete, matrix refresh | PATCH /admin/settings + GET /admin/captions + POST /admin/episodes/:id/captions/generate + DELETE /admin/captions/:id | caption_tracks, caption_jobs → captions.js worker | WIRED-WITH-NOTE — demo ASR/MT path works end-to-end; real providers need API keys in the environment (documented) |
| Notifications: broadcast send + history | POST /admin/notifications/broadcast + GET /admin/notifications | notifications (fan-out to all users), broadcasts | WIRED |
| Transactions: list + paging | GET /admin/transactions?limit= | coin_transactions | WIRED |

## Backend-only surface (no client caller in this territory)

| Endpoint | Caller | Verdict |
|---|---|---|
| GET /playback/verify | CDN/reverse proxy (HMAC is the credential) | WIRED-WITH-NOTE — intentional external surface, not an orphan |
| GET /episodes/:id/captions (list form) | none — the player uses playback's `captionLanguages` + the raw /captions/:lang fetch | WIRED-WITH-NOTE — redundant but harmless; entitlement-gated list kept for API completeness |
| POST /series/:id/follow | was orphaned; now called by the new Follow action (Series detail) | GAP-FIXED — see Series detail |
| DramaService.fetchSeasons | no UI caller — detail/player derive seasons locally from the episode list | WIRED-WITH-NOTE — dead service method, no user impact; left in place (removal is cosmetic) |
| DramaService.toggleFollow | was orphaned; now wired (above) | GAP-FIXED |
| All /admin/* endpoints | admin dashboard only | WIRED — intentional admin surface (see Dashboard) |
| GET /user/orders | PurchaseHistoryScreen (round 4: also reachable from the Account hub) | **GAP-FIXED (round 4)** — see Purchase history |
| POST /webhooks/revenuecat | RevenueCat servers (round 4) | WIRED — creates orders + applies entitlements via `recordOrder` (VIP: isPro + expiry; coins: grantCoins 'purchase'). Auth: REVENUECAT_WEBHOOK_SECRET as Bearer or HMAC-SHA256 `x-webhook-signature` over the raw body; secret unset → dev-mode only, else 503 WEBHOOK_NOT_CONFIGURED. Transaction-id idempotency (UNIQUE) makes retries grant exactly once; EXPIRATION lapses VIP, CANCELLATION records only. Exempt from the maintenance gate. Suite 6 cases 501–505, 508 |
| POST /admin/orders (+ GET list) | admin/support (round 4) | WIRED — manual order through the same `recordOrder` path (provider 'manual'); X-Admin-Token enforced. Suite 6 case 507 |
| GET /shorts | Shorts tab (round 4) | WIRED — see Shorts section. Suite 6 case 509 |
| Maintenance mode (settings.maintenance_mode) | dashboard sets it; backend gates all app endpoints with 503 (except /config + the webhook) | **GAP-FIXED (round 4)** — `MaintenanceScreen` (branded, message from /config `maintenanceMessage` ← settings.maintenance_message) is routed from splash when the flag is on at launch AND pushed globally by ApiClient's latched 503-MAINTENANCE hook (`ApiClient.onMaintenance`, set in bootstrap, via `appNavigatorKey`); Retry re-fetches /config and exits (pop or restart-from-splash) only when the flag cleared, clearing the latch — no loops. Widget-tested (render, still-down retry, cleared retry proceeds) |

## Config & settings cross-check (both directions)

- Every key in GET /config (`maintenanceMode`, `premiumPlaybackMode`, `paywallDailyCap`,
  `features.*` ×23, `player.*` ×3, `visual.*` ×4, `economy.*` ×2) maps to a settings key in
  `settings.js` and is parsed by `AppConfigService` under the identical name — verified
  field-by-field. Round 4 added `features.shorts` (← settings.shorts_enabled) and the
  top-level `maintenanceMessage` (← settings.maintenance_message, parsed as
  `AppConfigService.maintenanceMessage`). `features.ads` is parsed but has no behavioural
  consumer (noted above); `economy.wheelFreeSpinsPerDay` is parsed and exposed but the
  wheel UI uses the value from GET /rewards state instead (same source setting, no drift
  risk).
- Every client-called endpoint exists in routes.js with a matching response envelope
  (`{data: …}` unwrapped by ApiClient; raw VTT is the single documented exception) — round 4
  closed the last exception (GET /user/orders now exists). `api_client.dart` gained exactly
  one behaviour in round 4: the latched global 503-MAINTENANCE hook (see the maintenance row
  above); its 401 → POST /auth/refresh → Firebase re-exchange flow is unchanged.

## Auth & session (Round 3)

Splash decision tree (splash_screen.dart `_navigateToNextScreen`): onboarding
kill-switch / not-completed branches unchanged → onboarding; completed →
`AuthService.restoreSession()` → failure routes to `/login`; success →
returning paywall-cap flow → `/pricing` or `/home`. Bootstrap no longer
creates a guest session on fresh installs (gated on an existing Firebase
user or a stored refresh token). Onboarding completion exits via
`navigateOnboardingExit()` → `/login` when session-less (GAP-FIXED, see
Onboarding section).

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Splash session restore | SplashScreen → AuthService.restoreSession → fetchMe (ApiClient 401→refresh once) | GET /auth/me, POST /auth/refresh | routes.js → users, refresh_tokens | WIRED |
| Login: email + password Sign In | LoginScreen → AuthActions.signInEmail → AuthService.signInWithEmailAndPassword → exchangeFirebaseToken | Firebase Auth + POST /auth/firebase | routes.js → users, coin_transactions (welcome bonus), refresh_tokens | WIRED |
| Login: Forgot password? | AuthActions.sendPasswordReset → AuthService.sendPasswordResetEmail | Firebase Auth (reset email) | — (Firebase-side) | WIRED-WITH-NOTE — no-op state when Firebase isn't configured for the build; error surfaces as a snackbar |
| Register: name/email/password + terms checkbox (13+ line, tappable Terms/Privacy spans → /legal/terms, /legal/privacy) | Register button disabled until checkbox + fields valid → AuthActions.registerEmail → AuthService.signUpWithEmailAndPassword | Firebase Auth + POST /auth/firebase | routes.js → users | WIRED |
| Continue with Google | AuthActions.signInGoogle → AuthService.signInWithGoogle (Firebase signInWithProvider, guest link/relink) | Firebase Auth + POST /auth/firebase (+ POST /auth/relink when upgrading a guest) | routes.js → all user tables (merge) | WIRED-WITH-NOTE — AuthService returns false for real errors as well as cancels, so the UI treats false as "cancelled" (no error banner) |
| Continue with Apple | AuthActions.signInApple → AuthService.signInWithApple (sign_in_with_apple + OAuth credential, guest link/relink) | Firebase Auth + POST /auth/firebase (+ /auth/relink) | routes.js → all user tables (merge) | WIRED (same false-semantics note as Google) |
| Continue as Guest (+ "link later" caption) | AuthActions.signInGuest → AuthService.signInAsGuest → signInAnonymously + exchange | Firebase anonymous + POST /auth/firebase | routes.js → users (isGuest) | WIRED |
| Login footer: Privacy Policy / Terms of Service | pushNamed | — | — | WIRED → Legal screens (below) |
| Log out (Profile + AppSettings) | confirm dialog → AuthService.signOutToLogin | POST /auth/logout (family revocation) + Firebase signOut | routes.js → refresh_tokens (all revoked) | WIRED |
| Session persistence | TokenStore (flutter_secure_storage) + ApiClient refresh-on-401 | POST /auth/refresh | auth.js rotateRefresh → refresh_tokens | WIRED |

## Account & settings (Round 3)

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Profile header (avatar/name/email/provider badge/VIP + expiry) | ProfileContent ← AuthService.fetchMe / UserProvider | GET /auth/me | routes.js userJson → users | WIRED (provider derived client-side from Firebase providerData, model fallback) |
| Edit profile: name + avatar picker (6 bundled assets) → Save | EditProfileScreen → AccountService.updateProfile | PATCH /auth/me | routes.js → users.name / users.image | WIRED (new endpoint, suite-5 tested) |
| My coins → transaction history (paginated, signed amounts, balanceAfter) | CoinHistoryScreen → AccountService.fetchTransactions | GET /me/transactions | routes.js → coin_transactions (caller-only) | WIRED (new endpoint, suite-5 tested) |
| Subscription row | ProfileContent → /pricing (Pro: store-managed note toast) | — (RevenueCat, see Pricing) | — | WIRED-WITH-NOTE — purchases remain RevenueCat-side (v1 row 69 caveat) |
| Link account (guests) | SignInOptionsBottomSheet / EmailAuthBottomSheet → AuthService social/email + relink | POST /auth/firebase, POST /auth/relink | routes.js → all user tables (merge) | WIRED |
| Settings: Language | LanguageSelectionBottomSheet → LocaleProvider + AccountService.updateProfile(locale) | PATCH /auth/me | routes.js → users.locale | WIRED |
| Settings: Notifications toggle | NotificationSettingsBottomSheet → OneSignal + updateProfile(notificationsEnabled) + local pref mirror | PATCH /auth/me | routes.js → users.notificationsEnabled (new column) | WIRED |
| Settings: Playback (autoplay-next switch, video-quality picker) | AppSettings → updateProfile(autoplayNext / videoQuality), optimistic + revert | PATCH /auth/me | routes.js → users.autoplayNext / users.videoQuality | WIRED (rows added this round) |
| Settings: Player tutorial replay | PlayerTutorial.requestReplay (round 1) | local pref | — | WIRED |
| Settings: Clear cache | imageCache.clear + clearLiveImages + temp-dir sweep (path_provider), freed-count toast | local | — | WIRED (added this round) |
| Settings: About | PackageInfo.fromPlatform dialog (name/version/build) | local | — | WIRED (added this round) |
| Settings: Legal rows | pushNamed('/legal') with LegalUrlLauncher fallback | — | — | WIRED |
| Delete account (AppSettings danger zone) | DeleteAccountDialog (type DELETE to enable, optional password) → AuthService.deleteAccount | DELETE /auth/account + Firebase user delete | routes.js → all user tables wiped | WIRED |

## Legal (Round 3)

Full texts live in `lib/presentation/legal/legal_texts.dart` (Privacy 2,730
words, Terms 2,597, Subscription terms 1,037) and are mirrored in
docs/PRIVACY_POLICY.md / docs/TERMS_OF_SERVICE.md for store hosting;
docs/LEGAL.md carries the store-console steps and the Play Data Safety +
Apple nutrition-label mappings.

| Control | Handler → Service | Endpoint | Backend handler → data | Verdict |
|---|---|---|---|---|
| Legal hub rows (Privacy / Terms / Subscription / Licenses) | LegalHubScreen → pushNamed LegalRoutes.* (registered in app_routes.dart) | — | — | WIRED |
| Privacy Policy screen | PrivacyPolicyScreen (scrollable, selectable full text) | — | — | WIRED |
| Terms of Service screen | TermsOfServiceScreen | — | — | WIRED |
| Subscription & Purchases screen | SubscriptionTermsScreen | — | — | WIRED |
| Licenses & About | LicensesScreen → showLicensePage + About block (version param, default 1.0.4) | — | — | WIRED |
| Entry points: Login footer + Register checkbox links | pushNamed('/legal/privacy' / '/legal/terms') | — | — | WIRED |
| Entry points: Profile "Legal" row + AppSettings legal rows | pushNamed('/legal') (launcher fallback in settings) | — | — | WIRED |
