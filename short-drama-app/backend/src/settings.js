'use strict';
/**
 * Server-side settings store (table `settings`, key/value JSON).
 * Seeded from the app's defaults (firebase/remote_config_initial.json +
 * lib/services/firebase/remote_config_service.dart + reward_models.dart),
 * with env vars as the pre-store fallback. Admin edits via
 * GET/PATCH /api/v1/admin/settings take effect at runtime immediately —
 * routes read through getSetting() on every request, never a cached copy.
 */
const { all, get, run } = require('./db');

// Rebalanced 2026-11-22 (CODE_READINESS item 4): the day-1 deterministic
// earnable total across ALL sources was ~340 coins vs 240 to clear a whole
// series, making coins decorative. New ladder + trimmed missions/tasks/
// chests/wheel land day-1 at ~155 (see docs/CODE_READINESS.md for the math).
const CHECKIN_DEFAULT = [10, 20, 15, 15, 20, 10, 30]; // kDailyCheckinRewards
const intEnv = (name, dflt) => { const v = parseInt(process.env[name] || '', 10); return Number.isFinite(v) ? v : dflt; };

const PLAYER_FLAGS = [
  'player_swipe_next_episode', 'player_double_tap_seek', 'player_long_press_2x',
  'player_edge_brightness_volume', 'player_speed_menu', 'player_quality_selector',
  'player_auto_next', 'player_binge_mode', 'player_pip', 'player_scrub_chapters',
  'player_skip_intro', 'player_lock_controls', 'player_sleep_timer', 'player_share_moment',
];

const DEFAULTS = {
  maintenance_mode: false,
  premium_playback_mode: 'premium_content', // remote_config_initial.json default
  ads_enabled: true, // remote_config `is_ad_enabled` default true
  welcome_coin_bonus: intEnv('WELCOME_COIN_BONUS', 30),
  episode_unlock_coin_cost: intEnv('EPISODE_UNLOCK_COIN_COST', 30),
  ad_reward_amount: intEnv('AD_REWARD_AMOUNT', 20), // remote_config_service.dart: rewarded ad coins default 20
  ad_daily_cap: intEnv('AD_DAILY_CAP', 5),
  checkin_amounts: CHECKIN_DEFAULT,
  // ---- Phase 2: addictive coin economy ----
  wheel_enabled: true,
  wheel_segments: [2, 5, 10, 15, 20, 30, 50, 0], // rebalanced: EV/spin ~13.3 (was ~22.5)
  wheel_weights: [20, 18, 15, 14, 12, 10, 6, 5],
  wheel_free_spins_per_day: 3,
  wheel_extra_spin_cost: 20,
  chests_enabled: true,
  chest_milestones: [
    { threshold: 3, coins: 15 }, { threshold: 7, coins: 10 },
    { threshold: 12, coins: 20 }, { threshold: 20, coins: 40 },
  ],
  watch_time_enabled: true,
  watch_time_coins_per_block: 10,
  watch_time_block_minutes: 10,
  watch_time_daily_cap_coins: 100,
  missions_enabled: true,
  referrals_enabled: true,
  referral_bonus_referrer: 50,
  referral_bonus_referee: 50,
  // Anti-Sybil: max referral REWARDS one referrer can earn per (UTC) day.
  // A farm of fresh guest accounts can otherwise mint unlimited coins
  // (see security audit E6); the 24h referee window alone does not stop it.
  referral_daily_reward_cap: 10,
  checkin_level_bonus: 5, // extra coins per level above 1 on check-in
  checkin_streak_bonus: 2, // extra coins per streak day on check-in
  checkin_streak_cap: 7, // streak days counted toward the check-in bonus
  // Launch paywall frequency cap (client reads it from GET /config):
  // when true, the app shows the cold-start VIP paywall at most once per 24h.
  paywall_daily_cap: true,
  // ---- Phase 2: player feature flags ----
  ...Object.fromEntries(PLAYER_FLAGS.map((k) => [k, true])),
  skip_intro_window_seconds: 90,
  skip_intro_to_seconds: 75,
  auto_next_countdown_seconds: 5,
  // ---- Phase 2: visual ----
  default_theme_preset: 6, // int 1..7
  confetti_enabled: true,
  haptics_enabled: true,
  accent_color_override: '', // '' or #RRGGBB
  // ---- Phase 2: captions & translation ----
  captions_enabled: true,
  captions_auto_generate: true,
  caption_target_languages: ['ar', 'en'],
  asr_provider: 'demo', // demo|openai|local-whisper
  mt_provider: 'demo', // demo|deepl|google
};
const PREMIUM_MODES = ['disabled', 'premium_content', 'all_playback'];
const BOOL_KEYS = new Set([
  'maintenance_mode', 'ads_enabled', 'wheel_enabled', 'chests_enabled',
  'watch_time_enabled', 'missions_enabled', 'referrals_enabled',
  'confetti_enabled', 'haptics_enabled', 'captions_enabled', 'captions_auto_generate',
  'paywall_daily_cap',
  ...PLAYER_FLAGS,
]);
const INT_KEYS = new Set([
  'welcome_coin_bonus', 'episode_unlock_coin_cost', 'ad_reward_amount', 'ad_daily_cap',
  'wheel_free_spins_per_day', 'wheel_extra_spin_cost',
  'watch_time_coins_per_block', 'watch_time_block_minutes', 'watch_time_daily_cap_coins',
  'referral_bonus_referrer', 'referral_bonus_referee', 'referral_daily_reward_cap',
  'checkin_level_bonus', 'checkin_streak_bonus', 'checkin_streak_cap',
  'skip_intro_window_seconds', 'skip_intro_to_seconds', 'auto_next_countdown_seconds',
]);

