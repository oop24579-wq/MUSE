# HERO DRAMA — User-Simulation Evaluation

**Method:** I lived in the product as a first-time user. Part 1 was executed live against the
real backend (fresh temp DB, dev auth, port 8931) with a scripted-but-honest journey runner
(`docs/user-journey-eval.mjs`, day-shift helper `docs/user-journey-shift-days.mjs`) — every
claim below has HTTP evidence in the run log. Part 2 is a screen-by-screen read of the Flutter
UI code. No code was changed.

**Persona:** new guest user, no account, no coins, DramaBox/ReelShort habits, phone-first,
impatient, allergic to paywalls that appear before value.

---

## Part 1 — API user journeys

### J1 · Cold start — ✅ smooth, generous, well-stocked

- `POST /auth/firebase` (guest, no email) → 200 in one call. New user starts with
  **coinBalance = 30** (welcome bonus), `isGuest=true`, level 1, and a referral code
  (`HD895F5EF57C`) already present in the register response *and* in `GET /auth/me`.
- A welcome notification is waiting: *"Welcome to HERO DRAMA!"*.
- `GET /config` → 21/21 features on, `premiumPlaybackMode=premium_content`, unlock cost 30.
- `GET /home` → 7 sections, all populated: Featured hero (3), Trending (4), Top Ranking (5),
  New Releases (4), Hot grid (4), All Dramas (8), Browse by Genre (8).
- `GET /categories` → 7 genres (Romance, Revenge, CEO/Billionaire, Urban, Fantasy, Suspense, Werewolf).

*Friction:* none blocking. The catalog *looks* deep on the home screen, but it is the same
8 series recycled through every rail (see J2 note).

### J2 · Discovery — ✅ clear pricing signals, one serious labeling bug

- Discover filters (popular/latest/ranking) return sensibly different orders; `for-you`
  returns all 8; search `"CEO"` finds the 2 CEO titles.
- Episode list for a normal series is a model of clarity — every episode carries
  `isFree / isVipOnly / coinCost / isUnlocked` *before* you tap:
  ep1–2 free, ep3–10 `coinCost=30, isUnlocked=false`.
- **🐞 The VIP trap:** for the VIP-only series *Empire of Desire*, ep1–2 come back as
  `isFree=true, isVipOnly=true, isUnlocked=true` — every signal says "free, tap to watch" —
  but `GET /episodes/.../playback` returns **403 VIP_REQUIRED**. The client's
  `EpisodeModel.isLocked` is just `!isUnlocked`, so the episode grid shows **no lock at all**
  on those episodes. This is the single most confusing moment in the whole product:
  the app promises free, then refuses at the last step.
- Series detail is thin in places: *Married to the CEO* has only **1 related title**
  (its genre has 2 series total) and a 2-person cast.

### J3 · First watch — ✅ remembered correctly, with one caveat

- Playback of free ep1 → 200, real `videoUrl`, 4 quality labels, `captionLanguages: ["ar","en","orig"]`.
- Watched ep1 to completion → Continue Watching correctly *excludes* it (completed filtered).
- Watched ep2 to 30s → Continue Watching shows `Married to the CEO ep2 @30/104s`. Resume works.
- *Caveat:* History is **one row per series**, not per episode — after ep2, the completed
  ep1 vanishes from History entirely. A binge user cannot see "what did I watch last night"
  episode-by-episode; they only ever see their latest position per series.

### J4 · The paywall moment + the earn grind — ✅ fast rescue, economy is *very* generous

Lived sequence (balances are real):

| Step | Result | Balance |
|---|---|---|
| Arrive at ep3 with welcome bonus | — | 30 |
| Unlock ep3 (30) | 200 | **0** |
| Unlock ep4 with 0 coins | **402 INSUFFICIENT_COINS** "Need 30 coins, balance is 0" | 0 |
| Playback ep4 | **403 EPISODE_LOCKED** | 0 |
| Earn #1: daily check-in | +20 | 20 |
| Earn #2: claim *daily_checkin* mission | +10 | **30 → unlock possible** |
| Unlock ep4 | 200 | 0 |
| Wheel ×3 free spins | +100, +50, +50 (very lucky — see math) | 200 |
| Wheel spin #4 (paid, 20) | won 5 → net −15 | 185 |
| Ad reward ×1 | +20 | 205 |
| Missions: like 3 series +15, share +15, watch 3 eps +20 | | 255 |
| Chest @3 episodes | +15 | 270 |
| Unlock + watch ep5, ep6, ep7 (−90) | | 180 |
| Chest @7 episodes | +30 | 210 |
| Unlock + watch ep8 (−30); 16 min watched today | | 180 |
| Mission watch-15-min +25, watch-time claim +10 | | **215** |
| Chest @12 episodes | 403 CHEST_LOCKED (only 8 watched — correct) | — |

