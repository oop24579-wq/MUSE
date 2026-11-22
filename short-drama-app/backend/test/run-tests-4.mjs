// HERO DRAMA backend — ROUND 2 tests (suite 4, cases 301+).
// Covers: per-episode watch progress (S5: episode_progress table + endpoint),
// series-detail resumeEpisodeId (S3), rewards referralApplyBy/hasReferred.
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
const OUT_FILE = path.join(__dirname, 'LAST_RUN_4.txt');
const ADMIN_TOKEN = 'suite4-fixture';

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

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-test4-'));
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

async function req(method, urlPath, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
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
const SID = 'series-married-to-the-ceo';
async function episodesOf(token) {
  const r = await req('GET', `/series/${SID}/episodes`, { token });
  assertEq(r.status, 200, 'episodes status');
  return r.json.data.episodes;
}
async function seriesProgress(token, sid = SID) {
  const r = await req('GET', `/me/library/history/series/${sid}`, { token });
  assertEq(r.status, 200, 'series progress status');
  return r.json.data.episodes;
}
const postWatch = (token, ep, positionSeconds, completed = false) =>
  req('POST', '/me/watch-history', { token, body: { seriesId: SID, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds, durationSeconds: ep.durationSeconds, completed } });

try {
  await waitForHealth();
  log(`Server booted on ${BASE} with temp DB ${dbPath}`);

  await testCase(301, 'S5: per-episode progress returns EVERY watched episode; library/history stays one row per series', async () => {
    const u = await mkUser('r2-s5-user-a');
    const eps = await episodesOf(u.tokens.accessToken);
    assert(eps.length >= 3, 'seed series has >= 3 episodes');
    const [e1, e2] = eps;
    assertEq((await postWatch(u.tokens.accessToken, e1, e1.durationSeconds, true)).status, 200, 'post ep1');
    assertEq((await postWatch(u.tokens.accessToken, e2, 30)).status, 200, 'post ep2');
    const prog = await seriesProgress(u.tokens.accessToken);
    assertEq(prog.length, 2, 'progress has both episodes');
    const p1 = prog.find((x) => x.episodeId === e1.id);
    const p2 = prog.find((x) => x.episodeId === e2.id);
    assert(p1 && p1.completed === true, 'ep1 completed');
    assert(p2 && p2.completed === false && p2.positionSeconds === 30, 'ep2 partial at 30s');
    const hist = await req('GET', '/me/library/history', { token: u.tokens.accessToken });
    const rows = hist.json.data.history.filter((h) => h.series.id === SID);
    assertEq(rows.length, 1, 'watch_history still one row per series');
    assertEq(rows[0].episodeId, e2.id, 'the one row is the latest episode');
  });

  await testCase(302, 'S5: completed is sticky in episode_progress; position follows the latest report', async () => {
    const u = await mkUser('r2-s5-user-b');
    const [e1] = await episodesOf(u.tokens.accessToken);
    await postWatch(u.tokens.accessToken, e1, e1.durationSeconds, true);
    await postWatch(u.tokens.accessToken, e1, 5, false); // rewatch from the top, no flag
    const prog = await seriesProgress(u.tokens.accessToken);
    assertEq(prog.length, 1, 'one progress row');
    assertEq(prog[0].completed, true, 'completed survived a later unflagged post');
    assertEq(prog[0].positionSeconds, 5, 'position is the latest report');
  });

  await testCase(303, 'S5: episode_progress position is clamped to the real episode duration', async () => {
    const u = await mkUser('r2-s5-user-c');
    const [e1] = await episodesOf(u.tokens.accessToken);
    await postWatch(u.tokens.accessToken, e1, e1.durationSeconds + 9999);
    const prog = await seriesProgress(u.tokens.accessToken);
    assertEq(prog[0].positionSeconds, e1.durationSeconds, 'position clamped to duration');
  });

  await testCase(304, 'S3: series detail returns resumeEpisodeId of the latest watched episode (null when anonymous)', async () => {
    const u = await mkUser('r2-s3-user');
    const eps = await episodesOf(u.tokens.accessToken);
    await postWatch(u.tokens.accessToken, eps[1], 42);
    const d = await req('GET', `/series/${SID}`, { token: u.tokens.accessToken });
    assertEq(d.status, 200, 'detail status');
    assertEq(d.json.data.resumeEpisodeId, eps[1].id, 'resumeEpisodeId = latest episode');
    assertEq(d.json.data.resumeEpisodeNumber, eps[1].episodeNumber, 'resumeEpisodeNumber matches');
    const anon = await req('GET', `/series/${SID}`);
    assertEq(anon.json.data.resumeEpisodeId, null, 'anonymous detail has null resumeEpisodeId');
  });

  await testCase(305, 'rewards: referralApplyBy = createdAt + 24h; hasReferred flips after applying a code', async () => {
    const a = await mkUser('r2-ref-user-a');
    const b = await mkUser('r2-ref-user-b');
    const before = await req('GET', '/rewards', { token: b.tokens.accessToken });
    const st = before.json.data;
    assert(st.referralApplyBy, 'referralApplyBy present');
    assertEq(st.hasReferred, false, 'hasReferred false before applying');
    const created = Date.parse(b.user.createdAt || st.createdAt || '');
    if (Number.isFinite(created)) {
      const diffH = Math.abs(Date.parse(st.referralApplyBy) - (created + 24 * 3600e3)) / 3600e3;
      assert(diffH < 0.1, `referralApplyBy within 6min of createdAt+24h (off by ${diffH}h)`);
    }
    const aState = (await req('GET', '/rewards', { token: a.tokens.accessToken })).json.data;
    const apply = await req('POST', '/auth/referral', { token: b.tokens.accessToken, body: { code: aState.referralCode } });
    assertEq(apply.status, 200, `apply referral status (body ${apply.text})`);
    const after = await req('GET', '/rewards', { token: b.tokens.accessToken });
    assertEq(after.json.data.hasReferred, true, 'hasReferred true after applying');
  });

  await testCase(306, 'S5: relink merge moves episode_progress to the primary account (primary wins conflicts)', async () => {
    const guest = await mkUser('r2-merge-guest');
    const eps = await episodesOf(guest.tokens.accessToken);
    await postWatch(guest.tokens.accessToken, eps[0], eps[0].durationSeconds, true);
    await postWatch(guest.tokens.accessToken, eps[1], 25);
    const primary = await mkUser(emailToken('r2-primary-sub', 'r2.primary@example.com', 'Primary'));
    // Primary already has its own (partial) row for ep1: it must win the merge.
    await postWatch(primary.tokens.accessToken, eps[0], 7);
    const r = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id, guestAccessToken: guest.tokens.accessToken } });
    assertEq(r.status, 200, `relink status (body ${r.text})`);
    const prog = await seriesProgress(primary.tokens.accessToken);
    assertEq(prog.length, 2, 'primary sees both episodes after merge');
    const p1 = prog.find((x) => x.episodeId === eps[0].id);
    const p2 = prog.find((x) => x.episodeId === eps[1].id);
    assertEq(p1.positionSeconds, 7, 'primary ep1 row wins the conflict');
    assert(p2 && p2.positionSeconds === 25, 'guest ep2 progress moved over');
  });

  await testCase(307, 'S5: episode progress is per-user (another user sees none of it)', async () => {
    const a = await mkUser('r2-iso-user-a');
    const b = await mkUser('r2-iso-user-b');
    const [e1] = await episodesOf(a.tokens.accessToken);
    await postWatch(a.tokens.accessToken, e1, 60);
    const progB = await seriesProgress(b.tokens.accessToken);
    assertEq(progB.length, 0, 'user B has no progress for the series');
  });

  await testCase(308, 'S5: watch post with an episode from another series is rejected and records no progress', async () => {
    const u = await mkUser('r2-s5-user-d');
    const eps = await episodesOf(u.tokens.accessToken);
    const other = await req('GET', '/series', { token: u.tokens.accessToken }).catch(() => null);
    const bad = await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId: 'series-vip-empire-of-desire', episodeId: eps[0].id, episodeNumber: 1, positionSeconds: 10, durationSeconds: 10 } });
    assertEq(bad.status, 400, 'mismatched episode/series -> 400');
    const prog = await seriesProgress(u.tokens.accessToken, 'series-vip-empire-of-desire');
    assertEq(prog.length, 0, 'no progress recorded for the rejected post');
    assert(other === null || other.status !== 200 || true, 'noop');
  });
} finally {
  child.kill('SIGKILL');
  const summary = `\n===== ROUND 2 SUITE 4 SUMMARY =====\nTOTAL: ${passed + failed}  PASSED: ${passed}  FAILED: ${failed}\n${failures.length ? 'FAILURES:\n' + failures.join('\n') : 'ALL PASS'}\n`;
  log(summary);
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  fs.rmSync(tmpDir, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}
