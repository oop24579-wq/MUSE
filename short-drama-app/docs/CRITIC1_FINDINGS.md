# CRITIC #1 — Flutter App Findings

Adversarial logic review of `short-drama-mobile/lib/` (player, rewards,
detail, services, providers). Each CONFIRMED entry was fixed minimally in
the same pass. SUSPECT entries need Dart/device execution to confirm and
were deliberately NOT edited speculatively.

## Confirmed & fixed

| # | Sev | Location | Failure scenario | Fix |
|---|-----|----------|------------------|-----|
| 1 | MAJOR | `presentation/drama/episode_player_screen.dart` `_load()`/`_initController()` | User swipes to the next episode while the previous episode's controller is still initializing → the stale controller is disposed mid-init, its `catch` sets `_locked = true`, and the lock overlay appears over the new, playable episode; stale `_load()` also overwrote `_playback`/captions with the old episode's data. | Load-generation counter (`_loadGen`) checked after every await; `_initController` bails silently when `!identical(_controller, controller)` (post-init check + catch guard); `_playback`/`_captionCues` cleared at load start. |
| 2 | MAJOR | `episode_player_screen.dart` `_initController()` catch + `_load()` null-URL branch | A playable episode whose stream merely fails to load (network hiccup, bad URL) showed the **coin-unlock overlay** ("Spend N coins") — tapping Unlock could charge coins for an episode the user already owns. | New `_loadFailed` state, distinct from `_locked`: failures show a "Couldn't load this episode — Retry / Back" overlay; controls and skip-intro are gated on `!_loadFailed`. |
| 3 | MAJOR | `episode_player_screen.dart` `_record()` vs `_onTick()`/`_goToEpisode()`/`dispose()` | At episode end, `_onTick` posts `completed=true`, then the switch/dispose progress post overwrites it with `completed=false` (server upsert takes the flag verbatim) → finished episodes resurrect in Continue Watching and lose their watched checkmarks in the episode sheet. | `_record()` now sends `completed: completed \|\| _endHandled`, so once the end handler fired for an episode, later records for it stay completed. |
| 4 | MAJOR | `episode_player_screen.dart` `_handleUnlock()` | Lock overlay stays visible during the unlock network call; a double-tap fired two unlock POSTs (double coin charge) or stacked two paywalls. | `_unlocking` in-flight guard with try/finally around the whole handler. |
| 5 | MEDIUM | `episode_player_screen.dart` `_showEpisodeSheet()` My List button | Button state was a sheet-local `bool inList = false`, never read from the server: it always claimed "not in list", the first tap re-added a series already in My List, and removal from the sheet was impossible; failures also showed a success toast. | State field `_inMyList` loaded in `initState` from `fetchSeriesDetail().isFavorite`; toggle rolls back on a failed add (the distinguishable case), invalidates `myListProvider`, error toast on failure. |
| 6 | MEDIUM | `presentation/drama/series_detail_screen.dart` favorite action | Optimistic `_favOverride` was never rolled back and a success toast showed even when `toggleFavorite` failed (unlike `_toggleLike`, which reverts correctly). | Capture the result; on a failed add, restore `_favOverride = isFav` and show an error toast instead of success. |
| 7 | MEDIUM | `presentation/drama/widgets/streak_level_header.dart` level ring | Ring used raw `xp / nextLevelXp`; backend thresholds are cumulative (level L starts at `100·(L−1)²`, `nextLevelXp = 100·L²` — verified in `backend/src/routes.js`), so the ring showed 25% the moment level 2 was reached. `RewardsState.levelProgress` already had the correct math; the header didn't use it. | Ring now computes within-level progress with the same floor/span formula as `RewardsState.levelProgress`. |
| 8 | MEDIUM | `episode_player_screen.dart` `_applyCaptionLang()` | Caption VTT fetch for episode A landing after a switch to episode B overwrote B's cues with A's dialogue. | Capture `epId` before the await; drop the result if `_current.id != epId`. |
| 9 | MINOR (latent crash) | `episode_player_screen.dart` `initState`/`build`/`dispose` | Opening the player with an empty episode list crashed: `startIndex.clamp(0, -1)` throws and `_current` RangeErrors on every build (current callers guard, but `openPlayer` is a public entry point). | Empty list clamps safely, renders a "No episodes available" state with a Back button, `_load()` and `dispose()`'s `_record()` are guarded. |
| 10 | MEDIUM (UX dead end) | `episode_player_screen.dart` unlock failure path | `INSUFFICIENT_COINS` (HTTP 402) produced only a "Not enough coins" toast — no shortfall, no next step (user-simulation finding #2). | Dialog shows the exact shortfall (episode cost − `UserProvider` balance; server message "Need N coins, balance is B" as fallback) with an **Earn coins** action that pops to the shell and switches to the Rewards tab via the new `core/tab_router.dart` bridge (registered by `MainTabs`). |

## Verified clean (checked, no bug)

- **Wheel geometry** (`widgets/wheel_widget.dart`): painter starts segment 0 at −90° clockwise; final rotation ≡ −(i+0.5)·seg (mod 2π) + jitter — lands on the server-returned segment for every segment count. Spin has an in-flight guard and TickerCanceled handling.
- **Config flag keys**: every `feature('…')` key used in the player/rewards (`swipe_next_episode`, `double_tap_seek`, `long_press_2x`, `edge_brightness_volume`, `speed_menu`, `quality_selector`, `auto_next`, `binge_mode`, `pip`, `scrub_chapters`, `skip_intro`, `lock_controls`, `sleep_timer`, `share_moment`, `captions`, `wheel`, `chests`, `missions`, `referrals`, `watch_time`) matches the backend `/config` payload keys exactly; defaults are ON when `/config` fails, as specified.
- **WebVTT parser** (`widgets/player/caption_overlay.dart`): handles `HH:MM:SS.mmm` and `MM:SS.mmm`, cue identifiers, NOTE blocks, `\r\n`, multi-line text, tag stripping; cues missing an end time are dropped safely.
- **Claim buttons**: chest, mission, watch-time, starter-task, series-milestone and ad-bonus buttons all carry `_busy` double-submit guards.
- **Paywall timers** (paywall_4/5, custom scaffold, discount offer): all `Timer.periodic`/one-shot timers are cancelled in `dispose`.
- **RevenueCat** `.first` uses are all behind `isNotEmpty`/`current != null` guards; **Discover hero pager** disposes its `PageController` and guards the empty list.

## Suspects (not edited — need execution/device to confirm)

| # | Location | Suspicion |
|---|----------|-----------|
| S1 | `episode_player_screen.dart` `_onTick()` | `setState(() {})` on every controller tick rebuilds the whole player subtree several times per second. Needed today for scrubber/captions, but a perf risk on low-end devices; fixing means splitting tick-driven widgets (ValueListenableBuilder), a redesign rather than a minimal edit. |
| S2 | `widgets/player/lock_overlay.dart` | The outer full-screen `GestureDetector` registers a long-press recognizer with only an (empty) `onLongPressStart`; arena resolution against the inner unlock button's `onLongPress` depends on hit-test registration order. Expected to resolve to the inner button, but if the outer recognizer ever wins, the unlock long-press is silently swallowed. Verify on device. |
| S3 | `series_detail_screen.dart` `_playButton` | `resumeEpisodeNumber` is fetched and used to highlight a tile, but the hero Play button always opens the player at episode 1 (startIndex 0) instead of the resume episode. Looks like a wiring miss; not edited because multi-season series repeat episode numbers, so the correct target index is ambiguous without a season in the resume payload. |
| S4 | `series_detail_screen.dart` `_episodesSection` | Episode tiles open the player with the **season-filtered** list, so swipe/auto-next stay inside one season and the player's sheet header "Total N Episodes" counts only that season. Internally consistent (indices match), but may not be the intended product behaviour. |
| S5 | `episode_player_screen.dart` `_loadHistory()` | Watched checkmarks / resume positions are built from `fetchWatchHistory`, but the API returns **one history row per series** (latest episode only), so checkmarks can only ever appear for the most recent episode of a series. Client logic is written as if rows were per-episode; needs a per-episode history endpoint (backend) to truly fix. |
| S6 | `episode_player_screen.dart` `_expireSleepTimer()` | The fade-out drives whatever `_controller` is current when the timer expires; switching episode mid-fade fades/pauses the new episode, and the restore sets volume 1.0 rather than the user's edge-HUD volume. Narrow race, cosmetic impact. |
| S7 | **UX — gesture discoverability** (user-simulation finding #4) | The Phase-2 player gestures (swipe for next/prev episode, double-tap ±10s, long-press 2×, edge brightness/volume drags) have **zero teaching**: no coach marks, no first-run hint, no Settings entry. Users who aren't told will never find them. Recommended fix (not built — larger feature): one-time coach-mark overlay on first playback (3 gestures, dismissible, `player_tutorial_seen` SharedPreferences flag) plus a "Player gestures" row in Settings. Flagged here for the final report / product decision. |

## Static audit

Re-run after all edits (imports resolve + brace/paren/bracket balance with
a string/comment-aware scanner): see the tail of this file's companion run
output in the session report — 0 unresolved `package:drama_now`/relative
imports, 0 unbalanced files.
