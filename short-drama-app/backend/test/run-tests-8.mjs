// HERO DRAMA backend — suite 8 (cases 701+, FIX-1 input-validation round).
// Covers: V1 (non-string scalars bound to SQLite -> 500 in watch-history
// and notifications/read), V2 (non-string refreshToken / idToken -> 500 in
// auth.verify), V3 (huge decodable /shorts cursor -> 500 on OFFSET bind),
// V6 (like/favorite/follow treated 0 / null / "false" as a LIKE).
// Plain node, no deps. Boots a real server on a random port with a TEMP
// database (dev auth), so data/app.db is never touched.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const OUT_FILE = path.join(__dirname, 'LAST_RUN_8.txt');
const ADMIN_TOKEN = 'suite8-fixture';

const lines = [];
function log(...args) { const s = args.join(' '); lines.push(s); console.log(s); }
let passed = 0, failed = 0;
const failures = [];
async function testCase(num, name, fn) {
  try { await fn(); passed++; log(`PASS ${num}. ${name}`); }
  catch (e) { failed++; failures.push(`${num}. ${name}: ${e.message}`); log(`FAIL ${num}. ${name} -- ${e.message}`); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); }
function assertEq(actual, expected, msg) { if (actual !== expected) throw new Error(`${msg || 'not equal'} (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`); }
function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)); });
    s.on('error', reject);
  });
}

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test8-'));
const dbPath = path.join(tmpDir, 'app.db');
const port = await freePort();
const BASE = `http://127.0.0.1:${port}`;
const API = `${BASE}/api/v1`;
const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
  cwd: BACKEND,
  env: { ...process.env, PORT: String(port), DB_PATH: dbPath, FIREBASE_AUTH_DEV: '1', ADMIN_TOKEN, JWT_SECRET: 'test-jwt-secret-123' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
child.stdout.on('data', (d) => { serverLog += d; });
child.stderr.on('data', (d) => { serverLog += d; });

async function req(method, urlPath, { token, body, admin } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (admin) headers['X-Admin-Token'] = ADMIN_TOKEN;
  const res = await fetch(urlPath.startsWith('http') ? urlPath : API + urlPath, {
    method, headers, body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* keep null */ }
  return { status: res.status, json, text };
}
async function waitForHealth() {
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) return; } catch { /* not up */ }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('server did not become healthy. Log: ' + serverLog);
}
async function mkUser(idToken) {
  const r = await req('POST', '/auth/firebase', { body: { idToken } });
  assertEq(r.status, 200, 'auth status');
  return { user: r.json.data.user, tokens: r.json.data.tokens };
}
const SID = 'series-married-to-the-ceo';

