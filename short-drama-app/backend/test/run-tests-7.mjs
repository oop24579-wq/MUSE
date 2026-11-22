// HERO DRAMA backend — suite 7 (cases 601+, backend-fix round).
// Covers: SIM-A F1 (unlock VIP gate ordering), SIM-B F1 (webhook coin
// classification with entitlement_ids), SIM-B F4 (consumable lifecycle
// events create no orders), SIM-B F5b (lifecycle price inheritance),
// SIM-B F2 support (order periodEnd), SIM-C Bug 1 (profile name revert),
// Bug 2 (/for-you personalization), Bug 5 (resume final episode),
// Bug 3 (search field ranking), SIM-A F4 (connect_email guest gate),
// SIM-C Bug 6 (maintenance message in 503 body).
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
const OUT_FILE = path.join(__dirname, 'LAST_RUN_7.txt');
const ADMIN_TOKEN = 'suite7-fixture';

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

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test7-'));
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
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const emailToken = (sub, email, name) => `${b64u({ alg: 'RS256', typ: 'JWT' })}.${b64u({ sub, email, name })}.fakesig`;
async function mkUser(idToken) {
  const r = await req('POST', '/auth/firebase', { body: { idToken } });
  assertEq(r.status, 200, 'auth status');
  return { user: r.json.data.user, tokens: r.json.data.tokens };
}
const me = async (token) => (await req('GET', '/auth/me', { token })).json.data.user;
const ordersOf = async (token) => (await req('GET', '/user/orders', { token })).json.data;
const rcEvent = (over) => ({ api_version: '1.0', event: { type: 'INITIAL_PURCHASE', ...over } });

