// HERO DRAMA backend — CODE READINESS tests (suite 3, cases 201+).
// Covers: real Firebase RS256 verification (item 1), rate limiting (item 2),
// signed playback URLs (item 3), streak grace day (item 5).
// Plain node, no deps. Boots real server instances on random ports with TEMP
// databases; the Firebase JWKS is served by a local stub with a self-generated
// RSA keypair — no network access to Google is used anywhere in this suite.
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const OUT_FILE = path.join(__dirname, 'LAST_RUN_3.txt');
const ADMIN_TOKEN = '<redacted>';
const JWT_SECRET = '<redacted>';

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

// ---------- RSA keypair + JWT helpers (for Firebase tokens) ----------
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const otherKeys = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const KID = 'test-kid-1';
const publicJwk = publicKey.export({ format: 'jwk' });
publicJwk.kid = KID; publicJwk.use = 'sig'; publicJwk.alg = 'RS256';
const b64u = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
function signRs256(payload, key = privateKey, kid = KID) {
  const h = b64u({ alg: 'RS256', typ: 'JWT', kid });
  const p = b64u(payload);
  const sig = crypto.sign('RSA-SHA256', Buffer.from(`${h}.${p}`), key).toString('base64url');
  return `${h}.${p}.${sig}`;
}
const PROJECT = 'test-project-123';
const nowSec = () => Math.floor(Date.now() / 1000);
function firebasePayload(overrides = {}) {
  return {
    sub: 'firebase-user-abc', aud: PROJECT, iss: `https://securetoken.firebaseio.com/${PROJECT}`,
    iat: nowSec() - 60, exp: nowSec() + 3600, email: 'viewer@example.com', name: 'Viewer',
    firebase: { sign_in_provider: 'password' }, ...overrides,
  };
}

// ---------- server boot helper ----------
const boots = [];
async function boot(extraEnv) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test3-'));
  const dbPath = path.join(tmpDir, 'app.db');
  const port = await freePort();
  const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(port), DB_PATH: dbPath, ADMIN_TOKEN, JWT_SECRET, ...extraEnv },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let serverLog = '';
  child.stdout.on('data', (d) => { serverLog += d; });
  child.stderr.on('data', (d) => { serverLog += d; });
  const BASE = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) break; } catch { /* not up */ }
    if (i === 99) throw new Error('server did not become healthy: ' + serverLog);
    await new Promise((r) => setTimeout(r, 100));
  }
  const api = async (method, urlPath, { token, body } = {}) => {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(`${BASE}/api/v1${urlPath}`, { method, headers, body: body !== undefined ? JSON.stringify(body) : undefined });
    const text = await res.text();
    let json = null; try { json = JSON.parse(text); } catch { /* raw */ }
    return { status: res.status, json, text, headers: res.headers };
  };
  const handle = { child, dbPath, BASE, api, kill: () => child.kill('SIGKILL') };
  boots.push(handle);
  return handle;
}
async function login(srv, tag) {
  const r = await srv.api('POST', '/auth/firebase', { body: { idToken: `suite3-${tag}-token` } });
  assertEq(r.status, 200, `login ${tag} status`);
  return { token: r.json.data.tokens.accessToken, user: r.json.data.user };
}

// ---------- Part A: firebase.js unit tests (injected JWKS fetch, no network) ----------
const firebase = require(path.join(BACKEND, 'src', 'firebase.js'));
firebase.__setFetchForTests(async () => ({ keys: [publicJwk] }));

