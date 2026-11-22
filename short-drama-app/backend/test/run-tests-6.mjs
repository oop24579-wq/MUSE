// HERO DRAMA backend — suite 6 (cases 501+, Round 4).
// Covers: orders + RevenueCat webhook (VIP/coins entitlements, idempotency,
// HMAC/Bearer signature gate, expiration), GET /user/orders (shape the
// PurchaseHistoryScreen parses, isolation, paging), admin manual orders,
// GET /shorts (shape + cursor pagination + feature flag), GET /home
// "For You" personalization (affinity, guest fallback, completed exclusion),
// PATCH /auth/me consent sync, /config shorts flag + maintenance message.
// Plain node, no deps. Boots real servers on random ports with TEMP
// databases (dev auth), so data/app.db is never touched.
import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const OUT_FILE = path.join(__dirname, 'LAST_RUN_6.txt');
const ADMIN_TOKEN = 'suite6-fixture';
const WEBHOOK_SECRET = 'whsec-suite6';

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

async function boot(extraEnv) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test6-'));
  const dbPath = path.join(tmpDir, 'app.db');
  const port = await freePort();
  const BASE = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(port), DB_PATH: dbPath, FIREBASE_AUTH_DEV: '1', ADMIN_TOKEN, JWT_SECRET: 'test-jwt-secret-123', ...extraEnv },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let serverLog = '';
  child.stdout.on('data', (d) => { serverLog += d; });
  child.stderr.on('data', (d) => { serverLog += d; });
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) return { child, tmpDir, BASE, API: `${BASE}/api/v1` }; } catch { /* not up */ }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('server did not become healthy. Log: ' + serverLog);
}

function makeReq(API) {
  return async function req(method, urlPath, { token, body, admin, headers = {}, rawBody } = {}) {
    const h = { 'Content-Type': 'application/json', ...headers };
    if (token) h.Authorization = `Bearer ${token}`;
    if (admin) h['X-Admin-Token'] = ADMIN_TOKEN;
    const res = await fetch(urlPath.startsWith('http') ? urlPath : API + urlPath, {
      method, headers: h, body: rawBody !== undefined ? rawBody : (body !== undefined ? JSON.stringify(body) : undefined),
    });
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch { /* keep null */ }
    return { status: res.status, json, text };
  };
}

const main = await boot({});
const req = makeReq(main.API);
const secretSrv = await boot({ REVENUECAT_WEBHOOK_SECRET: WEBHOOK_SECRET });
const reqS = makeReq(secretSrv.API);

async function mkUser(idToken, r = req) {
  const res = await r('POST', '/auth/firebase', { body: { idToken } });
  assertEq(res.status, 200, 'auth status');
  return { user: res.json.data.user, tokens: res.json.data.tokens };
}
const me = async (token, r = req) => (await r('GET', '/auth/me', { token })).json.data.user;
const rcEvent = (over) => ({ api_version: '1.0', event: { type: 'INITIAL_PURCHASE', ...over } });

