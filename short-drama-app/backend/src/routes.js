'use strict';
const crypto = require('node:crypto');
const { all, get, run } = require('./db');
const auth = require('./auth');
const settings = require('./settings');
const captions = require('./captions');
// Runtime economy values come from the settings store (admin-editable);
// these helpers read live on every call so PATCH /admin/settings applies instantly.
const sWelcome = () => settings.getSetting('welcome_coin_bonus');
const sUnlockCost = () => settings.getSetting('episode_unlock_coin_cost');
const sAdCap = () => settings.getSetting('ad_daily_cap');
const sAdAmount = () => settings.getSetting('ad_reward_amount');
const sCheckin = () => settings.getSetting('checkin_amounts');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'dev-admin-token-change-me';
const now = () => new Date().toISOString();
const today = () => new Date().toISOString().slice(0, 10);
const J = (v) => { try { return JSON.parse(v || '[]'); } catch { return []; } };

function ok(res, data, status = 200) { send(res, status, { data }); }
function err(res, status, code, message) { send(res, status, { error: { code, message } }); }
function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Platform, X-Locale, X-App-Version, X-Device-Id, X-Admin-Token', 'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS' });
  res.end(body);
}
// ---- serializers (exact app model fields) ----
// ---- Phase 2 helpers: XP/levels, streaks, events, missions, daily events ----
const referralCodeFor = (id) => 'HD' + crypto.createHash('sha256').update(String(id)).digest('hex').slice(0, 6).toUpperCase();
const xpForLevel = (L) => 100 * (L - 1) * (L - 1);
function levelFromXp(xp) { let L = 1; while (xpForLevel(L + 1) <= (xp || 0)) L++; return L; }
function awardXp(userId, n) { if (n) run('UPDATE users SET xp=COALESCE(xp,0)+? WHERE id=?', n, userId); }
function dateShift(isoDate, days) { const d = new Date(isoDate + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + days); return d.toISOString().slice(0, 10); }
function checkinDateSet(userId) { return new Set(all('SELECT claimDate FROM checkins WHERE userId=?', userId).map((r) => r.claimDate)); }
function streakEnding(userId, endDate) { const set = checkinDateSet(userId); let n = 0; let d = endDate; while (set.has(d)) { n++; d = dateShift(d, -1); } return n; }
function currentStreak(userId) { const set = checkinDateSet(userId); if (set.has(today())) return streakEnding(userId, today()); return streakEnding(userId, dateShift(today(), -1)); }
function activeEvent() {
  const t = now();
  return get('SELECT * FROM events WHERE active=1 AND startsAt<=? AND endsAt>=? ORDER BY multiplier DESC LIMIT 1', t, t) || null;
}
function eventMultiplier() { const e = activeEvent(); return e ? e.multiplier : 1; }
function bumpDailyEvent(userId, metric, n = 1) {
  run('INSERT INTO user_daily_events(userId,eventDate,metric,count) VALUES(?,?,?,?) ON CONFLICT(userId,eventDate,metric) DO UPDATE SET count=count+excluded.count', userId, today(), metric, n);
}
function dailyEventCount(userId, metric) { const r = get('SELECT count FROM user_daily_events WHERE userId=? AND eventDate=? AND metric=?', userId, today(), metric); return r ? r.count : 0; }
function missionProgress(userId, mission) {
  if (mission.metric === 'watch_episodes') return get('SELECT COUNT(DISTINCT episodeId) c FROM watch_events WHERE userId=? AND eventDate=?', userId, today()).c;
  if (mission.metric === 'watch_minutes') { const r = get('SELECT seconds FROM watch_time_daily WHERE userId=? AND watchDate=?', userId, today()); return r ? Math.floor(r.seconds / 60) : 0; }
  if (mission.metric === 'likes' || mission.metric === 'shares') return dailyEventCount(userId, mission.metric);
  if (mission.metric === 'checkin') return get('SELECT 1 x FROM checkins WHERE userId=? AND claimDate=?', userId, today()) ? 1 : 0;
  return 0;
}
function watchTimeState(userId) {
  const row = get('SELECT * FROM watch_time_daily WHERE userId=? AND watchDate=?', userId, today());
  const seconds = row ? row.seconds : 0; const blocksClaimed = row ? row.blocksClaimed : 0;
  const perBlock = settings.getSetting('watch_time_coins_per_block');
  const blockMinutes = settings.getSetting('watch_time_block_minutes');
  const cap = settings.getSetting('watch_time_daily_cap_coins');
  const minutesToday = Math.floor(seconds / 60);
  const totalBlocks = blockMinutes > 0 ? Math.floor(minutesToday / blockMinutes) : 0;
  const alreadyPaid = blocksClaimed * perBlock;
  const claimableCoins = Math.max(0, Math.min(totalBlocks * perBlock - alreadyPaid, cap - alreadyPaid));
  return { seconds, blocksClaimed, minutesToday, totalBlocks, alreadyPaid, claimableCoins, perBlock, blockMinutes, cap };
}

