// HERO DRAMA backend — suite 5 (cases 401+).
// Covers: POST /auth/logout (family refresh revocation), PATCH /auth/me
// (strict allow-list profile patch), userJson.notificationsEnabled, and
// GET /me/transactions (caller-only, newest-first, paging).
// Plain node, no deps. Boots the real server on a random port with a TEMP
// database (dev auth), so data/app.db is never touched.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const OUT_FILE = path.join(__dirname, 'LAST_RUN_5.txt');
const ADMIN_TOKEN = 'suite5-fixture';

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

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test5-'));
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
const me = async (token) => (await req('GET', '/auth/me', { token })).json.data.user;
const adminGrant = async (userId, amount) => {
  const r = await req('POST', `/admin/users/${userId}/coins`, { admin: true, body: { amount } });
  assertEq(r.status, 200, `admin grant status (body ${r.text})`);
  return r.json.data.balance;
};

try {
  await waitForHealth();
  log(`Server booted on ${BASE} with temp DB ${dbPath}`);

  await testCase(401, 'logout: refresh works before; after logout the caller refresh AND a second session refresh are 401 (family revocation)', async () => {
    const s1 = await mkUser('s5-logout-user');
    // Refresh works before logout (rotate once, keep the fresh pair).
    const rot = await req('POST', '/auth/refresh', { body: { refreshToken: s1.tokens.refreshToken } });
    assertEq(rot.status, 200, `refresh before logout (body ${rot.text})`);
    const live = rot.json.data.tokens;
    // A second session of the SAME user (fresh login, new refresh token).
    const s2 = await mkUser('s5-logout-user');
    assertEq(s2.user.id, s1.user.id, 'second login is the same user');
    assert(s2.tokens.refreshToken !== live.refreshToken, 'second session has its own refresh token');
    const out = await req('POST', '/auth/logout', { token: live.accessToken, body: { refreshToken: live.refreshToken } });
    assertEq(out.status, 200, `logout status (body ${out.text})`);
    assertEq(out.json.data.success, true, 'logout returns success:true');
    const r1 = await req('POST', '/auth/refresh', { body: { refreshToken: live.refreshToken } });
    assertEq(r1.status, 401, 'logged-out session refresh -> 401');
    const r2 = await req('POST', '/auth/refresh', { body: { refreshToken: s2.tokens.refreshToken } });
    assertEq(r2.status, 401, 'SECOND session refresh also revoked (family) -> 401');
  });

  await testCase(402, 'logout: no token and garbage token -> 401', async () => {
    const noTok = await req('POST', '/auth/logout', { body: {} });
    assertEq(noTok.status, 401, 'logout without token -> 401');
    const bad = await req('POST', '/auth/logout', { token: 'not-a-real-token', body: {} });
    assertEq(bad.status, 401, 'logout with invalid token -> 401');
  });

  await testCase(403, 'PATCH /auth/me: happy path persists every allowed field and is visible via GET /auth/me', async () => {
    const u = await mkUser('s5-patch-user');
    const t = u.tokens.accessToken;
    const r = await req('PATCH', '/auth/me', { token: t, body: {
      name: '  Ahmed Hero  ', image: 'assets/avatars/hero.png', autoplayNext: false,
      videoQuality: '720p', locale: 'ar-EG', notificationsEnabled: false,
    } });
    assertEq(r.status, 200, `patch status (body ${r.text})`);
    const pu = r.json.data.user;
    assertEq(pu.name, 'Ahmed Hero', 'name stored trimmed');
    assertEq(pu.image, 'assets/avatars/hero.png', 'image in response');
    assertEq(pu.photoUrl, 'assets/avatars/hero.png', 'photoUrl mirrors image');
    assertEq(pu.autoplayNext, false, 'autoplayNext false');
    assertEq(pu.videoQuality, '720p', 'videoQuality 720p');
    assertEq(pu.locale, 'ar-EG', 'locale ar-EG');
    assertEq(pu.notificationsEnabled, false, 'notificationsEnabled false');
    const fresh = await me(t);
    assertEq(fresh.name, 'Ahmed Hero', 'name persisted via GET /auth/me');
    assertEq(fresh.videoQuality, '720p', 'videoQuality persisted');
    assertEq(fresh.autoplayNext, false, 'autoplayNext persisted');
    assertEq(fresh.notificationsEnabled, false, 'notificationsEnabled persisted');
    // Partial patch touches only the named fields.
    const r2 = await req('PATCH', '/auth/me', { token: t, body: { videoQuality: '1080p' } });
    assertEq(r2.status, 200, 'partial patch status');
    assertEq(r2.json.data.user.videoQuality, '1080p', 'partial patch applied');
    assertEq(r2.json.data.user.name, 'Ahmed Hero', 'other fields untouched by partial patch');
  });

  await testCase(404, 'PATCH /auth/me: unknown key -> 400 BAD_FIELD (and nothing is persisted)', async () => {
    const u = await mkUser('s5-badfield-user');
    const t = u.tokens.accessToken;
    const before = await me(t);
    const r = await req('PATCH', '/auth/me', { token: t, body: { coinBalance: 999999 } });
    assertEq(r.status, 400, 'unknown key -> 400');
    assertEq(r.json.error.code, 'BAD_FIELD', 'error code BAD_FIELD');
    const mixed = await req('PATCH', '/auth/me', { token: t, body: { name: 'Legit', isPro: true } });
    assertEq(mixed.status, 400, 'valid + unknown key -> 400');
    assertEq(mixed.json.error.code, 'BAD_FIELD', 'mixed patch code BAD_FIELD');
    const after = await me(t);
    assertEq(after.coinBalance, before.coinBalance, 'coinBalance unchanged');
    assertEq(after.isPro, false, 'isPro unchanged');
    assertEq(after.name, before.name, 'name unchanged by rejected mixed patch');
  });

  await testCase(405, 'PATCH /auth/me: empty body -> 400; unauthenticated -> 401', async () => {
    const u = await mkUser('s5-empty-user');
    const r = await req('PATCH', '/auth/me', { token: u.tokens.accessToken, body: {} });
    assertEq(r.status, 400, 'empty body -> 400');
    const noTok = await req('PATCH', '/auth/me', { body: { name: 'X' } });
    assertEq(noTok.status, 401, 'patch without token -> 401');
  });

  await testCase(406, 'PATCH /auth/me: invalid values -> 400 (videoQuality, name length, wrong types, locale, image length)', async () => {
    const u = await mkUser('s5-invalid-user');
    const t = u.tokens.accessToken;
    const badBodies = [
      ['bad videoQuality', { videoQuality: '4k' }],
      ['name too long (61)', { name: 'x'.repeat(61) }],
      ['name blank after trim', { name: '   ' }],
      ['name non-string', { name: 42 }],
      ['autoplayNext non-boolean', { autoplayNext: 'yes' }],
      ['notificationsEnabled non-boolean', { notificationsEnabled: 0 }],
      ['locale too short', { locale: 'a' }],
      ['locale too long', { locale: 'a'.repeat(11) }],
      ['image too long (501)', { image: 'x'.repeat(501) }],
    ];
    for (const [label, body] of badBodies) {
      const r = await req('PATCH', '/auth/me', { token: t, body });
      assertEq(r.status, 400, `${label} -> 400 (body ${r.text})`);
      assert(r.json.error && r.json.error.code, `${label} carries an error code`);
    }
    // Boundary values are accepted.
    const ok60 = await req('PATCH', '/auth/me', { token: t, body: { name: 'y'.repeat(60), videoQuality: '360p', locale: 'en' } });
    assertEq(ok60.status, 200, `boundary values accepted (body ${ok60.text})`);
    assertEq(ok60.json.data.user.name.length, 60, '60-char name stored');
  });

  await testCase(407, 'userJson.notificationsEnabled: defaults true for a new user; false/true round-trip via PATCH + GET /auth/me', async () => {
    const u = await mkUser('s5-notif-user');
    assertEq(u.user.notificationsEnabled, true, 'new user defaults notificationsEnabled=true');
    const t = u.tokens.accessToken;
    const off = await req('PATCH', '/auth/me', { token: t, body: { notificationsEnabled: false } });
    assertEq(off.json.data.user.notificationsEnabled, false, 'patched to false');
    assertEq((await me(t)).notificationsEnabled, false, 'false persists');
    const on = await req('PATCH', '/auth/me', { token: t, body: { notificationsEnabled: true } });
    assertEq(on.json.data.user.notificationsEnabled, true, 'patched back to true');
    assertEq((await me(t)).notificationsEnabled, true, 'true persists');
  });

  await testCase(408, 'PATCH /auth/me: patch only ever affects the caller (user B patching leaves user A untouched)', async () => {
    const a = await mkUser('s5-iso-user-a');
    const b = await mkUser('s5-iso-user-b');
    const aBefore = await me(a.tokens.accessToken);
    const r = await req('PATCH', '/auth/me', { token: b.tokens.accessToken, body: { name: 'B Was Here', videoQuality: '480p', notificationsEnabled: false } });
    assertEq(r.status, 200, 'B patch status');
    assertEq(r.json.data.user.id, b.user.id, 'patch response is B');
    const aAfter = await me(a.tokens.accessToken);
    assertEq(aAfter.name, aBefore.name, 'A name untouched by B patch');
    assertEq(aAfter.videoQuality, aBefore.videoQuality, 'A videoQuality untouched');
    assertEq(aAfter.notificationsEnabled, aBefore.notificationsEnabled, 'A notificationsEnabled untouched');
    assertEq((await me(b.tokens.accessToken)).name, 'B Was Here', 'B sees own patch');
  });

  await testCase(409, 'GET /me/transactions: seeded grants come back newest-first with the exact item shape and matching total', async () => {
    const u = await mkUser('s5-tx-user');
    const t = u.tokens.accessToken;
    await adminGrant(u.user.id, 10);
    await adminGrant(u.user.id, 20);
    await adminGrant(u.user.id, -5);
    const r = await req('GET', '/me/transactions', { token: t });
    assertEq(r.status, 200, `transactions status (body ${r.text})`);
    const { items, total } = r.json.data;
    assertEq(total, 4, 'total = welcome + 3 admin grants');
    assertEq(items.length, 4, 'all 4 items returned by default');
    assertEq(items.map((i) => i.amount).join(','), '-5,20,10,' + items[3].amount, 'newest-first order');
    assertEq(items[3].type, 'welcome_bonus', 'oldest item is the welcome bonus');
    assertEq(items[0].type, 'admin_adjust', 'newest item type');
    for (const it of items) {
      assertEq(Object.keys(it).sort().join(','), 'amount,balanceAfter,createdAt,id,refId,type', 'item shape is exactly {id,amount,type,refId,balanceAfter,createdAt}');
    }
    const bal = (await me(t)).coinBalance;
    assertEq(items[0].balanceAfter, bal, 'newest balanceAfter equals current balance');
  });

  await testCase(410, 'GET /me/transactions: limit/offset paging is stable and non-overlapping; oversized limit is clamped', async () => {
    const u = await mkUser('s5-page-user');
    const t = u.tokens.accessToken;
    await adminGrant(u.user.id, 1);
    await adminGrant(u.user.id, 2);
    await adminGrant(u.user.id, 3);
    const all = await req('GET', '/me/transactions?limit=500', { token: t });
    assertEq(all.json.data.total, 4, 'total 4');
    assertEq(all.json.data.items.length, 4, 'limit=500 clamped, returns all 4');
    const p1 = await req('GET', '/me/transactions?limit=2&offset=0', { token: t });
    const p2 = await req('GET', '/me/transactions?limit=2&offset=2', { token: t });
    assertEq(p1.json.data.items.length, 2, 'page 1 has 2');
    assertEq(p2.json.data.items.length, 2, 'page 2 has 2');
    assertEq(p1.json.data.total, 4, 'page 1 total');
    assertEq(p2.json.data.total, 4, 'page 2 total');
    const ids = [...p1.json.data.items, ...p2.json.data.items].map((i) => i.id);
    assertEq(new Set(ids).size, 4, 'pages do not overlap');
    assertEq(ids.join(','), all.json.data.items.map((i) => i.id).join(','), 'pages concatenate to the full newest-first list');
    const past = await req('GET', '/me/transactions?limit=2&offset=99', { token: t });
    assertEq(past.json.data.items.length, 0, 'offset past the end -> empty items');
    assertEq(past.json.data.total, 4, 'total still reported past the end');
  });

  await testCase(411, 'GET /me/transactions: user isolation (B sees only own rows) and 401 without a token', async () => {
    const a = await mkUser('s5-tx-iso-a');
    const b = await mkUser('s5-tx-iso-b');
    await adminGrant(a.user.id, 777);
    const ra = await req('GET', '/me/transactions', { token: a.tokens.accessToken });
    const rb = await req('GET', '/me/transactions', { token: b.tokens.accessToken });
    assertEq(ra.json.data.total, 2, 'A total = welcome + grant');
    assertEq(rb.json.data.total, 1, 'B total = welcome only');
    assert(rb.json.data.items.every((i) => i.amount !== 777), 'B never sees A grant');
    const noTok = await req('GET', '/me/transactions');
    assertEq(noTok.status, 401, 'transactions without token -> 401');
  });
} finally {
  child.kill('SIGKILL');
  const summary = `\n===== SUITE 5 SUMMARY =====\nTOTAL: ${passed + failed}  PASSED: ${passed}  FAILED: ${failed}\n${failures.length ? 'FAILURES:\n' + failures.join('\n') : 'ALL PASS'}\n`;
  log(summary);
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  fs.rmSync(tmpDir, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}