try {
  log(`Servers booted: main ${main.BASE}, secret ${secretSrv.BASE}`);

  await testCase(501, 'webhook VIP purchase (dev mode, no secret): order recorded in the exact screen shape + VIP entitlement applied', async () => {
    const u = await mkUser('s6-wh-vip');
    const expMs = Date.now() + 30 * 86400e3;
    const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({
      app_user_id: u.user.id, product_id: 'vip_monthly', entitlement_ids: ['vip'],
      price: 9.99, currency: 'USD', transaction_id: 'tx-1001', expiration_at_ms: expMs,
    }) });
    assertEq(r.status, 200, `webhook status (body ${r.text})`);
    assertEq(r.json.data.applied, true, 'webhook applied');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.status, 200, 'orders status');
    assertEq(orders.json.data.total, 1, 'one order');
    const o = orders.json.data.orders[0];
    assertEq(o.id, r.json.data.orderId, 'order id matches webhook response');
    assertEq(o.userId, u.user.id, 'order userId');
    assertEq(o.paymentProvider, 'revenuecat', 'paymentProvider revenuecat');
    assertEq(o.subscriptionPlanId, 'vip_monthly', 'subscriptionPlanId = productId for vip');
    assertEq(o.coinPackageId, null, 'coinPackageId null for vip');
    assertEq(o.kind, 'vip', 'kind vip');
    assertEq(o.status, 'paid', 'status paid (screen maps paid -> active)');
    assertEq(o.amountCents, 999, 'amountCents from price 9.99');
    assertEq(o.currency, 'USD', 'currency USD');
    assertEq(o.revenueCatTransactionId, 'tx-1001', 'transaction id stored');
    assert(typeof o.createdAt === 'string' && o.createdAt.length > 0, 'createdAt present');
    const after = await me(u.tokens.accessToken);
    assertEq(after.isPro, true, 'VIP entitlement applied (isPro)');
    assertEq(after.subscriptionExpirationDate, new Date(expMs).toISOString(), 'expiry from event expiration_at_ms');
  });

  await testCase(502, 'webhook coins purchase: grantCoins path credits the balance and writes a purchase ledger row', async () => {
    const u = await mkUser('s6-wh-coins');
    const before = (await me(u.tokens.accessToken)).coinBalance;
    const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({
      type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_500',
      price_in_pence: 499, currency: 'USD', transaction_id: 'tx-2001',
    }) });
    assertEq(r.status, 200, `webhook status (body ${r.text})`);
    assertEq(r.json.data.applied, true, 'applied');
    const after = (await me(u.tokens.accessToken)).coinBalance;
    assertEq(after, before + 500, 'balance +500 from product id amount');
    const txs = await req('GET', '/me/transactions', { token: u.tokens.accessToken });
    const purchase = txs.json.data.items.find((t) => t.type === 'purchase');
    assert(purchase, 'ledger has a purchase row');
    assertEq(purchase.amount, 500, 'ledger amount 500');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.orders[0].kind, 'coins', 'order kind coins');
    assertEq(orders.json.data.orders[0].coinPackageId, 'coins_500', 'coinPackageId = productId for coins');
    assertEq(orders.json.data.orders[0].amountCents, 499, 'amountCents from price_in_pence');
  });

  await testCase(503, 'webhook idempotency: the same transaction id delivered twice grants exactly once', async () => {
    const u = await mkUser('s6-wh-idem');
    const payload = rcEvent({ type: 'NON_RENEWING_PURCHASE', app_user_id: u.user.id, product_id: 'coins_300', transaction_id: 'tx-3001' });
    const r1 = await req('POST', '/webhooks/revenuecat', { body: payload });
    assertEq(r1.json.data.applied, true, 'first delivery applied');
    const bal1 = (await me(u.tokens.accessToken)).coinBalance;
    const r2 = await req('POST', '/webhooks/revenuecat', { body: payload });
    assertEq(r2.status, 200, 'retry still 200 (RevenueCat will not retry forever)');
    assertEq(r2.json.data.duplicate, true, 'second delivery flagged duplicate');
    const bal2 = (await me(u.tokens.accessToken)).coinBalance;
    assertEq(bal2, bal1, 'balance unchanged by the duplicate delivery');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.total, 1, 'exactly one order row');
  });

  await testCase(504, 'webhook signature gate (secret set): missing/wrong signature -> 401, HMAC and Bearer both accepted', async () => {
    const u = await mkUser('s6-wh-sig', reqS);
    const payload = JSON.stringify(rcEvent({ app_user_id: u.user.id, product_id: 'vip_weekly', transaction_id: 'tx-4001' }));
    const noSig = await reqS('POST', '/webhooks/revenuecat', { rawBody: payload });
    assertEq(noSig.status, 401, 'no signature -> 401');
    assertEq(noSig.json.error.code, 'INVALID_SIGNATURE', 'code INVALID_SIGNATURE');
    const badSig = crypto.createHmac('sha256', 'wrong-secret').update(payload).digest('hex');
    const wrong = await reqS('POST', '/webhooks/revenuecat', { rawBody: payload, headers: { 'x-webhook-signature': badSig } });
    assertEq(wrong.status, 401, 'wrong HMAC -> 401');
    const goodSig = crypto.createHmac('sha256', WEBHOOK_SECRET).update(payload).digest('hex');
    const good = await reqS('POST', '/webhooks/revenuecat', { rawBody: payload, headers: { 'x-webhook-signature': goodSig } });
    assertEq(good.status, 200, `correct HMAC -> 200 (body ${good.text})`);
    assertEq(good.json.data.applied, true, 'HMAC delivery applied');
    const payload2 = JSON.stringify(rcEvent({ app_user_id: u.user.id, product_id: 'vip_weekly', transaction_id: 'tx-4002' }));
    const bearer = await reqS('POST', '/webhooks/revenuecat', { rawBody: payload2, headers: { Authorization: `Bearer ${WEBHOOK_SECRET}` } });
    assertEq(bearer.status, 200, 'Bearer secret -> 200');
    assertEq(bearer.json.data.applied, true, 'Bearer delivery applied');
    const orders = await reqS('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.total, 2, 'only the two valid deliveries recorded');
  });

  await testCase(505, 'webhook unknown user / missing product: 200 with applied:false, nothing recorded, no crash', async () => {
    const ghost = await req('POST', '/webhooks/revenuecat', { body: rcEvent({ app_user_id: 'no-such-user', product_id: 'vip_monthly', transaction_id: 'tx-5001' }) });
    assertEq(ghost.status, 200, 'unknown user -> 200');
    assertEq(ghost.json.data.applied, false, 'unknown user not applied');
    const u = await mkUser('s6-wh-noproduct');
    const noProd = await req('POST', '/webhooks/revenuecat', { body: rcEvent({ app_user_id: u.user.id, transaction_id: 'tx-5002' }) });
    assertEq(noProd.status, 200, 'missing product -> 200');
    assertEq(noProd.json.data.applied, false, 'missing product not applied');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.total, 0, 'no orders recorded');
  });

  await testCase(506, 'GET /user/orders: caller-only isolation, newest-first paging, 401 without a token', async () => {
    const a = await mkUser('s6-orders-a');
    const b = await mkUser('s6-orders-b');
    for (const txId of ['tx-6001', 'tx-6002', 'tx-6003']) {
      await req('POST', '/webhooks/revenuecat', { body: rcEvent({ type: 'NON_RENEWING_PURCHASE', app_user_id: a.user.id, product_id: 'coins_100', transaction_id: txId }) });
    }
    const ra = await req('GET', '/user/orders', { token: a.tokens.accessToken });
    assertEq(ra.json.data.total, 3, 'A has 3 orders');
    assertEq(ra.json.data.orders[0].revenueCatTransactionId, 'tx-6003', 'newest first');
    const rb = await req('GET', '/user/orders', { token: b.tokens.accessToken });
    assertEq(rb.json.data.total, 0, 'B sees none of A orders');
    const p1 = await req('GET', '/user/orders?limit=2&offset=0', { token: a.tokens.accessToken });
    const p2 = await req('GET', '/user/orders?limit=2&offset=2', { token: a.tokens.accessToken });
    assertEq(p1.json.data.orders.length, 2, 'page 1 size');
    assertEq(p2.json.data.orders.length, 1, 'page 2 size');
    const ids = [...p1.json.data.orders, ...p2.json.data.orders].map((o) => o.id);
    assertEq(new Set(ids).size, 3, 'pages do not overlap');
    const noTok = await req('GET', '/user/orders');
    assertEq(noTok.status, 401, 'orders without token -> 401');
  });

  await testCase(507, 'admin manual order: creates + applies VIP via the shared path, provider manual; auth and validation enforced', async () => {
    const u = await mkUser('s6-manual');
    const noAdmin = await req('POST', '/admin/orders', { body: { userId: u.user.id, productId: 'vip_yearly', kind: 'vip' } });
    assertEq(noAdmin.status, 401, 'manual order without admin token -> 401');
    const ghost = await req('POST', '/admin/orders', { admin: true, body: { userId: 'nope', productId: 'vip_yearly', kind: 'vip' } });
    assertEq(ghost.status, 404, 'unknown user -> 404');
    const badAmt = await req('POST', '/admin/orders', { admin: true, body: { userId: u.user.id, productId: 'vip_yearly', kind: 'vip', amountCents: -5 } });
    assertEq(badAmt.status, 400, 'negative amountCents -> 400');
    const r = await req('POST', '/admin/orders', { admin: true, body: { userId: u.user.id, productId: 'vip_yearly', kind: 'vip', amountCents: 9999, currency: 'USD' } });
    assertEq(r.status, 201, `manual order status (body ${r.text})`);
    assertEq(r.json.data.paymentProvider, 'manual', 'provider manual');
    assertEq((await me(u.tokens.accessToken)).isPro, true, 'manual VIP applied');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.total, 1, 'manual order visible to the user');
    assertEq(orders.json.data.orders[0].paymentProvider, 'manual', 'user sees provider manual');
    const list = await req('GET', '/admin/orders?userId=' + u.user.id, { admin: true });
    assertEq(list.json.data.total, 1, 'admin list filtered by userId');
  });

  await testCase(508, 'webhook EXPIRATION: lapsed subscription records an expired order and isPro falls', async () => {
    const u = await mkUser('s6-wh-expire');
    await req('POST', '/webhooks/revenuecat', { body: rcEvent({ app_user_id: u.user.id, product_id: 'vip_monthly', transaction_id: 'tx-8001', expiration_at_ms: Date.now() + 30 * 86400e3 }) });
    assertEq((await me(u.tokens.accessToken)).isPro, true, 'pro after purchase');
    const r = await req('POST', '/webhooks/revenuecat', { body: rcEvent({ type: 'EXPIRATION', app_user_id: u.user.id, product_id: 'vip_monthly', transaction_id: 'tx-8002', expiration_at_ms: Date.now() - 1000 }) });
    assertEq(r.status, 200, 'expiration webhook 200');
    assertEq((await me(u.tokens.accessToken)).isPro, false, 'isPro false after expiration');
    const orders = await req('GET', '/user/orders', { token: u.tokens.accessToken });
    assertEq(orders.json.data.orders[0].status, 'expired', 'newest order is the expired one');
  });

  await testCase(509, 'GET /shorts: item shape, cursor pagination covers all 80 episodes without overlap, flag off -> empty', async () => {
    const p1 = await req('GET', '/shorts?limit=30');
    assertEq(p1.status, 200, `shorts status (body ${p1.text.slice(0, 200)})`);
    const items1 = p1.json.data.items;
    assertEq(items1.length, 30, 'page 1 has 30 items');
    assert(typeof p1.json.data.nextCursor === 'string' && p1.json.data.nextCursor.length > 0, 'nextCursor present');
    const it = items1[0];
    for (const k of ['id', 'seriesId', 'seriesTitle', 'posterUrl', 'videoUrl', 'likeCount', 'episodeNumber', 'durationSeconds', 'isUnlocked'])
      assert(k in it, `short item carries ${k}`);
    assert(it.seriesTitle.length > 0, 'seriesTitle non-empty');
    const p2 = await req('GET', '/shorts?limit=30&cursor=' + encodeURIComponent(p1.json.data.nextCursor));
    const p3 = await req('GET', '/shorts?limit=30&cursor=' + encodeURIComponent(p2.json.data.nextCursor));
    assertEq(p2.json.data.items.length, 30, 'page 2 has 30');
    assertEq(p3.json.data.items.length, 20, 'page 3 has the remaining 20');
    assertEq(p3.json.data.nextCursor, null, 'last page nextCursor null');
    const allIds = [...items1, ...p2.json.data.items, ...p3.json.data.items].map((i) => i.id);
    assertEq(new Set(allIds).size, 80, 'all 80 episodes, no overlap');
    const off = await req('PATCH', '/admin/settings', { admin: true, body: { shorts_enabled: false } });
    assertEq(off.status, 200, 'flag patch ok');
    const empty = await req('GET', '/shorts');
    assertEq(empty.json.data.items.length, 0, 'flag off -> no items');
    assertEq(empty.json.data.nextCursor, null, 'flag off -> no cursor');
    await req('PATCH', '/admin/settings', { admin: true, body: { shorts_enabled: true } });
    const back = await req('GET', '/shorts?limit=1');
    assertEq(back.json.data.items.length, 1, 'flag back on -> items flow again');
  });

  await testCase(510, 'GET /home For You: genre affinity ranks first, guest gets the trending fallback, completed series excluded', async () => {
    const urban = 'series-city-of-hidden-lies';
    const watch = async (token, seriesId, epN, completed) => {
      const r = await req('POST', '/me/watch-history', { token, body: { seriesId, episodeId: `${seriesId}-ep${epN}`, episodeNumber: epN, positionSeconds: 30, durationSeconds: 200, completed } });
      assertEq(r.status, 200, `watch-history ep${epN} (body ${r.text})`);
    };
    // Guest fallback: trending order (top rankScore first), section present.
    const guest = await req('GET', '/home');
    const gForYou = guest.json.data.sections.find((s) => s.sectionType === 'for_you');
    assert(gForYou, 'guest /home carries a for_you section');
    assertEq(gForYou.series[0].id, 'series-married-to-the-ceo', 'guest fallback = trending head');
    // Personalized: watch 3 episodes of the LOWEST-ranked urban series.
    const u = await mkUser('s6-foryou');
    for (const n of [1, 2, 3]) await watch(u.tokens.accessToken, urban, n, false);
    const mine = await req('GET', '/home', { token: u.tokens.accessToken });
    const myForYou = mine.json.data.sections.find((s) => s.sectionType === 'for_you');
    assert(myForYou, 'user /home carries a for_you section');
    assertEq(myForYou.series[0].id, urban, 'affinity genre (urban) ranks first despite lowest rankScore');
    assertEq(myForYou.series[0].genreId, 'genre-urban', 'first pick is the urban series');
    // Completed exclusion: finish every episode -> the series disappears.
    for (let n = 1; n <= 10; n++) await watch(u.tokens.accessToken, urban, n, true);
    const after = await req('GET', '/home', { token: u.tokens.accessToken });
    const afterForYou = after.json.data.sections.find((s) => s.sectionType === 'for_you');
    assert(!afterForYou.series.some((s) => s.id === urban), 'completed series excluded from For You');
  });

  await testCase(511, 'PATCH /auth/me consent: round-trips through userJson, strict validation, unknown key still BAD_FIELD', async () => {
    const u = await mkUser('s6-consent');
    const t = u.tokens.accessToken;
    assertEq(u.user.consent, null, 'consent null before any sync');
    const r = await req('PATCH', '/auth/me', { token: t, body: { consent: { version: 1, analytics: true, profiling: false, updatedAt: '2026-11-22T10:00:00.000Z' } } });
    assertEq(r.status, 200, `consent patch status (body ${r.text})`);
    assertEq(r.json.data.user.consent.version, 1, 'version stored');
    assertEq(r.json.data.user.consent.analytics, true, 'analytics stored');
    assertEq(r.json.data.user.consent.profiling, false, 'profiling stored');
    assertEq((await me(t)).consent.updatedAt, '2026-11-22T10:00:00.000Z', 'timestamp persisted via GET /auth/me');
    const badVersion = await req('PATCH', '/auth/me', { token: t, body: { consent: { version: 0, analytics: true, profiling: true } } });
    assertEq(badVersion.status, 400, 'version 0 -> 400');
    const badType = await req('PATCH', '/auth/me', { token: t, body: { consent: { version: 1, analytics: 'yes', profiling: true } } });
    assertEq(badType.status, 400, 'non-boolean analytics -> 400');
    const mixed = await req('PATCH', '/auth/me', { token: t, body: { consent: { version: 2, analytics: false, profiling: false }, isPro: true } });
    assertEq(mixed.status, 400, 'consent + unknown key -> 400');
    assertEq(mixed.json.error.code, 'BAD_FIELD', 'mixed patch code BAD_FIELD');
    assertEq((await me(t)).consent.version, 1, 'rejected patches changed nothing');
  });

  await testCase(512, 'GET /config: features.shorts present (default on) and maintenanceMessage round-trips from settings', async () => {
    const cfg = await req('GET', '/config');
    assertEq(cfg.json.data.features.shorts, true, 'features.shorts true by default');
    assertEq(cfg.json.data.maintenanceMessage, null, 'maintenanceMessage null when unset');
    const patch = await req('PATCH', '/admin/settings', { admin: true, body: { maintenance_message: 'Back at 18:00 Cairo time' } });
    assertEq(patch.status, 200, `message patch (body ${patch.text})`);
    const cfg2 = await req('GET', '/config');
    assertEq(cfg2.json.data.maintenanceMessage, 'Back at 18:00 Cairo time', 'message surfaces in /config');
    await req('PATCH', '/admin/settings', { admin: true, body: { maintenance_message: '' } });
    const cfg3 = await req('GET', '/config');
    assertEq(cfg3.json.data.maintenanceMessage, null, 'cleared message back to null');
    const badMsg = await req('PATCH', '/admin/settings', { admin: true, body: { maintenance_message: 'x'.repeat(201) } });
    assertEq(badMsg.status, 400, 'over-long maintenance_message -> 400');
  });
} finally {
  main.child.kill('SIGKILL');
  secretSrv.child.kill('SIGKILL');
  const summary = `\n===== SUITE 6 SUMMARY =====\nTOTAL: ${passed + failed}  PASSED: ${passed}  FAILED: ${failed}\n${failures.length ? 'FAILURES:\n' + failures.join('\n') : 'ALL PASS'}\n`;
  log(summary);
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  fs.rmSync(main.tmpDir, { recursive: true, force: true });
  fs.rmSync(secretSrv.tmpDir, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}