function ensureSettings() {
  for (const [k, v] of Object.entries(DEFAULTS)) {
    run('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)', k, JSON.stringify(v));
  }
}
ensureSettings();

function getSettings() {
  const out = { ...DEFAULTS };
  for (const row of all('SELECT key, value FROM settings')) {
    // hasOwn, NOT `in`: a legacy 'constructor' row would otherwise shadow
    // Object.prototype.constructor on the returned settings object.
    if (Object.hasOwn(out, row.key)) { try { out[row.key] = JSON.parse(row.value); } catch { /* keep default */ } }
  }
  return out;
}
function getSetting(key) { return getSettings()[key]; }

/** Validate + apply a partial patch. Returns {settings} or {error}. */
function updateSettings(patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch)) return { error: 'Body must be an object' };
  const clean = {};
  for (const [k, v] of Object.entries(patch)) {
    // hasOwn, NOT `in`: `'__proto__' in {}` and `'constructor' in {}` are
    // true via the prototype chain, which let inherited keys into the store.
    if (!Object.hasOwn(DEFAULTS, k)) return { error: `Unknown setting: ${k}` };
    if (BOOL_KEYS.has(k)) {
      if (typeof v !== 'boolean') return { error: `${k} must be a boolean` };
      clean[k] = v;
    } else if (k === 'premium_playback_mode') {
      if (!PREMIUM_MODES.includes(v)) return { error: `premium_playback_mode must be one of ${PREMIUM_MODES.join('|')}` };
      clean[k] = v;
    } else if (k === 'asr_provider') {
      if (!['demo', 'openai', 'local-whisper'].includes(v)) return { error: 'asr_provider must be one of demo|openai|local-whisper' };
      clean[k] = v;
    } else if (k === 'mt_provider') {
      if (!['demo', 'deepl', 'google'].includes(v)) return { error: 'mt_provider must be one of demo|deepl|google' };
      clean[k] = v;
    } else if (k === 'checkin_amounts') {
      if (!Array.isArray(v) || v.length !== 7 || v.some((n) => !Number.isInteger(n) || n < 0 || n > 1e9)) return { error: 'checkin_amounts must be an array of 7 non-negative integers (each <= 1e9)' };
      clean[k] = v;
    } else if (k === 'wheel_segments' || k === 'wheel_weights') {
      if (!Array.isArray(v) || !v.length || v.some((n) => !Number.isInteger(n) || n < 0 || n > 1e9)) return { error: `${k} must be a non-empty array of non-negative integers (each <= 1e9)` };
      clean[k] = v;
    } else if (k === 'chest_milestones') {
      const bad = !Array.isArray(v) || v.some((ms) => !ms || typeof ms !== 'object' || !Number.isInteger(ms.threshold) || ms.threshold <= 0 || !Number.isInteger(ms.coins) || ms.coins < 0);
      if (bad) return { error: 'chest_milestones must be an array of {threshold: positive int, coins: non-negative int}' };
      const thresholds = v.map((ms) => ms.threshold);
      if (new Set(thresholds).size !== thresholds.length) return { error: 'chest_milestones thresholds must be unique (duplicate thresholds make chests unclaimable)' };
      clean[k] = v.map((ms) => ({ threshold: ms.threshold, coins: ms.coins }));
    } else if (k === 'watch_time_block_minutes') {
      const n = Number(v);
      if (!Number.isInteger(n) || n < 1 || n > 1e9) return { error: 'watch_time_block_minutes must be a positive integer (1..1e9)' };
      clean[k] = n;
    } else if (k === 'caption_target_languages') {
      // Capped + shaped: an unbounded list would auto-generate that many
      // caption tracks (and MT calls) per episode (see security audit C6).
      const LANG = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})?$/;
      if (!Array.isArray(v) || v.length > 10 || v.some((s) => typeof s !== 'string' || !s || (s !== 'orig' && !LANG.test(s)))) return { error: 'caption_target_languages must be an array of at most 10 language codes' };
      clean[k] = v;
    } else if (k === 'default_theme_preset') {
      const n = Number(v);
      if (!Number.isInteger(n) || n < 1 || n > 7) return { error: 'default_theme_preset must be an integer 1..7' };
      clean[k] = n;
    } else if (k === 'accent_color_override') {
      if (typeof v !== 'string' || (v !== '' && !/^#[0-9a-fA-F]{6}$/.test(v))) return { error: "accent_color_override must be '' or #RRGGBB" };
      clean[k] = v;
    } else if (INT_KEYS.has(k)) {
      const n = Number(v);
      // 1e20 etc. are "integers" to Number.isInteger but overflow SQLite
      // INTEGER storage and break coin math — cap every admin int at 1e9.
      if (!Number.isInteger(n) || n < 0 || n > 1e9) return { error: `${k} must be a non-negative integer (<= 1e9)` };
      clean[k] = n;
    } else { // numeric settings (fallback)
      const n = Number(v);
      if (!Number.isInteger(n) || n < 0 || n > 1e9) return { error: `${k} must be a non-negative integer (<= 1e9)` };
      clean[k] = n;
    }
  }
  // Cross-field validation: wheel geometry must stay consistent with the
  // effective (patched-or-current) counterpart, or the spin silently degrades
  // to uniform random.
  const effective = { ...getSettings(), ...clean };
  if (Array.isArray(effective.wheel_segments) && Array.isArray(effective.wheel_weights)) {
    if (effective.wheel_segments.length !== effective.wheel_weights.length)
      return { error: `wheel_weights length (${effective.wheel_weights.length}) must equal wheel_segments length (${effective.wheel_segments.length})` };
    if (effective.wheel_weights.reduce((a, b) => a + b, 0) <= 0)
      return { error: 'wheel_weights must sum to more than 0' };
  }
  for (const [k, v] of Object.entries(clean)) {
    run('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', k, JSON.stringify(v));
  }
  return { settings: getSettings() };
}

module.exports = { DEFAULTS, PREMIUM_MODES, PLAYER_FLAGS, ensureSettings, getSettings, getSetting, updateSettings };