function userJson(u) {
  const xp = u.xp || 0;
  return { id: u.id, firebaseUid: u.firebaseUid, email: u.email, name: u.name, displayName: u.name, image: u.image, photoUrl: u.image,
    deviceId: u.deviceId, isGuest: !!u.isGuest, isAnonymous: !!u.isGuest, isPro: !!u.isPro, isVip: !!u.isPro,
    coinBalance: u.coinBalance, autoplayNext: !!u.autoplayNext, videoQuality: u.videoQuality || 'auto',
    subscriptionExpirationDate: u.subscriptionExpirationDate, platform: u.platform, appVersion: u.appVersion, locale: u.locale,
    referralCode: u.referralCode || referralCodeFor(u.id), xp, level: levelFromXp(xp),
    createdAt: u.createdAt, updatedAt: u.updatedAt, linkedAt: u.linkedAt || u.updatedAt };
}
function genreJson(g) { return { id: g.id, slug: g.slug, name: g.name, description: g.description, iconUrl: g.iconUrl, colorHex: g.colorHex, sortOrder: g.sortOrder }; }
function seriesJson(s) {
  const g = s.genreId ? get('SELECT * FROM genres WHERE id=?', s.genreId) : null;
  return { id: s.id, slug: s.slug, title: s.title, synopsis: s.synopsis, tagline: s.tagline, coverImageUrl: s.coverImageUrl, heroImageUrl: s.heroImageUrl,
    trailerUrl: s.trailerUrl, gradientStart: s.gradientStart, gradientEnd: s.gradientEnd, genreId: s.genreId,
    genre: g ? genreJson(g) : null, genreName: g ? g.name : null, releaseYear: s.releaseYear, totalEpisodes: s.totalEpisodes, totalSeasons: s.totalSeasons,
    language: s.language || 'en', dubLanguages: J(s.dubLanguages), isVipOnly: !!s.isVipOnly, isExclusive: !!s.isExclusive, isNew: !!s.isNew, isHot: !!s.isHot,
    isCompleted: !!s.isCompleted, isDubbed: !!s.isDubbed, viewCount: s.viewCount, likeCount: s.likeCount, ratingAvg: s.ratingAvg, ratingCount: s.ratingCount,
    rankScore: s.rankScore, isFeatured: !!s.isFeatured, sortOrder: s.sortOrder, tags: J(s.tags) };
}
function episodeJson(e, userId) {
  const unlocked = e.isFree || (userId && !!get('SELECT 1 x FROM episode_unlocks WHERE userId=? AND episodeId=?', userId, e.id));
  return { id: e.id, seriesId: e.seriesId, seasonId: e.seasonId, seasonNumber: e.seasonNumber, episodeNumber: e.episodeNumber, title: e.title,
    description: e.description, thumbnailUrl: e.thumbnailUrl, durationSeconds: e.durationSeconds, isFree: !!e.isFree, coinCost: e.coinCost,
    isVipOnly: !!e.isVipOnly, isUnlocked: !!unlocked, publishedAt: e.publishedAt, viewCount: e.viewCount, sortOrder: e.sortOrder };
}
function grantCoins(userId, amount, type, refId) {
  run('UPDATE users SET coinBalance=coinBalance+? WHERE id=?', amount, userId);
  const u = get('SELECT coinBalance FROM users WHERE id=?', userId);
  run('INSERT INTO coin_transactions(id,userId,amount,type,refId,balanceAfter,createdAt) VALUES(?,?,?,?,?,?,?)', auth.uid(), userId, amount, type, refId || null, u.coinBalance, now());
  return u.coinBalance;
}
function touchDevice(req, user) {
  const platform = req.headers['x-platform'], appVersion = req.headers['x-app-version'], locale = req.headers['x-locale'], deviceId = req.headers['x-device-id'];
  if (!user) return;
  if (platform || appVersion || locale || deviceId) {
    run('UPDATE users SET platform=COALESCE(?,platform), appVersion=COALESCE(?,appVersion), locale=COALESCE(?,locale), deviceId=COALESCE(?,deviceId), updatedAt=? WHERE id=?',
      platform || null, appVersion || null, locale || null, deviceId || null, now(), user.id);
    if (deviceId) run(`INSERT INTO user_devices(userId,deviceId,platform,appVersion,locale,lastSeenAt) VALUES(?,?,?,?,?,?)
      ON CONFLICT(userId,deviceId) DO UPDATE SET platform=excluded.platform, appVersion=excluded.appVersion, locale=excluded.locale, lastSeenAt=excluded.lastSeenAt`,
      user.id, deviceId, platform || null, appVersion || null, locale || null, now());
  }
}
function requireAuth(req, res) {
  const m = /^Bearer\s+(.+)$/i.exec(req.headers.authorization || '');
  const p = m && auth.verify(m[1]);
  if (!p || p.type !== 'access') { err(res, 401, 'UNAUTHORIZED', 'Missing or invalid access token'); return null; }
  const user = get('SELECT * FROM users WHERE id=?', p.sub);
  if (!user) { err(res, 401, 'UNAUTHORIZED', 'User not found'); return null; }
  touchDevice(req, user);
  return get('SELECT * FROM users WHERE id=?', user.id);
}
function optionalAuth(req) {
  const m = /^Bearer\s+(.+)$/i.exec(req.headers.authorization || '');
  const p = m && auth.verify(m[1]);
  return p && p.type === 'access' ? get('SELECT * FROM users WHERE id=?', p.sub) : null;
}
function taskProgress(userId, t) {
  if (t.actionType === 'watch_episodes') return get('SELECT COUNT(DISTINCT seriesId) c FROM watch_history WHERE userId=?', userId).c;
  if (t.actionType === 'collect_series') return get('SELECT COUNT(*) c FROM user_series WHERE userId=? AND favorite=1', userId).c;
  const done = get('SELECT 1 x FROM user_reward_tasks WHERE userId=? AND slug=?', userId, t.slug);
  return done ? t.target : 0;
}
function rewardsState(user) {
  const claims = all('SELECT * FROM checkins WHERE userId=? ORDER BY claimDate ASC', user.id);
  const claimedToday = claims.some((c) => c.claimDate === today());
  const pos = claims.length % 7; // completed in current cycle (0 if cycle just wrapped & not claimed today handled below)
  const inCycle = claimedToday ? ((claims.length - 1) % 7) + 1 : pos;
  const currentDay = claimedToday ? inCycle : (pos + 1);
  const days = sCheckin().map((coins, i) => ({ dayIndex: i + 1, coins, claimed: i + 1 < currentDay || (claimedToday && i + 1 === currentDay) || (i + 1 < currentDay), isToday: i + 1 === currentDay }));
  // fix claimed: days before currentDay claimed; today's claimed iff claimedToday
  days.forEach((d) => { d.claimed = d.dayIndex < currentDay || (d.dayIndex === currentDay && claimedToday); });
  const tasks = all('SELECT * FROM reward_tasks WHERE COALESCE(active,1)=1 ORDER BY sortOrder').map((t) => {
    const completed = !!get('SELECT 1 x FROM user_reward_tasks WHERE userId=? AND slug=?', user.id, t.slug);
    const isMilestone = t.actionType === 'watch_episodes' || t.actionType === 'collect_series';
    const progress = completed ? t.target : taskProgress(user.id, t);
    // One-shot starter tasks (connect_email, rate_app, ...) are claimable immediately;
    // milestone tasks become eligible only when progress reaches the target.
    const eligible = !completed && (isMilestone ? progress >= t.target : true);
    return { slug: t.slug, title: t.title, description: t.description, coins: t.coins, actionType: t.actionType, sortOrder: t.sortOrder, completed, progress, target: t.target, eligible };
  });
  // ---- Phase 2 extensions (existing fields above are unchanged) ----
  const fresh = get('SELECT * FROM users WHERE id=?', user.id) || user;
  const xp = fresh.xp || 0; const level = levelFromXp(xp);
  const spinRow = get('SELECT * FROM wheel_spins WHERE userId=? AND spinDate=?', user.id, today());
  const freePerDay = settings.getSetting('wheel_free_spins_per_day');
  const spinsLeft = Math.max(0, freePerDay - (spinRow ? spinRow.freeUsed : 0));
  const distinctToday = get('SELECT COUNT(DISTINCT episodeId) c FROM watch_events WHERE userId=? AND eventDate=?', user.id, today()).c;
  const chests = settings.getSetting('chest_milestones').map((ms) => ({
    id: 'chest_' + ms.threshold, threshold: ms.threshold, coins: ms.coins,
    claimed: !!get('SELECT 1 x FROM chest_claims WHERE userId=? AND chestDate=? AND threshold=?', user.id, today(), ms.threshold),
    unlocked: distinctToday >= ms.threshold,
  }));
  const wt = watchTimeState(user.id);
  const missions = settings.getSetting('missions_enabled')
    ? all('SELECT * FROM missions WHERE COALESCE(active,1)=1 ORDER BY sortOrder').map((ms) => {
      const progress = missionProgress(user.id, ms);
      return { slug: ms.slug, title: ms.title, description: ms.description, coins: ms.coins, progress, target: ms.target,
        completed: progress >= ms.target,
        claimed: !!get('SELECT 1 x FROM mission_claims WHERE userId=? AND slug=? AND claimDate=?', user.id, ms.slug, today()) };
    }) : [];
  const ev = activeEvent();
  return { coinBalance: fresh.coinBalance, claimedToday, currentDay, days, tasks,
    wheel: { enabled: !!settings.getSetting('wheel_enabled'), spinsLeft, freeSpinsPerDay: freePerDay, segments: settings.getSetting('wheel_segments'), extraSpinCost: settings.getSetting('wheel_extra_spin_cost') },
    chests, watchTime: { enabled: !!settings.getSetting('watch_time_enabled'), minutesToday: wt.minutesToday, coinsPerBlock: wt.perBlock, blockMinutes: wt.blockMinutes, claimableCoins: wt.claimableCoins, claimedCoinsToday: wt.alreadyPaid, dailyCapCoins: wt.cap },
    missions, currentStreak: currentStreak(user.id), xp, level, nextLevelXp: 100 * level * level,
    activeEvent: ev ? { name: ev.name, multiplier: ev.multiplier, endsAt: ev.endsAt } : null,
    referralCode: fresh.referralCode || referralCodeFor(user.id) };
}