try {
  await waitForHealth();
  log(`Server booted on ${BASE} with temp DB ${dbPath}`);

  await testCase(601, 'SIM-A F1: unlock on a FREE + VIP-only episode as non-VIP -> 403 VIP_REQUIRED (consistent with playback); VIP user -> 200 coins 0', async () => {
    const u = await mkUser('s7-unlock-guest');
    const eps = (await req('GET', '/series/series-vip-empire-of-desire/episodes', { token: u.tokens.accessToken })).json.data.episodes;
    const ep1 = eps.find((e) => e.episodeNumber === 1);
    assert(ep1.isFree === true && ep1.isVipOnly === true, 'fixture: ep1 is free + VIP-only');
    const unlock = await req('POST', `/episodes/${ep1.id}/unlock`, { token: u.tokens.accessToken, body: {} });
    assertEq(unlock.status, 403, `unlock status (body ${unlock.text})`);
    assertEq(unlock.json.error.code, 'VIP_REQUIRED', 'unlock code VIP_REQUIRED');
    const play = await req('GET', `/episodes/${ep1.id}/playback`, { token: u.tokens.accessToken });
    assertEq(play.status, 403, 'playback also 403');
    assertEq(play.json.error.code, 'VIP_REQUIRED', 'playback code matches unlock');
    const grant = await req('POST', `/admin/users/${u.user.id}/vip`, { admin: true, body: { isVip: true } });
    assertEq(grant.status, 200, 'admin VIP grant');
    const unlock2 = await req('POST', `/episodes/${ep1.id}/unlock`, { token: u.tokens.accessToken, body: {} });
    assertEq(unlock2.status, 200, 'VIP user unlock status');
    assertEq(unlock2.json.data.success, true, 'VIP user unlock succeeds');
    assertEq(unlock2.json.data.coins, 0, 'VIP user unlock is free');
  });

  await testCase(602, 'SIM-B F1: webhook coins_300 WITH entitlement_ids:["coins"] -> kind coins, +300 coins, no VIP', async () => {
    const u = await mkUser('s7-wh-coins-ent');
    const before = (await me(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({
      type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_300',
      entitlement_ids: ['coins'], price: 2.99, currency: 'USD', transaction_id: 's7-tx-300',
    }) });
    assertEq(r.status, 200, `webhook status (body ${r.text})`);
    assertEq(r.json.data.applied, true, 'applied');
    const after = await me(u.tokens.accessToken);
    assertEq(after.coinBalance, before + 300, 'balance +300');
    assertEq(after.isPro, false, 'coin purchase does NOT grant VIP');
    const orders = await ordersOf(u.tokens.accessToken);
    assertEq(orders.orders[0].kind, 'coins', 'order kind coins');
    assertEq(orders.orders[0].coinPackageId, 'coins_300', 'coinPackageId set');
    assertEq(orders.orders[0].subscriptionPlanId, null, 'subscriptionPlanId null');
  });

  await testCase(603, 'SIM-B F4: EXPIRATION and CANCELLATION for a coin product create NO order row and apply nothing', async () => {
    const u = await mkUser('s7-wh-coin-lifecycle');
    await req('POST', '/webhooks/revenuecat', { body: rcEvent({ type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_300', transaction_id: 's7-tx-life-0' }) });
    const balBefore = (await me(u.tokens.accessToken)).coinBalance;
    for (const [i, type] of ['EXPIRATION', 'CANCELLATION'].entries()) {
      const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({ type, app_user_id: u.user.id, product_id: 'coins_300', transaction_id: `s7-tx-life-${i + 1}` }) });
      assertEq(r.status, 200, `${type} status`);
      assertEq(r.json.data.applied, false, `${type} applied:false`);
      assert(typeof r.json.data.reason === 'string' && r.json.data.reason.length > 0, `${type} carries a reason`);
    }
    const orders = await ordersOf(u.tokens.accessToken);
    assertEq(orders.total, 1, 'only the original purchase order exists');
    assertEq((await me(u.tokens.accessToken)).coinBalance, balBefore, 'balance unchanged by lifecycle events');
  });

  await testCase(604, 'SIM-B F5b: VIP CANCELLATION with no price inherits amountCents/currency from the most recent paid order for the product', async () => {
    const u = await mkUser('s7-wh-cancel-inherit');
    await req('POST', '/webhooks/revenuecat', { body: rcEvent({
      app_user_id: u.user.id, product_id: 'vip_monthly', price: 12.34, currency: 'EUR',
      transaction_id: 's7-tx-ci-1', expiration_at_ms: Date.now() + 30 * 86400e3,
    }) });
    const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({ type: 'CANCELLATION', app_user_id: u.user.id, product_id: 'vip_monthly', transaction_id: 's7-tx-ci-2' }) });
    assertEq(r.status, 200, 'cancellation status');
    const orders = await ordersOf(u.tokens.accessToken);
    const cancel = orders.orders[0];
    assertEq(cancel.status, 'cancelled', 'newest order is the cancellation');
    assertEq(cancel.amountCents, 1234, 'amountCents inherited (1234)');
    assertEq(cancel.currency, 'EUR', 'currency inherited (EUR)');
  });

  await testCase(605, 'SIM-B F2 support: VIP order periodEnd = event expiration (webhook) and = applied expiry (admin manual order)', async () => {
    const u = await mkUser('s7-period-webhook');
    const expMs = Date.now() + 30 * 86400e3;
    await req('POST', '/webhooks/revenuecat', { body: rcEvent({
      app_user_id: u.user.id, product_id: 'vip_monthly', entitlement_ids: ['vip'],
      price: 9.99, currency: 'USD', transaction_id: 's7-tx-pe-1', expiration_at_ms: expMs,
    }) });
    const orders = await ordersOf(u.tokens.accessToken);
    assertEq(orders.orders[0].periodEnd, new Date(expMs).toISOString(), 'webhook VIP periodEnd = event expiration');
    const u2 = await mkUser('s7-period-manual');
    const manual = await req('POST', '/admin/orders', { admin: true, body: { userId: u2.user.id, productId: 'vip_yearly', kind: 'vip', amountCents: 9999, currency: 'USD' } });
    assertEq(manual.status, 201, `manual order status (body ${manual.text})`);
    assert(typeof manual.json.data.periodEnd === 'string' && manual.json.data.periodEnd.length > 0, 'manual VIP order carries periodEnd');
    assertEq(manual.json.data.periodEnd, (await me(u2.tokens.accessToken)).subscriptionExpirationDate, 'manual periodEnd = the expiry actually applied to the user');
  });

  await testCase(606, 'SIM-C Bug 1: PATCH /auth/me name survives re-login with a different claim name; a new user still gets the claim name', async () => {
    const u = await mkUser(emailToken('s7-name-sub', 's7.name@example.com', 'Claim One'));
    assertEq(u.user.name, 'Claim One', 'new user gets the claim name');
    const patch = await req('PATCH', '/auth/me', { token: u.tokens.accessToken, body: { name: 'Edited Name' } });
    assertEq(patch.status, 200, 'patch status');
    assertEq(patch.json.data.user.name, 'Edited Name', 'name edited');
    const relogin = await req('POST', '/auth/firebase', { body: { idToken: emailToken('s7-name-sub', 's7.name@example.com', 'Claim Two') } });
    assertEq(relogin.status, 200, 're-login status');
    assertEq(relogin.json.data.user.name, 'Edited Name', 're-login does NOT revert the edited name');
    assertEq((await me(relogin.json.data.tokens.accessToken)).name, 'Edited Name', 'stored name still the edited one');
    const fresh = await mkUser(emailToken('s7-name-fresh', 's7.fresh@example.com', 'Fresh Claim'));
    assertEq(fresh.user.name, 'Fresh Claim', 'brand-new user still gets the claim name');
  });

  await testCase(607, 'SIM-C Bug 2: GET /for-you is personalized (completed series excluded); guest gets 200 with the trending fallback', async () => {
    const guest = await req('GET', '/for-you');
    assertEq(guest.status, 200, 'guest /for-you status');
    assert(guest.json.data.series.length > 0, 'guest gets series');
    assertEq(guest.json.data.series[0].id, 'series-married-to-the-ceo', 'guest fallback = trending head');
    const urban = 'series-city-of-hidden-lies';
    const u = await mkUser('s7-foryou');
    for (let n = 1; n <= 10; n++) {
      const r = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: urban, episodeId: `${urban}-ep${n}`, episodeNumber: n, positionSeconds: 30, durationSeconds: 200, completed: true } });
      assertEq(r.status, 200, `watch ep${n}`);
    }
    const mine = await req('GET', '/for-you', { token: u.tokens.accessToken });
    assertEq(mine.status, 200, 'user /for-you status');
    assert(!mine.json.data.series.some((s) => s.id === urban), 'completed series excluded from /for-you');
  });

  await testCase(608, 'SIM-C Bug 5: series detail resume restarts at episode 1 after the completed FINAL episode; completed non-final keeps the existing resume point', async () => {
    const SID = 'series-married-to-the-ceo';
    const u = await mkUser('s7-resume-final');
    const eps = (await req('GET', `/series/${SID}/episodes`, { token: u.tokens.accessToken })).json.data.episodes;
    const last = eps[eps.length - 1];
    await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: SID, episodeId: last.id, episodeNumber: last.episodeNumber, positionSeconds: last.durationSeconds, durationSeconds: last.durationSeconds, completed: true } });
    const d = await req('GET', `/series/${SID}`, { token: u.tokens.accessToken });
    assertEq(d.json.data.resumeEpisodeId, eps[0].id, 'resume after final = first episode (restart)');
    assertEq(d.json.data.resumeEpisodeNumber, eps[0].episodeNumber, 'resume number matches the first episode');
    const u2 = await mkUser('s7-resume-mid');
    await req('POST', '/me/watch-history', { token: u2.tokens.accessToken, body: { seriesId: SID, episodeId: eps[1].id, episodeNumber: eps[1].episodeNumber, positionSeconds: eps[1].durationSeconds, durationSeconds: eps[1].durationSeconds, completed: true } });
    const d2 = await req('GET', `/series/${SID}`, { token: u2.tokens.accessToken });
    assertEq(d2.json.data.resumeEpisodeId, eps[1].id, 'completed non-final keeps the existing resume behaviour');
  });

  await testCase(609, 'SIM-C Bug 3: GET /search ranks title matches first, then tag matches, then synopsis-only matches', async () => {
    const mk = async (slug, title, synopsis, tags) => {
      const r = await req('POST', '/admin/series', { admin: true, body: { slug, title, synopsis, tags, genreId: 'genre-romance' } });
      assertEq(r.status, 201, `create ${slug} (body ${r.text})`);
      return r.json.data.id;
    };
    // Created in REVERSE rank order (synopsis, tag, title) so the old
    // unranked order would fail this test.
    const synId = await mk('zxqy-syn', 'Plain Alpha', 'a zxqy tale of secrets', []);
    const tagId = await mk('zxqy-tag', 'Plain Beta', 'nothing relevant here', ['zxqy']);
    const titleId = await mk('zxqy-title', 'Zxqy Chronicles', 'nothing relevant here', []);
    const r = await req('GET', '/search?q=zxqy');
    assertEq(r.status, 200, 'search status');
    const ids = r.json.data.series.map((s) => s.id);
    assertEq(JSON.stringify(ids), JSON.stringify([titleId, tagId, synId]), 'ranked order title > tag > synopsis');
  });

  await testCase(610, 'SIM-A F4: connect_email task refuses guests (403 EMAIL_LINK_REQUIRED, no payout); an email-linked user can claim it', async () => {
    const guest = await mkUser('s7-task-guest');
    const balBefore = (await me(guest.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/rewards/tasks/connect_email/complete', { token: guest.tokens.accessToken, body: {} });
    assertEq(r.status, 403, `guest connect_email status (body ${r.text})`);
    assertEq(r.json.error.code, 'EMAIL_LINK_REQUIRED', 'guest code EMAIL_LINK_REQUIRED');
    assertEq((await me(guest.tokens.accessToken)).coinBalance, balBefore, 'guest balance unchanged');
    const emailUser = await mkUser(emailToken('s7-task-email', 's7.task@example.com', 'Task User'));
    assertEq(emailUser.user.isGuest, false, 'fixture: email user is not a guest');
    const okR = await req('POST', '/rewards/tasks/connect_email/complete', { token: emailUser.tokens.accessToken, body: {} });
    assertEq(okR.status, 200, `email user connect_email status (body ${okR.text})`);
    assertEq(okR.json.data.success, true, 'email user claim succeeds');
    assertEq(okR.json.data.coins, 5, 'email user paid the task coins');
  });

  await testCase(611, 'SIM-C Bug 6: maintenance 503 body carries the configured maintenance_message when set', async () => {
    const u = await mkUser('s7-maint');
    try {
      const patch = await req('PATCH', '/admin/settings', { admin: true, body: { maintenance_message: 'Back soon — s7 maintenance', maintenance_mode: true } });
      assertEq(patch.status, 200, `settings patch (body ${patch.text})`);
      const r = await req('GET', '/categories', { token: u.tokens.accessToken });
      assertEq(r.status, 503, 'app endpoint 503 during maintenance');
      assertEq(r.json.error.code, 'MAINTENANCE', 'code MAINTENANCE');
      assertEq(r.json.error.message, 'Back soon — s7 maintenance', '503 body carries the configured message');
    } finally {
      await req('PATCH', '/admin/settings', { admin: true, body: { maintenance_mode: false, maintenance_message: '' } });
    }
    const after = await req('GET', '/categories', { token: u.tokens.accessToken });
    assertEq(after.status, 200, 'app works again after maintenance off');
  });
} finally {
  child.kill('SIGKILL');
  const summary = `\n===== SUITE 7 SUMMARY =====\nTOTAL: ${passed + failed}  PASSED: ${passed}  FAILED: ${failed}\n${failures.length ? 'FAILURES:\n' + failures.join('\n') : 'ALL PASS'}\n`;
  log(summary);
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  fs.rmSync(tmpDir, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}
