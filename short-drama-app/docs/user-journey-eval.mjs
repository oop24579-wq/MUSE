// HERO DRAMA — user-simulation journey runner (evaluation only, not part of the test suite)
// Usage: node eval-run.mjs day1|day2|day4   (server must be running at BASE)
import fs from 'node:fs';

const BASE = process.env.BASE || 'http://127.0.0.1:8931/api/v1';
const ADMIN = process.env.ADMIN_TOKEN || 'eval-admin-token';
const STATE_F = '/tmp/hd-eval/state.json';
const LOG_F = '/tmp/hd-eval/log.txt';
const phase = process.argv[2];

const logLines = [];
function log(...a) { const s = a.join(' '); console.log(s); logLines.push(s); }
function flush() { fs.appendFileSync(LOG_F, logLines.join('\n') + '\n'); logLines.length = 0; }

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const fakeToken = (sub, extra = {}) => `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub, ...extra })}.sig`;

async function call(method, path, { token, body, admin, raw } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (admin) headers['X-Admin-Token'] = ADMIN;
  const res = await fetch(BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  if (raw) return { status: res.status, text, ctype: res.headers.get('content-type') };
  let json = null; try { json = JSON.parse(text); } catch { /* */ }
  return { status: res.status, json, data: json && json.data, error: json && json.error };
}
const bal = async (t) => (await call('GET', '/me/coins', { token: t })).data.balance;

function saveState(s) { fs.writeFileSync(STATE_F, JSON.stringify(s, null, 2)); }
function loadState() { return JSON.parse(fs.readFileSync(STATE_F, 'utf8')); }

async function register(sub, extra) {
  const r = await call('POST', '/auth/firebase', { body: { idToken: fakeToken(sub, extra), deviceId: 'eval-device-1' } });
  return r;
}
async function watchFull(t, seriesId, ep) {
  // mimic a real player: report halfway, then full + completed
  await call('POST', '/me/watch-history', { token: t, body: { seriesId, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds: Math.floor(ep.durationSeconds / 2), durationSeconds: ep.durationSeconds, completed: false } });
  const r = await call('POST', '/me/watch-history', { token: t, body: { seriesId, episodeId: ep.id, episodeNumber: ep.episodeNumber, positionSeconds: ep.durationSeconds, durationSeconds: ep.durationSeconds, completed: true } });
  return r;
}

const S1 = 'series-married-to-the-ceo';
const VIP = 'series-vip-empire-of-desire';
const epId = (s, n) => `${s}-ep${n}`;

if (phase === 'day1') {
  log('\n########## DAY 1 ##########');
  // ---------------- J1: cold start ----------------
  log('\n== J1 COLD START ==');
  const reg = await register('eval-user-main', { name: 'Eval Guest' });
  log('register guest ->', reg.status, 'isGuest=', reg.data.user.isGuest, 'coinBalance=', reg.data.user.coinBalance, 'referralCode=', reg.data.user.referralCode, 'level=', reg.data.user.level);
  const T = reg.data.tokens.accessToken;
  const me = await call('GET', '/auth/me', { token: T });
  log('/auth/me -> coinBalance=', me.data.user.coinBalance, 'referralCode present:', !!me.data.user.referralCode, JSON.stringify(me.data.user.referralCode));
  const notif = await call('GET', '/notifications', { token: T });
  log('notifications ->', JSON.stringify((notif.data.items || notif.data.notifications || []).map(n => n.title)));
  const cfg = await call('GET', '/config');
  log('/config -> premiumPlaybackMode=', cfg.data.premiumPlaybackMode, 'unlockCost=', cfg.data.economy.episodeUnlockCoinCost, 'features:', Object.entries(cfg.data.features).filter(([, v]) => v).length + '/' + Object.keys(cfg.data.features).length, 'on');
  const home = await call('GET', '/home');
  const secs = home.data.sections || [];
  log('/home -> sections:', secs.map(s => `${s.title}(${s.sectionType}:${(s.items || s.series || []).length})`).join(' | '));
  const cats = await call('GET', '/categories');
  log('/categories ->', (cats.data.genres || []).map(g => g.name).join(', '));
  saveState({ token: T, userId: reg.data.user.id });

  // ---------------- J2: discovery ----------------
  log('\n== J2 DISCOVERY ==');
  for (const f of ['popular', 'latest', 'ranking']) {
    const d = await call('GET', `/discover?filter=${f}&limit=8`, { token: T });
    log(`discover ${f} ->`, (d.data.series || []).map(s => s.title).join(' | '));
  }
  const fy = await call('GET', '/for-you?limit=8', { token: T });
  log('for-you ->', (fy.data.series || []).length, 'series');
  const srch = await call('GET', '/search?q=CEO', { token: T });
  log('search "CEO" ->', (srch.data.series || []).map(s => s.title).join(' | '));
  const det = await call('GET', `/series/${S1}`, { token: T });
  log('series detail ->', det.data.series.title, '| cast:', (det.data.cast || []).map(c => c.person.name).join(','), '| related:', (det.data.related || []).length);
  const eps = await call('GET', `/series/${S1}/episodes`, { token: T });
  for (const e of eps.data.episodes) log(`  ep${e.episodeNumber}: isFree=${e.isFree} isVipOnly=${e.isVipOnly} coinCost=${e.coinCost} isUnlocked=${e.isUnlocked} dur=${e.durationSeconds}s`);
  const veps = await call('GET', `/series/${VIP}/episodes`, { token: T });
  log('VIP series episodes (note isFree vs isVipOnly):');
  for (const e of veps.data.episodes.slice(0, 3)) log(`  ep${e.episodeNumber}: isFree=${e.isFree} isVipOnly=${e.isVipOnly} coinCost=${e.coinCost} isUnlocked=${e.isUnlocked}`);
  const vplay = await call('GET', `/episodes/${epId(VIP, 1)}/playback`, { token: T });
  log('playback VIP-series ep1 (listed isFree=true, isUnlocked=true) ->', vplay.status, vplay.error ? vplay.error.code : 'OK');

  // ---------------- J3: first watch ----------------
  log('\n== J3 FIRST WATCH ==');
  const ep1 = eps.data.episodes[0], ep2 = eps.data.episodes[1];
  const play1 = await call('GET', `/episodes/${ep1.id}/playback`, { token: T });
  log('playback ep1 ->', play1.status, 'videoUrl:', (play1.data.videoUrl || '').split('/').pop(), 'qualities:', (play1.data.qualities || []).map(q => q.label).join(','), 'captionLanguages:', JSON.stringify(play1.data.captionLanguages));
  await watchFull(T, S1, ep1);
  let cont = await call('GET', '/me/library/continue', { token: T });
  log('after completing ep1: continue-watching =', JSON.stringify((cont.data.history || []).map(h => `ep${h.episodeNumber}@${h.positionSeconds}s completed=${h.completed}`)));
  await call('POST', '/me/watch-history', { token: T, body: { seriesId: S1, episodeId: ep2.id, episodeNumber: 2, positionSeconds: 30, durationSeconds: ep2.durationSeconds, completed: false } });
  cont = await call('GET', '/me/library/continue', { token: T });
  log('after watching ep2 to 30s: continue-watching =', JSON.stringify((cont.data.history || []).map(h => `${h.series.title} ep${h.episodeNumber}@${h.positionSeconds}/${h.durationSeconds}s`)));
  const hist = await call('GET', '/me/library/history', { token: T });
  log('history =', JSON.stringify((hist.data.history || []).map(h => `ep${h.episodeNumber}@${h.positionSeconds}s completed=${h.completed}`)));

  // ---------------- J4: paywall moment + earn paths ----------------
  log('\n== J4 PAYWALL MOMENT ==');
  log('balance at paywall approach:', await bal(T), '(welcome bonus)');
  let u = await call('POST', `/episodes/${epId(S1, 3)}/unlock`, { token: T });
  log('unlock ep3 ->', u.status, JSON.stringify(u.data), 'balance now', await bal(T));
  u = await call('POST', `/episodes/${epId(S1, 4)}/unlock`, { token: T });
  log('unlock ep4 with 0 coins ->', u.status, u.error ? `${u.error.code}: ${u.error.message}` : JSON.stringify(u.data));
  const p4 = await call('GET', `/episodes/${epId(S1, 4)}/playback`, { token: T });
  log('playback ep4 ->', p4.status, p4.error ? p4.error.code : 'OK');
  let actions = 0;
  const ci = await call('POST', '/rewards/checkin', { token: T }); actions++;
  log(`earn#${actions} checkin ->`, JSON.stringify(ci.data), 'balance', await bal(T));
  let rw = await call('GET', '/rewards', { token: T });
  const dcMission = (rw.data.missions || []).find(x => x.slug === 'daily_checkin');
  log('missions after checkin:', (rw.data.missions || []).map(x => `${x.slug}:${x.progress}/${x.target}${x.completed ? '(done)' : ''}`).join(' '));
  const mc = await call('POST', '/rewards/missions/daily_checkin/claim', { token: T }); actions++;
  log(`earn#${actions} claim daily_checkin mission ->`, JSON.stringify(mc.data), 'balance', await bal(T));
  log(`>>> TIME-TO-UNLOCK: ${actions} reward actions (check-in + mission claim) to go from 0 -> 30 coins`);
  u = await call('POST', `/episodes/${epId(S1, 4)}/unlock`, { token: T });
  log('unlock ep4 now ->', u.status, JSON.stringify(u.data), 'balance', await bal(T));
  // explore the rest of the earn economy
  for (let i = 1; i <= 3; i++) { const w = await call('POST', '/rewards/wheel/spin', { token: T }); log(`wheel spin ${i} -> segment=${w.data.segmentIndex} coins=${w.data.coins} spinsLeft=${w.data.spinsLeft} balance=${w.data.balance}`); }
  const w4 = await call('POST', '/rewards/wheel/spin', { token: T });
  log('wheel spin 4 (paid, cost 20) ->', w4.status, JSON.stringify(w4.data || w4.error));
  const ad = await call('POST', '/rewards/ad', { token: T });
  log('ad reward ->', JSON.stringify(ad.data), 'balance', await bal(T));
  for (const s of [S1, 'series-revenge-of-the-heiress', 'series-my-secret-husband']) await call('POST', `/series/${s}/like`, { token: T, body: { like: true } });
  await call('POST', '/content/share', { token: T, body: { seriesId: S1 } });
  for (const slug of ['like_3_series', 'share_1_series']) { const c = await call('POST', `/rewards/missions/${slug}/claim`, { token: T }); log(`claim mission ${slug} ->`, JSON.stringify(c.data || c.error), 'balance', await bal(T)); }
  // watch ep1..ep4 fully (ep1/ep2 already done; redo is harmless — high-water already set)
  for (const n of [1, 2, 3, 4]) await watchFull(T, S1, eps.data.episodes[n - 1]);
  const c3 = await call('POST', '/rewards/missions/watch_3_episodes/claim', { token: T });
  log('claim mission watch_3_episodes ->', JSON.stringify(c3.data || c3.error), 'balance', await bal(T));
  const ch3 = await call('POST', '/rewards/chests/chest_3/claim', { token: T });
  log('claim chest_3 (3 episodes) ->', JSON.stringify(ch3.data || ch3.error), 'balance', await bal(T));
  // grind ep5..ep8: unlock then watch
  for (const n of [5, 6, 7, 8]) {
    const uu = await call('POST', `/episodes/${epId(S1, n)}/unlock`, { token: T });
    log(`unlock ep${n} ->`, uu.status, JSON.stringify(uu.data || uu.error), 'balance', await bal(T));
    if (uu.status === 200) await watchFull(T, S1, eps.data.episodes[n - 1]);
    if (n === 7) { const ch7 = await call('POST', '/rewards/chests/chest_7/claim', { token: T }); log('claim chest_7 ->', JSON.stringify(ch7.data || ch7.error), 'balance', await bal(T)); }
  }
  rw = await call('GET', '/rewards', { token: T });
  log('watchTime state:', JSON.stringify(rw.data.watchTime), 'streak:', rw.data.currentStreak, 'xp:', rw.data.xp, 'level:', rw.data.level);
  const wm = await call('POST', '/rewards/missions/watch_15_minutes/claim', { token: T });
  log('claim mission watch_15_minutes ->', JSON.stringify(wm.data || wm.error), 'balance', await bal(T));
  const wt = await call('POST', '/rewards/watch-time/claim', { token: T });
  log('watch-time claim ->', JSON.stringify(wt.data || wt.error), 'balance', await bal(T));
  const ch12 = await call('POST', '/rewards/chests/chest_12/claim', { token: T });
  log('claim chest_12 (needs 12 eps, have 8) ->', ch12.status, ch12.error ? ch12.error.code : JSON.stringify(ch12.data));
  log('END OF DAY 1 balance:', await bal(T));

  // ---------------- J6: captions ----------------
  log('\n== J6 CAPTIONS ==');
  const caps = await call('GET', `/episodes/${ep1.id}/captions`, { token: T });
  log('ep1 caption languages ->', JSON.stringify(caps.data.languages));
  for (const lang of ['orig', 'ar', 'en']) {
    const v = await call('GET', `/episodes/${ep1.id}/captions/${lang}`, { token: T, raw: true });
    const cues = v.text.split('\n').filter(l => l.trim()).slice(0, 7);
    log(`ep1 captions/${lang} -> ${v.status} ${v.ctype} | first lines:`, cues.join(' ⏎ '));
    const times = [...v.text.matchAll(/(\d\d):(\d\d):(\d\d)\.(\d+) --> (\d\d):(\d\d):(\d\d)\.(\d+)/g)];
    if (times.length) { const last = times[times.length - 1]; log(`   cues=${times.length}, last cue ends at ${last[5]}:${last[6]}:${last[7]} vs episode duration ${ep1.durationSeconds}s`); }
  }
  const ep5caps = await call('GET', `/episodes/${epId(S1, 5)}/captions`, { token: T });
  log('ep5 (unlocked by me) caption languages ->', JSON.stringify(ep5caps.data.languages), '(none seeded -> empty until generated)');
  const gen = await call('POST', `/admin/episodes/${epId(S1, 5)}/captions/generate`, { admin: true, body: {} });
  log('admin generate captions ep5 ->', gen.status, JSON.stringify(gen.data || gen.error));
  for (let i = 0; i < 10; i++) {
    await new Promise(r => setTimeout(r, 700));
    const st = await call('GET', '/admin/captions', { admin: true });
    const rows = (st.data.items || st.data.tracks || []).filter(x => x.episodeId === epId(S1, 5));
    if (rows.length && rows.every(x => x.status === 'ready')) { log('ep5 tracks ready:', rows.map(x => `${x.lang}:${x.status}(${x.source})`).join(' ')); break; }
    if (i === 9) log('ep5 tracks after polling:', JSON.stringify(rows));
  }
  const caps5 = await call('GET', `/episodes/${epId(S1, 5)}/captions`, { token: T });
  log('ep5 caption languages now ->', JSON.stringify(caps5.data.languages));
  const ar5 = await call('GET', `/episodes/${epId(S1, 5)}/captions/ar`, { token: T, raw: true });
  log('ep5 captions/ar first lines:', ar5.text.split('\n').filter(l => l.trim()).slice(0, 6).join(' ⏎ '));
  const lockedCaps = await call('GET', `/episodes/${epId(S1, 9)}/captions/en`, { token: T, raw: true });
  log('ep9 (never unlocked) captions/en ->', lockedCaps.status, lockedCaps.text.slice(0, 120));

  // ---------------- J7: referral ----------------
  log('\n== J7 REFERRAL ==');
  const regB = await register('eval-user-b', { name: 'Friend B' });
  const TB = regB.data.tokens.accessToken;
  log('user B registered, balance:', regB.data.user.coinBalance, 'own referralCode:', regB.data.user.referralCode);
  const aBefore = await bal(T);
  const ref = await call('POST', '/auth/referral', { token: TB, body: { code: me.data.user.referralCode } });
  log('B applies A code ->', ref.status, JSON.stringify(ref.data || ref.error));
  log('B balance after:', await bal(TB), '| A balance before:', aBefore, 'after:', await bal(T));
  const ref2 = await call('POST', '/auth/referral', { token: TB, body: { code: me.data.user.referralCode } });
  log('B applies again ->', ref2.status, ref2.error ? ref2.error.code : JSON.stringify(ref2.data));
  const regC = await register('eval-user-c', {});
  const selfRef = await call('POST', '/auth/referral', { token: regC.data.tokens.accessToken, body: { code: regC.data.user.referralCode } });
  log('C applies OWN code ->', selfRef.status, selfRef.error ? selfRef.error.code : JSON.stringify(selfRef.data));
  flush();
}

if (phase === 'day2') {
  log('\n########## DAY 2 (dates shifted back 1 day) ##########');
  const { token: T } = loadState();
  const rw = await call('GET', '/rewards', { token: T });
  log('rewards state -> claimedToday:', rw.data.claimedToday, 'currentDay:', rw.data.currentDay, 'currentStreak:', rw.data.currentStreak, 'wheel spinsLeft:', rw.data.wheel.spinsLeft, 'chests:', (rw.data.chests || []).map(c => `${c.threshold}:${c.unlocked ? 'unlocked' : 'locked'}/${c.claimed ? 'claimed' : 'unclaimed'}`).join(' '), 'watchTime minutesToday:', rw.data.watchTime.minutesToday);
  const ci = await call('POST', '/rewards/checkin', { token: T });
  log('day-2 checkin ->', JSON.stringify(ci.data), '(ladder day 2 base=50, streak bonus min(1,7)*2=2 -> expect 52)');
  const rw2 = await call('GET', '/rewards', { token: T });
  log('after checkin -> currentStreak:', rw2.data.currentStreak, 'currentDay:', rw2.data.currentDay, 'balance:', rw2.data.coinBalance);
  flush();
}

if (phase === 'day4') {
  log('\n########## DAY 4 (missed a day — dates shifted 2 more days) ##########');
  const { token: T } = loadState();
  const rw = await call('GET', '/rewards', { token: T });
  log('rewards state -> claimedToday:', rw.data.claimedToday, 'currentDay:', rw.data.currentDay, 'currentStreak:', rw.data.currentStreak);
  const ci = await call('POST', '/rewards/checkin', { token: T });
  log('checkin after gap ->', JSON.stringify(ci.data), '(ladder reset -> expect day-1 base 20, no streak bonus)');
  const rw2 = await call('GET', '/rewards', { token: T });
  log('after checkin -> currentStreak:', rw2.data.currentStreak, 'currentDay:', rw2.data.currentDay);
  flush();
}
