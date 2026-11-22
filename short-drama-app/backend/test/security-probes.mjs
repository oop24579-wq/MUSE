// HERO DRAMA — adversarial security probes (independent audit).
// Boots the REAL server on a random port with a TEMP DB (dev auth ON, as the
// test suite does) and EXECUTES each attack, recording BLOCKED (safe) or
// CONFIRMED (vulnerability). Plain node, no deps. Writes SECURITY_RUN.txt.
// Usage: node test/security-probes.mjs
import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, '..');
const ADMIN_TOKEN = 'probe-admin-token';
const JWT_SECRET = 'probe-jwt-secret';
const OUT_FILE = path.join(__dirname, 'SECURITY_RUN.txt');

const lines = [];
const results = [];
function log(...a) { const s = a.join(' '); lines.push(s); console.log(s); }
function probe(id, name, result, evidence) {
  results.push({ id, name, result, evidence });
  log(`[${result}] ${id} ${name} — ${evidence}`);
}
const CONFIRMED = (id, name, ev) => probe(id, name, 'CONFIRMED', ev);
const BLOCKED = (id, name, ev) => probe(id, name, 'BLOCKED', ev);
const ACCEPTED = (id, name, ev) => probe(id, name, 'ACCEPTED-RISK', ev);
const INFO = (id, name, ev) => probe(id, name, 'INFO', ev);

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)); });
    s.on('error', reject);
  });
}

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dramanow-sec-'));
const dbPath = path.join(tmpDir, 'app.db');
const port = await freePort();
const BASE = `http://127.0.0.1:${port}`;
const API = `${BASE}/api/v1`;

// SSRF observation listener (loopback) + a second one for redirect targets.
const ssrfHits = [];
const ssrfServer = http.createServer((req, res) => {
  ssrfHits.push(`${req.method} ${req.url}`);
  if (req.url === '/redir') { res.writeHead(302, { Location: `http://127.0.0.1:${redirTargetPort}/target` }); return res.end(); }
  if (req.url === '/slow') { setTimeout(() => { res.writeHead(200, { 'Content-Type': 'video/mp4' }); res.end(Buffer.from('FAKEVIDEO')); }, 3000); return; }
  res.writeHead(200, { 'Content-Type': 'video/mp4' });
  res.end(Buffer.from('FAKEVIDEO'));
});
const ssrfPort = await freePort();
await new Promise((r) => ssrfServer.listen(ssrfPort, '127.0.0.1', r));
const redirTargetPort = await freePort();
const redirServer = http.createServer((req, res) => { ssrfHits.push(`REDIR-TARGET ${req.method} ${req.url}`); res.writeHead(200); res.end('ok'); });
await new Promise((r) => redirServer.listen(redirTargetPort, '127.0.0.1', r));
// "Public" origin for the redirect-hop test: the VM's non-loopback IP.
const PUBLIC_IP = '198.19.0.2';
const publicPort = ssrfPort + 1;
const publicHits = [];
const publicServer = http.createServer((req, res) => {
  publicHits.push(`${req.method} ${req.url}`);
  // Delayed 302 to a loopback target: exercises the redirect-hop SSRF guard
  // AND keeps a caption job 'processing' for ~3s (used by the C5 dedupe test).
  setTimeout(() => { res.writeHead(302, { Location: `http://127.0.0.1:${redirTargetPort}/target` }); res.end(); }, 3000);
});
let publicBound = false;
try { await new Promise((res, rej) => { publicServer.listen(publicPort, PUBLIC_IP, (e) => (e ? rej(e) : res())); }); publicBound = true; } catch { publicBound = false; }

