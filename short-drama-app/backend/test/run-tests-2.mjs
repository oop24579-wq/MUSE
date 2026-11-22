// HERO DRAMA backend integration tests — SUITE 2 (Critic #2: robustness,
// dashboard-flow contracts, streak/date logic, data-integrity journey).
// Plain node, no deps. Boots the real server on random ports with TEMP
// databases, so data/app.db is never touched. Writes test/LAST_RUN_2.txt.
// Case numbers start at 101 to stay distinct from suite 1 (1..57).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const ADMIN_TOKEN = 'test-admin-token-123';
const OUT_FILE = path.join(__dirname, 'LAST_RUN_2.txt');

const lines = [];
function log(...args) { const s = args.join(' '); lines.push(s); console.log(s); }
let passed = 0, failed = 0;
const failures = [];
async function testCase(num, name, fn) {
  try { await fn(); passed++; log(`PASS ${num}. ${name}`); }
  catch (e) { failed++; failures.push(`${num}. ${name}: ${e.message}`); log(`FAIL ${num}. ${name} -- ${e.message}`); }
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
// Same local-date algorithm as src/routes.js today().
const localDate = (offset = 0) => {
  const d = new Date(); d.setDate(d.getDate() + offset);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
};
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const emailToken = (sub, email, name) => `${b64u({ alg: 'RS256', typ: 'JWT' })}.${b64u({ sub, email, name })}.fakesig`;

async function boot(dbPath) {
  const port = await freePort();
  const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(port), DB_PATH: dbPath, FIREBASE_AUTH_DEV: '1', ADMIN_TOKEN, JWT_SECRET: 'test-jwt-secret-123' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let serverLog = '';
  child.stdout.on('data', (d) => { serverLog += d; });
  child.stderr.on('data', (d) => { serverLog += d; });
  const BASE = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) return { child, BASE, API: `${BASE}/api/v1` }; } catch { /* not up */ }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('server did not become healthy. Log: ' + serverLog);
}

