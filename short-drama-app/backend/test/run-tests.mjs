// HERO DRAMA / DramaNow backend integration tests.
// Plain node, no deps. Boots the real server on a random port with a TEMP
// database (DB_PATH env override supported by src/db.js), so data/app.db
// is never touched. Writes its own full output to test/LAST_RUN.txt.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const ADMIN_TOKEN = 'test-admin-token-123';
const OUT_FILE = path.join(__dirname, 'LAST_RUN.txt');

const lines = [];
function log(...args) {
  const s = args.join(' ');
  lines.push(s);
  console.log(s);
}

let passed = 0, failed = 0;
const failures = [];
async function testCase(num, name, fn) {
  try {
    await fn();
    passed++;
    log(`PASS ${num}. ${name}`);
  } catch (e) {
    failed++;
    failures.push(`${num}. ${name}: ${e.message}`);
    log(`FAIL ${num}. ${name} -- ${e.message}`);
  }
}
function assert(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); }
function assertEq(actual, expected, msg) {
  if (actual !== expected) throw new Error(`${msg || 'not equal'} (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`);
}

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)); });
    s.on('error', reject);
  });
}

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test-'));
const dbPath = path.join(tmpDir, 'app.db');
const port = await freePort();
const BASE = `http://127.0.0.1:${port}`;
const API = `${BASE}/api/v1`;

