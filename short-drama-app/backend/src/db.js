'use strict';
/**
 * Storage: node:sqlite (DatabaseSync) — verified loading on Node v24 in this VM.
 * Fallback note: if node:sqlite is unavailable, set STORAGE=json (not implemented as
 * primary path because sqlite works here); DB file lives at DB_PATH (default data/app.db).
 */
const fs = require('node:fs');
const path = require('node:path');
let DatabaseSync;
try { ({ DatabaseSync } = require('node:sqlite')); }
catch (e) { throw new Error('node:sqlite unavailable on this Node build: ' + e.message); }

const DB_PATH = process.env.DB_PATH
  ? path.resolve(process.cwd(), process.env.DB_PATH)
  : path.join(__dirname, '..', 'data', 'app.db');
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;');
db.exec(`
CREATE TABLE IF NOT EXISTS users(
  id TEXT PRIMARY KEY, firebaseUid TEXT UNIQUE NOT NULL, email TEXT, name TEXT, image TEXT,
  deviceId TEXT, isGuest INTEGER DEFAULT 1, isPro INTEGER DEFAULT 0, coinBalance INTEGER DEFAULT 0,
  autoplayNext INTEGER DEFAULT 1, videoQuality TEXT DEFAULT 'auto', subscriptionExpirationDate TEXT,
  platform TEXT, appVersion TEXT, locale TEXT, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL, linkedAt TEXT);
CREATE TABLE IF NOT EXISTS refresh_tokens(
  id TEXT PRIMARY KEY, userId TEXT NOT NULL, tokenHash TEXT NOT NULL, expiresAt TEXT NOT NULL,
  revoked INTEGER DEFAULT 0, createdAt TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS user_devices(
  userId TEXT NOT NULL, deviceId TEXT NOT NULL, platform TEXT, appVersion TEXT, locale TEXT,
  lastSeenAt TEXT NOT NULL, PRIMARY KEY(userId, deviceId));
CREATE TABLE IF NOT EXISTS genres(
  id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL, description TEXT,
  iconUrl TEXT, colorHex TEXT, sortOrder INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS series(
  id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, title TEXT NOT NULL, synopsis TEXT, tagline TEXT,
  coverImageUrl TEXT, heroImageUrl TEXT, trailerUrl TEXT, gradientStart TEXT, gradientEnd TEXT,
  genreId TEXT, releaseYear INTEGER, totalEpisodes INTEGER DEFAULT 0, totalSeasons INTEGER DEFAULT 1,
  language TEXT DEFAULT 'en', dubLanguages TEXT DEFAULT '[]',
  isVipOnly INTEGER DEFAULT 0, isExclusive INTEGER DEFAULT 0, isNew INTEGER DEFAULT 0, isHot INTEGER DEFAULT 0,
  isCompleted INTEGER DEFAULT 1, isDubbed INTEGER DEFAULT 0, viewCount INTEGER DEFAULT 0, likeCount INTEGER DEFAULT 0,
  ratingAvg REAL DEFAULT 0, ratingCount INTEGER DEFAULT 0, rankScore INTEGER DEFAULT 0,
  isFeatured INTEGER DEFAULT 0, sortOrder INTEGER DEFAULT 0, tags TEXT DEFAULT '[]', createdAt TEXT);
CREATE TABLE IF NOT EXISTS seasons(
  id TEXT PRIMARY KEY, seriesId TEXT NOT NULL, seasonNumber INTEGER DEFAULT 1, title TEXT, episodeCount INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS episodes(
  id TEXT PRIMARY KEY, seriesId TEXT NOT NULL, seasonId TEXT, seasonNumber INTEGER DEFAULT 1,
  episodeNumber INTEGER NOT NULL, title TEXT, description TEXT, videoUrl TEXT, thumbnailUrl TEXT,
  durationSeconds INTEGER, isFree INTEGER DEFAULT 1, coinCost INTEGER DEFAULT 0, isVipOnly INTEGER DEFAULT 0,
  publishedAt TEXT, viewCount INTEGER DEFAULT 0, sortOrder INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS episode_dubs(
  id TEXT PRIMARY KEY, episodeId TEXT NOT NULL, lang TEXT NOT NULL, videoUrl TEXT NOT NULL, UNIQUE(episodeId, lang));
CREATE TABLE IF NOT EXISTS persons(
  id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL, gender TEXT, imageUrl TEXT);
CREATE TABLE IF NOT EXISTS cast_members(
  id TEXT PRIMARY KEY, seriesId TEXT NOT NULL, personId TEXT NOT NULL, characterName TEXT, sortOrder INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS home_sections(
  id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, title TEXT NOT NULL, subtitle TEXT,
  sectionType TEXT NOT NULL, sortOrder INTEGER DEFAULT 0, locale TEXT DEFAULT 'en');
CREATE TABLE IF NOT EXISTS home_section_items(
  sectionId TEXT NOT NULL, seriesId TEXT NOT NULL, sortOrder INTEGER DEFAULT 0, PRIMARY KEY(sectionId, seriesId));
CREATE TABLE IF NOT EXISTS user_series(
  userId TEXT NOT NULL, seriesId TEXT NOT NULL, liked INTEGER DEFAULT 0, favorite INTEGER DEFAULT 0,
  following INTEGER DEFAULT 0, PRIMARY KEY(userId, seriesId));
CREATE TABLE IF NOT EXISTS watch_history(
  userId TEXT NOT NULL, seriesId TEXT NOT NULL, episodeId TEXT, episodeNumber INTEGER DEFAULT 1,
  positionSeconds INTEGER DEFAULT 0, durationSeconds INTEGER DEFAULT 0, completed INTEGER DEFAULT 0,
  watchedAt TEXT NOT NULL, PRIMARY KEY(userId, seriesId));
CREATE TABLE IF NOT EXISTS episode_unlocks(
  userId TEXT NOT NULL, episodeId TEXT NOT NULL, createdAt TEXT NOT NULL, PRIMARY KEY(userId, episodeId));
CREATE TABLE IF NOT EXISTS coin_transactions(
  id TEXT PRIMARY KEY, userId TEXT NOT NULL, amount INTEGER NOT NULL, type TEXT NOT NULL,
  refId TEXT, balanceAfter INTEGER, createdAt TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS checkins(
  userId TEXT NOT NULL, claimDate TEXT NOT NULL, dayIndex INTEGER NOT NULL, coins INTEGER NOT NULL,
  createdAt TEXT NOT NULL, PRIMARY KEY(userId, claimDate));
CREATE TABLE IF NOT EXISTS reward_tasks(
  slug TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, coins INTEGER DEFAULT 0,
  actionType TEXT, sortOrder INTEGER DEFAULT 0, target INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS user_reward_tasks(
  userId TEXT NOT NULL, slug TEXT NOT NULL, completedAt TEXT NOT NULL, PRIMARY KEY(userId, slug));
CREATE TABLE IF NOT EXISTS ad_rewards(
  userId TEXT NOT NULL, claimDate TEXT NOT NULL, count INTEGER DEFAULT 0, PRIMARY KEY(userId, claimDate));
CREATE TABLE IF NOT EXISTS notifications(
  id TEXT PRIMARY KEY, userId TEXT NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, body TEXT,
  imageUrl TEXT, payload TEXT, readAt TEXT, createdAt TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS broadcasts(
  id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT, type TEXT DEFAULT 'system',
  sentCount INTEGER DEFAULT 0, createdAt TEXT NOT NULL);
-- Phase 2: addictive coin economy
CREATE TABLE IF NOT EXISTS wheel_spins(
  userId TEXT NOT NULL, spinDate TEXT NOT NULL, freeUsed INTEGER DEFAULT 0, totalSpins INTEGER DEFAULT 0,
  PRIMARY KEY(userId, spinDate));
CREATE TABLE IF NOT EXISTS chest_claims(
  userId TEXT NOT NULL, chestDate TEXT NOT NULL, threshold INTEGER NOT NULL, coins INTEGER NOT NULL,
  claimedAt TEXT NOT NULL, PRIMARY KEY(userId, chestDate, threshold));
CREATE TABLE IF NOT EXISTS watch_time_daily(
  userId TEXT NOT NULL, watchDate TEXT NOT NULL, seconds INTEGER DEFAULT 0, blocksClaimed INTEGER DEFAULT 0,
  paidCoins INTEGER DEFAULT 0,
  PRIMARY KEY(userId, watchDate));
CREATE TABLE IF NOT EXISTS watch_progress(
  userId TEXT NOT NULL, episodeId TEXT NOT NULL, eventDate TEXT NOT NULL, maxPosition INTEGER DEFAULT 0,
  PRIMARY KEY(userId, episodeId, eventDate));
CREATE TABLE IF NOT EXISTS share_events(
  userId TEXT NOT NULL, seriesId TEXT NOT NULL, eventDate TEXT NOT NULL,
  PRIMARY KEY(userId, seriesId, eventDate));
CREATE TABLE IF NOT EXISTS watch_events(
  userId TEXT NOT NULL, episodeId TEXT NOT NULL, eventDate TEXT NOT NULL,
  PRIMARY KEY(userId, episodeId, eventDate));
CREATE TABLE IF NOT EXISTS user_daily_events(
  userId TEXT NOT NULL, eventDate TEXT NOT NULL, metric TEXT NOT NULL, count INTEGER DEFAULT 0,
  PRIMARY KEY(userId, eventDate, metric));
CREATE TABLE IF NOT EXISTS missions(
  slug TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, metric TEXT NOT NULL,
  target INTEGER DEFAULT 1, coins INTEGER DEFAULT 0, sortOrder INTEGER DEFAULT 0, active INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS mission_claims(
  userId TEXT NOT NULL, slug TEXT NOT NULL, claimDate TEXT NOT NULL,
  PRIMARY KEY(userId, slug, claimDate));
CREATE TABLE IF NOT EXISTS events(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, multiplier REAL DEFAULT 1, startsAt TEXT, endsAt TEXT,
  active INTEGER DEFAULT 1, createdAt TEXT NOT NULL);
-- Phase 2: captions & translation
CREATE TABLE IF NOT EXISTS caption_tracks(
  id TEXT PRIMARY KEY, episodeId TEXT NOT NULL, lang TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'asr', status TEXT NOT NULL DEFAULT 'queued', vtt TEXT,
  createdAt TEXT NOT NULL, UNIQUE(episodeId, lang));
CREATE TABLE IF NOT EXISTS caption_jobs(
  id TEXT PRIMARY KEY, episodeId TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'queued',
  step TEXT, error TEXT, targets TEXT, createdAt TEXT NOT NULL, finishedAt TEXT);
`);
// Migrations for DBs created before these columns existed.
try { db.exec('ALTER TABLE reward_tasks ADD COLUMN active INTEGER DEFAULT 1'); } catch { /* already present */ }
try { db.exec('ALTER TABLE users ADD COLUMN xp INTEGER DEFAULT 0'); } catch { /* already present */ }
try { db.exec('ALTER TABLE users ADD COLUMN referralCode TEXT'); } catch { /* already present */ }
try { db.exec('ALTER TABLE users ADD COLUMN referredBy TEXT'); } catch { /* already present */ }
try { db.exec('ALTER TABLE watch_time_daily ADD COLUMN paidCoins INTEGER DEFAULT 0'); } catch { /* already present */ }
try { db.exec('ALTER TABLE caption_jobs ADD COLUMN targets TEXT'); } catch { /* already present */ }
// Generate referral codes for users that do not have one yet:
// 'HD' + 10 hex chars from a hash of the user id (deterministic, stable).
// 10 chars (was 6) makes birthday collisions negligible at this scale, and the
// UNIQUE index below enforces it where the existing data allows.
{
  const crypto = require('node:crypto');
  const rows = db.prepare('SELECT id FROM users WHERE referralCode IS NULL').all();
  const upd = db.prepare('UPDATE users SET referralCode=? WHERE id=?');
  for (const r of rows) {
    const code = 'HD' + crypto.createHash('sha256').update(String(r.id)).digest('hex').slice(0, 10).toUpperCase();
    upd.run(code, r.id);
  }
  try { db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_referral_code ON users(referralCode)'); } catch { /* legacy duplicates: index skipped */ }
}
const all = (sql, ...p) => db.prepare(sql).all(...p);
const get = (sql, ...p) => db.prepare(sql).get(...p);
const run = (sql, ...p) => db.prepare(sql).run(...p);
/** Run fn inside a single IMMEDIATE transaction (all-or-nothing). */
function tx(fn) {
  db.exec('BEGIN IMMEDIATE');
  try { const r = fn(); db.exec('COMMIT'); return r; }
  catch (e) { try { db.exec('ROLLBACK'); } catch { /* ignore */ } throw e; }
}
module.exports = { db, all, get, run, tx, DB_PATH };