await testCase(201, 'firebase unit: valid RS256 token verifies and maps claims', async () => {
  firebase.__resetCache();
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload()), { projectId: PROJECT });
  assert(claims, 'claims returned');
  assertEq(claims.firebaseUid, 'firebase-user-abc', 'uid mapped from sub');
  assertEq(claims.email, 'viewer@example.com', 'email mapped');
  assertEq(claims.isAnonymous, false, 'password provider with email is not anonymous');
});
await testCase(202, 'firebase unit: wrong aud -> null', async () => {
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload({ aud: 'someone-else' })), { projectId: PROJECT });
  assertEq(claims, null, 'wrong aud rejected');
});
await testCase(203, 'firebase unit: wrong iss -> null', async () => {
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload({ iss: 'https://securetoken.firebaseio.com/other' })), { projectId: PROJECT });
  assertEq(claims, null, 'wrong iss rejected');
});
await testCase(204, 'firebase unit: expired token -> null', async () => {
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload({ exp: nowSec() - 10, iat: nowSec() - 7200 })), { projectId: PROJECT });
  assertEq(claims, null, 'expired rejected');
});
await testCase(205, 'firebase unit: token signed by a different key -> null', async () => {
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload(), otherKeys.privateKey), { projectId: PROJECT });
  assertEq(claims, null, 'bad signature rejected');
});
await testCase(206, 'firebase unit: unknown kid -> null', async () => {
  const claims = await firebase.verifyFirebaseIdToken(signRs256(firebasePayload(), privateKey, 'no-such-kid'), { projectId: PROJECT });
  assertEq(claims, null, 'unknown kid rejected');
});
await testCase(207, 'firebase unit: tampered payload -> null; garbage -> null', async () => {
  const good = signRs256(firebasePayload());
  const [h, , s] = good.split('.');
  const tampered = `${h}.${b64u(firebasePayload({ sub: 'attacker' }))}.${s}`;
  assertEq(await firebase.verifyFirebaseIdToken(tampered, { projectId: PROJECT }), null, 'tampered payload rejected');
  assertEq(await firebase.verifyFirebaseIdToken('not-a-jwt', { projectId: PROJECT }), null, 'garbage rejected');
});
await testCase(208, 'ratelimit unit: sliding window blocks after max and is per-key', async () => {
  const { createLimiter } = require(path.join(BACKEND, 'src', 'ratelimit.js'));
  const lim = createLimiter({ windowMs: 60000, max: 2 });
  const t0 = Date.now();
  assert(lim.check('ip-a', t0).allowed, 'first allowed');
  assert(lim.check('ip-a', t0 + 1).allowed, 'second allowed');
  const third = lim.check('ip-a', t0 + 2);
  assert(!third.allowed && third.retryAfterSec >= 1, 'third blocked with Retry-After');
  assert(lim.check('ip-b', t0 + 2).allowed, 'other key unaffected');
  assert(lim.check('ip-a', t0 + 60001).allowed, 'window slides open again');
});

// ---------- Part B: HTTP end-to-end with a stub JWKS server ----------
const jwksPort = await freePort();
const jwksServer = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=3600' });
  res.end(JSON.stringify({ keys: [publicJwk] }));
});
await new Promise((r) => jwksServer.listen(jwksPort, '127.0.0.1', r));
const srvB = await boot({ FIREBASE_PROJECT_ID: PROJECT, FIREBASE_JWKS_URL: `http://127.0.0.1:${jwksPort}/jwks` });

await testCase(209, 'firebase HTTP: valid token logs in, welcome bonus 30, profile mapped', async () => {
  const r = await srvB.api('POST', '/auth/firebase', { body: { idToken: signRs256(firebasePayload()) } });
  assertEq(r.status, 200, `status (body ${r.text})`);
  assertEq(r.json.data.user.email, 'viewer@example.com', 'email from verified claims');
  assertEq(r.json.data.user.coinBalance, 30, 'welcome bonus granted');
  assertEq(r.json.data.user.isGuest, false, 'email user is not guest');
});
await testCase(210, 'firebase HTTP: forged token (wrong key) -> 401 INVALID_TOKEN', async () => {
  const r = await srvB.api('POST', '/auth/firebase', { body: { idToken: signRs256(firebasePayload({ sub: 'forged-user' }), otherKeys.privateKey) } });
  assertEq(r.status, 401, 'status');
  assertEq(r.json.error.code, 'INVALID_TOKEN', 'error code');
});
await testCase(211, 'firebase HTTP: expired token -> 401; dev-style plain token -> 401', async () => {
  const expired = await srvB.api('POST', '/auth/firebase', { body: { idToken: signRs256(firebasePayload({ exp: nowSec() - 5, iat: nowSec() - 4000 })) } });
  assertEq(expired.status, 401, 'expired status');
  const plain = await srvB.api('POST', '/auth/firebase', { body: { idToken: 'test-user-one-token' } });
  assertEq(plain.status, 401, 'non-JWT token rejected in firebase mode (dev mode is OFF)');
});

// ---------- Part C: default mode (neither env set) -> 501 ----------
const srvC = await boot({});
await testCase(212, 'auth default mode: POST /auth/firebase -> 501 AUTH_NOT_CONFIGURED', async () => {
  const r = await srvC.api('POST', '/auth/firebase', { body: { idToken: 'anything' } });
  assertEq(r.status, 501, 'status');
  assertEq(r.json.error.code, 'AUTH_NOT_CONFIGURED', 'error code');
});