**Time-to-unlock from 0 coins: 2 actions** (check-in → claim the check-in mission),
under a minute of tapping. Check-in alone (20) is deliberately *not quite* enough —
you are forced to discover the missions list, which is good design.

#### The unlock-economy math (seeded settings, verified against `settings.js`)

- Price of content: **30 coins/episode**, eps 3–10 locked → **240 coins clears a whole series**.
- Welcome bonus: 30 = exactly one episode. A perfect teaser amount.
- Deterministic day-1 income (no luck involved):
  check-in 20 · all 5 missions 85 · ads 5×20 = 100 · watch-time up to 100 (10 coins/10 min)
  · chests 15+30 (+50 at 12 eps, +100 at 20 eps) · one-time starter tasks 140
  (email 50, rate-app 30, invite 40, notifications 20 — all claimable on trust, see friction #8).
  **Conservative day-1 total ≈ 400+ coins** before the wheel.
- Wheel: segments [5,10,15,20,30,50,100,0], weights [20,18,15,14,12,10,6,5] →
  **EV = 22.45 coins/spin**, 3 free spins/day ≈ **+67 EV/day**. My run drew 100/50/50
  (a ~0.1% outcome) — the *variance* is the product: a lucky new user feels rich,
  an unlucky one (28% chance a spin pays ≤10… actually 43% pay ≤10) feels cheated by the same wheel.
- Paid spins cost 20 vs EV 22.45 — near-fair, but **58% of paid spins return less than they cost**.
- **Verdict on the economy: generous to a fault.** A day-1 user can earn enough to unlock an
  entire 10-episode series (240) *and* bank a surplus — I ended day 1 with 215 after clearing
  6 episodes. Coins gate almost nothing; the **only hard paywall in the product is the VIP
  series**. If the business model is "coins slow you down until you subscribe", it isn't
  slowing anyone down on day 1. (It *is* excellent for day-1 retention.)

Small honesty note: the *watch 3 episodes* mission counted ep2 after only 30 seconds —
any progress >0s registers a "watch". Generous, arguably too generous.

### J5 · Retention loop (simulated Day 2 and a missed day) — ✅ works, ❄️ unforgiving

Day boundaries were simulated by shifting all date-keyed rows back (server restarted between
"days"), because reward "today" is server-local.

- **Day 2 return:** `claimedToday=false`, streak 1 shown, wheel back to 3 free spins,
  chests/watch-time reset. Check-in paid **57** = day-2 ladder 50 + streak bonus 2 +
  level bonus 5 (I'd hit level 2 on day 1). Streak → 2. The escalating ladder (20→50)
  plus visible streak is a real reason to come back.
- **After missing one day (Day 4):** `currentStreak=0`, ladder **reset to Day 1** —
  check-in paid 25 (base 20 + level 5, streak bonus gone). One missed day erases the
  entire ladder position. No grace day, no streak-freeze, and (from the API side) no
  "your streak is about to die" nudge. DramaBox-grade retention systems usually soften
  exactly this cliff; here the punishment is total and silent.

### J6 · Captions — ⚠️ pipeline works, content is a placeholder

- Seeded ep1/ep2 of *Married to the CEO* have ready tracks: `orig (asr)`, `ar (mt)`, `en (mt)`,
  served as proper `text/vtt`. Locked ep9 correctly refuses captions (403 EPISODE_LOCKED) —
  captions follow the same entitlement as video. Good hygiene.
- Admin-triggered generation for ep5 completed and the tracks appeared for the entitled user.
- **But the content would not let a non-Chinese speaker follow anything:**
  - The `ar` track is the English text with an `[ar]` prefix. The `en` track is the same
    English with `[en]`. **Neither is a translation** (demo MT is a pass-through).
  - The `orig` text is invented template lines ("You have no idea what is coming next.",
    "Tell me the truth. All of it.") generated from the episode *description* — it is not
    dialogue from the audio (demo ASR never listens).
  - **Coverage: 8 cues ending at 0:28 of a 97-second episode** — ~71% of the runtime has
    no captions at all, because cue count scales with description length.
  - Only **2 of 80 episodes** have any captions out of the box; ep5 had none until an
    admin generated them. A normal user cannot trigger generation.
- Verdict: the *plumbing* (entitlement, VTT delivery, language list in playback) is
  production-shaped; the *subtitles themselves* are a demo prop. Do not ship the CC button
  as a feature until a real ASR/MT provider is wired — a user who turns on Arabic captions
  and gets prefixed English will trust the app less than if there were no button.

### J7 · Referral — ✅ flawless, discoverable

- My code is in `GET /auth/me` and in `GET /rewards` — no hunting required.
- Friend B (fresh guest, 30 welcome) applied my code → **B: 30 → 80 (+50)**,
  **me: 215 → 265 (+50)**. Both sides paid, exactly as configured.
- Re-applying → **409 ALREADY_REFERRED**; applying your own code → **400 INVALID_CODE**.
- Hidden constraint a user will trip on: codes only work **within 24h of sign-up**
  (403 REFERRAL_WINDOW_CLOSED after that) — nothing in the payload tells the user this
  deadline exists until it fails.

---

## Part 2 — Screen-by-screen UX review (Flutter code read)

| Screen | Score | One-line justification |
|---|---|---|
| Onboarding | **6/10** | 4 short pages with drama copy, but hero art is leftover *music-app* assets (`onboarding_ai_songs.png`, `liveRadio`/`podcasts` hero types) and there's no genre-preference pick to personalize the first home screen. |
| Home / Discover | **8/10** | Hero pager + 6 rail types + filter tabs + a Continue Watching section type; docked a point because an 8-title catalog makes every rail show the same posters. |
| Shorts tab | **5/10** | A 37-line thin wrapper over the for-you list with a bare "Nothing to recommend yet" empty state — not the full-screen vertical dopamine feed DramaBox users expect as the core loop. |
| Series detail | **8/10** | Cast, related, resume-episode pre-selected in the grid, lock vs VIP icons on tiles; loses points for the VIP "free episode" labeling bug (J2) and 1-item related rails. |
| Episode player | **7/10** | Enormous control surface (swipe episodes, double-tap seek, long-press 2×, speed, quality, CC, sleep timer, lock, auto-next, binge) — but **nothing teaches the gestures**, the quality menu is cosmetic (API returns the same URL for 1080p–360p), and the not-enough-coins path is a dead-end toast. |
| Rewards | **8/10** | Streak/level header, check-in strip, tasks, wheel, chests, missions, watch-time, referral — all present, legible, and fed by one state call; loses points for a very long scroll (wheel sits below two task lists) and unverified honor-system tasks. |
| Paywall | **5/10** | Seven polished variants and working restore — undermined by being shown on **every cold start** to non-subscribed returning users, with the **close button deliberately hidden for 2 seconds** (`custom_paywall_scaffold.dart`). Feels like a trap, not an offer. |
| My List | **7/10** | Recently Watched + Collection tabs with friendly empty states; capped by history being one-row-per-series (J3 caveat). |
| Profile | **7/10** | Coin balance header, clear VIP/Free state, guest identity handled honestly; unremarkable but no friction found. |
| Settings | **6/10** | Broad (language, theme, notifications, subscriptions, legal) but still carries music-app string leftovers (`getFreeSongs`, "free song credits", song-balance hints in `app_en.arb`). |
| Notifications | **6/10** | Screen exists and the welcome notification lands, but in practice the inbox has exactly one message ever — no episode-drop or streak-saver notifications are generated by anything I could trigger. |

### Are the Phase-2 player gestures taught anywhere? — No.

I searched the player and onboarding for hints, coach marks, tooltips, or first-run flags:
the player persists speed/caption preferences via SharedPreferences but has **no
"seen the gestures" flag and no tutorial overlay**. Swipe-for-next-episode,
double-tap seek, long-press 2×, and edge brightness/volume are all invisible
features — a user who doesn't discover them by accident will never know the
"luxury controls" exist. This is the cheapest large UX win available (friction #4).

---

## Top 10 friction points (with a concrete fix for each)

1. **VIP "free" episodes lie, then refuse.** Episode list says `isFree=true, isUnlocked=true`
   for VIP-series eps 1–2; playback 403s. *Fix:* compute `isUnlocked` server-side with the
   VIP gate for non-pro users (or make client `isLocked` include `isVipOnly && !isPro`),
   and badge those episodes "VIP" instead of "Free".
2. **Insufficient-coins is a dead end.** The player shows a toast ("Not enough coins") with
   no next step. *Fix:* in the lock overlay, add "Earn coins" (deep-link to Rewards tab)
   and show the exact shortfall ("You need 12 more — a check-in + mission covers it").
3. **Paywall on every cold start + 2s hidden close button.** Returning non-pro users are
   paywalled before seeing any content, every launch. *Fix:* frequency-cap the launch
   paywall (max once/day, never before the user's first watch of the day) and render the
   close button immediately.
4. **Luxury gestures are undiscoverable.** No tutorial, hint, or settings entry.
   *Fix:* one-time coach-mark overlay on first playback (3 gestures, dismissible,
   `player_tutorial_seen` pref) + a "Player gestures" row in Settings.
5. **Captions are a demo prop wearing a production UI.** [ar]/[en] prefixed English,
   invented dialogue, 28s of coverage, 2/80 episodes. *Fix:* wire a real ASR→MT provider
   before marketing CC; until then, hide the CC button for episodes without *real* tracks
   and add a "Captions" availability line on the series page.
6. **Quality selector is fake.** All four labels return the same URL.
   *Fix:* hide the selector until per-quality transcodes exist (or serve one real
   lower-bitrate variant); a menu that does nothing teaches users to distrust menus.
7. **One missed day = total streak/ladder annihilation, silently.** *Fix:* add a grace
   day or a streak-freeze earned weekly, and fire a "streak ends tonight" notification
   (the notifications inbox needs a reason to exist anyway).
8. **Honor-system starter tasks pay 140 coins for unverified taps** (connect email,
   rate the app, invite a friend are claimable immediately). *Fix:* verify what's
   verifiable server-side (email task completes on relink; invite completes on a real
   referral), and move the rest to smaller payouts.
9. **The coin economy can't sustain a paywall.** Day-1 earnable (≈400+ deterministic)
   exceeds the cost of clearing a full series (240). *Fix:* escalating episode prices
   (e.g., 30 → 50 → 80 deeper into a series), trim the ad cap or mission payouts, and
   add a coin sink that isn't content (early access, cosmetics) — otherwise VIP is the
   only monetization surface and coins are decoration.
10. **Template leftovers undermine credibility.** Music-app onboarding art and "free
    songs" strings in a drama app; onboarding asks nothing about taste. *Fix:* replace
    hero assets with drama posters, purge song strings from all 13 locales, and add a
    one-tap genre pick in onboarding that seeds `/for-you`.

*Honorable mentions:* paid wheel spins (20) lose money 58% of the time with no odds
disclosure; the referral 24h window is invisible until it errors; "watch an episode"
missions count after ~1 second of progress; search matches titles only.

---

## Overall verdict — would a DramaBox user stay?

**For the first session: yes.** The bones are genuinely competitive — instant guest
entry, content on screen in one call, two free episodes per series, a paywall rescue
that takes 2 taps, a wheel, streaks, levels, and a referral loop that pays both sides.
I cleared 6 episodes and banked 215 coins on day 1 without spending anything or
hitting a wall I couldn't climb. The retention *mechanics* (ladder, streak, chests,
daily missions) all demonstrably work across days.

**For the first month: not yet.** Three things would churn a real DramaBox user:
(1) the catalog is 8 series × 10 episodes of stock-footage sample videos — the rails
already repeat on day 1; (2) the every-launch paywall with a hidden close button
trains resentment faster than the generous coin economy trains loyalty; and
(3) the trust leaks — "free" VIP episodes that refuse to play, fake quality labels,
and fake Arabic captions — each one teaches the user that the app's labels don't
mean what they say. Fix the labeling honesty (frictions #1, #5, #6), soften the
paywall cadence (#3), and deepen the catalog, and this is a product a DramaBox
user would keep. The economy needs *rebalancing toward scarcity*, not more generosity.

**Overall UX score: 6.8/10** — strong systems, honest-broker problems.