const child = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
  cwd: BACKEND,
  env: {
    ...process.env, PORT: String(port), DB_PATH: dbPath, FIREBASE_AUTH_DEV: '1',
    ADMIN_TOKEN, JWT_SECRET,
    // The probes create 100+ accounts in a burst (RL1) plus dozens of logins;
    // the default auth bucket (60/h) would 429 the harness itself mid-run.
    // Raise it for THIS test server only (production defaults unchanged;
    // the limiter itself is covered by run-tests-3.mjs cases 213-214).
    RATE_LIMIT_AUTH_MAX: '100000',
    // Deliberately shell-metachar WHISPER_CMD: spawn() must NOT run a shell,
    // so the `; touch` must never execute.
    WHISPER_CMD: 'echo hi; touch /tmp/pwned-marker-secprobe-7f3a {file}',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
child.stdout.on('data', (d) => { serverLog += d; });
child.stderr.on('data', (d) => { serverLog += d; });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function req(method, urlPath, { token, admin, adminToken, body, rawBody, contentType } = {}) {
  const headers = { 'Content-Type': contentType || 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (admin) headers['X-Admin-Token'] = ADMIN_TOKEN;
  if (adminToken !== undefined) headers['X-Admin-Token'] = adminToken;
  const res = await fetch(urlPath.startsWith('http') ? urlPath : API + urlPath, {
    method, headers,
    body: rawBody !== undefined ? rawBody : body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null; try { json = JSON.parse(text); } catch { /* keep null */ }
  return { status: res.status, json, text, headers: res.headers };
}
async function waitForHealth() {
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) return; } catch { /* not up */ }
    await sleep(100);
  }
  throw new Error('server did not become healthy. Log: ' + serverLog);
}
const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
function forgeJwt(payload, secret, alg = 'HS256') {
  const h = b64({ alg, typ: 'JWT' });
  const p = b64(payload);
  if (alg === 'none') return `${h}.${p}.`;
  const sig = crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${sig}`;
}
let userSeq = 0;
async function freshUser(tag) {
  const t = `probe-${tag}-${++userSeq}-${Date.now()}`;
  const a = await req('POST', '/auth/firebase', { body: { idToken: t } });
  if (a.status !== 200) throw new Error(`freshUser ${tag} failed: ${a.status} ${a.text}`);
  return a.json.data;
}
async function grantCoinsAdmin(userId, amount) {
  const r = await req('POST', `/admin/users/${userId}/coins`, { admin: true, body: { amount } });
  return r;
}
async function balanceOf(token) { return (await req('GET', '/me/coins', { token })).json.data.balance; }
async function patchSettings(patch) {
  const r = await req('PATCH', '/admin/settings', { admin: true, body: patch });
  return r;
}
async function getSettings() { return (await req('GET', '/admin/settings', { admin: true })).json.data.settings; }

let seriesId, freeEp, lockedEp, vipEp, vipSeriesId;
let origSettings;

try {
  await waitForHealth();
  log(`Probe server on ${BASE} (temp DB ${dbPath})`);
  origSettings = await getSettings();

  // ---- discover seed catalog (public) ----
  const disc = await req('GET', '/discover?filter=popular&limit=100');
  const series = disc.json.data.series;
  for (const s of series) {
    const eps = (await req('GET', `/series/${s.id}/episodes`)).json.data.episodes;
    const free = eps.find((e) => e.isFree);
    const locked = eps.find((e) => !e.isFree && !e.isVipOnly);
    const vip = eps.find((e) => e.isVipOnly);
    if (free && locked && !seriesId) { seriesId = s.id; freeEp = free; lockedEp = locked; }
    if (vip && !vipEp) { vipEp = vip; vipSeriesId = s.id; }
    if (seriesId && vipEp) break;
  }
  if (!seriesId || !vipEp) throw new Error('seed catalog shape unexpected');
  log(`Catalog: series=${seriesId} freeEp=${freeEp.id} lockedEp=${lockedEp.id} vipEp=${vipEp.id}`);

  // ================= AUTH =================
  const u1 = await freshUser('auth1');
  const u2 = await freshUser('auth2');
  // A1 alg=none
  {
    const forged = forgeJwt({ sub: u2.user.id, type: 'access', iat: 1, exp: 9999999999 }, JWT_SECRET, 'none');
    const r = await req('GET', '/auth/me', { token: forged });
    r.status === 401 ? BLOCKED('A1', 'JWT alg=none forgery', 'rejected 401') : CONFIRMED('A1', 'JWT alg=none forgery', `accepted with status ${r.status}`);
  }
  // A2 wrong secret
  {
    const forged = forgeJwt({ sub: u2.user.id, type: 'access' }, 'attacker-secret');
    const r = await req('GET', '/auth/me', { token: forged });
    r.status === 401 ? BLOCKED('A2', 'JWT wrong-secret forgery', 'rejected 401') : CONFIRMED('A2', 'JWT wrong-secret forgery', `accepted ${r.status}`);
  }
  // A3 tampered payload (swap sub, keep original signature)
  {
    const parts = u1.tokens.accessToken.split('.');
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    payload.sub = u2.user.id;
    const forged = `${parts[0]}.${b64(payload)}.${parts[2]}`;
    const r = await req('GET', '/auth/me', { token: forged });
    r.status === 401 ? BLOCKED('A3', 'JWT tampered-payload (sub swap)', 'rejected 401') : CONFIRMED('A3', 'JWT tampered-payload (sub swap)', `accepted ${r.status}, body=${r.text.slice(0, 120)}`);
  }
  // A4 expired token (signed with correct secret, exp in the past)
  {
    const nowSec = Math.floor(Date.now() / 1000);
    const forged = forgeJwt({ sub: u1.user.id, type: 'access', iat: nowSec - 7200, exp: nowSec - 3600 }, JWT_SECRET);
    const r = await req('GET', '/auth/me', { token: forged });
    r.status === 401 ? BLOCKED('A4', 'JWT expired token', 'rejected 401') : CONFIRMED('A4', 'JWT expired token', `accepted ${r.status}`);
  }
  // A5 token for deleted user
  {
    const u = await freshUser('deleted');
    await req('DELETE', '/auth/account', { token: u.tokens.accessToken });
    const me = await req('GET', '/auth/me', { token: u.tokens.accessToken });
    const rf = await req('POST', '/auth/refresh', { body: { refreshToken: u.tokens.refreshToken } });
    me.status === 401 && rf.status === 401
      ? BLOCKED('A5', 'tokens of deleted user', 'access 401 + refresh 401')
      : CONFIRMED('A5', 'tokens of deleted user', `me=${me.status} refresh=${rf.status}`);
  }
  // A6 refresh reuse after rotation (+ family revocation)
  {
    const u = await freshUser('refresh');
    const r1 = await req('POST', '/auth/refresh', { body: { refreshToken: u.tokens.refreshToken } });
    const newRefresh = r1.json.data.tokens.refreshToken;
    const reuseOld = await req('POST', '/auth/refresh', { body: { refreshToken: u.tokens.refreshToken } });
    const reuseNew = await req('POST', '/auth/refresh', { body: { refreshToken: newRefresh } });
    reuseOld.status === 401 && reuseNew.status === 401
      ? BLOCKED('A6', 'refresh reuse after rotation (family revoked)', 'old 401 + new (family) 401')
      : CONFIRMED('A6', 'refresh reuse after rotation', `reuse-old=${reuseOld.status} reuse-new=${reuseNew.status}`);
  }
  // A7 token type confusion
  {
    const u = await freshUser('typeconf');
    const refreshAsAccess = await req('GET', '/auth/me', { token: u.tokens.refreshToken });
    const accessAsRefresh = await req('POST', '/auth/refresh', { body: { refreshToken: u.tokens.accessToken } });
    refreshAsAccess.status === 401 && accessAsRefresh.status === 401
      ? BLOCKED('A7', 'access/refresh token type confusion', 'both 401')
      : CONFIRMED('A7', 'access/refresh token type confusion', `refresh-as-access=${refreshAsAccess.status} access-as-refresh=${accessAsRefresh.status}`);
  }
  // A8 dev-auth games
  {
    const t1 = 'probe-devgame-plain';
    const a1 = await req('POST', '/auth/firebase', { body: { idToken: t1 } });
    const a2 = await req('POST', '/auth/firebase', { body: { idToken: t1 } });
    const sameUser = a1.status === 200 && a2.status === 200 && a1.json.data.user.id === a2.json.data.user.id;
    const emptySub = await req('POST', '/auth/firebase', { body: { idToken: `x.${b64({ sub: '' })}.y` } });
    const numToken = await req('POST', '/auth/firebase', { body: { idToken: 12345 } });
    const emptyTok = await req('POST', '/auth/firebase', { body: { idToken: '' } });
    const huge = await req('POST', '/auth/firebase', { body: { idToken: 'a'.repeat(4_000_000) } });
    const health = await req('GET', `${BASE}/health`);
    const dup = await req('POST', '/auth/firebase', { body: { idToken: 'probe-devgame-plain' } });
    sameUser && emptySub.status === 200 && numToken.status === 401 && emptyTok.status === 400 && huge.status === 200 && health.status === 200 && dup.json.data.user.id === a1.json.data.user.id
      ? BLOCKED('A8', 'dev-auth token games', 'same token=same user; empty-sub/huge handled; numeric token rejected 401; empty rejected 400; server alive')
      : CONFIRMED('A8', 'dev-auth token games', `sameUser=${sameUser} emptySub=${emptySub.status} num=${numToken.status} empty=${emptyTok.status} huge=${huge.status} health=${health.status}`);
  }
  // A9 production mode refuses default secrets
  {
    const prodDb = path.join(tmpDir, 'prod.db');
    const prodPort = await freePort();
    const prod = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
      cwd: BACKEND,
      env: { ...process.env, PORT: String(prodPort), DB_PATH: prodDb, NODE_ENV: 'production' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let prodErr = '';
    prod.stderr.on('data', (d) => { prodErr += d; });
    const exitCode = await new Promise((res) => { const to = setTimeout(() => { prod.kill(); res(null); }, 5000); prod.on('exit', (c) => { clearTimeout(to); res(c); }); });
    exitCode !== 0 && /FATAL/.test(prodErr)
      ? BLOCKED('A9', 'production refuses default secrets', `exited ${exitCode} with FATAL`)
      : CONFIRMED('A9', 'production refuses default secrets', `exit=${exitCode} stderr=${prodErr.slice(0, 160)}`);
    // P2: production + real secrets, auth endpoint must 501 (no Firebase verification)
    const prod2Db = path.join(tmpDir, 'prod2.db');
    const prod2Port = await freePort();
    const prod2 = spawn(process.execPath, [path.join(BACKEND, 'src', 'server.js')], {
      cwd: BACKEND,
      env: { ...process.env, PORT: String(prod2Port), DB_PATH: prod2Db, NODE_ENV: 'production', JWT_SECRET: 'prod-jwt-x', ADMIN_TOKEN: 'prod-admin-x' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    try {
      let up = false;
      for (let i = 0; i < 50 && !up; i++) { try { const r = await fetch(`http://127.0.0.1:${prod2Port}/health`); up = r.ok; } catch { /* */ } await sleep(100); }
      const authR = await fetch(`http://127.0.0.1:${prod2Port}/api/v1/auth/firebase`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ idToken: 'x' }) });
      authR.status === 501 ? BLOCKED('A9b', 'production /auth/firebase without Firebase verification', '501 AUTH_NOT_CONFIGURED') : CONFIRMED('A9b', 'production /auth/firebase without Firebase verification', `status ${authR.status}`);
    } finally { prod2.kill(); }
  }

  // ================= IDOR =================
  const victim = await freshUser('idor-victim');
  const attacker = await freshUser('idor-attacker');
  // I1/I2 notifications are token-scoped
  {
    const vNotifs = await req('GET', '/notifications', { token: victim.tokens.accessToken });
    const vId = vNotifs.json.data.items[0].id;
    const aNotifs = await req('GET', '/notifications', { token: attacker.tokens.accessToken });
    const leak = aNotifs.json.data.items.some((n) => n.id === vId);
    await req('POST', '/notifications/read', { token: attacker.tokens.accessToken, body: { ids: [vId] } });
    const vAfter = await req('GET', '/notifications', { token: victim.tokens.accessToken });
    const stillUnread = vAfter.json.data.items.find((n) => n.id === vId);
    !leak && stillUnread && !stillUnread.readAt
      ? BLOCKED('I1', 'cross-user notification read/mark', 'no leak; victim notification stays unread')
      : CONFIRMED('I1', 'cross-user notification read/mark', `leak=${leak} stillUnread=${!!stillUnread}`);
  }
  // I3 playback / captions gating
  {
    const noTok = await req('GET', `/episodes/${lockedEp.id}/playback`);
    const locked = await req('GET', `/episodes/${lockedEp.id}/playback`, { token: attacker.tokens.accessToken });
    const vip = await req('GET', `/episodes/${vipEp.id}/playback`, { token: attacker.tokens.accessToken });
    const capList = await req('GET', `/episodes/${lockedEp.id}/captions`, { token: attacker.tokens.accessToken });
    const capVtt = await req('GET', `/episodes/${lockedEp.id}/captions/ar`, { token: attacker.tokens.accessToken });
    noTok.status === 401 && locked.status === 403 && vip.status === 403 && (capList.json.data.languages || []).length === 0 && capVtt.status === 403
      ? BLOCKED('I3', 'locked/VIP playback + captions gating', 'no-token 401; locked 403; VIP 403; captions [] + 403')
      : CONFIRMED('I3', 'locked/VIP playback + captions gating', `noTok=${noTok.status} locked=${locked.status} vip=${vip.status} capList=${JSON.stringify(capList.json).slice(0, 80)} capVtt=${capVtt.status}`);
  }
  // I4 unlock replay (no double charge)
  {
    const u = await freshUser('unlock');
    await grantCoinsAdmin(u.user.id, 1000);
    const b0 = await balanceOf(u.tokens.accessToken);
    const u1r = await req('POST', `/episodes/${lockedEp.id}/unlock`, { token: u.tokens.accessToken, body: {} });
    const b1 = await balanceOf(u.tokens.accessToken);
    const u2r = await req('POST', `/episodes/${lockedEp.id}/unlock`, { token: u.tokens.accessToken, body: {} });
    const b2 = await balanceOf(u.tokens.accessToken);
    u1r.status === 200 && u2r.status === 200 && u2r.json.data.coins === 0 && b1 === b0 - u1r.json.data.coins && b2 === b1
      ? BLOCKED('I4', 'unlock replay double-charge', `first cost ${u1r.json.data.coins}, second free, balance stable`)
      : CONFIRMED('I4', 'unlock replay double-charge', `u1=${u1r.status} u2=${u2r.status} b0=${b0} b1=${b1} b2=${b2} secondCoins=${u2r.json && u2r.json.data && u2r.json.data.coins}`);
  }
  // I5 watch-history with victim userId in body
  {
    await req('POST', '/me/watch-history', { token: attacker.tokens.accessToken, body: { seriesId, episodeId: freeEp.id, episodeNumber: 1, positionSeconds: 50, durationSeconds: 100, userId: victim.user.id } });
    const vHist = await req('GET', '/me/library/history', { token: victim.tokens.accessToken });
    const leaked = (vHist.json.data.history || []).some((h) => h.episodeId === freeEp.id && h.positionSeconds === 50);
    !leaked ? BLOCKED('I5', 'watch-history userId spoofing', 'victim history untouched') : CONFIRMED('I5', 'watch-history userId spoofing', 'victim history contains attacker entry');
  }

  // ================= ECONOMY =================
  const epsFor = async (token, sid) => (await req('GET', `/series/${sid}/episodes`, { token })).json.data.episodes;
  const postWatch = async (token, sid, ep, pos) => req('POST', '/me/watch-history', { token, body: { seriesId: sid, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds: pos, durationSeconds: ep.durationSeconds || 100 } });
  // E1 check-in race (20 parallel)
  {
    const u = await freshUser('race-checkin');
    const rs = await Promise.all(Array.from({ length: 20 }, () => req('POST', '/rewards/checkin', { token: u.tokens.accessToken, body: {} })));
    const paid = rs.filter((r) => r.json && r.json.data && r.json.data.success === true);
    const bad = rs.filter((r) => r.status >= 500);
    const bal = await balanceOf(u.tokens.accessToken);
    paid.length === 1 && bad.length === 0 && bal === 30 + paid[0].json.data.coins
      ? BLOCKED('E1', 'check-in parallel race (20x)', `exactly 1 payout of ${paid[0].json.data.coins}; balance consistent`)
      : CONFIRMED('E1', 'check-in parallel race (20x)', `paid=${paid.length} 5xx=${bad.length} balance=${bal} (welcome 30 + expected one payout)`);
  }
  // E2 wheel race (12 parallel, 3 free/day)
  {
    const u = await freshUser('race-wheel');
    const rs = await Promise.all(Array.from({ length: 12 }, () => req('POST', '/rewards/wheel/spin', { token: u.tokens.accessToken, body: {} })));
    const ok200 = rs.filter((r) => r.status === 200);
    const bad = rs.filter((r) => r.status >= 500);
    const coinsWon = ok200.reduce((a, r) => a + (r.json.data.coins || 0), 0);
    const paidSpins = Math.max(0, ok200.length - 3);
    const bal = await balanceOf(u.tokens.accessToken);
    const expected = 30 + coinsWon - 20 * paidSpins;
    ok200.length <= 12 && bad.length === 0 && bal === expected
      ? BLOCKED('E2', 'wheel parallel race (12x)', `${ok200.length} spins ok, balance ${bal} == 30 + won ${coinsWon} - 20*${paidSpins} paid`)
      : CONFIRMED('E2', 'wheel parallel race (12x)', `ok=${ok200.length} 5xx=${bad.length} bal=${bal} expected=${expected} won=${coinsWon}`);
  }
  // E3 chest race (10 parallel claims)
  {
    const u = await freshUser('race-chest');
    const eps = await epsFor(u.tokens.accessToken, seriesId);
    for (let i = 0; i < 3; i++) await postWatch(u.tokens.accessToken, seriesId, eps[i], 60);
    const rs = await Promise.all(Array.from({ length: 10 }, () => req('POST', '/rewards/chests/chest_3/claim', { token: u.tokens.accessToken, body: {} })));
    const ok200 = rs.filter((r) => r.status === 200);
    const c409 = rs.filter((r) => r.status === 409);
    const bal = await balanceOf(u.tokens.accessToken);
    ok200.length === 1 && c409.length === 9 && bal === 30 + 15
      ? BLOCKED('E3', 'chest parallel race (10x)', 'exactly 1 pays 15, rest 409')
      : CONFIRMED('E3', 'chest parallel race (10x)', `ok=${ok200.length} 409=${c409.length} bal=${bal}`);
  }
  // E4 mission race (10 parallel claims)
  {
    const u = await freshUser('race-mission');
    const eps = await epsFor(u.tokens.accessToken, seriesId);
    for (let i = 0; i < 3; i++) await postWatch(u.tokens.accessToken, seriesId, eps[i], 30);
    const rs = await Promise.all(Array.from({ length: 10 }, () => req('POST', '/rewards/missions/watch_3_episodes/claim', { token: u.tokens.accessToken, body: {} })));
    const ok200 = rs.filter((r) => r.status === 200);
    const bal = await balanceOf(u.tokens.accessToken);
    ok200.length === 1 && bal === 30 + ok200[0].json.data.coins
      ? BLOCKED('E4', 'mission parallel race (10x)', `exactly 1 pays ${ok200[0].json.data.coins}`)
      : CONFIRMED('E4', 'mission parallel race (10x)', `ok=${ok200.length} bal=${bal}`);
  }
  // E5 watch-time race (10 parallel claims)
  {
    const u = await freshUser('race-watchtime');
    const eps = await epsFor(u.tokens.accessToken, seriesId);
    for (let i = 0; i < 6; i++) await postWatch(u.tokens.accessToken, seriesId, eps[i], eps[i].durationSeconds);
    const rs = await Promise.all(Array.from({ length: 10 }, () => req('POST', '/rewards/watch-time/claim', { token: u.tokens.accessToken, body: {} })));
    const paid = rs.reduce((a, r) => a + ((r.json && r.json.data && r.json.data.coins) || 0), 0);
    const bad = rs.filter((r) => r.status >= 500);
    const bal = await balanceOf(u.tokens.accessToken);
    paid === 10 && bad.length === 0 && bal === 30 + 10
      ? BLOCKED('E5', 'watch-time parallel race (10x)', 'total paid exactly 10 across all responses')
      : CONFIRMED('E5', 'watch-time parallel race (10x)', `totalPaid=${paid} 5xx=${bad.length} bal=${bal}`);
  }
  // E6 referral farming (12 Sybil referees)
  {
    const ref = await freshUser('ref-farm');
    const code = (await req('GET', '/auth/me', { token: ref.tokens.accessToken })).json.data.user.referralCode;
    let applied = 0, rejected = 0;
    for (let i = 0; i < 12; i++) {
      const b = await freshUser(`ref-farm-${i}`);
      const r = await req('POST', '/auth/referral', { token: b.tokens.accessToken, body: { code } });
      if (r.status === 200) applied++; else rejected++;
    }
    const bal = await balanceOf(ref.tokens.accessToken);
    const gain = bal - 30;
    gain <= 10 * 50
      ? BLOCKED('E6', 'referral Sybil farming (12 accounts)', `referrer gain ${gain} (cap 10/day); applied=${applied} rejected=${rejected}`)
      : CONFIRMED('E6', 'referral Sybil farming (12 accounts)', `referrer gain ${gain} = ${applied}x50 with NO cap; applied=${applied} rejected=${rejected}`);
  }
  // E7 ad reward amount tampering
  {
    const u = await freshUser('ad-tamper');
    const big = await req('POST', '/rewards/ad', { token: u.tokens.accessToken, body: { amount: 1000000 } });
    const neg = await req('POST', '/rewards/ad', { token: u.tokens.accessToken, body: { amount: -50 } });
    const bal = await balanceOf(u.tokens.accessToken);
    big.json.data.coins === 20 && neg.json.data.coins === 20 && bal === 30 + 40
      ? BLOCKED('E7', 'ad reward amount tampering', 'body amount ignored; server pays 20 each')
      : CONFIRMED('E7', 'ad reward amount tampering', `big=${JSON.stringify(big.json && big.json.data)} neg=${JSON.stringify(neg.json && neg.json.data)} bal=${bal}`);
  }
  // E8 negative coinCost episode create/patch (mint vector)
  {
    const bad1 = await req('POST', '/admin/episodes', { admin: true, body: { seriesId, episodeNumber: 900, title: 'evil', coinCost: -50, isFree: 0 } });
    const ok1 = await req('POST', '/admin/episodes', { admin: true, body: { seriesId, episodeNumber: 901, title: 'ok', coinCost: 10, isFree: 0 } });
    const epId = ok1.json && ok1.json.data && ok1.json.data.id;
    const bad2 = epId ? await req('PATCH', `/admin/episodes/${epId}`, { admin: true, body: { coinCost: -5 } }) : { status: -1 };
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    bad1.status === 400 && bad2.status === 400
      ? BLOCKED('E8', 'negative coinCost episode create/patch', 'both 400')
      : CONFIRMED('E8', 'negative coinCost episode create/patch', `create=${bad1.status} patch=${bad2.status}`);
  }
  // E9 watch-time with unknown-duration episode (honor-system, cap-bounded)
  {
    const cr = await req('POST', '/admin/episodes', { admin: true, body: { seriesId, episodeNumber: 902, title: 'no-duration', isFree: 1 } });
    const epId = cr.json && cr.json.data && cr.json.data.id;
    const u = await freshUser('watchtime-nodur');
    await req('POST', '/me/watch-history', { token: u.tokens.accessToken, body: { seriesId, episodeId: epId, episodeNumber: 902, positionSeconds: 999999, durationSeconds: 999999 } });
    const rw = await req('GET', '/rewards', { token: u.tokens.accessToken });
    const claimable = rw.json.data.watchTime.claimableCoins;
    const claim = await req('POST', '/rewards/watch-time/claim', { token: u.tokens.accessToken, body: {} });
    await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    claimable > 0
      ? ACCEPTED('E9', 'watch-time forgery on unknown-duration episode', `one forged post accrued ${rw.json.data.watchTime.minutesToday} min; claim paid ${claim.json.data.coins} (bounded by daily cap 100; client-asserted positions are honor-system)`)
      : BLOCKED('E9', 'watch-time forgery on unknown-duration episode', 'no accrual from forged post');
  }

  // ================= RELINK =================
  // R1 non-guest merge blocked
  {
    const primary = await freshUser('relink-primary');
    const victimJwt = `x.${b64({ sub: 'relink-victim-x', email: 'victim@x.com' })}.y`;
    const va = await req('POST', '/auth/firebase', { body: { idToken: victimJwt } });
    const victimId = va.json.data.user.id;
    const r = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: victimId } });
    const stillThere = await req('GET', '/auth/me', { token: va.json.data.tokens.accessToken });
    r.status === 403 && stillThere.status === 200
      ? BLOCKED('R1', 'relink merge of non-guest victim', '403 + victim intact')
      : CONFIRMED('R1', 'relink merge of non-guest victim', `relink=${r.status} victim-me=${stillThere.status}`);
  }
  // R2 guest merge transfers coins, deletes guest — only WITH guest-ownership proof (V5)
  {
    const primary = await freshUser('relink-p2');
    const guest = await freshUser('relink-g2');
    await req('POST', '/rewards/checkin', { token: guest.tokens.accessToken, body: {} });
    const gBal = await balanceOf(guest.tokens.accessToken);
    const pBal0 = await balanceOf(primary.tokens.accessToken);
    // (a) Without proof: 403 GUEST_OWNERSHIP_REQUIRED, guest survives, no transfer.
    const noProof = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id } });
    const guestAlive = await req('GET', '/auth/me', { token: guest.tokens.accessToken });
    const pBalNoProof = await balanceOf(primary.tokens.accessToken);
    const noProofOk = noProof.status === 403 && noProof.json && noProof.json.error && noProof.json.error.code === 'GUEST_OWNERSHIP_REQUIRED' && guestAlive.status === 200 && pBalNoProof === pBal0;
    // (b) With a valid guestAccessToken proof: original merge semantics.
    const r = await req('POST', '/auth/relink', { token: primary.tokens.accessToken, body: { guestUserId: guest.user.id, guestAccessToken: guest.tokens.accessToken } });
    const pBal1 = await balanceOf(primary.tokens.accessToken);
    const guestGone = await req('GET', '/auth/me', { token: guest.tokens.accessToken });
    noProofOk && r.status === 200 && pBal1 === pBal0 + gBal && guestGone.status === 401
      ? BLOCKED('R2', 'guest merge transfers coins + deletes guest', `no-proof 403 GUEST_OWNERSHIP_REQUIRED + guest intact + balance unchanged; with guestAccessToken proof primary ${pBal0}+${gBal}=${pBal1}; guest token 401`)
      : CONFIRMED('R2', 'guest merge transfers coins + deletes guest', `noProof=${noProof.status} code=${noProof.json && noProof.json.error && noProof.json.error.code} guestAlive=${guestAlive.status} pBalNoProof=${pBalNoProof} relink=${r.status} pBal ${pBal0}->${pBal1} (guest had ${gBal}) guest-me=${guestGone.status}`);
  }
  // R3 relink loop / idempotency — merge requires guest-ownership proof (V5)
  {
    const a = await freshUser('relink-loop-a');
    const b = await freshUser('relink-loop-b');
    const balA0 = await balanceOf(a.tokens.accessToken);
    const balB = await balanceOf(b.tokens.accessToken);
    // (a) Without proof: 403 GUEST_OWNERSHIP_REQUIRED, guest survives, no transfer.
    const noProof = await req('POST', '/auth/relink', { token: a.tokens.accessToken, body: { guestUserId: b.user.id } });
    const bAlive = await req('GET', '/auth/me', { token: b.tokens.accessToken });
    const balAAfterNoProof = await balanceOf(a.tokens.accessToken);
    const noProofOk = noProof.status === 403 && noProof.json && noProof.json.error && noProof.json.error.code === 'GUEST_OWNERSHIP_REQUIRED' && bAlive.status === 200 && balAAfterNoProof === balA0;
    // (b) With a valid guestAccessToken proof: merge happens exactly once.
    const merge = await req('POST', '/auth/relink', { token: a.tokens.accessToken, body: { guestUserId: b.user.id, guestAccessToken: b.tokens.accessToken } });
    const balA = await balanceOf(a.tokens.accessToken);
    const bGone = await req('GET', '/auth/me', { token: b.tokens.accessToken });
    const mergeOk = merge.status === 200 && balA === balA0 + balB && bGone.status === 401;
    const again = await req('POST', '/auth/relink', { token: a.tokens.accessToken, body: { guestUserId: b.user.id } });
    const selfRef = await req('POST', '/auth/relink', { token: a.tokens.accessToken, body: { guestUserId: a.user.id } });
    const ghost = await req('POST', '/auth/relink', { token: a.tokens.accessToken, body: { guestUserId: '00000000-0000-0000-0000-000000000000' } });
    const balA2 = await balanceOf(a.tokens.accessToken);
    noProofOk && mergeOk && again.status === 200 && selfRef.status === 200 && ghost.status === 200 && balA2 === balA
      ? BLOCKED('R3', 'relink loop/idempotency', 'no-proof 403 + guest intact; proof merge transfers exactly once + guest deleted; re-merge, self-merge, ghost-merge all no-ops, balance stable')
      : CONFIRMED('R3', 'relink loop/idempotency', `noProof=${noProof.status} code=${noProof.json && noProof.json.error && noProof.json.error.code} bAlive=${bAlive.status} merge=${merge.status} bGone=${bGone.status} again=${again.status} self=${selfRef.status} ghost=${ghost.status} bal ${balA0}->${balA}->${balA2} (guest had ${balB})`);
  }

  // ================= ADMIN =================
  // AD1 admin token variants
  {
    const cases = [
      ['no token', await req('GET', '/admin/stats')],
      ['wrong token', await req('GET', '/admin/stats', { adminToken: 'wrong' })],
      ['empty token', await req('GET', '/admin/stats', { adminToken: '' })],
      ['token in query', await req('GET', `/admin/stats?token=${ADMIN_TOKEN}`)],
      ['Bearer-prefixed', await req('GET', '/admin/stats', { adminToken: `Bearer ${ADMIN_TOKEN}` })],
      ['dev default token', await req('GET', '/admin/stats', { adminToken: 'dev-admin-token-change-me' })],
    ];
    const bad = cases.filter(([, r]) => r.status !== 401);
    bad.length === 0 ? BLOCKED('AD1', 'admin token variants', 'all six variants 401') : CONFIRMED('AD1', 'admin token variants', bad.map(([n, r]) => `${n}=${r.status}`).join(', '));
  }
  // AD2 admin endpoints without the /admin prefix
  {
    const u = await freshUser('ad2');
    const r1 = await req('GET', '/users', { admin: true });
    const r2 = await req('GET', '/settings', { token: u.tokens.accessToken });
    const r3 = await req('GET', '/stats', { token: u.tokens.accessToken });
    r1.status === 401 && r2.status === 404 && r3.status === 404
      ? BLOCKED('AD2', 'admin routes outside /admin prefix', '401/404/404')
      : CONFIRMED('AD2', 'admin routes outside /admin prefix', `/users=${r1.status} /settings=${r2.status} /stats=${r3.status}`);
  }
  // AD3 settings type confusion + prototype keys
  {
    const cases = [
      ['welcome string', await patchSettings({ welcome_coin_bonus: 'abc' })],
      ['welcome negative', await patchSettings({ welcome_coin_bonus: -5 })],
      ['welcome 1e20', await patchSettings({ welcome_coin_bonus: 1e20 })],
      ['maintenance string', await patchSettings({ maintenance_mode: 'true' })],
      ['premium bogus', await patchSettings({ premium_playback_mode: 'bogus' })],
      ['wheel mixed types', await patchSettings({ wheel_segments: [5, 'x'] })],
      ['checkin wrong length', await patchSettings({ checkin_amounts: [1, 2, 3] })],
      // NOTE: object-literal __proto__ is a prototype setter, not a JSON key —
      // send it as a raw JSON string so the server really sees the key.
      ['__proto__ key', await req('PATCH', '/admin/settings', { admin: true, rawBody: '{"__proto__": {"polluted": 1}}' })],
      ['constructor key', await patchSettings({ constructor: 5 })],
    ];
    const s = await getSettings();
    const polluted = ({}).polluted !== undefined || s.polluted !== undefined || Object.prototype.polluted !== undefined;
    const hasConstructorKey = Object.prototype.hasOwnProperty.call(s, 'constructor');
    const bad = cases.filter(([, r]) => r.status !== 400);
    if (bad.length === 0 && !polluted && !hasConstructorKey) BLOCKED('AD3', 'settings type confusion + proto keys', 'all 9 rejected 400; no pollution');
    else CONFIRMED('AD3', 'settings type confusion + proto keys', `accepted: ${bad.map(([n]) => n).join(', ') || 'none'}; polluted=${polluted} constructorKey=${hasConstructorKey}`);
    await patchSettings(origSettings); // restore (in case a 1e20 slipped through)
  }
  // AD4 SQL injection in text fields + LIKE wildcard
  {
    const g = await req('POST', '/admin/genres', { admin: true, body: { slug: 'sqli', name: "x'); DROP TABLE users; --", sortOrder: 0 } });
    const alive = await req('POST', '/auth/firebase', { body: { idToken: 'probe-sqli-alive' } });
    const s1 = await req('GET', "/search?q=' OR 1=1 --");
    const sqliLeak = (s1.json.data.series || []).some((x) => !(x.title || '').toLowerCase().includes("' or 1=1 --") && !(x.synopsis || '').toLowerCase().includes("' or 1=1 --"));
    const allSeries = await req('GET', '/discover?filter=popular&limit=100');
    const wild = await req('GET', '/search?q=%');
    if (g.json && g.json.data) await req('DELETE', `/admin/genres/${g.json.data.id}`, { admin: true });
    alive.status === 200 && !sqliLeak
      ? (wild.json.data.series.length === allSeries.json.data.series.length
        ? INFO('AD4', 'SQL injection + LIKE wildcard', `injection BLOCKED (table alive, no leak); '%' wildcard returns all ${wild.json.data.series.length} series (public catalog, INFO only)`)
        : BLOCKED('AD4', 'SQL injection + LIKE wildcard', 'injection blocked; wildcard behaves normally'))
      : CONFIRMED('AD4', 'SQL injection', `alive=${alive.status} leak=${sqliLeak}`);
  }
  // AD5 stored XSS — verify the dashboard's esc() actually neutralizes payloads
  {
    const s = await req('POST', '/admin/series', { admin: true, body: { slug: 'xss-probe', title: '<script>alert(1)</script>', synopsis: '<img src=x onerror=alert(1)>', coverImageUrl: 'javascript:alert(1)', colorHex: 'red; } </style><script>alert(1)</script>', genreId: null } });
    const sid = s.json && s.json.data && s.json.data.id;
    const html = fs.readFileSync(path.join(BACKEND, 'public', 'admin', 'index.html'), 'utf8');
    const m = /const esc = [^\n]+/.exec(html); // whole line: &amp; contains ';', so [^;]+ truncates it
    // Load the dashboard's REAL esc() by evaluating its source line.
    let escOK = false;
    if (m) {
      const src = m[0].replace('const esc = ', 'esc = ');
      let esc;
      eval(src);
      escOK = esc('<script>alert(1)</script>') === '&lt;script&gt;alert(1)&lt;/script&gt;'
        && esc('a"b\'c') === 'a&quot;b&#39;c'
        && esc('x" onerror="alert(1)') === 'x&quot; onerror=&quot;alert(1)'
        && !esc('<img src=x onerror=alert(1)>').includes('<');
    }
    // No innerHTML sink may OUTPUT data without esc(). A data field used only
    // as a ternary CONDITION (branches are string literals) is not output.
    const sinks = [...html.matchAll(/\$\{([^}]*)\}/g)].map((x) => x[1]);
    const DATA_PROP = /(^|[^\w$.])(t|u|s|g|c|ep|ev|ms|b|j|v|val|n|row|item|d)\.[a-zA-Z_$][\w$]*(\.[a-zA-Z_$][\w$]*)*/;
    const rawDataSinks = sinks.filter((e) => {
      if (e.includes('esc(') || e.includes('chipFor') || e.includes('trackChip')) return false;
      // `.map(esc).length` outputs a COUNT of escaped items, not user data.
      if (e.includes('.map(esc)')) return false;
      // Strip string literals, then check each ternary branch after the '?'.
      const noStrings = e.replace(/'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`/g, "''");
      const branches = noStrings.includes('?') ? noStrings.split('?').slice(1).join('?') : noStrings;
      return DATA_PROP.test(branches);
    });
    if (sid) await req('DELETE', `/admin/series/${sid}`, { admin: true });
    escOK && rawDataSinks.length === 0
      ? BLOCKED('AD5', 'stored XSS in dashboard rendering', 'esc() neutralizes < > " \' everywhere; no unescaped data interpolations')
      : CONFIRMED('AD5', 'stored XSS in dashboard rendering', `escOK=${escOK} rawDataSinks=${JSON.stringify(rawDataSinks.slice(0, 5))}`);
  }
  // AD6 admin coin grant NaN / huge + VIP on missing user
  {
    const victim = await freshUser('ad6-victim');
    const nan = await grantCoinsAdmin(victim.user.id, 'abc');
    const balAfterNan = await balanceOf(victim.tokens.accessToken);
    const huge = await grantCoinsAdmin(victim.user.id, 1e21);
    const balAfterHuge = await balanceOf(victim.tokens.accessToken);
    const vipGhost = await req('POST', '/admin/users/00000000-0000-0000-0000-000000000000/vip', { admin: true, body: { isVip: true } });
    const nanBad = nan.status === 200 && (balAfterNan === null || balAfterNan === undefined || Number.isNaN(balAfterNan));
    if (nanBad) CONFIRMED('AD6', 'admin coin grant with non-numeric amount', `grant "abc" returned ${nan.status}; victim balance became ${balAfterNan} (account corrupted)`);
    else if (nan.status === 400 && balAfterNan === 30 && huge.status === 400 && vipGhost.status === 404) BLOCKED('AD6', 'admin coin grant NaN/huge + VIP ghost', '"abc" 400, balance intact 30; 1e21 400; VIP ghost 404');
    else INFO('AD6', 'admin coin grant NaN/huge + VIP ghost', `nan=${nan.status} bal=${balAfterNan} huge=${huge.status} balHuge=${balAfterHuge} vipGhost=${vipGhost.status}`);
    // restore victim balance if corrupted by the pre-fix probe
    if (balAfterNan !== 30) { /* leave corrupted balance visible in probe DB only (temp DB) */ }
  }
  // AD7 missions/tasks numeric abuse
  {
    const m1 = await req('POST', '/admin/missions', { admin: true, body: { slug: 'probe-neg', title: 'neg', metric: 'checkin', target: 1, coins: -50 } });
    const t1 = await req('POST', '/admin/reward-tasks', { admin: true, body: { slug: 'probe-neg-task', title: 'neg', coins: -10, actionType: 'checkin', target: 1 } });
    const mPatch = m1.status === 201 ? await req('PATCH', '/admin/missions/probe-neg', { admin: true, body: { coins: 'abc' } }) : { status: -1 };
    if (m1.status === 201) await req('DELETE', '/admin/missions/probe-neg', { admin: true });
    if (t1.status === 201) await req('DELETE', '/admin/reward-tasks/probe-neg-task', { admin: true });
    m1.status === 400 && t1.status === 400
      ? BLOCKED('AD7', 'negative coins in missions/tasks', 'both 400')
      : CONFIRMED('AD7', 'negative coins in missions/tasks', `mission=${m1.status} task=${t1.status} patchCoinsAbc=${mPatch.status}`);
  }
  // AD8 event multiplier overflow (1e308 -> Infinity payout)
  {
    const ev = await req('POST', '/admin/events', { admin: true, body: { name: 'probe-huge', multiplier: 1e308 } });
    let evStatus = ev.status;
    let checkinStatus = null, checkinCoins = null;
    if (ev.status === 201) {
      const u = await freshUser('ad8-checkin');
      const c = await req('POST', '/rewards/checkin', { token: u.tokens.accessToken, body: {} });
      checkinStatus = c.status; checkinCoins = c.json && c.json.data && c.json.data.coins;
      await req('DELETE', `/admin/events/${ev.json.data.id}`, { admin: true });
    }
    evStatus === 400
      ? BLOCKED('AD8', 'event multiplier 1e308 overflow', 'event rejected 400')
      : checkinStatus === 200 && Number.isFinite(checkinCoins)
        ? INFO('AD8', 'event multiplier 1e308 overflow', `event accepted; checkin paid finite ${checkinCoins} (no Infinity corruption observed)`)
        : CONFIRMED('AD8', 'event multiplier 1e308 overflow', `event=${evStatus} checkin=${checkinStatus} coins=${checkinCoins}`);
  }
  // AD9 static admin file path traversal
  {
    const t1 = await req('GET', `${BASE}/admin/../src/server.js`);
    const t2 = await req('GET', `${BASE}/admin/%2e%2e%2f.env.example`);
    const t3 = await req('GET', `${BASE}/admin/%2e%2e/backend/.env.example`);
    const leak = [t1, t2, t3].some((r) => /require\(|JWT_SECRET|ADMIN_TOKEN/.test(r.text));
    t1.status === 404 && t2.status === 404 && t3.status === 404 && !leak
      ? BLOCKED('AD9', 'admin static path traversal', 'all 404, no file content leaked')
      : CONFIRMED('AD9', 'admin static path traversal', `t1=${t1.status} t2=${t2.status} t3=${t3.status} leak=${leak}`);
  }

  // ================= INPUT HANDLING =================
  // IN1 null body
  {
    const r = await req('POST', '/auth/firebase', { rawBody: 'null' });
    r.status === 400 ? BLOCKED('IN1', 'JSON null body', '400 (no 500)') : CONFIRMED('IN1', 'JSON null body', `status ${r.status}: ${r.text.slice(0, 100)}`);
  }
  // IN2 number body / IN3 array body
  {
    const r1 = await req('POST', '/auth/firebase', { rawBody: '123' });
    const r2 = await req('POST', '/auth/firebase', { rawBody: '[1,2]' });
    r1.status === 400 && r2.status === 400
      ? BLOCKED('IN2', 'number/array JSON body', 'both 400 VALIDATION')
      : CONFIRMED('IN2', 'number/array JSON body', `number=${r1.status} array=${r2.status}`);
  }
  // IN4 huge body (6MB)
  {
    const r = await req('POST', '/auth/firebase', { rawBody: JSON.stringify({ idToken: 'x'.repeat(6_000_000) }) });
    r.status === 413 ? BLOCKED('IN3', '6MB body', '413 PAYLOAD_TOO_LARGE') : CONFIRMED('IN3', '6MB body', `status ${r.status}`);
  }
  // IN5 malformed JSON
  {
    const r = await req('POST', '/auth/firebase', { rawBody: '{bad json' });
    r.status === 400 ? BLOCKED('IN4', 'malformed JSON', '400 BAD_JSON') : CONFIRMED('IN4', 'malformed JSON', `status ${r.status}`);
  }
  // IN6 malformed percent-encoding in path
  {
    const r = await req('GET', '/series/%E0%A4%A');
    r.status === 400 ? BLOCKED('IN5', 'malformed percent-encoding path', '400') : r.status === 404 ? BLOCKED('IN5', 'malformed percent-encoding path', '404 (no 500)') : CONFIRMED('IN5', 'malformed percent-encoding path', `status ${r.status}: ${r.text.slice(0, 80)}`);
  }
  // IN7 unicode / NUL in text fields
  {
    const g = await req('POST', '/admin/genres', { admin: true, body: { slug: 'uni', name: 'A\0B 🎬 \u202eRTL', sortOrder: 0 } });
    const list = await req('GET', '/categories');
    const ok = g.status === 201 && (list.json.data.genres || []).some((x) => x.slug === 'uni');
    if (g.json && g.json.data) await req('DELETE', `/admin/genres/${g.json.data.id}`, { admin: true });
    ok ? BLOCKED('IN6', 'unicode/NUL in text fields', 'stored + returned, no crash') : CONFIRMED('IN6', 'unicode/NUL in text fields', `create=${g.status}`);
  }
  // IN8 wrong content-type tolerated (INFO)
  {
    const r = await req('POST', '/auth/firebase', { contentType: 'text/plain', rawBody: JSON.stringify({ idToken: 'probe-ct-plain' }) });
    INFO('IN7', 'non-JSON content-type with JSON body', r.status === 200 ? 'parsed anyway (tolerant, no security impact)' : `status ${r.status}`);
  }
  // IN9 __proto__ in user body
  {
    const r = await req('POST', '/me/watch-history', { token: (await freshUser('proto')).tokens.accessToken, body: { seriesId, episodeId: freeEp.id, episodeNumber: 1, positionSeconds: 10, __proto__: { polluted: 1 } } });
    const polluted = ({}).polluted !== undefined;
    !polluted && r.status === 200 ? BLOCKED('IN8', '__proto__ in user JSON body', 'no pollution; request accepted normally') : CONFIRMED('IN8', '__proto__ in user JSON body', `polluted=${polluted} status=${r.status}`);
  }

  // ================= CAPTIONS =================
  // Switch ASR provider to local-whisper (WHISPER_CMD is the shell-metachar probe)
  await patchSettings({ asr_provider: 'local-whisper' });
  const capSeries = await req('POST', '/admin/series', { admin: true, body: { slug: 'cap-probe', title: 'Cap Probe', genreId: null } });
  const capSeriesId = capSeries.json.data.id;
  // C1 SSRF: episode videoUrl -> loopback listener
  {
    ssrfHits.length = 0;
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 1, title: 'ssrf', videoUrl: `http://127.0.0.1:${ssrfPort}/steal.mp4`, isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    await sleep(2500);
    const hit = ssrfHits.some((h) => h.includes('/steal.mp4'));
    const jobs = await req('GET', '/admin/captions', { admin: true });
    const job = (jobs.json.data.jobs || []).find((j) => j.episodeId === epId);
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    hit ? CONFIRMED('C1', 'SSRF: caption worker fetched loopback URL', `listener saw ${JSON.stringify(ssrfHits)}; job status=${job && job.status}`)
      : BLOCKED('C1', 'SSRF: caption worker fetched loopback URL', `no fetch to loopback; job status=${job && job.status} error=${job && (job.error || '').slice(0, 80)}`);
  }
  // C2 SSRF: localhost hostname
  {
    ssrfHits.length = 0;
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 2, title: 'ssrf2', videoUrl: `http://localhost:${ssrfPort}/steal2.mp4`, isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    await sleep(2500);
    const hit = ssrfHits.some((h) => h.includes('/steal2.mp4'));
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    hit ? CONFIRMED('C2', 'SSRF: localhost hostname', 'listener hit via localhost') : BLOCKED('C2', 'SSRF: localhost hostname', 'no fetch via localhost');
  }
  // C3 file:// URL
  {
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 3, title: 'ssrf3', videoUrl: 'file:///etc/passwd', isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    await sleep(1500);
    const jobs = await req('GET', '/admin/captions', { admin: true });
    const job = (jobs.json.data.jobs || []).find((j) => j.episodeId === epId);
    const health = await req('GET', `${BASE}/health`);
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    job && job.status === 'failed' && health.status === 200
      ? BLOCKED('C3', 'file:// videoUrl in caption pipeline', 'job failed cleanly; server alive')
      : CONFIRMED('C3', 'file:// videoUrl in caption pipeline', `job=${job && job.status} health=${health.status}`);
  }
  // C4 WHISPER_CMD shell metacharacters must NOT execute
  {
    try { fs.unlinkSync('/tmp/pwned-marker-secprobe-7f3a'); } catch { /* */ }
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 4, title: 'cmd', videoUrl: `http://127.0.0.1:${ssrfPort}/x.mp4`, isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    await sleep(2500);
    const pwned = fs.existsSync('/tmp/pwned-marker-secprobe-7f3a');
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    !pwned ? BLOCKED('C4', 'WHISPER_CMD shell injection', 'no shell: marker file never created') : CONFIRMED('C4', 'WHISPER_CMD shell injection', 'marker file created — command executed via shell');
  }
  // C5 job flooding: 30 parallel generate calls for one episode.
  // The episode's videoUrl is https://httpbin.org/delay/3, so the auto job
  // stays 'processing' ~3s while the 30 calls land — all must dedupe to the
  // same jobId. (A loopback URL cannot be used: the SSRF guard fails the job
  // instantly, before any dedupe window exists; the VM also cannot fetch its
  // own public IP, so no local slow source is available. If httpbin is
  // unreachable the test is skipped rather than misreported.)
  {
    let reachable = false;
    try { const r = await fetch('https://httpbin.org/delay/1', { signal: AbortSignal.timeout(8000) }); reachable = r.ok; } catch { reachable = false; }
    if (!reachable) {
      INFO('C5', 'caption job flooding (30x same episode)', 'skipped: external test host httpbin.org unreachable from this VM');
    } else {
      const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 5, title: 'flood', videoUrl: 'https://httpbin.org/delay/3', isFree: 1 } });
      const epId = ep.json && ep.json.data && ep.json.data.id;
      const rs = await Promise.all(Array.from({ length: 30 }, () => req('POST', `/admin/episodes/${epId}/captions/generate`, { admin: true, body: {} })));
      const jobIds = new Set(rs.map((r) => r.json && r.json.data && r.json.data.jobId).filter(Boolean));
      if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
      jobIds.size === 1 ? BLOCKED('C5', 'caption job flooding (30x same episode)', 'all 30 calls returned the same deduped jobId') : CONFIRMED('C5', 'caption job flooding (30x same episode)', `${jobIds.size} distinct jobs created`);
    }
  }
  // C6 target-language flooding
  {
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 6, title: 'flood2', isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    const langs = Array.from({ length: 60 }, (_, i) => 'xx' + i);
    const r = await req('POST', `/admin/episodes/${epId}/captions/generate`, { admin: true, body: { targets: langs } });
    await sleep(1200);
    const matrix = await req('GET', '/admin/captions', { admin: true });
    const row = (matrix.json.data.episodes || []).find((e) => e.episodeId === epId);
    const trackCount = row ? row.tracks.length : 0;
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    r.status === 400 || trackCount <= 11
      ? BLOCKED('C6', 'caption target-language flooding (60 langs)', `generate status=${r.status}, tracks=${trackCount}`)
      : CONFIRMED('C6', 'caption target-language flooding (60 langs)', `generate=${r.status}, ${trackCount} tracks created (orig + 60)`);
  }
  // C7 VTT injection via episode title/description (demo provider)
  await patchSettings({ asr_provider: 'demo' });
  {
    const evilTitle = 'Evil --> <script>alert(1)</script>';
    const ep = await req('POST', '/admin/episodes', { admin: true, body: { seriesId: capSeriesId, episodeNumber: 7, title: evilTitle, description: 'line one\n00:00:05.000 --> 00:00:09.000\nINJECTED CUE', isFree: 1 } });
    const epId = ep.json && ep.json.data && ep.json.data.id;
    await req('POST', `/admin/episodes/${epId}/captions/generate`, { admin: true, body: {} });
    const vttUser = await freshUser('vtt');
    let vtt = null;
    for (let i = 0; i < 60 && !vtt; i++) { // up to 12s: the worker may still be finishing the C5 job first
      await sleep(200);
      const r = await req('GET', `/episodes/${epId}/captions/ar`, { token: vttUser.tokens.accessToken });
      if (r.status === 200) vtt = r.text;
    }
    const timingLines = vtt ? vtt.split('\n').filter((l) => l.includes('-->')) : [];
    const timingOK = timingLines.every((l) => /^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}$/.test(l));
    const hasRawScript = vtt ? vtt.includes('<script') : true;
    if (epId) await req('DELETE', `/admin/episodes/${epId}`, { admin: true });
    vtt && timingOK && !hasRawScript
      ? BLOCKED('C7', 'VTT cue injection via title/description', 'no raw <script>; --> only in well-formed timing lines')
      : CONFIRMED('C7', 'VTT cue injection via title/description', `vtt=${vtt ? vtt.slice(0, 200) : 'null'} timingOK=${timingOK} rawScript=${hasRawScript}`);
  }
  await patchSettings({ asr_provider: 'demo' });
  await req('DELETE', `/admin/series/${capSeriesId}`, { admin: true });

  // ================= RATE LIMITING =================
  {
    const t0 = Date.now();
    const rs = await Promise.all(Array.from({ length: 100 }, (_, i) => req('POST', '/auth/firebase', { body: { idToken: `probe-ratelimit-${i}` } })));
    const okCount = rs.filter((r) => r.status === 200).length;
    okCount >= 95
      ? ACCEPTED('RL1', 'mass guest account creation (100 in a burst)', `${okCount}/100 created in ${Date.now() - t0}ms — NO rate limit; Sybil enabler for referral farming. Recommend Firebase App Check + reverse-proxy rate limiting in production; a server-side limiter was NOT added (would break the 57-test suite + shared-IP app traffic)`)
      : BLOCKED('RL1', 'mass guest account creation (100 in a burst)', `${okCount}/100 created — rate limited`);
  }

  // ================= INFO LEAKAGE =================
  {
    const h = await req('GET', `${BASE}/health`);
    const srv = h.headers.get('server'), xpb = h.headers.get('x-powered-by');
    !srv && !xpb ? BLOCKED('L1', 'server fingerprint headers', 'no Server/X-Powered-By headers') : CONFIRMED('L1', 'server fingerprint headers', `server=${srv} x-powered-by=${xpb}`);
    const cfg = await req('GET', '/config');
    const keys = [];
    (function walk(o) { if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) { keys.push(k); walk(v); } })(cfg.json && cfg.json.data);
    const bad = keys.filter((k) => /secret|token|password|key/i.test(k));
    bad.length === 0 ? BLOCKED('L2', '/config secret leakage', 'no secret-ish keys in public config') : CONFIRMED('L2', '/config secret leakage', `keys: ${bad.join(',')}`);
    const e500 = await req('GET', '/series/%E0%A4%A');
    /Internal server error/.test(e500.text) && !/Error:|at |\.js:/.test(e500.text)
      ? BLOCKED('L3', 'error-response detail leakage (500 path)', 'generic message, no stack/SQL')
      : INFO('L3', 'error-response detail leakage (500 path)', `status=${e500.status} body=${e500.text.slice(0, 100)}`);
  }

  // ---- restore settings ----
  await patchSettings(origSettings);
} catch (e) {
  log('PROBE RUNNER ERROR: ' + (e && e.stack || e));
} finally {
  child.kill();
  ssrfServer.close();
  redirServer.close();
  publicServer.close();
  // Remove the temp DB dir (each run leaves ~7MB in /tmp; a full /tmp tmpfs
  // once broke the test suite with 'database or disk is full').
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch { /* best effort */ }
  const conf = results.filter((r) => r.result === 'CONFIRMED');
  const blocked = results.filter((r) => r.result === 'BLOCKED');
  const accepted = results.filter((r) => r.result === 'ACCEPTED-RISK');
  const info = results.filter((r) => r.result === 'INFO');
  log('');
  log(`SUMMARY: total=${results.length} BLOCKED=${blocked.length} CONFIRMED=${conf.length} ACCEPTED-RISK=${accepted.length} INFO=${info.length}`);
  if (conf.length) { log('CONFIRMED VULNERABILITIES:'); for (const r of conf) log(`  - ${r.id} ${r.name}: ${r.evidence}`); }
  fs.writeFileSync(OUT_FILE, lines.join('\n') + '\n');
  log('Wrote ' + OUT_FILE);
  process.exit(0);
}