try {
  await waitForHealth();
  log(`Server booted on ${BASE} with temp DB ${dbPath}`);

  await testCase(701, 'V1: watch-history with array/object seriesId -> 400 VALIDATION (never 500); server alive and a subsequent valid post works', async () => {
    const u = await mkUser('s8-watch-types');
    for (const bad of [['x'], { a: 1 }]) {
      const r = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: bad } });
      assertEq(r.status, 400, `status for seriesId=${JSON.stringify(bad)} (body ${r.text})`);
      assertEq(r.json.error.code, 'VALIDATION', 'error code VALIDATION');
    }
    const eps = (await req('GET', `/series/${SID}/episodes`, { token: u.tokens.accessToken })).json.data.episodes;
    const okR = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: SID, episodeId: eps[0].id, episodeNumber: 1, positionSeconds: 10, durationSeconds: eps[0].durationSeconds } });
    assertEq(okR.status, 200, `subsequent valid watch-history status (body ${okR.text})`);
    assertEq(okR.json.data.success, true, 'valid post succeeds after the attacks');
  });

  await testCase(702, 'V1 siblings: watch-history with array/object episodeId or non-number numeric fields -> 400 VALIDATION; valid post still works', async () => {
    const u = await mkUser('s8-watch-siblings');
    const eps = (await req('GET', `/series/${SID}/episodes`, { token: u.tokens.accessToken })).json.data.episodes;
    const badBodies = [
      { seriesId: SID, episodeId: ['x'] },
      { seriesId: SID, episodeId: { a: 1 } },
      { seriesId: SID, episodeId: eps[0].id, positionSeconds: [10] },
      { seriesId: SID, episodeId: eps[0].id, durationSeconds: { s: 1 } },
      { seriesId: SID, episodeId: eps[0].id, episodeNumber: 'one' },
    ];
    for (const body of badBodies) {
      const r = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body });
      assertEq(r.status, 400, `status for ${JSON.stringify(body)} (body ${r.text})`);
      assertEq(r.json.error.code, 'VALIDATION', 'error code VALIDATION');
    }
    const okR = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: SID, episodeId: eps[0].id, episodeNumber: 1, positionSeconds: 10, durationSeconds: eps[0].durationSeconds } });
    assertEq(okR.status, 200, 'valid post still works');
  });

  await testCase(703, 'V1: notifications/read with mixed-type ids [1,null,{},[]] or non-array ids -> 400 VALIDATION; valid ids and mark-all still work', async () => {
    const u = await mkUser('s8-notif-types');
    const mixed = await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: { ids: [1, null, {}, []] } });
    assertEq(mixed.status, 400, `mixed ids status (body ${mixed.text})`);
    assertEq(mixed.json.error.code, 'VALIDATION', 'error code VALIDATION');
    const scalar = await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: { ids: 'not-an-array' } });
    assertEq(scalar.status, 400, 'non-array ids status');
    assertEq(scalar.json.error.code, 'VALIDATION', 'error code VALIDATION');
    const list = await req('GET', '/notifications', { token: u.tokens.accessToken });
    assert(list.json.data.items.length > 0, 'fixture: user has the welcome notification');
    const target = list.json.data.items[0];
    const okR = await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: { ids: [target.id] } });
    assertEq(okR.status, 200, 'valid string ids still work');
    const markAll = await req('POST', '/notifications/read', { token: u.tokens.accessToken, body: {} });
    assertEq(markAll.status, 200, 'absent ids (mark-all) still works');
    const after = await req('GET', '/notifications', { token: u.tokens.accessToken });
    assertEq(after.json.data.unread, 0, 'all notifications read');
  });

  await testCase(704, 'V2: /auth/refresh with numeric/array/object refreshToken -> 401 (never 500); numeric idToken -> 401; a real refresh still rotates', async () => {
    for (const bad of [42, ['x'], { a: 1 }]) {
      const r = await req('POST', '/auth/refresh', { body: { refreshToken: bad } });
      assertEq(r.status, 401, `refresh status for ${JSON.stringify(bad)} (body ${r.text})`);
      assertEq(r.json.error.code, 'INVALID_REFRESH', 'error code INVALID_REFRESH');
    }
    const badId = await req('POST', '/auth/firebase', { body: { idToken: 42 } });
    assertEq(badId.status, 401, `firebase numeric idToken status (body ${badId.text})`);
    assertEq(badId.json.error.code, 'INVALID_TOKEN', 'error code INVALID_TOKEN');
    const u = await mkUser('s8-refresh-valid');
    const rot = await req('POST', '/auth/refresh', { body: { refreshToken: u.tokens.refreshToken } });
    assertEq(rot.status, 200, `valid refresh status (body ${rot.text})`);
    assert(typeof rot.json.data.tokens.accessToken === 'string' && rot.json.data.tokens.accessToken.length > 0, 'rotation returns fresh tokens');
  });

  await testCase(705, 'V3: GET /shorts with a huge decodable cursor (base64url of a 20-digit number) -> 200 empty page, never 500; normal cursor pagination unchanged', async () => {
    const huge = Buffer.from('99999999999999999999', 'utf8').toString('base64url');
    const r = await req('GET', '/shorts?cursor=' + encodeURIComponent(huge));
    assertEq(r.status, 200, `huge cursor status (body ${r.text.slice(0, 200)})`);
    assertEq(r.json.data.items.length, 0, 'huge cursor yields an empty page');
    assertEq(r.json.data.nextCursor, null, 'huge cursor yields nextCursor null');
    const p1 = await req('GET', '/shorts?limit=2');
    assertEq(p1.status, 200, 'first page status');
    assertEq(p1.json.data.items.length, 2, 'first page has 2 items');
    assert(typeof p1.json.data.nextCursor === 'string' && p1.json.data.nextCursor.length > 0, 'first page has a nextCursor');
    const p2 = await req('GET', '/shorts?limit=2&cursor=' + encodeURIComponent(p1.json.data.nextCursor));
    assertEq(p2.status, 200, 'second page status');
    assertEq(p2.json.data.items.length, 2, 'second page has 2 items');
    assert(!p2.json.data.items.some((i) => p1.json.data.items.some((j) => j.id === i.id)), 'pages do not overlap');
  });

  await testCase(706, 'V6: like/favorite with 0, "false", null or a missing key -> 400 VALIDATION and state unchanged; true/false still toggle', async () => {
    const u = await mkUser('s8-like-strict');
    const t = u.tokens.accessToken;
    const before = (await req('GET', `/series/${SID}`, { token: t })).json.data;
    assertEq(before.isLiked, false, 'fixture: not liked yet');
    const likeOk = await req('POST', `/series/${SID}/like`, { token: t, body: { like: true } });
    assertEq(likeOk.status, 200, 'like:true status');
    assertEq(likeOk.json.data.likeCount, before.series.likeCount + 1, 'like:true moves the count +1');
    for (const bad of [0, 'false', null]) {
      const r = await req('POST', `/series/${SID}/like`, { token: t, body: { like: bad } });
      assertEq(r.status, 400, `like:${JSON.stringify(bad)} status (body ${r.text})`);
      assertEq(r.json.error.code, 'VALIDATION', 'error code VALIDATION');
    }
    const missing = await req('POST', `/series/${SID}/like`, { token: t, body: {} });
    assertEq(missing.status, 400, 'missing like key status');
    const mid = (await req('GET', `/series/${SID}`, { token: t })).json.data;
    assertEq(mid.isLiked, true, 'state unchanged: still liked after invalid payloads');
    assertEq(mid.series.likeCount, before.series.likeCount + 1, 'likeCount unchanged after invalid payloads');
    const favBad = await req('POST', `/series/${SID}/favorite`, { token: t, body: { add: 0 } });
    assertEq(favBad.status, 400, 'favorite add:0 status');
    assertEq(favBad.json.error.code, 'VALIDATION', 'error code VALIDATION');
    const listMid = await req('GET', '/me/library/my-list', { token: t });
    assert(!listMid.json.data.series.some((s) => s.id === SID), 'favorite state unchanged: not in my-list');
    const unlike = await req('POST', `/series/${SID}/like`, { token: t, body: { like: false } });
    assertEq(unlike.status, 200, 'like:false status');
    assertEq(unlike.json.data.likeCount, before.series.likeCount, 'like:false restores the count');
    const favOk = await req('POST', `/series/${SID}/favorite`, { token: t, body: { add: true } });
    assertEq(favOk.status, 200, 'favorite add:true status');
    const listAfter = await req('GET', '/me/library/my-list', { token: t });
    assert(listAfter.json.data.series.some((s) => s.id === SID), 'favorite add:true lands in my-list');
    const favOff = await req('POST', `/series/${SID}/favorite`, { token: t, body: { add: false } });
    assertEq(favOff.status, 200, 'favorite add:false status');
  });

  await testCase(707, 'V6 sibling: follow with a non-boolean -> 400 VALIDATION and state unchanged; follow true/false still toggle', async () => {
    const u = await mkUser('s8-follow-strict');
    const t = u.tokens.accessToken;
    const bad = await req('POST', `/series/${SID}/follow`, { token: t, body: { follow: 'false' } });
    assertEq(bad.status, 400, `follow:"false" status (body ${bad.text})`);
    assertEq(bad.json.error.code, 'VALIDATION', 'error code VALIDATION');
    const d0 = (await req('GET', `/series/${SID}`, { token: t })).json.data;
    assertEq(d0.isFollowing, false, 'state unchanged: not following');
    const on = await req('POST', `/series/${SID}/follow`, { token: t, body: { follow: true } });
    assertEq(on.status, 200, 'follow:true status');
    const d1 = (await req('GET', `/series/${SID}`, { token: t })).json.data;
    assertEq(d1.isFollowing, true, 'follow:true follows');
    const off = await req('POST', `/series/${SID}/follow`, { token: t, body: { follow: false } });
    assertEq(off.status, 200, 'follow:false status');
    const d2 = (await req('GET', `/series/${SID}`, { token: t })).json.data;
    assertEq(d2.isFollowing, false, 'follow:false unfollows');
  });
  // ---- FIX-2 (cases 708+): V4 webhook catalog/amounts, V5 relink proof, F7 VIP unlock ----
  const me8 = async (token) => (await req('GET', '/auth/me', { token })).json.data.user;
  const orders8 = async (token) => (await req('GET', '/user/orders', { token })).json.data;
  const rc8 = (over) => ({ api_version: '1.0', event: { type: 'INITIAL_PURCHASE', ...over } });

  await testCase(708, 'V4: webhook unknown product coins_999999999 -> 200 applied:false unknown_product, balance unchanged, no order', async () => {
    const u = await mkUser('s8-wh-unknown');
    const before = (await me8(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/webhooks/revenuecat', { body: rc8({ type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_999999999', price: 999.99, transaction_id: 's8-tx-unknown-1' }) });
    assertEq(r.status, 200, 'status');
    assertEq(r.json.data.applied, false, 'applied:false');
    assertEq(r.json.data.reason, 'unknown_product', 'reason unknown_product');
    assertEq((await me8(u.tokens.accessToken)).coinBalance, before, 'balance unchanged (no mint)');
    assertEq((await orders8(u.tokens.accessToken)).total, 0, 'no order recorded');
  });

  await testCase(709, 'V4: webhook catalog coin product coins_500 -> exact catalog grant +500', async () => {
    const u = await mkUser('s8-wh-catalog');
    const before = (await me8(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/webhooks/revenuecat', { body: rc8({ type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_500', price: 4.99, transaction_id: 's8-tx-catalog-1' }) });
    assertEq(r.status, 200, 'status');
    assertEq(r.json.data.applied, true, 'applied');
    assertEq((await me8(u.tokens.accessToken)).coinBalance, before + 500, 'balance +500 exactly');
    const o = (await orders8(u.tokens.accessToken)).orders[0];
    assertEq(o.coinPackageId, 'coins_500', 'coinPackageId coins_500');
    assertEq(o.amountCents, 499, 'amountCents 499');
  });

  await testCase(710, 'V4: webhook negative / non-numeric price -> amountCents clamped to 0, catalog entitlement still applies', async () => {
    const u = await mkUser('s8-wh-negprice');
    const r = await req('POST', '/webhooks/revenuecat', { body: rc8({ app_user_id: u.user.id, product_id: 'vip_monthly', price: -99999, transaction_id: 's8-tx-neg-1', expiration_at_ms: Date.now() + 30 * 86400e3 }) });
    assertEq(r.status, 200, 'status');
    assertEq(r.json.data.applied, true, 'legit catalog event still applied');
    assertEq((await orders8(u.tokens.accessToken)).orders[0].amountCents, 0, 'amountCents clamped to 0 (not -9999900)');
    assert((await me8(u.tokens.accessToken)).isPro, 'VIP entitlement applied');
    const u2 = await mkUser('s8-wh-strprice');
    const r2 = await req('POST', '/webhooks/revenuecat', { body: rc8({ type: 'NON_RENEWING_PURCHASE', app_user_id: u2.user.id, product_id: 'coins_100', price: 'not-a-number', transaction_id: 's8-tx-neg-2' }) });
    assertEq(r2.status, 200, 'string price status');
    assertEq((await orders8(u2.tokens.accessToken)).orders[0].amountCents, 0, 'non-numeric price -> amountCents 0');
  });

  await testCase(711, 'V5: relink without proof -> 403 GUEST_OWNERSHIP_REQUIRED, guest intact, primary balance unchanged', async () => {
    const guest = await mkUser('s8-relink-guest-noproof');
    const primary = await mkUser('s8-relink-primary-noproof');
    const pBefore = (await me8(primary.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id } });
    assertEq(r.status, 403, 'status');
    assertEq(r.json.error.code, 'GUEST_OWNERSHIP_REQUIRED', 'code');
    assertEq((await req('GET', '/auth/me', { token: guest.tokens.accessToken })).status, 200, 'guest intact');
    assertEq((await me8(primary.tokens.accessToken)).coinBalance, pBefore, 'primary balance unchanged');
  });

  await testCase(712, 'V5: relink with valid guest access-token proof -> merges exactly once (balance = sum); retry idempotent', async () => {
    const guest = await mkUser('s8-relink-guest-proof');
    const primary = await mkUser('s8-relink-primary-proof');
    const gBal = (await me8(guest.tokens.accessToken)).coinBalance;
    const pBal = (await me8(primary.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id, guestAccessToken: guest.tokens.accessToken } });
    assertEq(r.status, 200, 'status');
    assertEq((await me8(primary.tokens.accessToken)).coinBalance, pBal + gBal, 'balance = sum');
    assertEq((await req('GET', '/auth/me', { token: guest.tokens.accessToken })).status, 401, 'guest deleted');
    const retry = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id } });
    assertEq(retry.status, 200, 'retry idempotent 200');
    assertEq((await me8(primary.tokens.accessToken)).coinBalance, pBal + gBal, 'retry grants nothing twice');
  });

  await testCase(713, 'V5: relink with ANOTHER user token as proof -> 403 and guest intact; guest refresh-token proof -> merges', async () => {
    const guest = await mkUser('s8-relink-guest-wrongproof');
    const other = await mkUser('s8-relink-other');
    const primary = await mkUser('s8-relink-primary-wrongproof');
    const bad = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id, guestAccessToken: other.tokens.accessToken } });
    assertEq(bad.status, 403, 'wrong-proof status');
    assertEq((await req('GET', '/auth/me', { token: guest.tokens.accessToken })).status, 200, 'guest intact');
    const gBal = (await me8(guest.tokens.accessToken)).coinBalance;
    const pBal = (await me8(primary.tokens.accessToken)).coinBalance;
    const okR = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id, guestRefreshToken: guest.tokens.refreshToken } });
    assertEq(okR.status, 200, 'refresh-proof status');
    assertEq((await me8(primary.tokens.accessToken)).coinBalance, pBal + gBal, 'refresh proof merges (balance = sum)');
  });

  await testCase(714, 'F7: VIP user unlocking non-free VIP-gated episode -> 200 via VIP, coins 0, balance unchanged, no unlock ledger charge', async () => {
    const u = await mkUser('s8-f7-vip');
    const eps = (await req('GET', '/series/series-vip-empire-of-desire/episodes', { token: u.tokens.accessToken })).json.data.episodes;
    const ep = eps.find((e) => e.episodeNumber === 3);
    assert(ep && ep.isVipOnly === true && ep.isFree === false, 'fixture: ep3 non-free + VIP-only');
    const grant = await req('POST', '/admin/users/' + u.user.id + '/vip', { admin: true, body: { isVip: true } });
    assertEq(grant.status, 200, 'admin VIP grant');
    const before = (await me8(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/episodes/' + ep.id + '/unlock', { token: u.tokens.accessToken, body: {} });
    assertEq(r.status, 200, 'unlock status');
    assertEq(r.json.data.success, true, 'success');
    assertEq(r.json.data.coins, 0, 'charged 0');
    assertEq(r.json.data.accessVia, 'vip', 'accessVia vip');
    assertEq((await me8(u.tokens.accessToken)).coinBalance, before, 'balance unchanged');
    const txs = await req('GET', '/me/transactions', { token: u.tokens.accessToken });
    assert(!txs.json.data.items.some((t) => t.type === 'episode_unlock'), 'no episode_unlock ledger row');
    const play = await req('GET', '/episodes/' + ep.id + '/playback', { token: u.tokens.accessToken });
    assertEq(play.status, 200, 'playback works via VIP');
  });

  await testCase(715, 'F7: non-VIP user unlocking VIP-gated episode -> 403 VIP_REQUIRED as before, balance unchanged', async () => {
    const u = await mkUser('s8-f7-nonvip');
    const eps = (await req('GET', '/series/series-vip-empire-of-desire/episodes', { token: u.tokens.accessToken })).json.data.episodes;
    const ep = eps.find((e) => e.episodeNumber === 3);
    const before = (await me8(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/episodes/' + ep.id + '/unlock', { token: u.tokens.accessToken, body: {} });
    assertEq(r.status, 403, 'status');
    assertEq(r.json.error.code, 'VIP_REQUIRED', 'code VIP_REQUIRED');
    assertEq((await me8(u.tokens.accessToken)).coinBalance, before, 'balance unchanged');
  });

  await testCase(716, 'FIX-3: GET /shorts leaks no stream URL for locked items (videoUrl null/absent); unlocked keep videoUrl; VIP user re-exposes a previously-locked VIP item and playback 403 is unchanged for the free user', async () => {
    const free = await mkUser('s8-shorts-leak-free');
    const t = free.tokens.accessToken;
    // Guest (unauthenticated) view must be equally clean.
    const guestFeed = await req('GET', '/shorts?limit=100');
    assertEq(guestFeed.status, 200, 'guest /shorts status');
    assert(guestFeed.json.data.items.filter((i) => !i.isUnlocked).every((i) => i.videoUrl === null || i.videoUrl === undefined), 'guest: every locked item has videoUrl null/absent');
    const feed = await req('GET', '/shorts?limit=100', { token: t });
    assertEq(feed.status, 200, 'free /shorts status');
    const items = feed.json.data.items;
    assert(items.length > 0, 'fixture: shorts feed is non-empty');
    const locked = items.filter((i) => !i.isUnlocked);
    const unlocked = items.filter((i) => i.isUnlocked);
    assert(locked.length >= 1, `fixture: at least one locked item exists (got ${locked.length})`);
    assert(unlocked.length >= 1, `fixture: at least one unlocked item exists (got ${unlocked.length})`);
    for (const i of locked) assert(i.videoUrl === null || i.videoUrl === undefined, `locked item ${i.id} must not carry a stream URL (got ${JSON.stringify(i.videoUrl)})`);
    for (const i of unlocked) assert(typeof i.videoUrl === 'string' && i.videoUrl.length > 0, `unlocked item ${i.id} must still carry its videoUrl`);
    // Target a known VIP-gated episode (same fixture as 714/715) so the
    // VIP re-exposure check below is deterministic.
    const eps = (await req('GET', '/series/series-vip-empire-of-desire/episodes', { token: t })).json.data.episodes;
    const ep = eps.find((e) => e.episodeNumber === 3);
    assert(ep && ep.isVipOnly === true && ep.isFree === false, 'fixture: VIP ep3 non-free + VIP-only');
    const lockedVip = items.find((i) => i.id === ep.id);
    assert(lockedVip, 'fixture: VIP ep3 appears in the shorts feed');
    assertEq(lockedVip.isUnlocked, false, 'VIP ep3 is locked for the free user');
    assert(lockedVip.videoUrl === null || lockedVip.videoUrl === undefined, 'VIP ep3 videoUrl is null/absent for the free user (leak closed)');
    // Playback gate is unchanged: the same episode still 403s for the free user.
    const playFree = await req('GET', '/episodes/' + ep.id + '/playback', { token: t });
    assertEq(playFree.status, 403, 'free playback still 403');
    assertEq(playFree.json.error.code, 'VIP_REQUIRED', 'free playback code VIP_REQUIRED');
    // Grant VIP to the SAME user: the previously-locked item must now
    // expose its URL exactly as playback does.
    const grant = await req('POST', '/admin/users/' + free.user.id + '/vip', { admin: true, body: { isVip: true } });
    assertEq(grant.status, 200, 'admin VIP grant');
    const feedVip = await req('GET', '/shorts?limit=100', { token: t });
    assertEq(feedVip.status, 200, 'VIP /shorts status');
    const nowUnlocked = feedVip.json.data.items.find((i) => i.id === ep.id);
    assert(nowUnlocked, 'VIP ep3 still in the feed after VIP grant');
    assertEq(nowUnlocked.isUnlocked, true, 'VIP ep3 isUnlocked for the VIP user');
    assert(typeof nowUnlocked.videoUrl === 'string' && nowUnlocked.videoUrl.length > 0, 'VIP ep3 now exposes its videoUrl');
    const playVip = await req('GET', '/episodes/' + ep.id + '/playback', { token: t });
    assertEq(playVip.status, 200, 'VIP playback status');
    assertEq(nowUnlocked.videoUrl, playVip.json.data.videoUrl, 'shorts videoUrl matches the entitlement-checked playback videoUrl');
    // Invariant still holds across the whole VIP feed.
    assert(feedVip.json.data.items.filter((i) => !i.isUnlocked).every((i) => i.videoUrl === null || i.videoUrl === undefined), 'VIP feed: every still-locked item has videoUrl null/absent');
  });

} finally {
  child.kill('SIGKILL');
  const summary = `\n===== SUITE 8 SUMMARY =====\nTOTAL: ${passed + failed}  PASSED: ${passed}  FAILED: ${failed}\n${failures.length ? 'FAILURES:\n' + failures.join('\n') : 'ALL PASS'}\n`;
  log(summary);
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  fs.rmSync(tmpDir, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}