const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
  cwd: BACKEND,
  env: {
    ...process.env,
    PORT: String(port),
    DB_PATH: dbPath,
    FIREBASE_AUTH_DEV: '1',
    ADMIN_TOKEN,
    JWT_SECRET: 'test-jwt-secret-123',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
child.stdout.on('data', (d) => { serverLog += d; });
child.stderr.on('data', (d) => { serverLog += d; });

async function req(method, urlPath, { token, admin, adminToken, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (admin) headers['X-Admin-Token'] = ADMIN_TOKEN;
  if (adminToken !== undefined) headers['X-Admin-Token'] = adminToken;
  const res = await fetch(urlPath.startsWith('http') ? urlPath : API + urlPath, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let json = null;
  const text = await res.text();
  try { json = JSON.parse(text); } catch { /* keep null */ }
  return { status: res.status, json, text, headers: res.headers };
}

async function waitForHealth() {
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(`${BASE}/health`);
      if (r.ok) return;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('server did not become healthy. Server log: ' + serverLog);
}

function hasKeyDeep(obj, key) {
  if (!obj || typeof obj !== 'object') return false;
  if (Object.prototype.hasOwnProperty.call(obj, key)) return true;
  return Object.values(obj).some((v) => hasKeyDeep(v, key));
}

// Shared state across cases
let user1, tokens1, user2, tokens2;
let seriesId, freeEp, lockedEp, lockedCost, vipSeriesId, vipEp;
let historySeriesId;

try {
  await waitForHealth();
  log(`Server booted on ${BASE} with temp DB ${dbPath}`);

  // 1. health/root responds
  await testCase(1, 'health/root responds', async () => {
    const h = await req('GET', `${BASE}/health`);
    assertEq(h.status, 200, 'GET /health status');
    assert(h.json && h.json.ok === true, 'health body ok:true');
    const r = await req('GET', `${BASE}/`);
    assertEq(r.status, 200, 'GET / status');
    assert(r.json && r.json.ok === true, 'root body ok:true');
  });

  // 2. dev firebase auth creates user + welcome coin bonus (30)
  await testCase(2, 'dev firebase auth creates user + welcome coin bonus (30)', async () => {
    const r = await req('POST', '/auth/firebase', { body: { idToken: 'test-user-one-token' } });
    assertEq(r.status, 200, 'auth status');
    assert(r.json.data.tokens.accessToken, 'accessToken present');
    assert(r.json.data.tokens.refreshToken, 'refreshToken present');
    assert(r.json.data.user && r.json.data.user.id, 'user present');
    user1 = r.json.data.user; tokens1 = r.json.data.tokens;
    assertEq(user1.coinBalance, 30, 'welcome bonus in auth response coinBalance');
    const coins = await req('GET', '/me/coins', { token: tokens1.accessToken });
    assertEq(coins.status, 200, 'GET /me/coins status');
    assertEq(coins.json.data.balance, 30, 'welcome bonus via GET /me/coins');
  });

  // 3. refresh flow
  await testCase(3, 'refresh flow: new tokens issued; old refresh token rejected', async () => {
    const oldRefresh = tokens1.refreshToken;
    const r = await req('POST', '/auth/refresh', { body: { refreshToken: oldRefresh } });
    assertEq(r.status, 200, 'refresh status');
    assert(r.json.data.tokens.accessToken, 'new accessToken present');
    assert(r.json.data.tokens.refreshToken, 'new refreshToken present');
    assert(r.json.data.tokens.refreshToken !== oldRefresh, 'refresh token rotated');
    tokens1 = r.json.data.tokens;
    const reuse = await req('POST', '/auth/refresh', { body: { refreshToken: oldRefresh } });
    assertEq(reuse.status, 401, 'old refresh token must be rejected');
  });

  // 4. categories
  await testCase(4, 'GET /categories returns genres with required fields', async () => {
    const r = await req('GET', '/categories');
    assertEq(r.status, 200, 'categories status');
    const genres = r.json.data.genres;
    assert(Array.isArray(genres) && genres.length > 0, 'genres non-empty array');
    for (const g of genres) {
      for (const f of ['id', 'slug', 'name']) assert(g[f], `genre missing field ${f}: ${JSON.stringify(g)}`);
    }
  });

  // 5. home sections shape
  await testCase(5, 'GET /home sections shape', async () => {
    const KNOWN = new Set(['featured_hero', 'series_carousel', 'ranking_list', 'new_releases', 'hot_grid', 'vertical_grid', 'genre_grid']);
    const r = await req('GET', '/home');
    assertEq(r.status, 200, 'home status');
    const sections = r.json.data.sections;
    assert(Array.isArray(sections) && sections.length > 0, 'sections non-empty array');
    for (const s of sections) {
      assert(KNOWN.has(s.sectionType), `unknown sectionType: ${s.sectionType}`);
      assert(Array.isArray(s.series), `section ${s.slug} series is not an array`);
    }
  });

  // 6. discover filters
  await testCase(6, 'discover filters popular/latest/ranking all return series[]', async () => {
    for (const f of ['popular', 'latest', 'ranking']) {
      const r = await req('GET', `/discover?filter=${f}`);
      assertEq(r.status, 200, `discover ${f} status`);
      assert(Array.isArray(r.json.data.series) && r.json.data.series.length > 0, `discover ${f} series[] non-empty`);
    }
    const all = await req('GET', '/discover?filter=popular');
    seriesId = all.json.data.series[0].id;
    // Prefer a known non-VIP series for playback/unlock cases:
    const married = all.json.data.series.find((s) => s.slug === 'married-to-the-ceo');
    if (married) seriesId = married.id;
    const vip = all.json.data.series.find((s) => s.slug === 'vip-empire-of-desire');
    assert(vip, 'seeded VIP series present in discover');
    vipSeriesId = vip.id;
    historySeriesId = (all.json.data.series.find((s) => s.id !== seriesId) || all.json.data.series[0]).id;
  });

  // 7. search
  await testCase(7, 'search?q= returns matches', async () => {
    const r = await req('GET', '/search?q=CEO');
    assertEq(r.status, 200, 'search status');
    assert(Array.isArray(r.json.data.series) && r.json.data.series.length > 0, 'search returns matches');
    assert(r.json.data.series.some((s) => /CEO/i.test(s.title)), 'a match mentions CEO in title');
  });

  // 8. series detail shape
  await testCase(8, 'series detail shape', async () => {
    const r = await req('GET', `/series/${seriesId}`, { token: tokens1.accessToken });
    assertEq(r.status, 200, 'series detail status');
    const d = r.json.data;
    for (const k of ['series', 'cast', 'related', 'isFavorite', 'isFollowing', 'isLiked', 'resumeEpisodeNumber']) {
      assert(k in d, `detail missing key ${k}`);
    }
    assert(d.series && d.series.id === seriesId, 'series object matches');
    assert(Array.isArray(d.cast), 'cast is array');
    assert(Array.isArray(d.related), 'related is array');
    assert(typeof d.isFavorite === 'boolean' && typeof d.isFollowing === 'boolean' && typeof d.isLiked === 'boolean', 'flags are booleans');
  });

  // Episodes fixture for cases 9-14
  {
    const eps = await req('GET', `/series/${seriesId}/episodes`, { token: tokens1.accessToken });
    const list = eps.json.data.episodes;
    freeEp = list.find((e) => e.isFree);
    lockedEp = list.find((e) => !e.isFree && !e.isVipOnly);
    lockedCost = lockedEp ? lockedEp.coinCost : null;
    const vipEps = await req('GET', `/series/${vipSeriesId}/episodes`, { token: tokens1.accessToken });
    vipEp = vipEps.json.data.episodes[0];
  }

  // 9. episodes list contains NO videoUrl
  await testCase(9, 'episodes list contains NO videoUrl field anywhere', async () => {
    assert(freeEp && lockedEp, 'episode fixtures found');
    const r = await req('GET', `/series/${seriesId}/episodes`, { token: tokens1.accessToken });
    assertEq(r.status, 200, 'episodes status');
    assert(Array.isArray(r.json.data.episodes) && r.json.data.episodes.length > 0, 'episodes non-empty');
    assert(!hasKeyDeep(r.json, 'videoUrl'), 'videoUrl key found in episodes response');
    assert(!r.text.includes('"videoUrl"'), 'videoUrl string found in raw episodes response');
  });

  // 10. playback free episode
  await testCase(10, 'playback free episode -> 200 with videoUrl', async () => {
    const r = await req('GET', `/episodes/${freeEp.id}/playback`, { token: tokens1.accessToken });
    assertEq(r.status, 200, 'free playback status');
    assert(typeof r.json.data.videoUrl === 'string' && r.json.data.videoUrl.length > 0, 'videoUrl present');
  });

  // 11. playback locked coin episode -> 403
  await testCase(11, 'playback locked coin episode -> 403', async () => {
    const r = await req('GET', `/episodes/${lockedEp.id}/playback`, { token: tokens1.accessToken });
    assertEq(r.status, 403, 'locked playback status');
  });

  // 12. unlock with insufficient balance -> INSUFFICIENT_COINS
  await testCase(12, 'unlock with insufficient balance -> INSUFFICIENT_COINS', async () => {
    // Fresh user (welcome balance 30) spends it on one locked episode,
    // leaving balance 0, then tries another locked episode.
    const a = await req('POST', '/auth/firebase', { body: { idToken: 'test-user-two-token' } });
    assertEq(a.status, 200, 'user2 auth status');
    user2 = a.json.data.user; tokens2 = a.json.data.tokens;
    const eps = await req('GET', `/series/${seriesId}/episodes`, { token: tokens2.accessToken });
    const locked = eps.json.data.episodes.filter((e) => !e.isFree && !e.isVipOnly);
    assert(locked.length >= 2, 'need at least 2 locked episodes');
    const spend = await req('POST', `/episodes/${locked[0].id}/unlock`, { token: tokens2.accessToken });
    assertEq(spend.status, 200, 'user2 first unlock should succeed (spend welcome coins)');
    const bal = await req('GET', '/me/coins', { token: tokens2.accessToken });
    assert(bal.json.data.balance < locked[1].coinCost, `balance ${bal.json.data.balance} should be below cost ${locked[1].coinCost}`);
    const r = await req('POST', `/episodes/${locked[1].id}/unlock`, { token: tokens2.accessToken });
    assert(r.json.error && r.json.error.code === 'INSUFFICIENT_COINS', `expected INSUFFICIENT_COINS, got status ${r.status} body ${r.text}`);
  });

  // 13. admin grant -> unlock succeeds -> balance decreased -> playback 200
  await testCase(13, 'grant coins via admin -> unlock succeeds -> balance decreased by coinCost -> playback 200', async () => {
    const grant = await req('POST', `/admin/users/${user1.id}/coins`, { admin: true, body: { amount: 100 } });
    assertEq(grant.status, 200, 'admin grant status');
    const before = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    const unlock = await req('POST', `/episodes/${lockedEp.id}/unlock`, { token: tokens1.accessToken });
    assertEq(unlock.status, 200, `unlock status (body ${unlock.text})`);
    assert(unlock.json.data.success === true, 'unlock success');
    const after = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    assertEq(after, before - lockedCost, 'balance decreased by coinCost');
    const play = await req('GET', `/episodes/${lockedEp.id}/playback`, { token: tokens1.accessToken });
    assertEq(play.status, 200, 'playback after unlock status');
    assert(play.json.data.videoUrl, 'videoUrl after unlock');
  });

  // 14. VIP-only episode
  await testCase(14, 'VIP-only episode: 403 for non-VIP; admin sets VIP -> playback 200', async () => {
    assert(vipEp, 'VIP episode fixture found');
    const denied = await req('GET', `/episodes/${vipEp.id}/playback`, { token: tokens1.accessToken });
    assertEq(denied.status, 403, 'non-VIP playback of VIP episode');
    const setVip = await req('POST', `/admin/users/${user1.id}/vip`, { admin: true, body: { isVip: true } });
    assertEq(setVip.status, 200, 'admin set VIP status');
    const play = await req('GET', `/episodes/${vipEp.id}/playback`, { token: tokens1.accessToken });
    assertEq(play.status, 200, `VIP playback status (body ${play.text})`);
    assert(play.json.data.videoUrl, 'VIP videoUrl present');
  });

  // 15. checkin idempotent per day
  await testCase(15, 'checkin: first claim pays; second claim same day does NOT double-pay', async () => {
    const before = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    const first = await req('POST', '/rewards/checkin', { token: tokens1.accessToken, body: {} });
    assertEq(first.status, 200, 'checkin status');
    assert(first.json.data.success === true && first.json.data.coins > 0, `first checkin pays (body ${first.text})`);
    const mid = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    assertEq(mid, before + first.json.data.coins, 'balance increased by checkin coins');
    const second = await req('POST', '/rewards/checkin', { token: tokens1.accessToken, body: {} });
    assertEq(second.status, 200, 'second checkin status');
    assert(second.json.data.success === false || second.json.data.coins === 0, 'second checkin must not pay');
    const after = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    assertEq(after, mid, 'balance unchanged after second checkin');
  });

  // 16. reward task complete once
  await testCase(16, 'reward task complete: once pays, second time does not', async () => {
    const before = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    const first = await req('POST', '/rewards/tasks/rate_app/complete', { token: tokens1.accessToken, body: {} });
    assertEq(first.status, 200, 'task complete status');
    assert(first.json.data.success === true && first.json.data.coins > 0, `first task completion pays (body ${first.text})`);
    const mid = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    assertEq(mid, before + first.json.data.coins, 'balance increased by task coins');
    const second = await req('POST', '/rewards/tasks/rate_app/complete', { token: tokens1.accessToken, body: {} });
    assert(second.json.data.success === false || second.json.data.coins === 0, 'second task completion must not pay');
    const after = (await req('GET', '/me/coins', { token: tokens1.accessToken })).json.data.balance;
    assertEq(after, mid, 'balance unchanged after second task completion');
  });

  // 17. favorite -> my-list
  await testCase(17, 'favorite a series -> appears in GET /me/library/my-list', async () => {
    const fav = await req('POST', `/series/${seriesId}/favorite`, { token: tokens1.accessToken, body: { add: true } });
    assertEq(fav.status, 200, 'favorite status');
    const list = await req('GET', '/me/library/my-list', { token: tokens1.accessToken });
    assertEq(list.status, 200, 'my-list status');
    assert(Array.isArray(list.json.data.series) && list.json.data.series.some((s) => s.id === seriesId), 'favorited series in my-list');
  });

  // 18. watch-history -> history + continue
  await testCase(18, 'POST /me/watch-history -> appears in history and in continue (incomplete)', async () => {
    const eps = await req('GET', `/series/${historySeriesId}/episodes`, { token: tokens1.accessToken });
    const ep = eps.json.data.episodes[0];
    const post = await req('POST', '/me/watch-history', {
      token: tokens1.accessToken,
      body: { seriesId: historySeriesId, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds: 30, durationSeconds: 100, completed: false },
    });
    assertEq(post.status, 200, 'watch-history POST status');
    const hist = await req('GET', '/me/library/history', { token: tokens1.accessToken });
    assertEq(hist.status, 200, 'history status');
    assert(Array.isArray(hist.json.data.history) && hist.json.data.history.some((h) => h.series && h.series.id === historySeriesId), 'series in history');
    const cont = await req('GET', '/me/library/continue', { token: tokens1.accessToken });
    assertEq(cont.status, 200, 'continue status');
    assert(Array.isArray(cont.json.data.history) && cont.json.data.history.some((h) => h.series && h.series.id === historySeriesId), 'series in continue');
  });

  // 19. notifications broadcast / read
  await testCase(19, 'notifications: admin broadcast -> unread >=1 -> read -> unread 0', async () => {
    const bc = await req('POST', '/admin/notifications/broadcast', { admin: true, body: { title: 'Test Broadcast XYZ', body: 'Hello testers' } });
    assertEq(bc.status, 200, 'broadcast status');
    const list = await req('GET', '/notifications', { token: tokens1.accessToken });
    assertEq(list.status, 200, 'notifications status');
    assert(list.json.data.items.some((n) => n.title === 'Test Broadcast XYZ'), 'broadcast visible to user');
    assert(list.json.data.unread >= 1, `unread >= 1 (got ${list.json.data.unread})`);
    const read = await req('POST', '/notifications/read', { token: tokens1.accessToken, body: {} });
    assertEq(read.status, 200, 'notifications/read status');
    const after = await req('GET', '/notifications', { token: tokens1.accessToken });
    assertEq(after.json.data.unread, 0, 'unread 0 after read-all');
  });

  // 20. admin genre create/delete reflected in /categories
  await testCase(20, 'admin genre create -> reflected in GET /categories -> admin delete -> gone', async () => {
    const slug = 'test-genre-xyz';
    const create = await req('POST', '/admin/genres', { admin: true, body: { slug, name: 'Test Genre XYZ', description: 'Created by tests', sortOrder: 99 } });
    assert(create.status === 200 || create.status === 201, `genre create status ${create.status} (body ${create.text})`);
    const genreId = create.json.data.id;
    assert(genreId, 'created genre has id');
    const cats1 = await req('GET', '/categories');
    assert(cats1.json.data.genres.some((g) => g.slug === slug), 'new genre in /categories');
    const del = await req('DELETE', `/admin/genres/${genreId}`, { admin: true });
    assertEq(del.status, 200, 'genre delete status');
    const cats2 = await req('GET', '/categories');
    assert(!cats2.json.data.genres.some((g) => g.slug === slug), 'genre gone from /categories after delete');
  });

  // 21. admin stats
  await testCase(21, 'GET /admin/stats returns the counters', async () => {
    const r = await req('GET', '/admin/stats', { admin: true });
    assertEq(r.status, 200, 'stats status');
    for (const k of ['users', 'series', 'episodes', 'views', 'coinsGranted']) {
      assert(typeof r.json.data[k] === 'number', `stats counter ${k} is a number`);
    }
    assert(r.json.data.users >= 2 && r.json.data.series > 0 && r.json.data.episodes > 0, 'stats counters plausible');
  });

  // 22. admin auth rejection
  await testCase(22, 'admin endpoints reject missing/wrong X-Admin-Token (401)', async () => {
    const missing = await req('GET', '/admin/stats');
    assertEq(missing.status, 401, 'missing admin token -> 401');
    const wrong = await req('GET', '/admin/stats', { adminToken: 'wrong-token' });
    assertEq(wrong.status, 401, 'wrong admin token -> 401');
  });

  // ================= EXTENDED: full-control-panel admin surface =================
  let origSettings = null;
  const getSettings = async () => {
    const r = await req('GET', '/admin/settings', { admin: true });
    assertEq(r.status, 200, 'GET /admin/settings status');
    return r.json.data.settings;
  };
  const patchSettings = async (patch) => req('PATCH', '/admin/settings', { admin: true, body: patch });

  // 23. admin settings object
  await testCase(23, 'GET /admin/settings returns the settings object', async () => {
    origSettings = await getSettings();
    const s = origSettings;
    assert(s && typeof s === 'object', 'settings object present');
    assertEq(s.welcome_coin_bonus, 30, 'welcome_coin_bonus default');
    assertEq(s.episode_unlock_coin_cost, 30, 'episode_unlock_coin_cost default');
    assertEq(s.maintenance_mode, false, 'maintenance_mode default false');
    assert(['disabled', 'premium_content', 'all_playback'].includes(s.premium_playback_mode), `premium_playback_mode valid (got ${s.premium_playback_mode})`);
    assertEq(s.ads_enabled, true, 'ads_enabled default true');
    assert(Array.isArray(s.checkin_amounts) && s.checkin_amounts.length === 7 && s.checkin_amounts.every((n) => typeof n === 'number'), 'checkin_amounts is an array of 7 numbers');
  });

  // 24. episode_unlock_coin_cost setting drives unlock deduction
  await testCase(24, 'PATCH episode_unlock_coin_cost=5 -> fresh user unlock deducts 5 (not 30); restored after', async () => {
    assert(origSettings, 'origSettings captured in case 23');
    let createdEpId = null;
    try {
      const patch = await patchSettings({ episode_unlock_coin_cost: 5 });
      assertEq(patch.status, 200, `PATCH settings status (body ${patch.text})`);
      assertEq(patch.json.data.settings.episode_unlock_coin_cost, 5, 'setting applied');
      // Seeded episodes carry an explicit per-episode coinCost which takes
      // precedence (cost = episode.coinCost || settings.episode_unlock_coin_cost),
      // so exercise the settings-priced path with an episode that has no
      // explicit price (coinCost 0).
      const ep = await req('POST', '/admin/episodes', {
        admin: true,
        body: { seriesId, episodeNumber: 99, title: 'Settings Cost Episode', videoUrl: 'https://example.com/settings-cost.mp4', isFree: false, coinCost: 0 },
      });
      assertEq(ep.status, 201, `admin episode create status (body ${ep.text})`);
      createdEpId = ep.json.data.id;
      assert(createdEpId, 'created episode id');
      const a = await req('POST', '/auth/firebase', { body: { idToken: 'test-user-three-token' } });
      assertEq(a.status, 200, 'user3 auth status');
      const t3 = a.json.data.tokens.accessToken;
      const balBefore = (await req('GET', '/me/coins', { token: t3 })).json.data.balance;
      assertEq(balBefore, 30, 'user3 starts with welcome balance 30');
      const unlock = await req('POST', `/episodes/${createdEpId}/unlock`, { token: t3, body: {} });
      assertEq(unlock.status, 200, `unlock status (body ${unlock.text})`);
      assertEq(unlock.json.data.coins, 5, 'unlock charged the settings cost 5');
      const balAfter = (await req('GET', '/me/coins', { token: t3 })).json.data.balance;
      assertEq(balAfter, balBefore - 5, 'balance math: 30 - 5 = 25');
    } finally {
      await patchSettings({ episode_unlock_coin_cost: origSettings.episode_unlock_coin_cost });
      if (createdEpId) await req('DELETE', `/admin/episodes/${createdEpId}`, { admin: true });
    }
    const restored = await getSettings();
    assertEq(restored.episode_unlock_coin_cost, origSettings.episode_unlock_coin_cost, 'unlock cost setting restored');
  });

  // 25. checkin_amounts setting reflected in GET /rewards for a new user
  await testCase(25, 'PATCH checkin_amounts day-1=77 -> new user GET /rewards days[0].coins == 77; restored after', async () => {
    assert(origSettings, 'origSettings captured in case 23');
    const patched = [...origSettings.checkin_amounts];
    patched[0] = 77;
    try {
      const patch = await patchSettings({ checkin_amounts: patched });
      assertEq(patch.status, 200, `PATCH checkin_amounts status (body ${patch.text})`);
      const a = await req('POST', '/auth/firebase', { body: { idToken: 'test-user-four-token' } });
      assertEq(a.status, 200, 'user4 auth status');
      const rewards = await req('GET', '/rewards', { token: a.json.data.tokens.accessToken });
      assertEq(rewards.status, 200, 'GET /rewards status');
      assert(Array.isArray(rewards.json.data.days) && rewards.json.data.days.length === 7, 'rewards days[7]');
      assertEq(rewards.json.data.days[0].coins, 77, 'days[0].coins reflects patched checkin_amounts');
    } finally {
      await patchSettings({ checkin_amounts: origSettings.checkin_amounts });
    }
    const restored = await getSettings();
    assertEq(restored.checkin_amounts[0], origSettings.checkin_amounts[0], 'checkin_amounts restored');
  });

  // 26. maintenance mode
  await testCase(26, 'maintenance mode: app endpoints 503, admin still 200, restore -> app works again', async () => {
    try {
      const on = await patchSettings({ maintenance_mode: true });
      assertEq(on.status, 200, `PATCH maintenance on status (body ${on.text})`);
      assertEq(on.json.data.settings.maintenance_mode, true, 'maintenance_mode on');
      const withToken = await req('GET', '/categories', { token: tokens1.accessToken });
      assertEq(withToken.status, 503, 'GET /categories (user token) during maintenance');
      assert(withToken.json && withToken.json.error && withToken.json.error.code, '503 has error envelope');
      const noToken = await req('GET', '/categories');
      assertEq(noToken.status, 503, 'GET /categories (unauthenticated) during maintenance');
      const adminStats = await req('GET', '/admin/stats', { admin: true });
      assertEq(adminStats.status, 200, 'admin endpoints still respond during maintenance');
    } finally {
      await patchSettings({ maintenance_mode: false });
    }
    const after = await req('GET', '/categories', { token: tokens1.accessToken });
    assertEq(after.status, 200, 'GET /categories works again after maintenance off');
  });

  // 27. reward tasks admin CRUD
  await testCase(27, 'reward tasks admin CRUD: create -> visible in GET /rewards -> delete -> gone', async () => {
    const slug = 'test_task_xyz';
    const create = await req('POST', '/admin/reward-tasks', {
      admin: true,
      body: { slug, title: 'Test Task XYZ', description: 'Created by tests', coins: 15, actionType: 'custom_test', target: 1, sortOrder: 99 },
    });
    assert(create.status === 200 || create.status === 201, `task create status ${create.status} (body ${create.text})`);
    const rewards1 = await req('GET', '/rewards', { token: tokens1.accessToken });
    assert(rewards1.json.data.tasks.some((t) => t.slug === slug), 'created task appears in GET /rewards tasks');
    const del = await req('DELETE', `/admin/reward-tasks/${slug}`, { admin: true });
    assertEq(del.status, 200, `task delete status (body ${del.text})`);
    const rewards2 = await req('GET', '/rewards', { token: tokens1.accessToken });
    assert(!rewards2.json.data.tasks.some((t) => t.slug === slug), 'task gone from GET /rewards after delete');
  });

  // 28. broadcast list in admin
  await testCase(28, 'GET /admin/notifications includes the broadcast from case 19', async () => {
    const r = await req('GET', '/admin/notifications', { admin: true });
    assertEq(r.status, 200, `admin notifications status (body ${r.text.slice(0, 200)})`);
    const items = r.json.data.items || r.json.data.notifications || [];
    assert(Array.isArray(items) && items.some((n) => n.title === 'Test Broadcast XYZ'), 'broadcast listed in admin notifications');
  });

  // 29. admin transactions include the case-13 coin grant
  await testCase(29, 'GET /admin/transactions includes the coin-grant transaction from case 13', async () => {
    const r = await req('GET', '/admin/transactions?limit=200', { admin: true });
    assertEq(r.status, 200, `admin transactions status (body ${r.text.slice(0, 200)})`);
    const items = r.json.data.items || [];
    assert(Array.isArray(items) && items.length > 0, 'transactions non-empty');
    assert(items.some((t) => t.userId === user1.id && t.amount === 100 && t.type === 'admin_adjust'),
      'admin_adjust +100 grant for user1 present in transactions');
  });

  // 30. premium_playback_mode all_playback gates even free episodes
  await testCase(30, 'premium_playback_mode=all_playback -> free playback 403 for non-VIP; back to disabled -> 200; original restored', async () => {
    assert(origSettings, 'origSettings captured in case 23');
    // user2 is a non-VIP user (case 12); user1 was made VIP in case 14.
    try {
      const on = await patchSettings({ premium_playback_mode: 'all_playback' });
      assertEq(on.status, 200, `PATCH all_playback status (body ${on.text})`);
      const denied = await req('GET', `/episodes/${freeEp.id}/playback`, { token: tokens2.accessToken });
      assertEq(denied.status, 403, 'free-episode playback for non-VIP under all_playback');
      const off = await patchSettings({ premium_playback_mode: 'disabled' });
      assertEq(off.status, 200, 'PATCH disabled status');
      const allowed = await req('GET', `/episodes/${freeEp.id}/playback`, { token: tokens2.accessToken });
      assertEq(allowed.status, 200, 'free-episode playback after returning to disabled');
      assert(allowed.json.data.videoUrl, 'videoUrl present after disabled');
    } finally {
      await patchSettings({ premium_playback_mode: origSettings.premium_playback_mode });
    }
    const restored = await getSettings();
    assertEq(restored.premium_playback_mode, origSettings.premium_playback_mode, 'premium_playback_mode restored to original');
  });

  // ================= PHASE 2: config / economy / captions =================
  const freshUser = async (tag) => {
    const a = await req('POST', '/auth/firebase', { body: { idToken: `phase2-${tag}-token` } });
    assertEq(a.status, 200, `fresh user ${tag} auth`);
    return a.json.data;
  };
  const balanceOf = async (token) => (await req('GET', '/me/coins', { token })).json.data.balance;
  const seriesEpisodes = async (token, sid) => (await req('GET', `/series/${sid}/episodes`, { token })).json.data.episodes;
  const postWatch = async (token, sid, ep, positionSeconds, durationSeconds = 1000) => {
    const r = await req('POST', '/me/watch-history', { token, body: { seriesId: sid, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds, durationSeconds, completed: false } });
    assertEq(r.status, 200, 'watch-history post in phase2');
    return r;
  };

  // 31. GET /config shape + settings PATCH reflects
  await testCase(31, 'GET /config shape (features/player/visual/economy) + PATCH player_pip=false reflects', async () => {
    const r = await req('GET', '/config');
    assertEq(r.status, 200, 'config status (no auth)');
    const c = r.json.data;
    assertEq(c.maintenanceMode, false, 'config maintenanceMode');
    assert(c.premiumPlaybackMode, 'config premiumPlaybackMode present');
    for (const k of ['swipe_next_episode', 'double_tap_seek', 'long_press_2x', 'edge_brightness_volume', 'speed_menu', 'quality_selector', 'auto_next', 'binge_mode', 'pip', 'scrub_chapters', 'skip_intro', 'lock_controls', 'sleep_timer', 'share_moment', 'captions', 'wheel', 'chests', 'missions', 'referrals', 'watch_time', 'ads'])
      assertEq(typeof c.features[k], 'boolean', `config features.${k} is boolean`);
    assertEq(c.player.skipIntroWindowSeconds, 90, 'skipIntroWindowSeconds');
    assertEq(c.player.skipIntroToSeconds, 75, 'skipIntroToSeconds');
    assertEq(c.player.autoNextCountdownSeconds, 5, 'autoNextCountdownSeconds');
    assertEq(c.visual.defaultThemePreset, 6, 'defaultThemePreset');
    assertEq(c.visual.confettiEnabled, true, 'confettiEnabled');
    assertEq(c.economy.episodeUnlockCoinCost, 30, 'config episodeUnlockCoinCost');
    assertEq(c.economy.wheelFreeSpinsPerDay, 3, 'config wheelFreeSpinsPerDay');
    try {
      await patchSettings({ player_pip: false });
      const r2 = await req('GET', '/config');
      assertEq(r2.json.data.features.pip, false, 'features.pip reflects PATCH');
    } finally { await patchSettings({ player_pip: true }); }
  });

  // 32. wheel spin
  await testCase(32, 'wheel: free spin shape, free spins exhaust at setting=1, paid spin deducts cost, insufficient -> 402', async () => {
    const u = await freshUser('wheel');
    const t = u.tokens.accessToken;
    try {
      await patchSettings({ wheel_free_spins_per_day: 1 });
      const rw = await req('GET', '/rewards', { token: t });
      assertEq(rw.json.data.wheel.spinsLeft, 1, 'wheel spinsLeft starts at patched free/day');
      assert(Array.isArray(rw.json.data.wheel.segments) && rw.json.data.wheel.segments.length === 8, 'wheel segments in /rewards');
      const b0 = await balanceOf(t);
      const spin1 = await req('POST', '/rewards/wheel/spin', { token: t, body: {} });
      assertEq(spin1.status, 200, `free spin status (body ${spin1.text})`);
      assert(spin1.json.data.success === true && Number.isInteger(spin1.json.data.segmentIndex), 'spin shape success+segmentIndex');
      assertEq(spin1.json.data.spinsLeft, 0, 'free spins exhausted after 1 (setting=1)');
      assertEq(await balanceOf(t), b0 + spin1.json.data.coins, 'balance = before + free spin winnings');
      const b1 = await balanceOf(t);
      const spin2 = await req('POST', '/rewards/wheel/spin', { token: t, body: {} });
      assertEq(spin2.status, 200, `paid spin status (body ${spin2.text})`);
      assertEq(await balanceOf(t), b1 - 20 + spin2.json.data.coins, 'paid spin deducts wheel_extra_spin_cost 20 then pays winnings');
      await patchSettings({ wheel_extra_spin_cost: 100000 });
      const spin3 = await req('POST', '/rewards/wheel/spin', { token: t, body: {} });
      assertEq(spin3.status, 402, 'insufficient balance for paid spin -> 402');
      assertEq(spin3.json.error.code, 'INSUFFICIENT_COINS', '402 code INSUFFICIENT_COINS');
    } finally {
      await patchSettings({ wheel_free_spins_per_day: 3, wheel_extra_spin_cost: 20 });
    }
  });

  // 33. chests
  await testCase(33, 'chests: claim before unlock -> 403; watch 3 distinct episodes -> claim pays 15; second -> 409', async () => {
    const u = await freshUser('chest');
    const t = u.tokens.accessToken;
    const early = await req('POST', '/rewards/chests/chest_3/claim', { token: t, body: {} });
    assertEq(early.status, 403, 'chest claim before unlock -> 403');
    assertEq(early.json.error.code, 'CHEST_LOCKED', 'CHEST_LOCKED code');
    const eps = await seriesEpisodes(t, seriesId);
    for (let i = 0; i < 3; i++) await postWatch(t, seriesId, eps[i], 60);
    const rw = await req('GET', '/rewards', { token: t });
    const chest = rw.json.data.chests.find((c) => c.id === 'chest_3');
    assert(chest && chest.unlocked === true && chest.claimed === false, 'chest_3 unlocked after 3 episodes');
    const b0 = await balanceOf(t);
    const claim = await req('POST', '/rewards/chests/chest_3/claim', { token: t, body: {} });
    assertEq(claim.status, 200, `chest claim status (body ${claim.text})`);
    assertEq(claim.json.data.coins, 15, 'chest_3 pays fixed 15');
    assertEq(await balanceOf(t), b0 + 15, 'balance increased by chest coins');
    const again = await req('POST', '/rewards/chests/chest_3/claim', { token: t, body: {} });
    assertEq(again.status, 409, 'second chest claim -> 409');
  });

  // 34. watch-time claim + daily cap
  await testCase(34, 'watch-time: >=10 min accrual -> claim pays 10; second claim pays 0; daily cap respected', async () => {
    const u = await freshUser('watchtime');
    const t = u.tokens.accessToken;
    const eps = await seriesEpisodes(t, seriesId);
    await postWatch(t, seriesId, eps[0], 600, 600);
    const rw = await req('GET', '/rewards', { token: t });
    assert(rw.json.data.watchTime.minutesToday >= 10, `minutesToday >= 10 (got ${rw.json.data.watchTime.minutesToday})`);
    assertEq(rw.json.data.watchTime.claimableCoins, 10, 'claimable = 1 block x 10 coins');
    const b0 = await balanceOf(t);
    const claim = await req('POST', '/rewards/watch-time/claim', { token: t, body: {} });
    assertEq(claim.status, 200, 'watch-time claim status');
    assertEq(claim.json.data.coins, 10, 'watch-time claim pays 10');
    assertEq(await balanceOf(t), b0 + 10, 'balance increased by watch-time coins');
    const second = await req('POST', '/rewards/watch-time/claim', { token: t, body: {} });
    assertEq(second.status, 200, 'second watch-time claim status (ad-style tolerance)');
    assert(second.json.data.success === false && second.json.data.coins === 0, 'second immediate claim pays 0');
    // Daily cap: cap=5, fresh user accrues a full block but can only claim 5.
    try {
      await patchSettings({ watch_time_daily_cap_coins: 5 });
      const u2 = await freshUser('watchcap');
      const t2 = u2.tokens.accessToken;
      const eps2 = await seriesEpisodes(t2, seriesId);
      await postWatch(t2, seriesId, eps2[0], 600, 600);
      const rw2 = await req('GET', '/rewards', { token: t2 });
      assertEq(rw2.json.data.watchTime.claimableCoins, 5, 'claimable clamped to daily cap 5');
      const c2 = await req('POST', '/rewards/watch-time/claim', { token: t2, body: {} });
      assertEq(c2.json.data.coins, 5, 'claim pays capped 5');
    } finally { await patchSettings({ watch_time_daily_cap_coins: 100 }); }
  });

  // 35. missions
  await testCase(35, 'missions: watch_3_episodes progress 3 after 3 episodes; claim pays 20 once; second -> 409', async () => {
    const u = await freshUser('mission');
    const t = u.tokens.accessToken;
    const eps = await seriesEpisodes(t, seriesId);
    for (let i = 0; i < 3; i++) await postWatch(t, seriesId, eps[i], 30);
    const rw = await req('GET', '/rewards', { token: t });
    const ms = rw.json.data.missions.find((x) => x.slug === 'watch_3_episodes');
    assert(ms, 'watch_3_episodes mission listed');
    assertEq(ms.progress, 3, 'mission progress = 3');
    assertEq(ms.completed, true, 'mission completed flag');
    const b0 = await balanceOf(t);
    const claim = await req('POST', '/rewards/missions/watch_3_episodes/claim', { token: t, body: {} });
    assertEq(claim.status, 200, `mission claim status (body ${claim.text})`);
    assertEq(claim.json.data.coins, 20, 'mission pays 20');
    assertEq(await balanceOf(t), b0 + 20, 'balance increased by mission coins');
    const again = await req('POST', '/rewards/missions/watch_3_episodes/claim', { token: t, body: {} });
    assertEq(again.status, 409, 'second mission claim -> 409');
  });

  // 36. referrals
  await testCase(36, 'referral: B uses A code -> both +50; reuse -> 409; self-code -> 400', async () => {
    const a = await freshUser('ref-a');
    const meA = await req('GET', '/auth/me', { token: a.tokens.accessToken });
    const code = meA.json.data.user.referralCode;
    assert(code && code.startsWith('HD'), `referralCode present on /auth/me (got ${code})`);
    assert(typeof meA.json.data.user.xp === 'number' && typeof meA.json.data.user.level === 'number', 'user gains xp/level fields');
    const b = await freshUser('ref-b');
    const balA0 = await balanceOf(a.tokens.accessToken);
    const balB0 = await balanceOf(b.tokens.accessToken);
    const apply = await req('POST', '/auth/referral', { token: b.tokens.accessToken, body: { code } });
    assertEq(apply.status, 200, `referral apply status (body ${apply.text})`);
    assertEq(apply.json.data.coins, 50, 'referee bonus 50');
    assertEq(await balanceOf(b.tokens.accessToken), balB0 + 50, 'referee balance +50');
    assertEq(await balanceOf(a.tokens.accessToken), balA0 + 50, 'referrer balance +50');
    const reuse = await req('POST', '/auth/referral', { token: b.tokens.accessToken, body: { code } });
    assertEq(reuse.status, 409, 'referral reuse -> 409');
    const c = await freshUser('ref-c');
    const meC = await req('GET', '/auth/me', { token: c.tokens.accessToken });
    const self = await req('POST', '/auth/referral', { token: c.tokens.accessToken, body: { code: meC.json.data.user.referralCode } });
    assertEq(self.status, 400, 'self-code -> 400');
  });

  // 37. event multiplier on checkin
  await testCase(37, 'event multiplier x2 (admin-created, active now) doubles checkin; deactivated after', async () => {
    const s = await getSettings();
    const base = s.checkin_amounts[0];
    const nowIso = new Date().toISOString();
    const ev = await req('POST', '/admin/events', { admin: true, body: { name: 'Test Double Event', multiplier: 2, startsAt: new Date(Date.now() - 60000).toISOString(), endsAt: new Date(Date.now() + 3600000).toISOString(), active: true } });
    assertEq(ev.status, 201, `event create status (body ${ev.text})`);
    const evId = ev.json.data.id;
    try {
      const u = await freshUser('event');
      const t = u.tokens.accessToken;
      const rw = await req('GET', '/rewards', { token: t });
      assert(rw.json.data.activeEvent && rw.json.data.activeEvent.multiplier === 2, 'activeEvent exposed in /rewards');
      const ci = await req('POST', '/rewards/checkin', { token: t, body: {} });
      assertEq(ci.status, 200, 'checkin under event status');
      // Fresh user: level 1 (+0), streakBeforeToday 0 (+0) -> expected = base * 2.
      assertEq(ci.json.data.coins, base * 2, `checkin doubled: base ${base} x2 = ${base * 2} (got ${ci.json.data.coins}, now ${nowIso})`);
    } finally {
      const off = await req('PATCH', `/admin/events/${evId}`, { admin: true, body: { active: false } });
      assertEq(off.status, 200, 'event deactivate status');
    }
    const u2 = await freshUser('event-off');
    const rw2 = await req('GET', '/rewards', { token: u2.tokens.accessToken });
    assertEq(rw2.json.data.activeEvent, null, 'activeEvent null after deactivation');
  });

  // 38. captions demo job end-to-end
  let captionEpId = null;
  await testCase(38, 'captions: admin generate (demo) -> job done -> tracks ready orig+ar+en; list has NO videoUrl; raw VTT served', async () => {
    captionEpId = freeEp.id;
    const gen = await req('POST', `/admin/episodes/${captionEpId}/captions/generate`, { admin: true, body: {} });
    assertEq(gen.status, 201, `caption generate status (body ${gen.text})`);
    const jobId = gen.json.data.jobId;
    assert(jobId, 'jobId returned');
    let job = null;
    for (let i = 0; i < 75; i++) {
      const adm = await req('GET', '/admin/captions', { admin: true });
      job = (adm.json.data.jobs || []).find((j) => j.id === jobId);
      if (job && (job.status === 'done' || job.status === 'failed')) break;
      await new Promise((r) => setTimeout(r, 200));
    }
    assert(job, 'caption job found in admin list');
    assertEq(job.status, 'done', `caption job done (error: ${job.error})`);
    const list = await req('GET', `/episodes/${captionEpId}/captions`, { token: tokens1.accessToken });
    assertEq(list.status, 200, 'captions list status');
    const langs = list.json.data.languages.map((l) => l.lang);
    for (const L of ['orig', 'ar', 'en']) assert(langs.includes(L), `ready track ${L} listed (got ${langs})`);
    assert(!list.text.includes('videoUrl'), 'captions list response must NOT contain videoUrl anywhere');
    const raw = await req('GET', `/episodes/${captionEpId}/captions/ar`, { token: tokens1.accessToken });
    assertEq(raw.status, 200, 'raw caption status');
    assert((raw.headers.get('content-type') || '').includes('text/vtt'), `raw caption content-type text/vtt (got ${raw.headers.get('content-type')})`);
    assert(raw.text.startsWith('WEBVTT'), 'VTT first line is WEBVTT');
    assert(raw.text.includes('-->'), 'VTT contains cue timings');
  });

  // 39. playback captionLanguages + qualities
  await testCase(39, 'playback includes captionLanguages [orig,ar,en] and qualities array of 4', async () => {
    assert(captionEpId, 'caption episode from case 38');
    const r = await req('GET', `/episodes/${captionEpId}/playback`, { token: tokens1.accessToken });
    assertEq(r.status, 200, 'playback status');
    for (const L of ['orig', 'ar', 'en']) assert(r.json.data.captionLanguages.includes(L), `captionLanguages includes ${L} (got ${JSON.stringify(r.json.data.captionLanguages)})`);
    assert(Array.isArray(r.json.data.qualities) && r.json.data.qualities.length === 4, 'qualities array of 4');
    assertEq(r.json.data.qualities.map((q) => q.label).join(','), '1080p,720p,480p,360p', 'quality labels');
    assert(r.json.data.qualities.every((q) => q.url === r.json.data.videoUrl), 'quality urls = resolved videoUrl');
  });

  // 40. admin DELETE caption track + captions_enabled=false hides languages
  await testCase(40, 'admin DELETE caption track -> gone from list; captions_enabled=false -> playback captionLanguages []', async () => {
    assert(captionEpId, 'caption episode from case 38');
    const adm = await req('GET', '/admin/captions', { admin: true });
    const epEntry = (adm.json.data.episodes || []).find((e) => e.episodeId === captionEpId);
    assert(epEntry, 'episode in admin captions');
    const enTrack = epEntry.tracks.find((tr) => tr.lang === 'en');
    assert(enTrack, 'en track present before delete');
    const del = await req('DELETE', `/admin/captions/${enTrack.id}`, { admin: true });
    assertEq(del.status, 200, 'delete caption track status');
    const list = await req('GET', `/episodes/${captionEpId}/captions`, { token: tokens1.accessToken });
    assert(!list.json.data.languages.some((l) => l.lang === 'en'), 'en track gone from list after delete');
    try {
      await patchSettings({ captions_enabled: false });
      const play = await req('GET', `/episodes/${captionEpId}/playback`, { token: tokens1.accessToken });
      assertEq(play.status, 200, 'playback status with captions disabled');
      assertEq(play.json.data.captionLanguages.length, 0, 'captionLanguages [] when captions disabled');
    } finally { await patchSettings({ captions_enabled: true }); }
  });

  // 41. auto-generate on admin episode create
  await testCase(41, 'auto-generate: admin-create episode with videoUrl -> caption job appears for it', async () => {
    const s = await getSettings();
    assertEq(s.captions_auto_generate, true, 'captions_auto_generate on');
    assertEq(s.captions_enabled, true, 'captions_enabled on');
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId, episodeNumber: 98, title: 'Auto Caption Episode', description: 'An episode created by tests. It should get captions automatically.', videoUrl: 'https://example.com/auto-caption.mp4', isFree: true, coinCost: 0 } });
    assertEq(ep.status, 201, `episode create status (body ${ep.text})`);
    const newEpId = ep.json.data.id;
    try {
      let found = null;
      for (let i = 0; i < 75; i++) {
        const adm = await req('GET', '/admin/captions', { admin: true });
        found = (adm.json.data.jobs || []).find((j) => j.episodeId === newEpId);
        if (found) break;
        await new Promise((r) => setTimeout(r, 200));
      }
      assert(found, 'caption job appeared for auto-created episode');
    } finally {
      await req('DELETE', `/admin/episodes/${newEpId}`, { admin: true });
    }
  });

  // 42. maintenance still 503s, /config exempt
  await testCase(42, 'maintenance: app endpoints 503 while GET /config still responds 200', async () => {
    try {
      await patchSettings({ maintenance_mode: true });
      const cfg = await req('GET', '/config');
      assertEq(cfg.status, 200, 'GET /config during maintenance');
      assertEq(cfg.json.data.maintenanceMode, true, 'config reports maintenanceMode true');
      const cats = await req('GET', '/categories', { token: tokens1.accessToken });
      assertEq(cats.status, 503, 'GET /categories during maintenance -> 503');
    } finally { await patchSettings({ maintenance_mode: false }); }
    const after = await req('GET', '/config');
    assertEq(after.json.data.maintenanceMode, false, 'maintenance off after restore');
  });
} catch (e) {
  failed++;
  log(`FATAL: ${e.message}`);
} finally {
  const total = passed + failed;
  log('');
  log(`SUMMARY: total=${total} passed=${passed} failed=${failed}`);
  if (failures.length) {
    log('FAILURES:');
    failures.forEach((f) => log(`  - ${f}`));
  }
  log(failed === 0 ? 'RESULT: ALL PASS' : 'RESULT: FAILURES PRESENT');
  try { fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n'); } catch { /* ignore */ }
  child.kill('SIGTERM');
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch { /* ignore */ }
  process.exit(failed === 0 ? 0 : 1);
}