function makeReq(API) {
  return async function req(method, urlPath, { token, admin, body, headers } = {}) {
    const h = { 'Content-Type': 'application/json', ...(headers || {}) };
    if (token) h.Authorization = `Bearer ${token}`;
    if (admin) h['X-Admin-Token'] = ADMIN_TOKEN;
    // Admin calls are written dashboard-style ('/genres', '/settings', ...):
    // route them under /api/v1/admin where adminHandle lives.
    let url = urlPath;
    if (admin && !url.startsWith('http') && !url.startsWith('/admin')) url = '/admin' + url;
    const res = await fetch(url.startsWith('http') ? url : API + url, {
      method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = null; try { json = JSON.parse(text); } catch { /* raw body (VTT etc.) */ }
    return { status: res.status, json, text, headers: res.headers };
  };
}

// =====================================================================
// BOOT A — robustness / contract cases 101..135
// =====================================================================
const tmpA = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test2a-'));
const dbPathA = path.join(tmpA, 'app.db');
const A = await boot(dbPathA);
const req = makeReq(A.API);
log(`Suite 2 boot A on ${A.BASE} (temp DB ${dbPathA})`);

async function mkUser(tokenStr, headers) {
  const r = await req('POST', '/auth/firebase', { body: { idToken: tokenStr }, headers });
  assertEq(r.status, 200, 'mkUser auth status');
  return { user: r.json.data.user, tokens: r.json.data.tokens };
}
async function patchSettings(body) {
  const r = await req('PATCH', '/settings', { admin: true, body });
  assertEq(r.status, 200, 'PATCH /settings status: ' + JSON.stringify(r.json));
  return r.json.data.settings;
}

// ---------- pagination / limit edges ----------
await testCase(101, 'limit=0 is clamped to 1 (discover returns exactly 1)', async () => {
  const r = await req('GET', '/discover?limit=0');
  assertEq(r.status, 200, 'status');
  assertEq(r.json.data.series.length, 1, 'limit=0 must clamp to a single item');
});
await testCase(102, 'limit=100000 is clamped to <=100 (returns whole 8-series catalog)', async () => {
  const r = await req('GET', '/discover?limit=100000');
  assertEq(r.status, 200, 'status');
  assert(r.json.data.series.length <= 100, 'must not exceed 100');
  assertEq(r.json.data.series.length, 8, 'seed catalog has 8 series');
});
await testCase(103, 'limit=abc (non-numeric) falls back to default page', async () => {
  const r = await req('GET', '/discover?limit=abc');
  assertEq(r.status, 200, 'status');
  assertEq(r.json.data.series.length, 8, 'default page returns the full seed catalog');
});
await testCase(104, 'genre series limit is exact (limit=1 -> 1, limit=2 -> 2)', async () => {
  const one = await req('GET', '/genres/genre-ceo/series?limit=1');
  assertEq(one.json.data.series.length, 1, 'limit=1');
  const two = await req('GET', '/genres/genre-ceo/series?limit=2');
  assertEq(two.json.data.series.length, 2, 'limit=2 (genre-ceo seeds 2 series)');
});

// ---------- search edges ----------
await testCase(105, 'search with missing/empty q returns 200 + array (pins current behavior)', async () => {
  const noQ = await req('GET', '/search');
  assertEq(noQ.status, 200, 'no-q status');
  assert(Array.isArray(noQ.json.data.series), 'no-q series array');
  const emptyQ = await req('GET', '/search?q=');
  assertEq(emptyQ.status, 200, 'empty-q status');
  assert(Array.isArray(emptyQ.json.data.series), 'empty-q series array');
});
await testCase(106, 'search with a 5000-char query does not crash', async () => {
  const r = await req('GET', '/search?q=' + 'x'.repeat(5000));
  assertEq(r.status, 200, 'status');
  assertEq(r.json.data.series.length, 0, 'no matches for nonsense query');
});
await testCase(107, 'search matches Arabic (unicode) titles and substrings', async () => {
  const c = await req('POST', '/series', { admin: true, body: { slug: 'critic-arabic', title: 'حب في المدينة', synopsis: 'قصة حب قصيرة', genreId: 'genre-romance' } });
  assertEq(c.status, 201, 'create Arabic series status');
  const byWord = await req('GET', '/search?q=' + encodeURIComponent('المدينة'));
  assert(byWord.json.data.series.some((s) => s.slug === 'critic-arabic'), 'Arabic substring search must find the series');
  const bySyn = await req('GET', '/search?q=' + encodeURIComponent('قصيرة'));
  assert(bySyn.json.data.series.some((s) => s.slug === 'critic-arabic'), 'Arabic synopsis search must find the series');
});

// ---------- empty containers ----------
await testCase(108, 'genre with no series (and unknown genre) -> 200 []', async () => {
  const g = await req('POST', '/genres', { admin: true, body: { slug: 'critic-empty', name: 'Empty Genre' } });
  assertEq(g.status, 201, 'create genre status');
  const r = await req('GET', '/genres/genre-critic-empty/series');
  assertEq(r.status, 200, 'status');
  assertEq(r.json.data.series.length, 0, 'empty genre has no series');
  const unk = await req('GET', '/genres/genre-does-not-exist/series');
  assertEq(unk.status, 200, 'unknown genre status (pins current behavior)');
  assertEq(unk.json.data.series.length, 0, 'unknown genre -> []');
});
await testCase(109, 'series with no episodes: detail 200, episodes []', async () => {
  const c = await req('POST', '/series', { admin: true, body: { slug: 'critic-noeps', title: 'No Episodes Yet', genreId: 'genre-romance' } });
  assertEq(c.status, 201, 'create status');
  const d = await req('GET', '/series/series-critic-noeps');
  assertEq(d.status, 200, 'detail status');
  assertEq(d.json.data.series.title, 'No Episodes Yet', 'detail title');
  assertEq(d.json.data.cast.length, 0, 'no cast');
  const eps = await req('GET', '/series/series-critic-noeps/episodes');
  assertEq(eps.status, 200, 'episodes status');
  assertEq(eps.json.data.episodes.length, 0, 'no episodes');
});

// ---------- home sections ordering ----------
await testCase(110, 'home sections are sortOrder-ascending; seeded section items keep seed order', async () => {
  const r = await req('GET', '/home');
  assertEq(r.status, 200, 'status');
  const secs = r.json.data.sections;
  const orders = secs.map((s) => s.sortOrder);
  assertEq(JSON.stringify(orders), JSON.stringify([...orders].sort((a, b) => a - b)), 'sections sorted by sortOrder');
  const trending = secs.find((s) => s.slug === 'trending-now');
  assert(trending, 'trending section exists');
  assertEq(JSON.stringify(trending.series.map((s) => s.id)),
    JSON.stringify(['series-married-to-the-ceo', 'series-revenge-of-the-heiress', 'series-my-secret-husband', 'series-the-last-signal']),
    'trending items in seed order');
});
await testCase(111, 'home section CRUD round-trip: create order -> PATCH reorder -> /home reflects -> delete', async () => {
  const ids = ['series-married-to-the-ceo', 'series-revenge-of-the-heiress', 'series-my-secret-husband'];
  const c = await req('POST', '/home-sections', { admin: true, body: { slug: 'critic-sec', title: 'Critic Picks', sectionType: 'series_carousel', sortOrder: 99, seriesIds: ids } });
  assertEq(c.status, 201, 'create status');
  const secId = c.json.data.id;
  const list = await req('GET', '/home-sections', { admin: true });
  const mine = list.json.data.items.find((s) => s.id === secId);
  assertEq(JSON.stringify(mine.seriesIds), JSON.stringify(ids), 'admin list preserves submitted order');
  const home1 = await req('GET', '/home');
  const inHome = home1.json.data.sections.find((s) => s.slug === 'critic-sec');
  assertEq(JSON.stringify(inHome.series.map((s) => s.id)), JSON.stringify(ids), '/home reflects create order');
  const reversed = [...ids].reverse();
  const p = await req('PATCH', `/home-sections/${secId}`, { admin: true, body: { seriesIds: reversed } });
  assertEq(p.status, 200, 'patch status');
  const home2 = await req('GET', '/home');
  const inHome2 = home2.json.data.sections.find((s) => s.slug === 'critic-sec');
  assertEq(JSON.stringify(inHome2.series.map((s) => s.id)), JSON.stringify(reversed), '/home reflects PATCH reorder');
  const d = await req('DELETE', `/home-sections/${secId}`, { admin: true });
  assertEq(d.status, 200, 'delete status');
  const home3 = await req('GET', '/home');
  assert(!home3.json.data.sections.some((s) => s.slug === 'critic-sec'), 'deleted section gone from /home');
});

// ---------- two devices / concurrent check-in ----------
await testCase(112, 'two devices, one user: devices tracked; 5 parallel check-ins pay exactly once', async () => {
  const devA = { 'X-Device-Id': 'critic-device-A', 'X-Platform': 'android' };
  const devB = { 'X-Device-Id': 'critic-device-B', 'X-Platform': 'ios' };
  const u1 = await mkUser('critic-two-device-token', devA);
  const u2 = await mkUser('critic-two-device-token', devB);
  assertEq(u2.user.id, u1.user.id, 'same idToken must resolve to the same user on both devices');
  const users = await req('GET', '/users?q=', { admin: true });
  const row = users.json.data.items.find((u) => u.id === u1.user.id);
  const devIds = (row.devices || []).map((d) => d.deviceId);
  assert(devIds.includes('critic-device-A') && devIds.includes('critic-device-B'), 'both devices recorded, got ' + JSON.stringify(devIds));
  const results = await Promise.all(Array.from({ length: 5 }, () =>
    req('POST', '/rewards/checkin', { token: u2.tokens.accessToken })));
  const wins = results.filter((r) => r.json && r.json.data && r.json.data.success === true);
  assertEq(wins.length, 1, 'exactly one of 5 parallel check-ins may pay');
  const coins = await req('GET', '/me/coins', { token: u1.tokens.accessToken });
  assertEq(coins.json.data.balance, 50, 'balance = 30 welcome + 20 day-1 checkin, paid once');
});

// ---------- streak / date logic (check-in rows seeded straight into the DB) ----------
function seedCheckins(userId, offsets) {
  const db = new DatabaseSync(dbPathA);
  db.exec('PRAGMA busy_timeout=8000');
  const stmt = db.prepare('INSERT OR IGNORE INTO checkins(userId,claimDate,dayIndex,coins,createdAt) VALUES(?,?,?,?,?)');
  for (const off of offsets) stmt.run(userId, localDate(off), 1, 0, new Date().toISOString());
  db.close();
}
await testCase(113, 'streak day 2: yesterday checked in -> payout = day-2 amount + streak bonus; streak=2', async () => {
  const u = await mkUser('critic-streak-2-token');
  seedCheckins(u.user.id, [-1]);
  const r = await req('POST', '/rewards/checkin', { token: u.tokens.accessToken });
  assertEq(r.status, 200, 'checkin status');
  assertEq(r.json.data.success, true, 'checkin succeeds');
  assertEq(r.json.data.coins, 52, 'day-2 base 50 + min(1,7)*2 streak bonus = 52');
  const st = await req('GET', '/rewards', { token: u.tokens.accessToken });
  assertEq(st.json.data.currentStreak, 2, 'currentStreak');
  assertEq(st.json.data.currentDay, 2, 'currentDay');
  assert(st.json.data.days[0].claimed && st.json.data.days[1].claimed, 'days 1-2 claimed');
  assertEq(st.json.data.days[2].claimed, false, 'day 3 not claimed');
});
await testCase(114, 'broken streak: check-ins at -3,-2 only -> ladder restarts at day 1 (pays 20)', async () => {
  const u = await mkUser('critic-streak-broken-token');
  seedCheckins(u.user.id, [-3, -2]);
  const r = await req('POST', '/rewards/checkin', { token: u.tokens.accessToken });
  assertEq(r.json.data.coins, 20, 'day-1 amount, no streak bonus');
  const st = await req('GET', '/rewards', { token: u.tokens.accessToken });
  assertEq(st.json.data.currentStreak, 1, 'streak restarts at 1');
  assertEq(st.json.data.currentDay, 1, 'currentDay back to 1');
});
await testCase(115, '7-day streak wraps the ladder: day 8 pays day-1 amount + capped streak bonus (34)', async () => {
  const u = await mkUser('critic-streak-7-token');
  seedCheckins(u.user.id, [-1, -2, -3, -4, -5, -6, -7]);
  const r = await req('POST', '/rewards/checkin', { token: u.tokens.accessToken });
  assertEq(r.json.data.coins, 34, 'day-1 base 20 + min(7,7)*2 = 34');
  const st = await req('GET', '/rewards', { token: u.tokens.accessToken });
  assertEq(st.json.data.currentStreak, 8, 'streak counts all 8 days');
  assertEq(st.json.data.currentDay, 1, 'ladder wrapped to a new cycle');
  assertEq(st.json.data.days[0].claimed, true, 'new cycle day 1 claimed');
  assertEq(st.json.data.days[1].claimed, false, 'new cycle day 2 not yet claimed');
});

// ---------- settings boundary values ----------
await testCase(116, 'ad_daily_cap=0 -> ad reward pays nothing and balance is unchanged', async () => {
  const u = await mkUser('critic-adcap0-token');
  await patchSettings({ ad_daily_cap: 0 });
  try {
    const r = await req('POST', '/rewards/ad', { token: u.tokens.accessToken, body: {} });
    assertEq(r.json.data.success, false, 'cap 0 blocks the reward');
    assertEq(r.json.data.coins, 0, 'no coins paid');
    const coins = await req('GET', '/me/coins', { token: u.tokens.accessToken });
    assertEq(coins.json.data.balance, 30, 'balance unchanged (welcome only)');
  } finally { await patchSettings({ ad_daily_cap: 5 }); }
});
await testCase(117, 'wheel_free_spins_per_day=0 -> first spin is paid (cost deducted)', async () => {
  const u = await mkUser('critic-wheel0-token');
  await patchSettings({ wheel_free_spins_per_day: 0, wheel_extra_spin_cost: 5 });
  try {
    const r = await req('POST', '/rewards/wheel/spin', { token: u.tokens.accessToken });
    assertEq(r.status, 200, 'spin status');
    assertEq(r.json.data.spinsLeft, 0, 'no free spins');
    assertEq(r.json.data.balance, 30 - 5 + r.json.data.coins, 'balance = welcome - spin cost + winnings');
    const txs = await req('GET', `/transactions?type=wheel_spin_cost&userId=${u.user.id}`, { admin: true });
    assertEq(txs.json.data.total, 1, 'exactly one wheel_spin_cost transaction');
  } finally { await patchSettings({ wheel_free_spins_per_day: 3, wheel_extra_spin_cost: 20 }); }
});
await testCase(118, 'watch-time: per-block 0 pays 0; block_minutes=0 rejected by validation', async () => {
  const bad = await req('PATCH', '/settings', { admin: true, body: { watch_time_block_minutes: 0 } });
  assertEq(bad.status, 400, 'block_minutes=0 must be rejected');
  const u = await mkUser('critic-wt0-token');
  await patchSettings({ watch_time_block_minutes: 1, watch_time_coins_per_block: 0 });
  try {
    const eps = await req('GET', '/series/series-married-to-the-ceo/episodes', { token: u.tokens.accessToken });
    const ep = eps.json.data.episodes[0];
    const w = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: 'series-married-to-the-ceo', episodeId: ep.id, episodeNumber: 1, positionSeconds: ep.durationSeconds, durationSeconds: ep.durationSeconds } });
    assertEq(w.status, 200, 'watch post status');
    const claim = await req('POST', '/rewards/watch-time/claim', { token: u.tokens.accessToken });
    assertEq(claim.json.data.success, false, 'per-block 0 -> nothing claimable');
    assertEq(claim.json.data.coins, 0, 'zero coins');
  } finally { await patchSettings({ watch_time_block_minutes: 10, watch_time_coins_per_block: 10 }); }
});
await testCase(119, 'overlapping events: the HIGHEST active multiplier wins check-in', async () => {
  const e2 = await req('POST', '/events', { admin: true, body: { name: 'Critic x2', multiplier: 2, startsAt: null, endsAt: null, active: true } });
  assertEq(e2.status, 201, 'create x2 event');
  const e3 = await req('POST', '/events', { admin: true, body: { name: 'Critic x3', multiplier: 3, startsAt: null, endsAt: null, active: true } });
  assertEq(e3.status, 201, 'create x3 event');
  try {
    const u1 = await mkUser('critic-event-hi-token');
    const c1 = await req('POST', '/rewards/checkin', { token: u1.tokens.accessToken });
    assertEq(c1.json.data.coins, 60, 'day-1 20 x highest multiplier 3 = 60');
    const del = await req('DELETE', `/events/${e3.json.data.id}`, { admin: true });
    assertEq(del.status, 200, 'delete x3 event');
    const u2 = await mkUser('critic-event-lo-token');
    const c2 = await req('POST', '/rewards/checkin', { token: u2.tokens.accessToken });
    assertEq(c2.json.data.coins, 40, 'with x3 gone, x2 applies: 20 x 2 = 40');
  } finally {
    await req('DELETE', `/events/${e2.json.data.id}`, { admin: true });
    await req('DELETE', `/events/${e3.json.data.id}`, { admin: true });
  }
});
await testCase(120, 'settings validation: duplicate chest thresholds 400; wheel weights/segments mismatch 400', async () => {
  const dup = await req('PATCH', '/settings', { admin: true, body: { chest_milestones: [{ threshold: 3, coins: 10 }, { threshold: 3, coins: 20 }] } });
  assertEq(dup.status, 400, 'duplicate chest thresholds rejected');
  const mm = await req('PATCH', '/settings', { admin: true, body: { wheel_segments: [5, 10, 15] } });
  assertEq(mm.status, 400, 'segments without matching weights rejected');
  const okPatch = await req('PATCH', '/settings', { admin: true, body: { wheel_segments: [5, 10, 15], wheel_weights: [1, 1, 1] } });
  assertEq(okPatch.status, 200, 'matching segments+weights accepted');
  await patchSettings({ wheel_segments: [5, 10, 15, 20, 30, 50, 100, 0], wheel_weights: [20, 18, 15, 14, 12, 10, 6, 5] });
});

