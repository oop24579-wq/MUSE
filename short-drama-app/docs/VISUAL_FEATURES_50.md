# HERO DRAMA — 50 Visual / UX Features

Status key:
- **IMPLEMENTED** — real working code (Phase 2, or pre-existing and verified in the Phase 1/2 audits).
- **CONFIG** — behaviour is driven end-to-end by the dashboard → settings store → `GET /api/v1/config` → app.
- **SCAFFOLD** — a surface/field/widget exists and is wired, but the final polish or native side is not done. Marked honestly.

Counts for the 50 numbered items: **44 IMPLEMENTED · 1 CONFIG · 5 SCAFFOLD**
(plus two cross-cutting configuration surfaces listed after the tables:
dashboard-selected theme preset = CONFIG, accent-colour override = SCAFFOLD).

## Player

| # | Feature | Where | Status |
|---|---------|-------|--------|
| 1 | Vertical swipe up/down for next/previous episode, with haptic + centred "EP N · title" chip | `episode_player_screen.dart` | IMPLEMENTED |
| 2 | Double-tap seek −10s/+10s with animated ripple and seconds label | `widgets/player/seek_ripple.dart` | IMPLEMENTED |
| 3 | Long-press anywhere = 2× speed while held, "2×" badge, release restores user speed | `episode_player_screen.dart` | IMPLEMENTED |
| 4 | Edge drag controls: right edge brightness, left edge volume, on-screen HUD bars with % (platform channel guarded; brightness falls back to a dim overlay, volume to player volume — native channel implementation still needed for system-level control) | `widgets/player/edge_hud.dart`, `widgets/player/player_platform_service.dart` | IMPLEMENTED |
| 5 | Playback speed menu (0.5/0.75/1/1.25/1.5/2), remembered per user | `episode_player_screen.dart` | IMPLEMENTED |
| 6 | Quality selector chip + sheet (Auto/1080p/720p/480p/360p from the playback response), switches URL keeping position | `episode_player_screen.dart`, `services/drama/playback_service.dart` | IMPLEMENTED |
| 7 | Auto-next episode with animated countdown ring, Next button, cancel | `widgets/player/auto_next_overlay.dart` | IMPLEMENTED |
| 8 | Binge mode: auto-plays next episodes in place, skips the countdown and detail sheet | `episode_player_screen.dart` | IMPLEMENTED |
| 9 | Picture-in-Picture entry point (guarded platform call, graceful "not supported" toast; no native PiP implementation yet) | `widgets/player/player_platform_service.dart` | SCAFFOLD |
| 10 | Progress bar with buffered indicator, drag scrubbing with time tooltip, chapter ticks at 25/50/75% | `widgets/player/chapter_progress_bar.dart` | IMPLEMENTED |
| 11 | "Skip Intro" button in the opening window; window and skip-to seconds come from the dashboard | `episode_player_screen.dart` + `/config` | IMPLEMENTED |
| 12 | Lock-controls overlay (child lock): all gestures disabled, long-press to unlock | `widgets/player/lock_overlay.dart` | IMPLEMENTED |
| 13 | Sleep timer (15/30/60 min / end of episode) with remaining-time chip and volume fade-out | `episode_player_screen.dart` | IMPLEMENTED |
| 14 | Share-the-moment button: shares series + episode + current timestamp | `episode_player_screen.dart` | IMPLEMENTED |
| 15 | Resume-from-last-position banner with Restart option | `episode_player_screen.dart` | IMPLEMENTED |
| 16 | Episode sheet polish: current-episode highlight + equalizer icon, watched checkmarks, locked badges with coin cost | `episode_player_screen.dart` | IMPLEMENTED |
| 17 | Subtitle/CC button with language sheet (Off / Original / العربية / English / + any ready language) | `episode_player_screen.dart` | IMPLEMENTED |
| 18 | Caption overlay: bottom pill, pure-Dart WebVTT parser, Small/Medium/Large font sizes, language + size remembered globally | `widgets/player/caption_overlay.dart` | IMPLEMENTED |
| 19 | Buffering state with branded loading indicator over the video | `episode_player_screen.dart` (pre-existing player states, kept through the Phase 2 rewrite) | IMPLEMENTED |
| 20 | Background-audio continue toggle (player no longer auto-pauses on app inactive when ON) | `episode_player_screen.dart` | IMPLEMENTED |

## Rewards & engagement visuals