async function handle(req, res, url, body) {
  const p = url.pathname.replace(/^\/api\/v1/, '');
  const q = url.searchParams;
  const limit = Math.min(parseInt(q.get('limit') || '40', 10) || 40, 100);
  // ---------- PUBLIC APP CONFIG (no auth; EXEMPT from maintenance — the app needs it to know maintenance is on) ----------
  if (req.method === 'GET' && p === '/config') {
    const S = settings.getSettings();
    return ok(res, {
      maintenanceMode: !!S.maintenance_mode, premiumPlaybackMode: S.premium_playback_mode,
      features: {
        swipe_next_episode: !!S.player_swipe_next_episode, double_tap_seek: !!S.player_double_tap_seek,
        long_press_2x: !!S.player_long_press_2x, edge_brightness_volume: !!S.player_edge_brightness_volume,
        speed_menu: !!S.player_speed_menu, quality_selector: !!S.player_quality_selector,
        auto_next: !!S.player_auto_next, binge_mode: !!S.player_binge_mode, pip: !!S.player_pip,
        scrub_chapters: !!S.player_scrub_chapters, skip_intro: !!S.player_skip_intro,
        lock_controls: !!S.player_lock_controls, sleep_timer: !!S.player_sleep_timer,
        share_moment: !!S.player_share_moment, captions: !!S.captions_enabled,
        wheel: !!S.wheel_enabled, chests: !!S.chests_enabled, missions: !!S.missions_enabled,
        referrals: !!S.referrals_enabled, watch_time: !!S.watch_time_enabled, ads: !!S.ads_enabled,
      },
      player: { skipIntroWindowSeconds: S.skip_intro_window_seconds, skipIntroToSeconds: S.skip_intro_to_seconds, autoNextCountdownSeconds: S.auto_next_countdown_seconds },
      visual: { defaultThemePreset: S.default_theme_preset, confettiEnabled: !!S.confetti_enabled, hapticsEnabled: !!S.haptics_enabled, accentColorOverride: S.accent_color_override },
      economy: { episodeUnlockCoinCost: S.episode_unlock_coin_cost, wheelFreeSpinsPerDay: S.wheel_free_spins_per_day },
    });
  }
  // ---------- MAINTENANCE MODE (settings store; admin API is a separate handler and stays up) ----------
  if (settings.getSetting('maintenance_mode')) return err(res, 503, 'MAINTENANCE', 'HERO DRAMA is temporarily down for maintenance. Please try again soon!');
  // ---------- AUTH ----------
  if (req.method === 'POST' && p === '/auth/firebase') {
    if (process.env.FIREBASE_AUTH_DEV !== '1') return err(res, 501, 'AUTH_NOT_CONFIGURED', 'Production Firebase verification not configured (set FIREBASE_AUTH_DEV=1 for dev)');
    if (!body.idToken) return err(res, 400, 'VALIDATION', 'idToken is required');
    const claims = auth.devDecodeFirebaseToken(body.idToken);
    let user = get('SELECT * FROM users WHERE firebaseUid=?', claims.firebaseUid);
    if (!user) {
      const id = auth.uid(); const t = now();
      run('INSERT INTO users(id,firebaseUid,email,name,image,deviceId,isGuest,coinBalance,createdAt,updatedAt,linkedAt,referralCode,xp) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
        id, claims.firebaseUid, claims.email, claims.name, claims.picture, body.deviceId || null, claims.email ? 0 : 1, 0, t, t, t, referralCodeFor(id), 0);
      const welcome = sWelcome();
      grantCoins(id, welcome, 'welcome_bonus', null);
      run('INSERT INTO notifications(id,userId,type,title,body,createdAt) VALUES(?,?,?,?,?,?)', auth.uid(), id, 'welcome', 'Welcome to HERO DRAMA!', `You received ${welcome} free coins. Start watching now!`, t);
      user = get('SELECT * FROM users WHERE id=?', id);
    } else if (body.deviceId) run('UPDATE users SET deviceId=? WHERE id=?', body.deviceId, user.id);
    touchDevice(req, user); user = get('SELECT * FROM users WHERE id=?', user.id);
    return ok(res, { tokens: auth.issueTokens(user.id), user: userJson(user) });
  }
  if (req.method === 'POST' && p === '/auth/refresh') {
    if (!body.refreshToken) return err(res, 400, 'VALIDATION', 'refreshToken is required');
    const tokens = auth.rotateRefresh(body.refreshToken);
    if (!tokens) return err(res, 401, 'INVALID_REFRESH', 'Invalid or revoked refresh token');
    const payload = auth.verify(tokens.accessToken);
    const user = get('SELECT * FROM users WHERE id=?', payload.sub);
    return ok(res, { tokens, user: userJson(user) });
  }
  // all routes below need auth except public catalog GETs (still accept optional auth)
  const PUBLIC = req.method === 'GET' && ['/categories', '/discover', '/for-you', '/search', '/home'].includes(p) || (req.method === 'GET' && /^\/genres\/[^/]+\/series$/.test(p)) || (req.method === 'GET' && /^\/series\/[^/]+$/.test(p)) || (req.method === 'GET' && /^\/series\/[^/]+\/episodes$/.test(p));
  let user = PUBLIC ? optionalAuth(req) : requireAuth(req, res);
  if (!PUBLIC && !user) return;
  if (req.method === 'POST' && p === '/auth/relink') {
    const guestId = body.guestUserId;
    if (!guestId || guestId === user.id) return ok(res, { success: true });
    const guest = get('SELECT * FROM users WHERE id=?', guestId);
    if (guest) {
      if (guest.coinBalance > 0) grantCoins(user.id, guest.coinBalance, 'relink_merge', guestId);
      run('UPDATE watch_history SET userId=? WHERE userId=?', user.id, guestId);
      run('UPDATE user_series SET userId=? WHERE userId=? AND seriesId NOT IN (SELECT seriesId FROM user_series WHERE userId=?)', user.id, guestId, user.id);
      run('UPDATE episode_unlocks SET userId=? WHERE userId=? AND episodeId NOT IN (SELECT episodeId FROM episode_unlocks WHERE userId=?)', user.id, guestId, user.id);
      run('UPDATE refresh_tokens SET revoked=1 WHERE userId=?', guestId);
      run('DELETE FROM users WHERE id=?', guestId);
    }
    return ok(res, { success: true });
  }
  if (req.method === 'GET' && p === '/auth/me') return ok(res, { user: userJson(user) });
  if (req.method === 'POST' && p === '/auth/referral') {
    if (!settings.getSetting('referrals_enabled')) return err(res, 403, 'FEATURE_DISABLED', 'Referrals are disabled');
    if (user.referredBy) return err(res, 409, 'ALREADY_REFERRED', 'A referral code was already applied to this account');
    const code = String(body.code || '').trim();
    const ownCode = user.referralCode || referralCodeFor(user.id);
    if (!code || code === ownCode) return err(res, 400, 'INVALID_CODE', 'Invalid referral code');
    const referrer = get('SELECT * FROM users WHERE referralCode=?', code);
    if (!referrer || referrer.id === user.id) return err(res, 400, 'INVALID_CODE', 'Invalid referral code');
    run('UPDATE users SET referredBy=? WHERE id=?', referrer.id, user.id);
    grantCoins(referrer.id, settings.getSetting('referral_bonus_referrer'), 'referral', user.id);
    const refereeBonus = settings.getSetting('referral_bonus_referee');
    const balance = grantCoins(user.id, refereeBonus, 'referral', referrer.id);
    return ok(res, { success: true, coins: refereeBonus, balance });
  }
  if (req.method === 'DELETE' && p === '/auth/account') {
    run('DELETE FROM refresh_tokens WHERE userId=?', user.id); run('DELETE FROM users WHERE id=?', user.id);
    return ok(res, { success: true });
  }
  // ---------- CATALOG ----------
  if (req.method === 'GET' && p === '/categories') return ok(res, { genres: all('SELECT * FROM genres ORDER BY sortOrder').map(genreJson) });
  let m;
  if (req.method === 'GET' && (m = /^\/genres\/([^/]+)\/series$/.exec(p)))
    return ok(res, { series: all('SELECT * FROM series WHERE genreId=? ORDER BY sortOrder LIMIT ?', decodeURIComponent(m[1]), limit).map(seriesJson) });
  if (req.method === 'GET' && p === '/discover') {
    const f = q.get('filter') || 'popular';
    const order = f === 'latest' ? 'releaseYear DESC, createdAt DESC' : f === 'ranking' ? 'rankScore DESC' : 'viewCount DESC';
    const rows = all(`SELECT * FROM series ORDER BY ${order} LIMIT ?`, limit);
    if (f !== 'ranking') return ok(res, { series: rows.map(seriesJson) });
    // Ranking responses gain rankDelta vs the stored daily snapshot
    // (prevIndex - currentIndex; positive = moved up). First ever = all 0.
    const fullOrder = all('SELECT id FROM series ORDER BY rankScore DESC').map((r) => r.id);
    let snap = null;
    const snapRow = get("SELECT value FROM meta WHERE key='rank_snapshot'");
    if (snapRow) { try { snap = JSON.parse(snapRow.value); } catch { snap = null; } }
    const prevOrder = snap && Array.isArray(snap.order) ? snap.order : [];
    const series = rows.map((s) => {
      const cur = fullOrder.indexOf(s.id);
      const prev = prevOrder.indexOf(s.id);
      return { ...seriesJson(s), rankDelta: prev >= 0 && cur >= 0 ? prev - cur : 0 };
    });
    if (!snap || snap.date !== today()) {
      run("INSERT INTO meta(key,value) VALUES('rank_snapshot',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", JSON.stringify({ date: today(), order: fullOrder }));
    }
    return ok(res, { series });
  }
  if (req.method === 'GET' && p === '/for-you')
    return ok(res, { series: all('SELECT * FROM series ORDER BY rankScore DESC, viewCount DESC LIMIT ?', limit).map(seriesJson) });
  if (req.method === 'GET' && p === '/search') {
    const term = '%' + (q.get('q') || '') + '%';
    return ok(res, { series: all('SELECT * FROM series WHERE title LIKE ? OR synopsis LIKE ? OR tags LIKE ? LIMIT ?', term, term, term, limit).map(seriesJson) });
  }
  if (req.method === 'GET' && p === '/home') {
    const sections = all('SELECT * FROM home_sections ORDER BY sortOrder').map((s) => ({
      id: s.id, slug: s.slug, title: s.title, subtitle: s.subtitle, sectionType: s.sectionType, sortOrder: s.sortOrder,
      series: all('SELECT sr.* FROM home_section_items i JOIN series sr ON sr.id=i.seriesId WHERE i.sectionId=? ORDER BY i.sortOrder', s.id).map(seriesJson),
    }));
    return ok(res, { sections });
  }
  if (req.method === 'GET' && (m = /^\/series\/([^/]+)$/.exec(p))) {
    const s = get('SELECT * FROM series WHERE id=? OR slug=?', decodeURIComponent(m[1]), decodeURIComponent(m[1]));
    if (!s) return err(res, 404, 'NOT_FOUND', 'Series not found');
    const cast = all('SELECT c.*, p.slug pslug, p.name pname, p.gender pgender, p.imageUrl pimg FROM cast_members c JOIN persons p ON p.id=c.personId WHERE c.seriesId=? ORDER BY c.sortOrder', s.id)
      .map((c) => ({ id: c.id, characterName: c.characterName, sortOrder: c.sortOrder, personId: c.personId, person: { id: c.personId, slug: c.pslug, name: c.pname, gender: c.pgender, imageUrl: c.pimg }, personSlug: c.pslug, personName: c.pname, personGender: c.pgender, personImageUrl: c.pimg }));
    const related = all('SELECT * FROM series WHERE genreId=? AND id!=? ORDER BY rankScore DESC LIMIT 6', s.genreId, s.id).map(seriesJson);
    const us = user ? get('SELECT * FROM user_series WHERE userId=? AND seriesId=?', user.id, s.id) : null;
    const hist = user ? get('SELECT * FROM watch_history WHERE userId=? AND seriesId=?', user.id, s.id) : null;
    return ok(res, { series: seriesJson(s), cast, related, isFavorite: !!(us && us.favorite), isFollowing: !!(us && us.following), isLiked: !!(us && us.liked), resumeEpisodeNumber: hist ? hist.episodeNumber : null });
  }
  if (req.method === 'GET' && (m = /^\/series\/([^/]+)\/episodes$/.exec(p))) {
    const s = get('SELECT * FROM series WHERE id=? OR slug=?', decodeURIComponent(m[1]), decodeURIComponent(m[1]));
    if (!s) return err(res, 404, 'NOT_FOUND', 'Series not found');
    return ok(res, { episodes: all('SELECT * FROM episodes WHERE seriesId=? ORDER BY episodeNumber', s.id).map((e) => episodeJson(e, user && user.id)) });
  }
  if (req.method === 'GET' && (m = /^\/episodes\/([^/]+)\/playback$/.exec(p))) {
    const e = get('SELECT * FROM episodes WHERE id=?', decodeURIComponent(m[1]));
    if (!e) return err(res, 404, 'NOT_FOUND', 'Episode not found');
    const s = get('SELECT * FROM series WHERE id=?', e.seriesId);
    // premium_playback_mode (settings): disabled = premium gating off (coin unlocks still apply);
    // premium_content = VIP-only content requires VIP (default, pre-settings behavior);
    // all_playback = every playback, even free episodes, requires an active VIP subscription.
    const premiumMode = settings.getSetting('premium_playback_mode');
    if (premiumMode === 'all_playback' && !user.isPro) return err(res, 403, 'VIP_REQUIRED', 'Playback currently requires an active VIP subscription');
    const vipGate = premiumMode !== 'disabled' && (e.isVipOnly || (s && s.isVipOnly));
    if (vipGate && !user.isPro) return err(res, 403, 'VIP_REQUIRED', 'This episode requires VIP');
    if (!e.isFree && !vipGate && !get('SELECT 1 x FROM episode_unlocks WHERE userId=? AND episodeId=?', user.id, e.id))
      return err(res, 403, 'EPISODE_LOCKED', 'Unlock this episode with coins first');
    const lang = q.get('lang');
    const dub = lang ? get('SELECT * FROM episode_dubs WHERE episodeId=? AND lang=?', e.id, lang) : null;
    const resolvedUrl = dub ? dub.videoUrl : e.videoUrl;
    // Quality ladder: all entries currently point at the resolved videoUrl/dub URL —
    // real per-quality transcodes plug in here when a transcoder is added.
    const qualities = ['1080p', '720p', '480p', '360p'].map((label) => ({ label, url: resolvedUrl }));
    return ok(res, { videoUrl: resolvedUrl, qualities, captionLanguages: captions.readyLanguages(e.id) });
  }
  // ---------- CAPTIONS (raw WebVTT is NOT the JSON envelope — the player fetches it raw) ----------
  if (req.method === 'GET' && (m = /^\/episodes\/([^/]+)\/captions(?:\/([^/]+))?$/.exec(p))) {
    const epId = decodeURIComponent(m[1]); const capLang = m[2] ? decodeURIComponent(m[2]) : null;
    const e = get('SELECT * FROM episodes WHERE id=?', epId);
    if (!e) return err(res, 404, 'NOT_FOUND', 'Episode not found');
    if (!capLang) {
      const languages = settings.getSetting('captions_enabled')
        ? all("SELECT lang, source, status FROM caption_tracks WHERE episodeId=? AND status='ready' ORDER BY lang", epId).map((t) => ({ lang: t.lang, source: t.source, status: t.status }))
        : [];
      return ok(res, { languages });
    }
    const track = settings.getSetting('captions_enabled')
      ? get("SELECT * FROM caption_tracks WHERE episodeId=? AND lang=? AND status='ready'", epId, capLang) : null;
    if (!track || !track.vtt) return err(res, 404, 'NOT_FOUND', 'Caption track not found');
    res.writeHead(200, { 'Content-Type': 'text/vtt; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
    return res.end(track.vtt);
  }
  if (req.method === 'POST' && (m = /^\/episodes\/([^/]+)\/unlock$/.exec(p))) {
    const e = get('SELECT * FROM episodes WHERE id=?', decodeURIComponent(m[1]));
    if (!e) return err(res, 404, 'NOT_FOUND', 'Episode not found');
    if (e.isFree || get('SELECT 1 x FROM episode_unlocks WHERE userId=? AND episodeId=?', user.id, e.id)) return ok(res, { success: true, coins: 0, balance: user.coinBalance });
    const cost = e.coinCost || sUnlockCost();
    if (user.coinBalance < cost) return err(res, 402, 'INSUFFICIENT_COINS', `Need ${cost} coins, balance is ${user.coinBalance}`);
    const balance = grantCoins(user.id, -cost, 'episode_unlock', e.id);
    run('INSERT OR IGNORE INTO episode_unlocks(userId,episodeId,createdAt) VALUES(?,?,?)', user.id, e.id, now());
    return ok(res, { success: true, coins: cost, balance });
  }
  // ---------- SOCIAL ----------
  for (const [action, field, key] of [['like', 'liked', 'like'], ['favorite', 'favorite', 'add'], ['follow', 'following', 'follow']]) {
    if (req.method === 'POST' && (m = new RegExp(`^/series/([^/]+)/${action}$`).exec(p))) {
      const s = get('SELECT * FROM series WHERE id=? OR slug=?', decodeURIComponent(m[1]), decodeURIComponent(m[1]));
      if (!s) return err(res, 404, 'NOT_FOUND', 'Series not found');
      const want = body[key] !== false;
      run(`INSERT INTO user_series(userId,seriesId,${field}) VALUES(?,?,?) ON CONFLICT(userId,seriesId) DO UPDATE SET ${field}=excluded.${field}`, user.id, s.id, want ? 1 : 0);
      if (action === 'like') { run('UPDATE series SET likeCount=MAX(0,likeCount+?) WHERE id=?', want ? 1 : -1, s.id); if (want) bumpDailyEvent(user.id, 'likes'); }
      const fresh = get('SELECT * FROM series WHERE id=?', s.id);
      return ok(res, { success: true, likeCount: fresh.likeCount });
    }
  }
  if (req.method === 'GET' && p === '/me/library/my-list')
    return ok(res, { series: all('SELECT sr.* FROM user_series u JOIN series sr ON sr.id=u.seriesId WHERE u.userId=? AND u.favorite=1', user.id).map(seriesJson) });
  const histJson = (h) => { const s = get('SELECT * FROM series WHERE id=?', h.seriesId); return s ? { series: seriesJson(s), episodeId: h.episodeId, episodeNumber: h.episodeNumber, positionSeconds: h.positionSeconds, durationSeconds: h.durationSeconds, completed: !!h.completed, watchedAt: h.watchedAt } : null; };
  if (req.method === 'GET' && p === '/me/library/history')
    return ok(res, { history: all('SELECT * FROM watch_history WHERE userId=? ORDER BY watchedAt DESC LIMIT ?', user.id, limit).map(histJson).filter(Boolean) });
  if (req.method === 'GET' && p === '/me/library/continue')
    return ok(res, { history: all('SELECT * FROM watch_history WHERE userId=? AND completed=0 ORDER BY watchedAt DESC LIMIT ?', user.id, limit).map(histJson).filter(Boolean) });
  if (req.method === 'POST' && p === '/me/watch-history') {
    if (!body.seriesId) return err(res, 400, 'VALIDATION', 'seriesId is required');
    // Phase 2 watch accrual (existing history upsert behavior below is unchanged):
    // delta = clamp(newPosition - oldPosition, 0, durationSeconds || newPosition),
    // where oldPosition is the stored position for this same episode (0 for a new one).
    const prev = get('SELECT * FROM watch_history WHERE userId=? AND seriesId=?', user.id, body.seriesId);
    const newPos = body.positionSeconds || 0;
    const oldPos = prev && body.episodeId && prev.episodeId === body.episodeId ? (prev.positionSeconds || 0) : 0;
    const delta = Math.max(0, Math.min(newPos - oldPos, body.durationSeconds || newPos));
    if (delta > 0) run('INSERT INTO watch_time_daily(userId,watchDate,seconds,blocksClaimed) VALUES(?,?,?,0) ON CONFLICT(userId,watchDate) DO UPDATE SET seconds=seconds+excluded.seconds', user.id, today(), delta);
    if (body.episodeId) run('INSERT OR IGNORE INTO watch_events(userId,episodeId,eventDate) VALUES(?,?,?)', user.id, body.episodeId, today());
    if (body.completed && body.episodeId) {
      // +5 XP the first time this episode is completed today (per-episode daily marker).
      const marker = 'completed:' + body.episodeId;
      if (!dailyEventCount(user.id, marker)) { bumpDailyEvent(user.id, marker); awardXp(user.id, 5); }
    }
    run(`INSERT INTO watch_history(userId,seriesId,episodeId,episodeNumber,positionSeconds,durationSeconds,completed,watchedAt) VALUES(?,?,?,?,?,?,?,?)
      ON CONFLICT(userId,seriesId) DO UPDATE SET episodeId=excluded.episodeId, episodeNumber=excluded.episodeNumber, positionSeconds=excluded.positionSeconds, durationSeconds=excluded.durationSeconds, completed=excluded.completed, watchedAt=excluded.watchedAt`,
      user.id, body.seriesId, body.episodeId || null, body.episodeNumber || 1, body.positionSeconds || 0, body.durationSeconds || 0, body.completed ? 1 : 0, now());
    return ok(res, { success: true });
  }
  if (req.method === 'POST' && p === '/content/share') {
    bumpDailyEvent(user.id, 'shares');
    return ok(res, { success: true });
  }
  if (req.method === 'POST' && p === '/content/view') {
    if (body.type === 'series') run('UPDATE series SET viewCount=viewCount+1 WHERE id=?', body.id);
    if (body.type === 'episode') run('UPDATE episodes SET viewCount=viewCount+1 WHERE id=?', body.id);
    return ok(res, { success: true });
  }
  // ---------- COINS / REWARDS ----------
  if (req.method === 'GET' && p === '/me/coins') return ok(res, { balance: user.coinBalance });
  if (req.method === 'GET' && p === '/rewards') return ok(res, rewardsState(user));
  if (req.method === 'POST' && p === '/rewards/checkin') {
    if (get('SELECT 1 x FROM checkins WHERE userId=? AND claimDate=?', user.id, today())) return ok(res, { success: false, coins: 0 });
    const count = get('SELECT COUNT(*) c FROM checkins WHERE userId=?', user.id).c;
    const dayIndex = (count % 7) + 1;
    // Phase 2 payout: round((base + (level-1)*5 + min(streakBeforeToday,7)*2) * activeEventMultiplier)
    const streakBeforeToday = streakEnding(user.id, dateShift(today(), -1));
    const level = levelFromXp(user.xp || 0);
    const coins = Math.round((sCheckin()[dayIndex - 1] + (level - 1) * 5 + Math.min(streakBeforeToday, 7) * 2) * eventMultiplier());
    run('INSERT INTO checkins(userId,claimDate,dayIndex,coins,createdAt) VALUES(?,?,?,?,?)', user.id, today(), dayIndex, coins, now());
    grantCoins(user.id, coins, 'checkin', String(dayIndex));
    bumpDailyEvent(user.id, 'checkin');
    awardXp(user.id, 10);
    return ok(res, { success: true, coins });
  }
  // ---------- PHASE 2: WHEEL / CHESTS / WATCH-TIME / MISSIONS ----------
  if (req.method === 'POST' && p === '/rewards/wheel/spin') {
    if (!settings.getSetting('wheel_enabled')) return err(res, 403, 'FEATURE_DISABLED', 'The reward wheel is disabled');
    const freePerDay = settings.getSetting('wheel_free_spins_per_day');
    const row = get('SELECT * FROM wheel_spins WHERE userId=? AND spinDate=?', user.id, today());
    const freeUsed = row ? row.freeUsed : 0;
    let balance = user.coinBalance;
    if (freeUsed < freePerDay) {
      run('INSERT INTO wheel_spins(userId,spinDate,freeUsed,totalSpins) VALUES(?,?,1,1) ON CONFLICT(userId,spinDate) DO UPDATE SET freeUsed=freeUsed+1, totalSpins=totalSpins+1', user.id, today());
    } else {
      const cost = settings.getSetting('wheel_extra_spin_cost');
      if (user.coinBalance < cost) return err(res, 402, 'INSUFFICIENT_COINS', `Need ${cost} coins for an extra spin, balance is ${user.coinBalance}`);
      balance = grantCoins(user.id, -cost, 'wheel_spin_cost', null);
      run('INSERT INTO wheel_spins(userId,spinDate,freeUsed,totalSpins) VALUES(?,?,0,1) ON CONFLICT(userId,spinDate) DO UPDATE SET totalSpins=totalSpins+1', user.id, today());
    }
    const segments = settings.getSetting('wheel_segments');
    const weights = settings.getSetting('wheel_weights');
    let segmentIndex = 0;
    if (Array.isArray(weights) && weights.length === segments.length && weights.reduce((a, b) => a + b, 0) > 0) {
      let r = Math.random() * weights.reduce((a, b) => a + b, 0);
      for (let i = 0; i < weights.length; i++) { r -= weights[i]; if (r < 0) { segmentIndex = i; break; } segmentIndex = i; }
    } else segmentIndex = Math.floor(Math.random() * segments.length);
    const coins = Math.round((segments[segmentIndex] || 0) * eventMultiplier());
    if (coins > 0) balance = grantCoins(user.id, coins, 'wheel', String(segmentIndex));
    else balance = get('SELECT coinBalance FROM users WHERE id=?', user.id).coinBalance;
    awardXp(user.id, 2);
    const after = get('SELECT * FROM wheel_spins WHERE userId=? AND spinDate=?', user.id, today());
    return ok(res, { success: true, segmentIndex, coins, balance, spinsLeft: Math.max(0, freePerDay - (after ? after.freeUsed : 0)) });
  }
  if (req.method === 'POST' && (m = /^\/rewards\/chests\/([^/]+)\/claim$/.exec(p))) {
    if (!settings.getSetting('chests_enabled')) return err(res, 403, 'FEATURE_DISABLED', 'Watch chests are disabled');
    const cm = /^chest_(\d+)$/.exec(decodeURIComponent(m[1]));
    const milestone = cm ? settings.getSetting('chest_milestones').find((ms) => ms.threshold === parseInt(cm[1], 10)) : null;
    if (!milestone) return err(res, 404, 'NOT_FOUND', 'Chest not found');
    const distinctToday = get('SELECT COUNT(DISTINCT episodeId) c FROM watch_events WHERE userId=? AND eventDate=?', user.id, today()).c;
    if (distinctToday < milestone.threshold) return err(res, 403, 'CHEST_LOCKED', `Watch ${milestone.threshold} episodes today to unlock this chest`);
    if (get('SELECT 1 x FROM chest_claims WHERE userId=? AND chestDate=? AND threshold=?', user.id, today(), milestone.threshold))
      return err(res, 409, 'ALREADY_CLAIMED', 'Chest already claimed today');
    // Chests pay the FIXED milestone coins — no event multiplier (by design).
    run('INSERT INTO chest_claims(userId,chestDate,threshold,coins,claimedAt) VALUES(?,?,?,?,?)', user.id, today(), milestone.threshold, milestone.coins, now());
    const balance = grantCoins(user.id, milestone.coins, 'chest', 'chest_' + milestone.threshold);
    awardXp(user.id, 5);
    return ok(res, { success: true, coins: milestone.coins, balance });
  }
  if (req.method === 'POST' && p === '/rewards/watch-time/claim') {
    if (!settings.getSetting('watch_time_enabled')) return err(res, 403, 'FEATURE_DISABLED', 'Watch-time rewards are disabled');
    const wt = watchTimeState(user.id);
    // Mirrors /rewards/ad cap semantics: nothing claimable -> 200 {success:false, coins:0}.
    if (wt.claimableCoins <= 0) return ok(res, { success: false, coins: 0, balance: user.coinBalance });
    const coins = Math.round(wt.claimableCoins * eventMultiplier());
    run('UPDATE watch_time_daily SET blocksClaimed=? WHERE userId=? AND watchDate=?', wt.totalBlocks, user.id, today());
    const balance = grantCoins(user.id, coins, 'watch_time', null);
    return ok(res, { success: true, coins, balance });
  }
  if (req.method === 'POST' && (m = /^\/rewards\/missions\/([^/]+)\/claim$/.exec(p))) {
    const mission = get('SELECT * FROM missions WHERE slug=?', decodeURIComponent(m[1]));
    if (!mission || mission.active === 0) return err(res, 404, 'NOT_FOUND', 'Mission not found');
    if (missionProgress(user.id, mission) < mission.target) return err(res, 403, 'MISSION_INCOMPLETE', 'Mission target not reached yet');
    if (get('SELECT 1 x FROM mission_claims WHERE userId=? AND slug=? AND claimDate=?', user.id, mission.slug, today()))
      return err(res, 409, 'ALREADY_CLAIMED', 'Mission already claimed today');
    run('INSERT INTO mission_claims(userId,slug,claimDate) VALUES(?,?,?)', user.id, mission.slug, today());
    const balance = grantCoins(user.id, mission.coins, 'mission', mission.slug); // no event multiplier on missions
    awardXp(user.id, 10);
    return ok(res, { success: true, coins: mission.coins, balance });
  }
  if (req.method === 'POST' && p === '/rewards/ad') {
    if (!settings.getSetting('ads_enabled')) return ok(res, { success: false, coins: 0, reason: 'ADS_DISABLED' });
    const amount = sAdAmount(); // settings store is authoritative for the rewarded-ad amount
    const row = get('SELECT * FROM ad_rewards WHERE userId=? AND claimDate=?', user.id, today());
    if (row && row.count >= sAdCap()) return ok(res, { success: false, coins: 0 });
    run('INSERT INTO ad_rewards(userId,claimDate,count) VALUES(?,?,1) ON CONFLICT(userId,claimDate) DO UPDATE SET count=count+1', user.id, today());
    grantCoins(user.id, amount, 'ad_reward', null);
    return ok(res, { success: true, coins: amount });
  }
  if (req.method === 'POST' && (m = /^\/rewards\/tasks\/([^/]+)\/complete$/.exec(p))) {
    const t = get('SELECT * FROM reward_tasks WHERE slug=?', decodeURIComponent(m[1]));
    if (!t || t.active === 0) return err(res, 404, 'NOT_FOUND', 'Task not found');
    if (get('SELECT 1 x FROM user_reward_tasks WHERE userId=? AND slug=?', user.id, t.slug)) return ok(res, { success: false, coins: 0 });
    const isMilestone = t.actionType === 'watch_episodes' || t.actionType === 'collect_series';
    if (isMilestone && taskProgress(user.id, t) < t.target) return ok(res, { success: false, coins: 0 });
    run('INSERT INTO user_reward_tasks(userId,slug,completedAt) VALUES(?,?,?)', user.id, t.slug, now());
    grantCoins(user.id, t.coins, 'reward_task', t.slug);
    awardXp(user.id, 5);
    return ok(res, { success: true, coins: t.coins });
  }
  // ---------- NOTIFICATIONS ----------
  if (req.method === 'GET' && p === '/notifications') {
    const items = all('SELECT * FROM notifications WHERE userId=? ORDER BY createdAt DESC LIMIT 100', user.id)
      .map((n) => ({ id: n.id, userId: n.userId, type: n.type, title: n.title, body: n.body, imageUrl: n.imageUrl, payload: n.payload ? JSON.parse(n.payload) : null, readAt: n.readAt, createdAt: n.createdAt }));
    return ok(res, { items, unread: items.filter((i) => !i.readAt).length });
  }
  if (req.method === 'POST' && p === '/notifications/read') {
    if (Array.isArray(body.ids) && body.ids.length) body.ids.forEach((id) => run('UPDATE notifications SET readAt=? WHERE id=? AND userId=?', now(), id, user.id));
    else run('UPDATE notifications SET readAt=? WHERE userId=? AND readAt IS NULL', now(), user.id);
    return ok(res, { success: true });
  }
  return err(res, 404, 'NOT_FOUND', `No route ${req.method} ${p}`);
}
// ---------- ADMIN ----------
function adminHandle(req, res, url, body) {
  if ((req.headers['x-admin-token'] || '') !== ADMIN_TOKEN) return err(res, 401, 'UNAUTHORIZED', 'Invalid X-Admin-Token');
  const p = url.pathname.replace(/^\/api\/v1\/admin/, ''); let m;
  if (req.method === 'GET' && p === '/stats') {
    const views = get('SELECT COALESCE(SUM(viewCount),0) v FROM series').v + get('SELECT COALESCE(SUM(viewCount),0) v FROM episodes').v;
    const granted = get("SELECT COALESCE(SUM(amount),0) v FROM coin_transactions WHERE amount>0").v;
    const txJson = (t) => { const u = get('SELECT email,name FROM users WHERE id=?', t.userId); return { id: t.id, userId: t.userId, userEmail: u ? u.email : null, userName: u ? u.name : null, amount: t.amount, type: t.type, refId: t.refId, balanceAfter: t.balanceAfter, createdAt: t.createdAt }; };
    return ok(res, { users: get('SELECT COUNT(*) c FROM users').c, series: get('SELECT COUNT(*) c FROM series').c, episodes: get('SELECT COUNT(*) c FROM episodes').c, views, coinsGranted: granted,
      newUsersToday: get("SELECT COUNT(*) c FROM users WHERE substr(createdAt,1,10)=?", today()).c,
      coinsInCirculation: get('SELECT COALESCE(SUM(coinBalance),0) v FROM users').v,
      vipUsers: get('SELECT COUNT(*) c FROM users WHERE isPro=1').c,
      topSeries: all('SELECT id,title,viewCount FROM series ORDER BY viewCount DESC LIMIT 5'),
      recentTransactions: all('SELECT * FROM coin_transactions ORDER BY createdAt DESC, rowid DESC LIMIT 10').map(txJson) });
  }
  // ---------- SETTINGS ----------
  if (p === '/settings') {
    if (req.method === 'GET') return ok(res, { settings: settings.getSettings() });
    if (req.method === 'PATCH') { const r = settings.updateSettings(body); if (r.error) return err(res, 400, 'VALIDATION', r.error); return ok(res, { settings: r.settings }); }
  }
  // ---------- PHASE 2: MISSIONS CRUD ----------
  if (p === '/missions' || p.startsWith('/missions/')) {
    const MISSION_METRICS = ['watch_episodes', 'watch_minutes', 'likes', 'shares', 'checkin'];
    const missionJson = (ms) => ({ slug: ms.slug, title: ms.title, description: ms.description, metric: ms.metric, target: ms.target, coins: ms.coins, sortOrder: ms.sortOrder, active: ms.active !== 0 });
    if (req.method === 'GET' && p === '/missions') return ok(res, { items: all('SELECT * FROM missions ORDER BY sortOrder').map(missionJson) });
    if (req.method === 'POST' && p === '/missions') {
      if (!body.slug || !body.title) return err(res, 400, 'VALIDATION', 'slug and title are required');
      if (!MISSION_METRICS.includes(body.metric)) return err(res, 400, 'VALIDATION', `metric must be one of ${MISSION_METRICS.join('|')}`);
      if (get('SELECT 1 x FROM missions WHERE slug=?', body.slug)) return err(res, 409, 'CONFLICT', 'A mission with this slug already exists');
      run('INSERT INTO missions(slug,title,description,metric,target,coins,sortOrder,active) VALUES(?,?,?,?,?,?,?,?)', body.slug, body.title, body.description || null, body.metric, parseInt(body.target || '1', 10) || 1, parseInt(body.coins || '0', 10) || 0, parseInt(body.sortOrder || '0', 10) || 0, body.active === false ? 0 : 1);
      return ok(res, missionJson(get('SELECT * FROM missions WHERE slug=?', body.slug)), 201);
    }
    if ((m = /^\/missions\/([^/]+)$/.exec(p))) {
      const slug = decodeURIComponent(m[1]);
      const ms = get('SELECT * FROM missions WHERE slug=?', slug);
      if (!ms) return err(res, 404, 'NOT_FOUND', 'Mission not found');
      if (req.method === 'PATCH') {
        if (body.metric !== undefined && !MISSION_METRICS.includes(body.metric)) return err(res, 400, 'VALIDATION', `metric must be one of ${MISSION_METRICS.join('|')}`);
        const F = ['title', 'description', 'metric', 'target', 'coins', 'sortOrder']; const cols = F.filter((f) => body[f] !== undefined);
        if (body.active !== undefined) { cols.push('active'); body.active = body.active ? 1 : 0; }
        if (cols.length) run(`UPDATE missions SET ${cols.map((c) => c + '=?').join(',')} WHERE slug=?`, ...cols.map((c) => body[c]), slug);
        return ok(res, missionJson(get('SELECT * FROM missions WHERE slug=?', slug)));
      }
      if (req.method === 'DELETE') { run('DELETE FROM missions WHERE slug=?', slug); return ok(res, { success: true }); }
    }
  }
  // ---------- PHASE 2: EVENTS CRUD (multiplier windows) ----------
  if (p === '/events' || p.startsWith('/events/')) {
    const eventJson = (e) => ({ id: e.id, name: e.name, multiplier: e.multiplier, startsAt: e.startsAt, endsAt: e.endsAt, active: e.active !== 0, createdAt: e.createdAt });
    if (req.method === 'GET' && p === '/events') return ok(res, { items: all('SELECT * FROM events ORDER BY createdAt DESC').map(eventJson) });
    if (req.method === 'POST' && p === '/events') {
      if (!body.name) return err(res, 400, 'VALIDATION', 'name is required');
      const mult = Number(body.multiplier); if (!Number.isFinite(mult) || mult <= 0) return err(res, 400, 'VALIDATION', 'multiplier must be a positive number');
      const id = body.id || auth.uid();
      run('INSERT INTO events(id,name,multiplier,startsAt,endsAt,active,createdAt) VALUES(?,?,?,?,?,?,?)', id, body.name, mult, body.startsAt || null, body.endsAt || null, body.active === false ? 0 : 1, now());
      return ok(res, eventJson(get('SELECT * FROM events WHERE id=?', id)), 201);
    }
    if ((m = /^\/events\/([^/]+)$/.exec(p))) {
      const id = decodeURIComponent(m[1]);
      const ev = get('SELECT * FROM events WHERE id=?', id);
      if (!ev) return err(res, 404, 'NOT_FOUND', 'Event not found');
      if (req.method === 'PATCH') {
        if (body.multiplier !== undefined && (!Number.isFinite(Number(body.multiplier)) || Number(body.multiplier) <= 0)) return err(res, 400, 'VALIDATION', 'multiplier must be a positive number');
        const F = ['name', 'multiplier', 'startsAt', 'endsAt']; const cols = F.filter((f) => body[f] !== undefined);
        if (body.active !== undefined) { cols.push('active'); body.active = body.active ? 1 : 0; }
        if (cols.length) run(`UPDATE events SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, ...cols.map((c) => body[c]), id);
        return ok(res, eventJson(get('SELECT * FROM events WHERE id=?', id)));
      }
      if (req.method === 'DELETE') { run('DELETE FROM events WHERE id=?', id); return ok(res, { success: true }); }
    }
  }
  // ---------- PHASE 2: CAPTIONS ADMIN ----------
  if (req.method === 'GET' && p === '/captions') {
    const eps = all('SELECT ct.episodeId, ct.id trackId, ct.lang, ct.source, ct.status, e.seriesId, e.episodeNumber, e.title FROM caption_tracks ct JOIN episodes e ON e.id=ct.episodeId ORDER BY e.seriesId, e.episodeNumber, ct.lang');
    const byEp = new Map();
    for (const r of eps) {
      if (!byEp.has(r.episodeId)) byEp.set(r.episodeId, { episodeId: r.episodeId, seriesId: r.seriesId, episodeNumber: r.episodeNumber, title: r.title, tracks: [] });
      byEp.get(r.episodeId).tracks.push({ id: r.trackId, lang: r.lang, source: r.source, status: r.status });
    }
    const jobs = all('SELECT * FROM caption_jobs ORDER BY createdAt DESC, rowid DESC LIMIT 50')
      .map((j) => ({ id: j.id, episodeId: j.episodeId, status: j.status, step: j.step, error: j.error, createdAt: j.createdAt, finishedAt: j.finishedAt }));
    return ok(res, { episodes: [...byEp.values()], jobs });
  }
  if (req.method === 'DELETE' && (m = /^\/captions\/([^/]+)$/.exec(p))) {
    run('DELETE FROM caption_tracks WHERE id=?', decodeURIComponent(m[1]));
    return ok(res, { success: true });
  }
  if (req.method === 'POST' && (m = /^\/episodes\/([^/]+)\/captions\/generate$/.exec(p))) {
    const ep = get('SELECT * FROM episodes WHERE id=?', decodeURIComponent(m[1]));
    if (!ep) return err(res, 404, 'NOT_FOUND', 'Episode not found');
    const jobId = captions.enqueueCaptionJob(ep.id, Array.isArray(body.targets) ? body.targets : undefined);
    return ok(res, { jobId }, 201);
  }
  // ---------- TRANSACTIONS LOG ----------
  if (req.method === 'GET' && p === '/transactions') {
    const tLimit = Math.min(parseInt(url.searchParams.get('limit') || '50', 10) || 50, 200);
    const tOffset = Math.max(parseInt(url.searchParams.get('offset') || '0', 10) || 0, 0);
    const conds = [], args = [];
    if (url.searchParams.get('type')) { conds.push('t.type=?'); args.push(url.searchParams.get('type')); }
    if (url.searchParams.get('userId')) { conds.push('t.userId=?'); args.push(url.searchParams.get('userId')); }
    const where = conds.length ? ' WHERE ' + conds.join(' AND ') : '';
    const total = get(`SELECT COUNT(*) c FROM coin_transactions t${where}`, ...args).c;
    const items = all(`SELECT t.*, u.email userEmail, u.name userName FROM coin_transactions t LEFT JOIN users u ON u.id=t.userId${where} ORDER BY t.createdAt DESC, t.rowid DESC LIMIT ? OFFSET ?`, ...args, tLimit, tOffset);
    return ok(res, { items, total, limit: tLimit, offset: tOffset });
  }
  // ---------- REWARD TASKS CRUD ----------
  if (p === '/reward-tasks' || p.startsWith('/reward-tasks/')) {
    const taskJson = (t) => ({ slug: t.slug, title: t.title, description: t.description, coins: t.coins, actionType: t.actionType, target: t.target, sortOrder: t.sortOrder, active: t.active !== 0 });
    if (req.method === 'GET' && p === '/reward-tasks') return ok(res, { items: all('SELECT * FROM reward_tasks ORDER BY sortOrder').map(taskJson) });
    if (req.method === 'POST' && p === '/reward-tasks') {
      if (!body.slug || !body.title) return err(res, 400, 'VALIDATION', 'slug and title are required');
      if (get('SELECT 1 x FROM reward_tasks WHERE slug=?', body.slug)) return err(res, 409, 'CONFLICT', 'A task with this slug already exists');
      run('INSERT INTO reward_tasks(slug,title,description,coins,actionType,sortOrder,target,active) VALUES(?,?,?,?,?,?,?,?)', body.slug, body.title, body.description || null, parseInt(body.coins || '0', 10) || 0, body.actionType || null, parseInt(body.sortOrder || '0', 10) || 0, parseInt(body.target || '1', 10) || 1, body.active === false ? 0 : 1);
      return ok(res, taskJson(get('SELECT * FROM reward_tasks WHERE slug=?', body.slug)), 201);
    }
    if ((m = /^\/reward-tasks\/([^/]+)$/.exec(p))) {
      const slug = decodeURIComponent(m[1]);
      const t = get('SELECT * FROM reward_tasks WHERE slug=?', slug);
      if (!t) return err(res, 404, 'NOT_FOUND', 'Reward task not found');
      if (req.method === 'PATCH') {
        const F = ['title', 'description', 'coins', 'actionType', 'target', 'sortOrder']; const cols = F.filter((f) => body[f] !== undefined);
        if (body.active !== undefined) { cols.push('active'); body.active = body.active ? 1 : 0; }
        if (cols.length) run(`UPDATE reward_tasks SET ${cols.map((c) => c + '=?').join(',')} WHERE slug=?`, ...cols.map((c) => body[c]), slug);
        return ok(res, taskJson(get('SELECT * FROM reward_tasks WHERE slug=?', slug)));
      }
      if (req.method === 'DELETE') { run('DELETE FROM reward_tasks WHERE slug=?', slug); return ok(res, { success: true }); }
    }
  }
  const crud = (table, toJson, fields) => {
    if (req.method === 'GET' && p === `/${table}`) return ok(res, { items: all(`SELECT * FROM ${table === 'genres' ? 'genres' : table} ORDER BY sortOrder`).map(toJson) });
    if (req.method === 'POST' && p === `/${table}`) {
      const id = body.id || (table === 'genres' ? 'genre-' + (body.slug || auth.uid()) : table.slice(0, -1) + '-' + (body.slug || auth.uid()));
      const cols = fields.filter((f) => body[f] !== undefined);
      run(`INSERT INTO ${table}(id,${cols.join(',')}) VALUES(?,${cols.map(() => '?').join(',')})`, id, ...cols.map((c) => body[c]));
      return ok(res, toJson(get(`SELECT * FROM ${table} WHERE id=?`, id)), 201);
    }
    if ((m = new RegExp(`^/${table}/([^/]+)$`).exec(p))) {
      const id = decodeURIComponent(m[1]);
      if (req.method === 'PATCH') { const cols = fields.filter((f) => body[f] !== undefined); if (cols.length) run(`UPDATE ${table} SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, ...cols.map((c) => body[c]), id); return ok(res, toJson(get(`SELECT * FROM ${table} WHERE id=?`, id))); }
      if (req.method === 'DELETE') { run(`DELETE FROM ${table} WHERE id=?`, id); return ok(res, { success: true }); }
    }
    return null;
  };
  const SER_FIELDS = ['slug', 'title', 'synopsis', 'tagline', 'coverImageUrl', 'heroImageUrl', 'trailerUrl', 'gradientStart', 'gradientEnd', 'genreId', 'releaseYear', 'totalEpisodes', 'totalSeasons', 'language', 'dubLanguages', 'isVipOnly', 'isExclusive', 'isNew', 'isHot', 'isCompleted', 'isDubbed', 'viewCount', 'likeCount', 'ratingAvg', 'ratingCount', 'rankScore', 'isFeatured', 'sortOrder', 'tags'];
  const normSeries = (b) => { const o = { ...b }; for (const k of ['isVipOnly', 'isExclusive', 'isNew', 'isHot', 'isCompleted', 'isDubbed', 'isFeatured']) if (o[k] !== undefined) o[k] = o[k] ? 1 : 0; for (const k of ['dubLanguages', 'tags']) if (Array.isArray(o[k])) o[k] = JSON.stringify(o[k]); return o; };
  // genres / series / episodes need body normalization; handle series separately
  if (p.startsWith('/genres')) { const r = crud('genres', genreJson, ['slug', 'name', 'description', 'iconUrl', 'colorHex', 'sortOrder']); if (r !== null) return; }
  if (p.startsWith('/series')) {
    // ----- Cast CRUD: /admin/series/:id/cast[/:castId] (persons + cast_members) -----
    if ((m = /^\/series\/([^/]+)\/cast(?:\/([^/]+))?$/.exec(p))) {
      const sid = decodeURIComponent(m[1]); const castId = m[2] ? decodeURIComponent(m[2]) : null;
      const s = get('SELECT * FROM series WHERE id=? OR slug=?', sid, sid);
      if (!s) return err(res, 404, 'NOT_FOUND', 'Series not found');
      const castJson = (c) => { const per = get('SELECT * FROM persons WHERE id=?', c.personId); return { id: c.id, seriesId: c.seriesId, personId: c.personId, name: per ? per.name : null, personSlug: per ? per.slug : null, gender: per ? per.gender : null, photoUrl: per ? per.imageUrl : null, imageUrl: per ? per.imageUrl : null, characterName: c.characterName, sortOrder: c.sortOrder }; };
      if (req.method === 'GET' && !castId) return ok(res, { items: all('SELECT * FROM cast_members WHERE seriesId=? ORDER BY sortOrder', s.id).map(castJson) });
      if (req.method === 'POST' && !castId) {
        if (!body.name && !body.personId) return err(res, 400, 'VALIDATION', 'name is required');
        let person = body.personId ? get('SELECT * FROM persons WHERE id=?', body.personId) : null;
        if (!person) {
          const base = String(body.name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'person';
          let slug = base; let n = 1; while (get('SELECT 1 x FROM persons WHERE slug=?', slug)) slug = base + '-' + (++n);
          const pid = 'person-' + slug;
          run('INSERT INTO persons(id,slug,name,gender,imageUrl) VALUES(?,?,?,?,?)', pid, slug, body.name, body.gender || null, body.photoUrl || body.imageUrl || null);
          person = get('SELECT * FROM persons WHERE id=?', pid);
        } else if (body.photoUrl || body.imageUrl) run('UPDATE persons SET imageUrl=? WHERE id=?', body.photoUrl || body.imageUrl, person.id);
        const cid = auth.uid();
        run('INSERT INTO cast_members(id,seriesId,personId,characterName,sortOrder) VALUES(?,?,?,?,?)', cid, s.id, person.id, body.characterName || null, parseInt(body.sortOrder || '0', 10) || 0);
        return ok(res, castJson(get('SELECT * FROM cast_members WHERE id=?', cid)), 201);
      }
      if (castId) {
        const c = get('SELECT * FROM cast_members WHERE id=? AND seriesId=?', castId, s.id);
        if (!c) return err(res, 404, 'NOT_FOUND', 'Cast member not found');
        if (req.method === 'PATCH') {
          if (body.characterName !== undefined || body.sortOrder !== undefined) run('UPDATE cast_members SET characterName=COALESCE(?,characterName), sortOrder=COALESCE(?,sortOrder) WHERE id=?', body.characterName !== undefined ? body.characterName : null, body.sortOrder !== undefined ? parseInt(body.sortOrder, 10) : null, castId);
          const per = get('SELECT * FROM persons WHERE id=?', c.personId);
          if (per && (body.name !== undefined || body.photoUrl !== undefined || body.imageUrl !== undefined || body.gender !== undefined))
            run('UPDATE persons SET name=?, imageUrl=?, gender=? WHERE id=?', body.name !== undefined ? body.name : per.name, (body.photoUrl || body.imageUrl) !== undefined ? (body.photoUrl || body.imageUrl) : per.imageUrl, body.gender !== undefined ? body.gender : per.gender, per.id);
          return ok(res, castJson(get('SELECT * FROM cast_members WHERE id=?', castId)));
        }
        if (req.method === 'DELETE') { run('DELETE FROM cast_members WHERE id=?', castId); return ok(res, { success: true }); }
      }
    }
    if (req.method === 'GET' && p === '/series') return ok(res, { items: all('SELECT * FROM series ORDER BY sortOrder').map(seriesJson) });
    if (req.method === 'POST' && p === '/series') { const b = normSeries(body); const id = b.id || 'series-' + (b.slug || auth.uid()); const cols = SER_FIELDS.filter((f) => b[f] !== undefined); run(`INSERT INTO series(id,${cols.join(',')},createdAt) VALUES(?,${cols.map(() => '?').join(',')},?)`, id, ...cols.map((c) => b[c]), now()); return ok(res, seriesJson(get('SELECT * FROM series WHERE id=?', id)), 201); }
    if ((m = /^\/series\/([^/]+)$/.exec(p))) { const id = decodeURIComponent(m[1]); const b = normSeries(body);
      if (req.method === 'PATCH') { const cols = SER_FIELDS.filter((f) => b[f] !== undefined); if (cols.length) run(`UPDATE series SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, ...cols.map((c) => b[c]), id); return ok(res, seriesJson(get('SELECT * FROM series WHERE id=?', id))); }
      if (req.method === 'DELETE') { run('DELETE FROM episodes WHERE seriesId=?', id); run('DELETE FROM series WHERE id=?', id); return ok(res, { success: true }); } }
  }
  if (p.startsWith('/episodes')) {
    if (req.method === 'GET' && p === '/episodes') { const sid = url.searchParams.get('seriesId'); const rows = sid ? all('SELECT * FROM episodes WHERE seriesId=? ORDER BY episodeNumber', sid) : all('SELECT * FROM episodes ORDER BY seriesId, episodeNumber LIMIT 500'); return ok(res, { items: rows.map((e) => ({ ...e, isFree: !!e.isFree, isVipOnly: !!e.isVipOnly, dubs: all('SELECT lang,videoUrl FROM episode_dubs WHERE episodeId=?', e.id) })) }); }
    if (req.method === 'POST' && p === '/episodes') { const id = body.id || auth.uid(); run('INSERT INTO episodes(id,seriesId,seasonId,seasonNumber,episodeNumber,title,description,videoUrl,thumbnailUrl,durationSeconds,isFree,coinCost,isVipOnly,publishedAt,sortOrder) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', id, body.seriesId, body.seasonId || null, body.seasonNumber || 1, body.episodeNumber, body.title || null, body.description || null, body.videoUrl || null, body.thumbnailUrl || null, body.durationSeconds || null, body.isFree ? 1 : 0, body.coinCost || 0, body.isVipOnly ? 1 : 0, body.publishedAt || now(), body.sortOrder || body.episodeNumber || 0); (body.dubs || []).forEach((d) => run('INSERT OR REPLACE INTO episode_dubs(id,episodeId,lang,videoUrl) VALUES(?,?,?,?)', auth.uid(), id, d.lang, d.videoUrl)); if (body.videoUrl && settings.getSetting('captions_auto_generate') && settings.getSetting('captions_enabled')) { try { captions.enqueueCaptionJob(id); } catch (e) { console.error('[captions] auto-generate enqueue failed', e); } } return ok(res, get('SELECT * FROM episodes WHERE id=?', id), 201); }
    if ((m = /^\/episodes\/([^/]+)$/.exec(p))) { const id = decodeURIComponent(m[1]);
      if (req.method === 'PATCH') { const F = ['seriesId', 'seasonId', 'seasonNumber', 'episodeNumber', 'title', 'description', 'videoUrl', 'thumbnailUrl', 'durationSeconds', 'coinCost', 'publishedAt', 'sortOrder']; const cols = F.filter((f) => body[f] !== undefined); if (body.isFree !== undefined) { cols.push('isFree'); body.isFree = body.isFree ? 1 : 0; } if (body.isVipOnly !== undefined) { cols.push('isVipOnly'); body.isVipOnly = body.isVipOnly ? 1 : 0; } if (cols.length) run(`UPDATE episodes SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, ...cols.map((c) => body[c]), id); if (Array.isArray(body.dubs)) { run('DELETE FROM episode_dubs WHERE episodeId=?', id); body.dubs.forEach((d) => run('INSERT INTO episode_dubs(id,episodeId,lang,videoUrl) VALUES(?,?,?,?)', auth.uid(), id, d.lang, d.videoUrl)); } return ok(res, get('SELECT * FROM episodes WHERE id=?', id)); }
      if (req.method === 'DELETE') { run('DELETE FROM episodes WHERE id=?', id); return ok(res, { success: true }); } }
  }
  if (p.startsWith('/home-sections')) {
    if (req.method === 'GET' && p === '/home-sections') return ok(res, { items: all('SELECT * FROM home_sections ORDER BY sortOrder').map((s) => ({ ...s, seriesIds: all('SELECT seriesId FROM home_section_items WHERE sectionId=? ORDER BY sortOrder', s.id).map((r) => r.seriesId) })) });
    if (req.method === 'POST' && p === '/home-sections') { const id = body.id || 'sec-' + (body.slug || auth.uid()); run('INSERT INTO home_sections(id,slug,title,subtitle,sectionType,sortOrder,locale) VALUES(?,?,?,?,?,?,?)', id, body.slug, body.title, body.subtitle || null, body.sectionType, body.sortOrder || 0, body.locale || 'en'); (body.seriesIds || body.items || []).forEach((sid, i) => run('INSERT INTO home_section_items(sectionId,seriesId,sortOrder) VALUES(?,?,?)', id, sid, i + 1)); return ok(res, { id }, 201); }
    if ((m = /^\/home-sections\/([^/]+)$/.exec(p))) { const id = decodeURIComponent(m[1]);
      if (req.method === 'PATCH') { const F = ['slug', 'title', 'subtitle', 'sectionType', 'sortOrder', 'locale']; const cols = F.filter((f) => body[f] !== undefined); if (cols.length) run(`UPDATE home_sections SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, ...cols.map((c) => body[c]), id); if (Array.isArray(body.seriesIds || body.items)) { run('DELETE FROM home_section_items WHERE sectionId=?', id); (body.seriesIds || body.items).forEach((sid, i) => run('INSERT INTO home_section_items(sectionId,seriesId,sortOrder) VALUES(?,?,?)', id, sid, i + 1)); } return ok(res, { success: true }); }
      if (req.method === 'DELETE') { run('DELETE FROM home_section_items WHERE sectionId=?', id); run('DELETE FROM home_sections WHERE id=?', id); return ok(res, { success: true }); } }
  }
  if (req.method === 'GET' && p === '/users') {
    const search = (url.searchParams.get('q') || url.searchParams.get('search') || '').trim();
    const rows = search
      ? all('SELECT * FROM users WHERE email LIKE ? OR name LIKE ? ORDER BY createdAt DESC LIMIT 500', '%' + search + '%', '%' + search + '%')
      : all('SELECT * FROM users ORDER BY createdAt DESC LIMIT 500');
    return ok(res, { items: rows.map((u) => ({ ...userJson(u), devices: all('SELECT * FROM user_devices WHERE userId=?', u.id) })) });
  }
  if (req.method === 'GET' && (m = /^\/users\/([^/]+)\/summary$/.exec(p))) {
    const u = get('SELECT * FROM users WHERE id=?', decodeURIComponent(m[1]));
    if (!u) return err(res, 404, 'NOT_FOUND', 'User not found');
    const cnt = (sql) => get(sql, u.id).c;
    return ok(res, { user: userJson(u),
      favorites: cnt('SELECT COUNT(*) c FROM user_series WHERE userId=? AND favorite=1'),
      following: cnt('SELECT COUNT(*) c FROM user_series WHERE userId=? AND following=1'),
      liked: cnt('SELECT COUNT(*) c FROM user_series WHERE userId=? AND liked=1'),
      historyEntries: cnt('SELECT COUNT(*) c FROM watch_history WHERE userId=?'),
      unlocks: cnt('SELECT COUNT(*) c FROM episode_unlocks WHERE userId=?'),
      coinBalance: u.coinBalance,
      recentTransactions: all('SELECT * FROM coin_transactions WHERE userId=? ORDER BY createdAt DESC, rowid DESC LIMIT 10', u.id) });
  }
  if (req.method === 'DELETE' && (m = /^\/users\/([^/]+)$/.exec(p))) {
    const uidToDelete = decodeURIComponent(m[1]);
    if (!get('SELECT 1 x FROM users WHERE id=?', uidToDelete)) return err(res, 404, 'NOT_FOUND', 'User not found');
    for (const t of ['refresh_tokens', 'user_devices', 'user_series', 'watch_history', 'episode_unlocks', 'coin_transactions', 'checkins', 'user_reward_tasks', 'ad_rewards', 'notifications', 'wheel_spins', 'chest_claims', 'watch_time_daily', 'watch_events', 'user_daily_events', 'mission_claims'])
      run(`DELETE FROM ${t} WHERE userId=?`, uidToDelete);
    run('DELETE FROM users WHERE id=?', uidToDelete);
    return ok(res, { success: true });
  }
  if (req.method === 'POST' && (m = /^\/users\/([^/]+)\/coins$/.exec(p))) { const u = get('SELECT * FROM users WHERE id=?', decodeURIComponent(m[1])); if (!u) return err(res, 404, 'NOT_FOUND', 'User not found'); const bal = grantCoins(u.id, parseInt(body.amount || '0', 10), 'admin_adjust', null); return ok(res, { success: true, balance: bal }); }
  if (req.method === 'POST' && (m = /^\/users\/([^/]+)\/vip$/.exec(p))) { run('UPDATE users SET isPro=? WHERE id=?', body.isVip ? 1 : 0, decodeURIComponent(m[1])); return ok(res, { success: true }); }
  if (req.method === 'GET' && p === '/notifications') return ok(res, { items: all('SELECT * FROM broadcasts ORDER BY createdAt DESC, rowid DESC LIMIT 200') });
  if (req.method === 'POST' && p === '/notifications/broadcast') { const users = all('SELECT id FROM users'); const t = now(); users.forEach((u) => run('INSERT INTO notifications(id,userId,type,title,body,createdAt) VALUES(?,?,?,?,?,?)', auth.uid(), u.id, body.type || 'system', body.title || '', body.body || null, t)); run('INSERT INTO broadcasts(id,title,body,type,sentCount,createdAt) VALUES(?,?,?,?,?,?)', auth.uid(), body.title || '', body.body || null, body.type || 'system', users.length, t); return ok(res, { success: true, sent: users.length }); }
  return err(res, 404, 'NOT_FOUND', `No admin route ${req.method} ${p}`);
}
module.exports = { handle, adminHandle, ok, err };