// ---------- Part D: rate limiting over HTTP ----------
const srvD = await boot({
  FIREBASE_AUTH_DEV: '1',
  RATE_LIMIT_AUTH_MAX: '3', RATE_LIMIT_AUTH_WINDOW_MS: '60000',
  RATE_LIMIT_API_MAX: '6', RATE_LIMIT_API_WINDOW_MS: '60000',
});
await testCase(213, 'rate limit: auth bucket allows 3, 4th POST /auth/* -> 429 RATE_LIMITED + Retry-After', async () => {
  for (let i = 0; i < 3; i++) {
    const r = await srvD.api('POST', '/auth/firebase', { body: { idToken: `rl-user-${i}` } });
    assertEq(r.status, 200, `auth attempt ${i + 1} allowed`);
  }
  const blocked = await srvD.api('POST', '/auth/firebase', { body: { idToken: 'rl-user-4' } });
  assertEq(blocked.status, 429, '4th blocked');
  assertEq(blocked.json.error.code, 'RATE_LIMITED', 'error code');
  assert(Number(blocked.headers.get('retry-after')) >= 1, 'Retry-After header present');
});
await testCase(214, 'rate limit: general API bucket blocks after RATE_LIMIT_API_MAX', async () => {
  let last = null;
  for (let i = 0; i < 6; i++) {
    last = await srvD.api('GET', '/config');
    assertEq(last.status, 200, `config fetch ${i + 1} allowed`);
  }
  last = await srvD.api('GET', '/config');
  assertEq(last.status, 429, '7th config fetch blocked');
  assertEq(last.json.error.code, 'RATE_LIMITED', 'error code');
});

// ---------- Part E: signed playback URLs ----------
const SIGNING_SECRET = ['test','playback','signing','3'].join('-');
const srvE = await boot({ FIREBASE_AUTH_DEV: '1', PLAYBACK_SIGNING_SECRET: ['test','playback','signing','3'].join('-') });
await testCase(215, 'playback signing: response carries playbackToken + signedVideoUrl when secret set', async () => {
  const { token } = await login(srvE, 'sign');
  const eps = await srvE.api('GET', '/series/series-married-to-the-ceo/episodes', { token });
  const free = eps.json.data.episodes.find((e) => e.isFree);
  const pb = await srvE.api('GET', `/episodes/${free.id}/playback`, { token });
  assertEq(pb.status, 200, 'playback status');
  assert(pb.json.data.playbackToken && pb.json.data.playbackToken.sig && pb.json.data.playbackToken.exp > nowSec(), 'playbackToken present and unexpired');
  assert(pb.json.data.signedVideoUrl.includes(`sig=${pb.json.data.playbackToken.sig}`), 'signedVideoUrl carries the sig');
});
await testCase(216, 'playback verify: valid token -> 200 valid:true', async () => {
  const { token, user } = await login(srvE, 'verify');
  const eps = await srvE.api('GET', '/series/series-married-to-the-ceo/episodes', { token });
  const free = eps.json.data.episodes.find((e) => e.isFree);
  const pb = await srvE.api('GET', `/episodes/${free.id}/playback`, { token });
  const { exp, sig } = pb.json.data.playbackToken;
  const v = await srvE.api('GET', `/playback/verify?episodeId=${free.id}&userId=${user.id}&exp=${exp}&sig=${sig}`);
  assertEq(v.status, 200, `verify status (body ${v.text})`);
  assertEq(v.json.data.valid, true, 'valid flag');
});
await testCase(217, 'playback verify: tampered sig -> 403; expired-but-valid sig -> 403', async () => {
  const { token, user } = await login(srvE, 'verify2');
  const eps = await srvE.api('GET', '/series/series-married-to-the-ceo/episodes', { token });
  const free = eps.json.data.episodes.find((e) => e.isFree);
  const pb = await srvE.api('GET', `/episodes/${free.id}/playback`, { token });
  const { exp, sig } = pb.json.data.playbackToken;
  const bad = await srvE.api('GET', `/playback/verify?episodeId=${free.id}&userId=${user.id}&exp=${exp}&sig=${sig.slice(0, -2)}AA`);
  assertEq(bad.status, 403, 'tampered sig rejected');
  const pastExp = nowSec() - 60;
  const pastSig = crypto.createHmac('sha256', SIGNING_SECRET).update(`${free.id}.${user.id}.${pastExp}`).digest('base64url');
  const expired = await srvE.api('GET', `/playback/verify?episodeId=${free.id}&userId=${user.id}&exp=${pastExp}&sig=${pastSig}`);
  assertEq(expired.status, 403, 'expired token rejected even with a valid HMAC');
});
const srvE2 = await boot({ FIREBASE_AUTH_DEV: '1' });
await testCase(218, 'playback signing OFF (no secret): no playbackToken field, verify -> 404', async () => {
  const { token } = await login(srvE2, 'nosign');
  const eps = await srvE2.api('GET', '/series/series-married-to-the-ceo/episodes', { token });
  const free = eps.json.data.episodes.find((e) => e.isFree);
  const pb = await srvE2.api('GET', `/episodes/${free.id}/playback`, { token });
  assertEq(pb.status, 200, 'playback still works unsigned');
  assert(!('playbackToken' in pb.json.data), 'no playbackToken without the secret');
  const v = await srvE2.api('GET', `/playback/verify?episodeId=${free.id}&userId=x&exp=1&sig=y`);
  assertEq(v.status, 404, 'verify endpoint disabled without the secret');
});