// ---------- unlock / social idempotency ----------
await testCase(121, 'unlocking an already-unlocked episode is free and writes no second transaction', async () => {
  const u = await mkUser('critic-unlock2-token');
  await req('POST', `/users/${u.user.id}/coins`, { admin: true, body: { amount: 100 } });
  const ep = 'series-married-to-the-ceo-ep3';
  const first = await req('POST', `/episodes/${ep}/unlock`, { token: u.tokens.accessToken });
  assertEq(first.json.data.coins, 30, 'first unlock charges the episode cost');
  const balAfterFirst = first.json.data.balance;
  const second = await req('POST', `/episodes/${ep}/unlock`, { token: u.tokens.accessToken });
  assertEq(second.status, 200, 'second unlock status');
  assertEq(second.json.data.coins, 0, 'second unlock is free');
  assertEq(second.json.data.balance, balAfterFirst, 'balance unchanged by second unlock');
  const txs = await req('GET', `/transactions?type=episode_unlock&userId=${u.user.id}`, { admin: true });
  assertEq(txs.json.data.total, 1, 'exactly one episode_unlock transaction');
});
await testCase(122, 'like toggle storm (8 flips) ends consistent: count moves only on transitions', async () => {
  const u = await mkUser('critic-like-storm-token');
  const sid = 'series-my-secret-husband';
  const before = (await req('GET', `/series/${sid}`)).json.data.series.likeCount;
  const seq = [true, true, false, true, true, false, false, true];
  let expected = before;
  let prev = false;
  for (const want of seq) {
    const r = await req('POST', `/series/${sid}/like`, { token: u.tokens.accessToken, body: { like: want } });
    if (want !== prev) expected += want ? 1 : -1;
    prev = want;
    assertEq(r.json.data.likeCount, expected, `likeCount after like=${want}`);
  }
  const detail = await req('GET', `/series/${sid}`, { token: u.tokens.accessToken });
  assertEq(detail.json.data.isLiked, true, 'final state liked');
  assertEq(detail.json.data.series.likeCount, before + 1, 'net effect of the storm is +1');
  await req('POST', `/series/${sid}/like`, { token: u.tokens.accessToken, body: { like: false } });
  const after = (await req('GET', `/series/${sid}`)).json.data.series.likeCount;
  assertEq(after, before, 'unlike restores the original count');
});
await testCase(123, 'favorite toggle storm: my-list holds the series exactly once, then none', async () => {
  const u = await mkUser('critic-fav-storm-token');
  const sid = 'series-the-last-signal';
  for (const want of [true, true, false, true]) {
    await req('POST', `/series/${sid}/favorite`, { token: u.tokens.accessToken, body: { add: want } });
  }
  const list = await req('GET', '/me/library/my-list', { token: u.tokens.accessToken });
  assertEq(list.json.data.series.filter((s) => s.id === sid).length, 1, 'series appears exactly once');
  await req('POST', `/series/${sid}/favorite`, { token: u.tokens.accessToken, body: { add: false } });
  const list2 = await req('GET', '/me/library/my-list', { token: u.tokens.accessToken });
  assertEq(list2.json.data.series.filter((s) => s.id === sid).length, 0, 'series removed');
});
await testCase(124, 'notifications read is idempotent (same id twice; read-all twice)', async () => {
  const u = await mkUser('critic-notif-token');
  await req('POST', '/notifications/broadcast', { admin: true, body: { title: 'Critic One', body: 'first' } });
  let n = await req('GET', '/notifications', { token: u.tokens.accessToken });
  assert(n.json.data.unread >= 1, 'unread after broadcast');
  const target = n.json.data.items.find((i) => i.title === 'Critic One');
  const unreadBefore = n.json.data.unread;
  await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: { ids: [target.id] } });
  await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: { ids: [target.id] } });
  n = await req('GET', '/notifications', { token: u.tokens.accessToken });
  assertEq(n.json.data.unread, unreadBefore - 1, 'double read of one id decrements exactly once');
  await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: {} });
  await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: {} });
  n = await req('GET', '/notifications', { token: u.tokens.accessToken });
  assertEq(n.json.data.unread, 0, 'read-all twice ends at zero unread');
});

