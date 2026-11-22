'use strict';
/**
 * Server-side settings store (table `settings`, key/value JSON).
 * Seeded from the app's defaults (firebase/remote_config_initial.json +
 * lib/services/firebase/remote_config_service.dart + reward_models.dart),
 * with env vars as the pre-store fallback. Admin edits via
 * GET/PATCH /api/v1/admin/settings take effect at runtime immediately —
 * routes read through getSetting() on every request, never a cached copy.
 */
const { get, run } = require('./db');

const CHECKIN_DEFAULT = [20, 50, 35, 30, 35, 20, 50]; // kDailyCheckinRewards
const intEnv = (name, dflt) => { const v = parseInt(process.env[name] || '', 10); return Number.isFinite(v) ? v : dflt; };

const DEFAULTS = {
  maintenance_mode: false,
  premium_playback_mode: 'premium_content', // remote_config_initial.json default
  ads_enabled: true, // remote_config `is_ad_enabled` default true
  welcome_coin_bonus: intEnv('WELCOME_COIN_BONUS', 30),
  episode_unlock_coin_cost: intEnv('EPISODE_UNLOCK_COIN_COST', 30),
  ad_reward_amount: intEnv('AD_REWARD_AMOUNT', 20), // remote_config_service.dart: rewarded ad coins default 20
  ad_daily_cap: intEnv('AD_DAILY_CAP', 5),
  checkin_amounts: CHECKIN_DEFAULT,
};
const PREMIUM_MODES = ['disabled', 'premium_content', 'all_playback'];

function ensureSettings() {
  for (const [k, v] of Object.entries(DEFAULTS)) {
    run('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)', k, JSON.stringify(v));
  }
}
ensureSettings();

function getSettings() {
  const out = { ...DEFAULTS };
  for (const k of Object.keys(DEFAULTS)) {
    const row = get('SELECT value FROM settings WHERE key=?', k);
    if (row) { try { out[k] = JSON.parse(row.value); } catch { /* keep default */ } }
  }
  return out;
}
function getSetting(key) { return getSettings()[key]; }

/** Validate + apply a partial patch. Returns {settings} or {error}. */
function updateSettings(patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch)) return { error: 'Body must be an object' };
  const clean = {};
  for (const [k, v] of Object.entries(patch)) {
    if (!(k in DEFAULTS)) return { error: `Unknown setting: ${k}` };
    if (k === 'maintenance_mode' || k === 'ads_enabled') {
      if (typeof v !== 'boolean') return { error: `${k} must be a boolean` };
      clean[k] = v;
    } else if (k === 'premium_playback_mode') {
      if (!PREMIUM_MODES.includes(v)) return { error: `premium_playback_mode must be one of ${PREMIUM_MODES.join('|')}` };
      clean[k] = v;
    } else if (k === 'checkin_amounts') {
      if (!Array.isArray(v) || v.length !== 7 || v.some((n) => !Number.isInteger(n) || n < 0)) return { error: 'checkin_amounts must be an array of 7 non-negative integers' };
      clean[k] = v;
    } else { // numeric settings
      const n = Number(v);
      if (!Number.isInteger(n) || n < 0) return { error: `${k} must be a non-negative integer` };
      clean[k] = n;
    }
  }
  for (const [k, v] of Object.entries(clean)) {
    run('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', k, JSON.stringify(v));
  }
  return { settings: getSettings() };
}

module.exports = { DEFAULTS, PREMIUM_MODES, ensureSettings, getSettings, getSetting, updateSettings };
