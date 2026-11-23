# Round 5 — Luxury / UX Round

All 13 user-approved items implemented. Zero cost: code only, three free
pub.dev packages added, no paid services or keys. Backend untouched.

## Verification

- `flutter analyze` — exit 0, "No issues found!"
- `flutter test` (real tree) — **123/123** (101 baseline + 22 new)
- `flutter test` (GitHub-mirror simulation, binaries excluded) — **123/123**
- New tests: `test/round5_luxury_test.dart` (22 tests)

## New dependencies

- `wakelock_plus` ^1.2.10 — keep-screen-on
- `palette_generator` ^0.3.3+5 — poster color extraction
- `local_auth` ^2.3.0 — biometric app lock
- (`flutter_secure_storage` and `crypto` were already in the tree and are
  used for the PIN store / salted hash.)

## New shared pieces

- `lib/services/luxury_settings_service.dart` — device-local settings
  (SharedPreferences + in-memory cache): keep-screen-on (default on),
  haptics (default on), protection level (default player-only), app-lock
  switch (default off). These are per-device settings and are deliberately
  NOT synced to the backend profile.
- `lib/services/wakelock_service.dart` — gateway seam + pure gating
  decision + transition-only application.
- `lib/services/content_protection_service.dart` — `herodrama/content_protection`
  channel, iOS capture/screenshot event streams, level helpers.
- `lib/services/app_lock_service.dart` — PIN (salted SHA-256 in secure
  storage, never plaintext), 30 s resume-relock rule, arm/unlock state
  machine, `PinStore` seam for tests.
- `lib/services/double_back_guard.dart` — pure double-press window logic.
- `lib/services/poster_palette_service.dart` — palette extraction with
  per-series in-memory cache + miss cache, extractor seam for tests.
- Settings UI: new card in `app_settings.dart` (both toggles, protection
  picker, app-lock setup/change/remove flows with PIN dialogs).

## Per item

1. **Wakelock** — `WakelockService.sync()` is driven from the player tick
   listener and the Shorts page controller listener, only on real
   play/pause transitions; released on pause/end/dispose. Gated by the
   "Keep screen on while watching" settings toggle (default on).
   Files: wakelock_service, episode_player_screen, shorts_content,
   luxury_settings_service, app_settings.

2. **Immersive playback** — player `initState` switches SystemChrome to
   `immersiveSticky`; `dispose` restores edge-to-edge + the exact overlay
   style from main.dart. Tap-to-show controls unchanged (system UI stays
   hidden). Files: episode_player_screen.

3. **Content protection** — MethodChannel `herodrama/content_protection`.
   Android: `FLAG_SECURE` set/clear in MainActivity. iOS (AppDelegate):
   observes `UIScreen.capturedDidChangeNotification` +
   `userDidTakeScreenshotNotification`, forwards them to Dart; the player
   covers the video with a black privacy overlay (and pauses) while a
   capture is active, and shows a brief notice after a screenshot.
   Setting: Off / Player only (default) / Whole app, applied at startup
   (bootstrap), on player enter/exit, and immediately when changed.
   **Honest limitation:** iOS cannot block screenshots or recordings —
   it can only detect recording (→ overlay) and notify after a
   screenshot. Android protection is complete (black output).

4. **Smart header** — the existing collapsing header in MainTabs no
   longer vanishes: it collapses into a 38 px frosted (BackdropFilter
   blur) slim bar showing the current section title, with a 2 px
   Continue Watching progress hairline fed by the most recent
   in-progress watch-history entry (hidden when none — never faked).
   Tab switches reset/refresh it. Note: the header lives in the tab
   shell, so "context" = current section; pushed screens (series
   detail) cover the shell and keep their own top bars.
   Files: main_tabs.

5. **Smart back** — (a) Player wrapped in PopScope; back while
   screen-locked → hint toast, no exit; back with controls hidden →
   reveals controls first, second back exits. (b) Root: existing
   double-back-to-exit kept, now via the testable `DoubleBackGuard`
   and WITH the "Press back again to exit" toast that was missing.
   (c) Tab/scroll state already preserved by IndexedStack + the shell's
   structure (verified, no change needed). (d) Back during an in-flight
   unlock (`_unlocking`) → confirm dialog before leaving.
   Files: episode_player_screen, main_tabs, double_back_guard.