// ---------- watch-history high-water / ordering ----------
await testCase(125, 'watch-history: repeat + seek-back posts never inflate accrued watch-time', async () => {
  const u = await mkUser('critic-hw-token');
  const sid = 'series-revenge-of-the-heiress';
  const eps = (await req('GET', `/series/${sid}/episodes`, { token: u.tokens.accessToken })).json.data.episodes;
  const ep = eps[0];
  const post = (pos) => req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: sid, episodeId: ep.id, episodeNumber: 1, positionSeconds: pos, durationSeconds: ep.durationSeconds } });
  const minutes = async () => (await req('GET', '/rewards', { token: u.tokens.accessToken })).json.data.watchTime.minutesToday;
  await post(50);
  assertEq(await minutes(), 0, '50s accrued < 1 minute');
  await post(ep.durationSeconds);
  assertEq(await minutes(), Math.floor(ep.durationSeconds / 60), 'full episode accrued');
  await post(ep.durationSeconds);
  assertEq(await minutes(), Math.floor(ep.durationSeconds / 60), 'repeat post at same position adds nothing');
  await post(10);
  assertEq(await minutes(), Math.floor(ep.durationSeconds / 60), 'seek-back post adds nothing');
});
await testCase(126, 'watch-history episode switch: one history entry per series, last episode wins', async () => {
  const u = await mkUser('critic-hw2-token');
  const sid = 'series-city-of-hidden-lies';
  const eps = (await req('GET', `/series/${sid}/episodes`, { token: u.tokens.accessToken })).json.data.episodes;
  await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: sid, episodeId: eps[1].id, episodeNumber: 2, positionSeconds: 30, durationSeconds: eps[1].durationSeconds } });
  await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: sid, episodeId: eps[0].id, episodeNumber: 1, positionSeconds: 30, durationSeconds: eps[0].durationSeconds } });
  const hist = (await req('GET', '/me/library/history', { token: u.tokens.accessToken })).json.data.history;
  const mine = hist.filter((h) => h.series.id === sid);
  assertEq(mine.length, 1, 'exactly one history entry for the series');
  assertEq(mine[0].episodeId, eps[0].id, 'entry points at the most recent episode');
});