| # | Feature | Where | Status |
|---|---------|-------|--------|
| 21 | Wheel-of-fortune: painted segments, 4s ease-out spin that lands exactly on the server-decided segment | `widgets/wheel_widget.dart` | IMPLEMENTED |
| 22 | Treasure chests row: locked / pulsing-glow unlocked / claimed states with claim celebration | `widgets/chest_row.dart` | IMPLEMENTED |
| 23 | Daily missions with animated progress bars and claim states | `widgets/missions_section.dart` | IMPLEMENTED |
| 24 | Streak flame + level ring (XP progress ring with level number) header | `widgets/streak_level_header.dart` | IMPLEMENTED |
| 25 | Coin balance count-up animation when the balance changes | `widgets/coin_balance_header.dart` | IMPLEMENTED |
| 26 | Confetti burst (40-particle pure-Flutter painter) on check-in, wheel wins, chest/mission/task claims and referral bonus | `lib/widgets/confetti_burst.dart` | IMPLEMENTED |
| 27 | Haptic feedback service (light/medium/heavy/success), globally gated by config | `lib/services/haptics_service.dart` | IMPLEMENTED |
| 28 | Limited-time event banner chip ("Event — rewards ×2!") on the rewards screen | `rewards_content.dart` | IMPLEMENTED |
| 29 | Referral card: copyable code chip + apply-a-code field | `rewards_content.dart` | IMPLEMENTED |
| 30 | Watch-time card: minutes today, next-block progress bar, claimable coins | `rewards_content.dart` | IMPLEMENTED |
| 31 | 7-day check-in strip with per-day coin amounts from the server | `widgets/daily_checkin_strip.dart` (pre-existing, server-driven amounts) | IMPLEMENTED |
| 32 | Reward task tiles with server progress/target and claim buttons | `widgets/reward_task_tile.dart`, `widgets/series_reward_tile.dart` (pre-existing) | IMPLEMENTED |

## Home, catalog & profile visuals

| # | Feature | Where | Status |
|---|---------|-------|--------|
| 33 | Featured hero pager cards on Home | `widgets/featured_hero_card.dart` (pre-existing) | IMPLEMENTED |
| 34 | Shimmer skeleton loading on series detail and lists | `series_detail_screen.dart` and list widgets (pre-existing) | IMPLEMENTED |
| 35 | Poster ribbon badges (NEW / HOT / VIP / EXCLUSIVE) | `widgets/series_badge.dart` (pre-existing) | IMPLEMENTED |
| 36 | Dub-language flags on covers | `widgets/lang_flags.dart` (pre-existing) | IMPLEMENTED |
| 37 | Category gradient grid with per-genre icons | `widgets/genre_grid.dart` (pre-existing) | IMPLEMENTED |
| 38 | Continue-watching cards with progress bars | `widgets/continue_watching_card.dart` (pre-existing) | IMPLEMENTED |
| 39 | Ranking list with gold/silver/bronze-style top ranks | `widgets/ranking_list_tile.dart` (pre-existing) | IMPLEMENTED |
| 40 | Ranking movement arrows (▲▼): server now sends `rankDelta` in `/discover?filter=ranking`; the tile does not render the arrows yet | backend `routes.js` (field live) / `widgets/ranking_list_tile.dart` (render pending) | SCAFFOLD |
| 41 | "Because you watched" rail: programmable today as a dashboard Home Section (vertical_grid) with hand-picked series | Dashboard → Home Sections | CONFIG |
| 42 | Related-series rail on the detail screen (API-driven) | `series_detail_screen.dart` (pre-existing) | IMPLEMENTED |
| 43 | Cast row with avatar images on the detail screen | `series_detail_screen.dart` (pre-existing, API-driven cast) | IMPLEMENTED |
| 44 | Series detail collapsing hero with parallax | `series_detail_screen.dart` (hero exists; parallax collapse not reworked in Phase 2) | SCAFFOLD |
| 45 | Poster 3D tilt on scroll | — (not built) | SCAFFOLD |
| 46 | Dynamic accent colour extracted from the poster palette | — (not built; no new deps allowed) | SCAFFOLD |
| 47 | Empty-state illustration for My List / library | `assets/images/library_empty_icon.png` + `my_list_content.dart` (pre-existing) | IMPLEMENTED |
| 48 | Splash screen with brand logo | `splash_screen.dart` (pre-existing) | IMPLEMENTED |
| 49 | Onboarding hero variants (carousel / split / waveform art) | `presentation/onboarding/` (pre-existing) | IMPLEMENTED |
| 50 | Animated paywall collage + plan cards | `widgets/animated_paywall_collage.dart` (pre-existing) | IMPLEMENTED |

## Dashboard-driven visual configuration (cross-cutting)

These are counted inside the items above but worth listing as one control surface: every
player feature (items 1–18) has an individual **Feature Flags** toggle; the theme preset
(7 palettes, itemised below), confetti on/off, haptics on/off, countdown seconds and
skip-intro timings are all editable in **Visual & Theme**; the accent-colour override is
exposed in the dashboard and `/config` but the app does not apply it yet (SCAFFOLD —
the two `ColorScheme`s are built deep inside the preset palettes, so there is no single
safe override point).

- Default theme preset (1–7) selected in the dashboard, applied by the app at startup
  via `/config` → `ThemeProvider` — **CONFIG** (this is the delivery mechanism behind
  the pre-existing 7-preset system in `lib/theme/app_theme.dart`).