6. **PiP (Android)** — Manifest: `supportsPictureInPicture="true"` +
   `pictureInPicture` in configChanges. MainActivity: stores playback
   state/aspect from Dart (`setPlaybackState` on the existing
   `hero_drama/media_controls` channel), `enterPip` builds
   PictureInPictureParams with the aspect clamped to Android's legal
   range, `onUserLeaveHint` enters PiP when playing, and
   `onPictureInPictureModeChanged` reports back so the player does not
   background-pause inside PiP (plus a 2 s intent window after the PiP
   button tap). Dart: PiP button now Android-only.
   **Limitation:** iOS not supported (video_player rendering path) —
   no button is shown there, nothing is faked.

7. **Player screen lock** — built on the existing controls-lock: lock
   button in the top bar, `LockOverlay` swallows all gestures, unlock
   by long-press on the lock badge (with haptic), and smart-back is
   blocked while locked with a hint. Files: episode_player_screen
   (lock overlay widget already existed in widgets/player).

8. **Next-episode countdown** — end-of-episode flow now goes through
   the pure, tested `decideNextEpisodeAction`: no countdown and no
   auto-advance when the next episode is locked (the ended state
   stays; locked UX is reached manually). Countdown length remains
   the remote-config value (default 5 s). The overlay gained the next
   episode's poster thumbnail; Play/Cancel fire haptics.
   Files: episode_player_screen, widgets/player/auto_next_overlay.

9. **Smart preload** — after an episode starts, the next episode's
   controller is initialized (paused at 0) with the same
   entitlement-checked URL resolution as playback, only on
   Wi-Fi/Ethernet (unknown connectivity = allowed), never for a
   locked episode. `_load` adopts the preloaded controller on advance
   (fresh init fallback on any mismatch/failure); stale preloads are
   disposed on episode/language/quality changes and on dispose.
   Every failure is silent by design.
   Files: episode_player_screen.

10. **Dynamic poster colors** — `PosterPaletteService` extracts the
    dominant color from the series poster (CachedNetworkImageProvider),
    cached per series id; the detail hero gradient blends it into the
    page background. Any failure → the previous plain theme gradient.
    Files: poster_palette_service, series_detail_screen.

11. **Hero poster transition** — detail hero image and the player's
    poster backdrop share `Hero(tag: 'series-poster-<seriesId>')`.
    Only this detail→player pair is wired (no list posters), so no
    duplicate-tag crashes. Files: series_detail_screen,
    episode_player_screen.

12. **App lock** — `local_auth` biometrics + PIN pad fallback.
    Enabling in Settings requires creating a 4–6 digit PIN (entered
    twice), stored as salt + `sha256(salt:pin)` in
    flutter_secure_storage (verified by read-back before enabling).
    `AppLockGate` sits in MaterialApp's builder above the Navigator:
    it arms when the home shell mounts (after splash routing — the
    splash/consent/login chain is never gated) and re-locks after
    >30 s in background. "Forgot PIN" (inline confirm, since routed
    dialogs would render under the gate) signs out, wipes the PIN,
    disables the lock, and routes to /login.
    Files: app_lock_service, app_lock_gate, app_lock_screen, main,
    main_tabs (arm), app_settings, luxury_settings_service.

13. **Haptics polish** — all call sites route through `HapticsService`,
    which now honours BOTH the remote-config kill switch and the new
    local "Haptic feedback" toggle (default on): like + favorite
    (series detail), Shorts like, unlock success (celebratory
    double-tap), episode swipe (existing), player screen lock/unlock,
    countdown Play/Cancel, app-lock success/failure.
    Files: haptics_service, series_detail_screen, shorts_content,
    episode_player_screen, app_lock_screen, app_settings.

## Native changes (not compiled here — kept minimal/standard)

- `android/.../MainActivity.kt` — registers `hero_drama/media_controls`
  (brightness/volume get+set — previously Dart-only with no native
  side, so the edge-HUD silently fell back — plus `setPlaybackState`,
  `enterPip`, `pipModeChanged` reporting) and
  `herodrama/content_protection` (FLAG_SECURE). Adds
  `onUserLeaveHint` PiP entry and PiP-mode callback.
- `android/app/src/main/AndroidManifest.xml` — PiP attributes above.
- `ios/Runner/AppDelegate.swift` — registers
  `herodrama/content_protection` (setSecure no-op success, isCaptured,
  capture/screenshot observers).

All Dart channel calls fail soft (MissingPluginException → feature
silently off), so tests and other platforms are unaffected.