// ---------- admin CRUD round-trips ----------
await testCase(127, 'missions CRUD: create -> claimable -> deactivate (claim 404) -> delete', async () => {
  const c = await req('POST', '/missions', { admin: true, body: { slug: 'critic_like_2', title: 'Like 2 series (critic)', metric: 'likes', target: 2, coins: 33, sortOrder: 99, active: true } });
  assertEq(c.status, 201, 'create mission status');
  const u = await mkUser('critic-mission-token');
  await req('POST', '/series/series-married-to-the-ceo/like', { token: u.tokens.accessToken, body: { like: true } });
  await req('POST', '/series/series-revenge-of-the-heiress/like', { token: u.tokens.accessToken, body: { like: true } });
  const st = await req('GET', '/rewards', { token: u.tokens.accessToken });
  const ms = st.json.data.missions.find((x) => x.slug === 'critic_like_2');
  assert(ms && ms.completed === true && ms.progress === 2, 'mission visible and completed in /rewards');
  const balBefore = (await req('GET', '/me/coins', { token: u.tokens.accessToken })).json.data.balance;
  const claim = await req('POST', '/rewards/missions/critic_like_2/claim', { token: u.tokens.accessToken });
  assertEq(claim.status, 200, 'claim status');
  assertEq(claim.json.data.coins, 33, 'claim pays mission coins');
  assertEq(claim.json.data.balance, balBefore + 33, 'balance increased by mission coins');
  const p = await req('PATCH', '/missions/critic_like_2', { admin: true, body: { active: false } });
  assertEq(p.status, 200, 'deactivate status');
  assertEq(p.json.data.active, false, 'mission now inactive');
  const u2 = await mkUser('critic-mission-2-token');
  await req('POST', '/series/series-married-to-the-ceo/like', { token: u2.tokens.accessToken, body: { like: true } });
  await req('POST', '/series/series-revenge-of-the-heiress/like', { token: u2.tokens.accessToken, body: { like: true } });
  const claim2 = await req('POST', '/rewards/missions/critic_like_2/claim', { token: u2.tokens.accessToken });
  assertEq(claim2.status, 404, 'claiming an inactive mission 404s');
  const d = await req('DELETE', '/missions/critic_like_2', { admin: true });
  assertEq(d.status, 200, 'delete status');
  const list = await req('GET', '/missions', { admin: true });
  assert(!list.json.data.items.some((x) => x.slug === 'critic_like_2'), 'mission gone from admin list');
});
await testCase(128, 'events CRUD: invalid date 400, negative multiplier 400, PATCH reflected, DELETE removes', async () => {
  const badDate = await req('POST', '/events', { admin: true, body: { name: 'Bad', multiplier: 2, startsAt: 'not-a-date' } });
  assertEq(badDate.status, 400, 'invalid startsAt rejected');
  const badMult = await req('POST', '/events', { admin: true, body: { name: 'Bad', multiplier: -2 } });
  assertEq(badMult.status, 400, 'negative multiplier rejected');
  const zeroMult = await req('POST', '/events', { admin: true, body: { name: 'Bad', multiplier: 0 } });
  assertEq(zeroMult.status, 400, 'zero multiplier rejected');
  const c = await req('POST', '/events', { admin: true, body: { name: 'Critic Event', multiplier: 1.5, active: false } });
  assertEq(c.status, 201, 'create status');
  const id = c.json.data.id;
  const p = await req('PATCH', `/events/${id}`, { admin: true, body: { multiplier: 2.5, name: 'Critic Event v2' } });
  assertEq(p.json.data.multiplier, 2.5, 'PATCH multiplier reflected');
  assertEq(p.json.data.name, 'Critic Event v2', 'PATCH name reflected');
  const badPatch = await req('PATCH', `/events/${id}`, { admin: true, body: { endsAt: 'garbage' } });
  assertEq(badPatch.status, 400, 'PATCH invalid endsAt rejected');
  const d = await req('DELETE', `/events/${id}`, { admin: true });
  assertEq(d.status, 200, 'delete status');
  const list = await req('GET', '/events', { admin: true });
  assert(!list.json.data.items.some((x) => x.id === id), 'event gone from list');
});
await testCase(129, 'reward-task PATCH coins: completion pays the PATCHED amount', async () => {
  const p = await req('PATCH', '/reward-tasks/rate_app', { admin: true, body: { coins: 45 } });
  assertEq(p.status, 200, 'patch status');
  assertEq(p.json.data.coins, 45, 'coins patched');
  const u = await mkUser('critic-taskpatch-token');
  const done = await req('POST', '/rewards/tasks/rate_app/complete', { token: u.tokens.accessToken });
  assertEq(done.json.data.success, true, 'task completes');
  assertEq(done.json.data.coins, 45, 'payout uses patched coins, not the seeded 30');
});
await testCase(130, 'admin transactions: pages are disjoint, total stable, type filter narrows', async () => {
  const p1 = await req('GET', '/transactions?limit=3&offset=0', { admin: true });
  const p2 = await req('GET', '/transactions?limit=3&offset=3', { admin: true });
  assertEq(p1.json.data.total, p2.json.data.total, 'total stable across pages');
  const ids1 = new Set(p1.json.data.items.map((t) => t.id));
  assert(p2.json.data.items.every((t) => !ids1.has(t.id)), 'pages do not overlap');
  const wb = await req('GET', '/transactions?type=welcome_bonus&limit=100', { admin: true });
  assert(wb.json.data.items.every((t) => t.type === 'welcome_bonus'), 'type filter returns only that type');
  assertEq(wb.json.data.total, wb.json.data.items.length, 'filtered total matches returned rows (under one page)');
});
await testCase(131, 'admin users search: email substring matches; nonsense matches nothing', async () => {
  const u = await mkUser(emailToken('critic-search-sub-1', 'critic.search@example.com', 'Critic Search'));
  assertEq(u.user.email, 'critic.search@example.com', 'dev token email claim lands on the user');
  const hit = await req('GET', '/users?q=critic.search', { admin: true });
  assert(hit.json.data.items.some((x) => x.id === u.user.id), 'search finds the user by email substring');
  const miss = await req('GET', '/users?q=zzz-no-such-user-zzz', { admin: true });
  assertEq(miss.json.data.items.length, 0, 'nonsense search returns []');
});
await testCase(132, 'admin captions: seeded tracked episodes listed with tracks; jobs array present', async () => {
  const r = await req('GET', '/captions', { admin: true });
  assertEq(r.status, 200, 'status');
  assert(Array.isArray(r.json.data.jobs), 'jobs array present');
  const seeded = r.json.data.episodes.filter((e) => e.seriesId === 'series-married-to-the-ceo');
  assert(seeded.length >= 2, 'two seeded episodes have caption tracks');
  for (const ep of seeded) {
    const langs = ep.tracks.filter((t) => t.status === 'ready').map((t) => t.lang).sort();
    assertEq(JSON.stringify(langs), JSON.stringify(['ar', 'en', 'orig']), 'ready orig+ar+en tracks');
  }
});
await testCase(133, 'dashboard static assets: /admin HTML, logo.png content types, missing file 404', async () => {
  const html = await fetch(A.BASE + '/admin');
  assertEq(html.status, 200, '/admin status');
  assert((html.headers.get('content-type') || '').includes('text/html'), '/admin is text/html');
  const htmlText = await html.text();
  assert(htmlText.includes('HERO DRAMA'), 'dashboard HTML served');
  const logo = await fetch(A.BASE + '/admin/logo.png');
  assertEq(logo.status, 200, 'logo status');
  assert((logo.headers.get('content-type') || '').includes('image/png'), 'logo is image/png');
  await logo.arrayBuffer();
  const missing = await fetch(A.BASE + '/admin/nope.txt');
  assertEq(missing.status, 404, 'missing admin file 404s');
});
await testCase(134, 'dashboard static path traversal is blocked', async () => {
  const t1 = await fetch(A.BASE + '/admin/../src/server.js');
  assertEq(t1.status, 404, 'dot-dot traversal must not serve source files');
  await t1.text();
  const t2 = await fetch(A.BASE + '/admin/%2e%2e%2fsrc%2fserver.js');
  assert(t2.status !== 200, 'encoded traversal must not serve source files (got ' + t2.status + ')');
  await t2.text();
});
await testCase(135, 'deleting a genre leaves its series readable with a null genre (pins graceful degradation)', async () => {
  const g = await req('POST', '/genres', { admin: true, body: { slug: 'critic-doomed', name: 'Doomed' } });
  const gid = g.json.data.id;
  const s = await req('POST', '/series', { admin: true, body: { slug: 'critic-orphan-series', title: 'Orphan Series', genreId: gid } });
  assertEq(s.status, 201, 'series created in genre');
  const d = await req('DELETE', `/genres/${gid}`, { admin: true });
  assertEq(d.status, 200, 'genre deleted');
  const detail = await req('GET', '/series/series-critic-orphan-series');
  assertEq(detail.status, 200, 'series still readable');
  assertEq(detail.json.data.series.genre, null, 'genre resolves to null, no crash');
  assertEq(detail.json.data.series.genreId, gid, 'genreId left dangling (documented Low finding)');
});