// ---------- Part F: streak grace day ----------
const { DatabaseSync } = require('node:sqlite');
const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const shiftDays = (days) => { const d = new Date(); d.setDate(d.getDate() + days); return fmt(d); };
function insertCheckins(dbPath, userId, dates) {
  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA busy_timeout=5000');
  const stmt = db.prepare('INSERT INTO checkins(userId,claimDate,dayIndex,coins,createdAt) VALUES(?,?,?,?,?)');
  for (const dt of dates) stmt.run(userId, dt, 1, 10, new Date().toISOString());
  db.close();
}
const srvF = await boot({ FIREBASE_AUTH_DEV: '1' });

await testCase(219, 'streak grace: consecutive days — streak counts, check-in pays ladder day 3 + streak bonus', async () => {
  const { token, user } = await login(srvF, 'grace-ontime');
  insertCheckins(srvF.dbPath, user.id, [shiftDays(-2), shiftDays(-1)]);
  const rw = await srvF.api('GET', '/rewards', { token });
  assertEq(rw.json.data.currentStreak, 2, 'streak 2 before today');
  assertEq(rw.json.data.graceAvailable, true, 'grace still available');
  assertEq(rw.json.data.streakAtRisk, false, 'not at risk (grace unused)');
  const ci = await srvF.api('POST', '/rewards/checkin', { token, body: {} });
  assertEq(ci.json.data.coins, 19, 'day-3 ladder 15 + streak bonus 2*2 = 19');
  const rw2 = await srvF.api('GET', '/rewards', { token });
  assertEq(rw2.json.data.currentStreak, 3, 'streak 3 after check-in');
});
await testCase(220, 'streak grace: exactly one missed day PRESERVES the streak (pause, not reset)', async () => {
  const { token, user } = await login(srvF, 'grace-one-miss');
  insertCheckins(srvF.dbPath, user.id, [shiftDays(-2)]);
  const rw = await srvF.api('GET', '/rewards', { token });
  assertEq(rw.json.data.currentStreak, 1, 'streak preserved at 1 after one missed day');
  assertEq(rw.json.data.streakAtRisk, true, 'at risk: one more miss resets it');
  assertEq(rw.json.data.graceAvailable, false, 'grace consumed by the missed day');
  const ci = await srvF.api('POST', '/rewards/checkin', { token, body: {} });
  assertEq(ci.json.data.coins, 22, 'ladder resumes at day 2: 20 + streak bonus 1*2 = 22');
  const rw2 = await srvF.api('GET', '/rewards', { token });
  assertEq(rw2.json.data.currentStreak, 2, 'streak resumed to 2 (missed day not counted)');
});
await testCase(221, 'streak grace: two missed days RESET the streak', async () => {
  const { token, user } = await login(srvF, 'grace-two-miss');
  insertCheckins(srvF.dbPath, user.id, [shiftDays(-3)]);
  const rw = await srvF.api('GET', '/rewards', { token });
  assertEq(rw.json.data.currentStreak, 0, 'streak reset to 0');
  const ci = await srvF.api('POST', '/rewards/checkin', { token, body: {} });
  assertEq(ci.json.data.coins, 10, 'ladder restarts at day 1 = 10');
  const rw2 = await srvF.api('GET', '/rewards', { token });
  assertEq(rw2.json.data.currentStreak, 1, 'new streak starts at 1');
});
await testCase(222, 'streak grace: a gap INSIDE the run is forgiven once (claimed days only count)', async () => {
  const { token, user } = await login(srvF, 'grace-inside');
  insertCheckins(srvF.dbPath, user.id, [shiftDays(-4), shiftDays(-3), shiftDays(-1)]);
  const rw = await srvF.api('GET', '/rewards', { token });
  assertEq(rw.json.data.currentStreak, 3, 'run of 3 claimed days with one internal gap');
  assertEq(rw.json.data.graceAvailable, false, 'internal gap consumed the grace');
  const ci = await srvF.api('POST', '/rewards/checkin', { token, body: {} });
  assertEq(ci.json.data.coins, 21, 'day-4 ladder 15 + streak bonus 3*2 = 21');
});

for (const b of boots) b.kill();
jwksServer.close();
log('');
log(`SUMMARY: total=${passed + failed} passed=${passed} failed=${failed}`);
if (failures.length) { log('FAILURES:'); failures.forEach((f) => log(' - ' + f)); }
log(failed === 0 ? 'RESULT: ALL PASS' : 'RESULT: FAILURES PRESENT');
fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
process.exit(failed === 0 ? 0 : 1);