await testCase(136, 'REGRESSION (USER_EVALUATION J2): VIP-series episodes serialize isUnlocked=false for non-VIP, true for VIP', async () => {
  const vipSid = 'series-vip-empire-of-desire';
  const plain = await mkUser('critic-j2-plain-token');
  const list = await req('GET', `/series/${vipSid}/episodes`, { token: plain.tokens.accessToken });
  assertEq(list.status, 200, 'episode list status');
  const byNum = (n) => list.json.data.episodes.find((e) => e.episodeNumber === n);
  // Seed: eps 1-2 of the VIP series carry isFree=1 AND isVipOnly=1 — the exact
  // combination that used to serialize isUnlocked=true while playback 403'd.
  assertEq(byNum(1).isFree, true, 'seed check: ep1 flagged free');
  assertEq(byNum(1).isVipOnly, true, 'seed check: ep1 flagged VIP-only');
  assertEq(byNum(1).isUnlocked, false, 'non-VIP: ep1 must NOT serialize as unlocked');
  assertEq(byNum(2).isUnlocked, false, 'non-VIP: ep2 must NOT serialize as unlocked');
  assertEq(byNum(3).isUnlocked, false, 'non-VIP: ep3 must NOT serialize as unlocked');
  const play = await req('GET', `/episodes/${byNum(1).id}/playback`, { token: plain.tokens.accessToken });
  assertEq(play.status, 403, 'non-VIP playback still refused');
  assertEq(play.json.error.code, 'VIP_REQUIRED', 'playback refusal is the VIP gate');
  // Anonymous viewers get the same honest lock signal.
  const anon = await req('GET', `/series/${vipSid}/episodes`);
  assertEq(anon.json.data.episodes.find((e) => e.episodeNumber === 1).isUnlocked, false, 'anonymous: ep1 locked');
  // Control: a free episode of a NON-VIP series still serializes unlocked.
  const ctrl = await req('GET', '/series/series-married-to-the-ceo/episodes', { token: plain.tokens.accessToken });
  assertEq(ctrl.json.data.episodes.find((e) => e.episodeNumber === 1).isUnlocked, true, 'control: free non-VIP episode stays unlocked');
  // Grant VIP -> the same list now unlocks, and playback agrees (even ep3,
  // which is not free: the VIP gate, once passed, skips the coin gate).
  await req('POST', `/users/${plain.user.id}/vip`, { admin: true, body: { isVip: true } });
  const list2 = await req('GET', `/series/${vipSid}/episodes`, { token: plain.tokens.accessToken });
  const byNum2 = (n) => list2.json.data.episodes.find((e) => e.episodeNumber === n);
  assertEq(byNum2(1).isUnlocked, true, 'VIP: ep1 unlocked');
  assertEq(byNum2(3).isUnlocked, true, 'VIP: ep3 unlocked via the VIP gate');
  const play2 = await req('GET', `/episodes/${byNum2(1).id}/playback`, { token: plain.tokens.accessToken });
  assertEq(play2.status, 200, 'VIP playback succeeds');
  assert(play2.json.data.videoUrl, 'VIP playback returns a videoUrl');
  const play3 = await req('GET', `/episodes/${byNum2(3).id}/playback`, { token: plain.tokens.accessToken });
  assertEq(play3.status, 200, 'VIP playback of non-free gated ep3 succeeds without coins');
});

A.child.kill();
