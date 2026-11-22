'use strict';
/**
 * Captions & translation pipeline — audio-based, like Facebook's auto-translate:
 *   video audio --ASR--> original-language timed segments --MT--> translated segments --render--> WebVTT
 * There are NO per-video subtitle uploads; tracks are generated from the audio.
 *
 * Providers are chosen by the settings store:
 *   asr_provider: 'demo' (default) | 'openai' | 'local-whisper'
 *   mt_provider:  'demo' (default) | 'deepl'  | 'google'
 *
 * DEMO MODE (the default): the demo ASR invents plausible-but-FAKE caption text
 * derived from the episode title/description, and the demo MT only prefixes each
 * cue with a "[<lang>] " tag without actually translating. Plug in real provider
 * keys (OPENAI_API_KEY / DEEPL_API_KEY / GOOGLE_TRANSLATE_API_KEY / WHISPER_CMD)
 * and switch the provider settings for production output.
 */
const dns = require('node:dns').promises;
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { all, get, run } = require('./db');
const auth = require('./auth');
const settings = require('./settings');

/**
 * SSRF guard for the ASR downloader (security audit C1/C2): episode videoUrls
 * are admin-set, but a stolen admin token must not turn the server into a
 * proxy into the private network (loopback, RFC1918, link-local, cloud
 * metadata 169.254.169.254). Every URL — including redirect hops — is
 * validated before fetching. TOCTOU note: the DNS answer is checked at
 * validation time; fetch may resolve again, so this is defense-in-depth,
 * not a guarantee against a hostile DNS.
 */
function isBlockedIp(ip) {
  if (net.isIP(ip) === 4) {
    const [a, b] = ip.split('.').map(Number);
    if (a === 0 || a === 10 || a === 127) return true; // 0/8, 10/8, loopback
    if (a === 169 && b === 254) return true; // link-local incl. cloud metadata
    if (a === 172 && b >= 16 && b <= 31) return true; // 172.16/12
    if (a === 192 && b === 168) return true; // 192.168/16
    if (a === 100 && b >= 64 && b <= 127) return true; // 100.64/10 CGNAT
    if (a >= 224) return true; // multicast + reserved
    return false;
  }
  if (net.isIP(ip) === 6) {
    const low = ip.toLowerCase();
    if (low === '::1' || low === '::') return true;
    if (/^fe[89ab][0-9a-f]*:/.test(low)) return true; // fe80::/10 link-local
    if (/^f[cd][0-9a-f]*:/.test(low)) return true; // fc00::/7 unique-local
    if (low.startsWith('::ffff:')) { const v4 = low.slice(7); if (net.isIP(v4) === 4) return isBlockedIp(v4); }
    return false;
  }
  return true; // not an IP at all -> blocked (defensive)
}
async function assertPublicHttpUrl(raw) {
  let u;
  try { u = new URL(raw); } catch { throw new Error('Invalid video URL for ASR'); }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') throw new Error('Video URL for ASR must be http(s)');
  const host = u.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local')) throw new Error('Video URL host is not public (localhost)');
  if (net.isIP(host)) {
    if (isBlockedIp(host)) throw new Error('Video URL resolves to a private/loopback address — blocked (SSRF guard)');
    return u.toString();
  }
  let addrs;
  try { addrs = await dns.lookup(host, { all: true }); } catch { throw new Error('Video URL host could not be resolved'); }
  if (!addrs.length) throw new Error('Video URL host could not be resolved');
  for (const a of addrs) if (isBlockedIp(a.address)) throw new Error('Video URL resolves to a private/loopback address — blocked (SSRF guard)');
  return u.toString();
}

// Language-code shape for caption targets: 2-3 letter code, optional region.
const LANG_RE = /^[a-z]{2,3}(-[a-zA-Z]{2,4})?$/;
/** Sanitize a targets list: keep 'orig' + valid codes, dedupe, cap at 10. */
function sanitizeTargets(targets) {
  const list = Array.isArray(targets) ? targets : settings.getSetting('caption_target_languages');
  const seen = new Set(); const out = [];
  for (const t of list) {
    if (typeof t !== 'string') continue;
    const lang = t.trim();
    if (lang !== 'orig' && !LANG_RE.test(lang)) continue;
    if (seen.has(lang)) continue;
    seen.add(lang); out.push(lang);
    if (out.length >= 10) break;
  }
  return out.length ? out : ['ar', 'en'];
}

const now = () => new Date().toISOString();

// ---------------------------------------------------------------- WebVTT ----
function fmtTime(sec) {
  const ms = Math.max(0, Math.round(sec * 1000));
  const h = String(Math.floor(ms / 3600000)).padStart(2, '0');
  const m = String(Math.floor((ms % 3600000) / 60000)).padStart(2, '0');
  const s = String(Math.floor((ms % 60000) / 1000)).padStart(2, '0');
  const milli = String(ms % 1000).padStart(3, '0');
  return `${h}:${m}:${s}.${milli}`;
}
function cleanSegments(segments) {
  // Sanitize + normalize provider output before rendering: escape VTT markup
  // chars, flatten newlines (a raw newline would inject fake cues), drop empty
  // cues, sort by start, and guarantee end > start.
  return (segments || [])
    .map((s) => ({
      start: Math.max(0, Number(s.start) || 0),
      end: Number(s.end) || 0,
      text: String(s.text || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\s*\n\s*/g, ' ').trim(),
    }))
    .filter((s) => s.text)
    .sort((a, b) => a.start - b.start)
    .map((s) => ({ ...s, end: Math.max(s.end, s.start + 0.5) }));
}
function renderVtt(segments) {
  let out = 'WEBVTT\n\n';
  for (const seg of cleanSegments(segments)) out += `${fmtTime(seg.start)} --> ${fmtTime(seg.end)}\n${seg.text}\n\n`;
  return out;
}

// ------------------------------------------------------------- Demo ASR -----
// DEMO PLACEHOLDER: deterministic generator producing plausible-but-fake text
// from the episode title/description. It does NOT listen to the audio at all.
function demoAsrSegments(episode) {
  const title = episode.title || 'Episode';
  const desc = (episode.description || '').trim();
  let lines = desc.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
  const templates = [
    `${title} — the story continues.`,
    'You have no idea what is coming next.',
    'Wait. Did you hear that?',
    'I never wanted it to end like this.',
    'Everything changes from this moment on.',
    'Tell me the truth. All of it.',
    'She turned around and froze.',
    'This was never part of the plan.',
    'Some secrets are better left buried.',
    'He had been waiting for this day.',
    'The door opened, and nobody spoke.',
    'To be continued...',
  ];
  let ti = 0;
  while (lines.length < 8) lines.push(templates[ti++ % templates.length]);
  lines = lines.slice(0, 14);
  return lines.map((text, i) => {
    const dur = 3 + (i % 2); // 3-4s cues
    return { start: i * 3.5, end: i * 3.5 + dur, text };
  });
}

// ------------------------------------------------------------------ ASR -----
async function downloadToTemp(url) {
  // Bounded download: a stalled or huge videoUrl must never wedge the single
  // caption worker (30s timeout, 200 MB cap). Redirects are followed manually
  // (max 3) so every hop passes the SSRF guard — fetch's default redirect
  // following would let a public URL bounce into the private network.
  let current = url;
  for (let hop = 0; hop < 4; hop++) {
    const safe = await assertPublicHttpUrl(current);
    const res = await fetch(safe, { signal: AbortSignal.timeout(30000), redirect: 'manual' });
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      if (!loc) throw new Error(`Failed to download video for ASR (HTTP ${res.status})`);
      if (hop === 3) throw new Error('Too many redirects fetching video for ASR');
      current = new URL(loc, safe).toString();
      continue;
    }
    if (!res.ok) throw new Error(`Failed to download video for ASR (HTTP ${res.status})`);
    const declared = parseInt(res.headers.get('content-length') || '0', 10);
    if (declared > 200 * 1024 * 1024) throw new Error('Video too large for ASR download (>200MB)');
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length > 200 * 1024 * 1024) throw new Error('Video too large for ASR download (>200MB)');
    const file = path.join(os.tmpdir(), `hd-asr-${auth.uid()}.mp4`);
    fs.writeFileSync(file, buf);
    return file;
  }
  throw new Error('Too many redirects fetching video for ASR');
}

async function asrSegments(episode) {
  const provider = settings.getSetting('asr_provider');
  if (provider === 'openai') {
    const key = process.env.OPENAI_API_KEY;
    if (!key) throw new Error('asr_provider=openai but OPENAI_API_KEY is not set');
    if (!episode.videoUrl) throw new Error('Episode has no videoUrl to transcribe');
    const file = await downloadToTemp(episode.videoUrl);
    try {
      const form = new FormData();
      form.append('file', new Blob([fs.readFileSync(file)], { type: 'video/mp4' }), 'video.mp4');
      form.append('model', 'whisper-1');
      form.append('response_format', 'verbose_json');
      const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form, signal: AbortSignal.timeout(120000),
      });
      if (!res.ok) throw new Error(`OpenAI transcription failed (HTTP ${res.status}): ${(await res.text()).slice(0, 200)}`);
      const json = await res.json();
      const segs = (json.segments || []).map((s) => ({ start: s.start, end: s.end, text: String(s.text || '').trim() })).filter((s) => s.text);
      if (!segs.length && json.text) return [{ start: 0, end: 4, text: String(json.text).trim() }];
      if (!segs.length) throw new Error('OpenAI transcription returned no segments');
      return segs;
    } finally { try { fs.unlinkSync(file); } catch { /* ignore */ } }
  }
  if (provider === 'local-whisper') {
    const cmd = process.env.WHISPER_CMD;
    if (!cmd) throw new Error('asr_provider=local-whisper but WHISPER_CMD is not set');
    if (!episode.videoUrl) throw new Error('Episode has no videoUrl to transcribe');
    const file = await downloadToTemp(episode.videoUrl);
    try {
      const rendered = cmd.replace('{file}', file);
      const parts = rendered.split(/\s+/).filter(Boolean);
      const outJson = await new Promise((resolve, reject) => {
        const child = spawn(parts[0], parts.slice(1), { stdio: ['ignore', 'pipe', 'pipe'] });
        let err = '';
        child.stderr.on('data', (d) => { err += d; });
        child.on('error', reject);
        child.on('close', (code) => {
          if (code !== 0) return reject(new Error(`WHISPER_CMD exited with code ${code}: ${err.slice(0, 200)}`));
          const jsonFile = file.replace(/\.[^.]+$/, '.json');
          try { resolve(JSON.parse(fs.readFileSync(jsonFile, 'utf8'))); }
          catch (e) { reject(new Error('Could not read whisper JSON output: ' + e.message)); }
        });
      });
      const segs = (outJson.segments || []).map((s) => ({ start: s.start, end: s.end, text: String(s.text || '').trim() })).filter((s) => s.text);
      if (!segs.length) throw new Error('local-whisper returned no segments');
      return segs;
    } finally { try { fs.unlinkSync(file); } catch { /* ignore */ } }
  }
  // 'demo' (default)
  return demoAsrSegments(episode);
}

// ------------------------------------------------------------------- MT -----
async function translateSegments(segments, lang) {
  const provider = settings.getSetting('mt_provider');
  if (provider === 'deepl') {
    const key = process.env.DEEPL_API_KEY;
    if (!key) throw new Error('mt_provider=deepl but DEEPL_API_KEY is not set');
    const params = new URLSearchParams();
    segments.forEach((s) => params.append('text', s.text));
    params.append('target_lang', lang.toUpperCase());
    const res = await fetch('https://api-free.deepl.com/v2/translate', {
      method: 'POST', headers: { Authorization: `DeepL-Auth-Key ${key}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: params, signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) throw new Error(`DeepL translate failed (HTTP ${res.status})`);
    const json = await res.json();
    return segments.map((s, i) => ({ ...s, text: (json.translations && json.translations[i] && json.translations[i].text) || s.text }));
  }
  if (provider === 'google') {
    const key = process.env.GOOGLE_TRANSLATE_API_KEY;
    if (!key) throw new Error('mt_provider=google but GOOGLE_TRANSLATE_API_KEY is not set');
    const res = await fetch(`https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(key)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: segments.map((s) => s.text), target: lang, format: 'text' }), signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) throw new Error(`Google Translate failed (HTTP ${res.status})`);
    const json = await res.json();
    const trs = (json.data && json.data.translations) || [];
    return segments.map((s, i) => ({ ...s, text: (trs[i] && trs[i].translatedText) || s.text }));
  }
  // 'demo' (default) DEMO PLACEHOLDER: pass-through text prefixed with a language tag.
  return segments.map((s) => ({ ...s, text: `[${lang}] ${s.text}` }));
}

// --------------------------------------------------------------- Tracks -----
function upsertTrack(episodeId, lang, source, status, vtt) {
  const existing = get('SELECT * FROM caption_tracks WHERE episodeId=? AND lang=?', episodeId, lang);
  if (existing) {
    run('UPDATE caption_tracks SET source=?, status=?, vtt=COALESCE(?,vtt) WHERE id=?', source, status, vtt || null, existing.id);
    return existing.id;
  }
  const id = auth.uid();
  run('INSERT INTO caption_tracks(id,episodeId,lang,source,status,vtt,createdAt) VALUES(?,?,?,?,?,?,?)', id, episodeId, lang, source, status, vtt || null, now());
  return id;
}
function setTrackStatus(episodeId, lang, status) {
  run('UPDATE caption_tracks SET status=? WHERE episodeId=? AND lang=?', status, episodeId, lang);
}
function readyLanguages(episodeId) {
  if (!settings.getSetting('captions_enabled')) return [];
  return all("SELECT lang FROM caption_tracks WHERE episodeId=? AND status='ready' ORDER BY lang", episodeId).map((r) => r.lang);
}

/** Synchronous demo generation (used by the seed so tracks exist deterministically). */
function generateDemoTracksSync(episodeId, targets) {
  const episode = get('SELECT * FROM episodes WHERE id=?', episodeId);
  if (!episode) return;
  const langs = sanitizeTargets(targets);
  const segments = demoAsrSegments(episode);
  upsertTrack(episodeId, 'orig', 'asr', 'ready', renderVtt(segments));
  for (const lang of langs) {
    if (lang === 'orig') continue;
    const translated = segments.map((s) => ({ ...s, text: `[${lang}] ${s.text}` })); // demo MT placeholder
    upsertTrack(episodeId, lang, 'mt', 'ready', renderVtt(translated));
  }
}

// --------------------------------------------------------------- Worker -----
let workerRunning = false;

function enqueueCaptionJob(episodeId, targets) {
  const langs = sanitizeTargets(targets);
  // Dedupe: an already queued/processing job for this episode is reused, so a
  // double-click (or create + manual generate) never runs ASR/MT twice.
  const existing = get("SELECT * FROM caption_jobs WHERE episodeId=? AND status IN ('queued','processing') ORDER BY createdAt ASC LIMIT 1", episodeId);
  if (existing) return existing.id;
  const jobId = auth.uid();
  run("INSERT INTO caption_jobs(id,episodeId,status,step,targets,createdAt) VALUES(?,?,'queued','queued',?,?)", jobId, episodeId, JSON.stringify(langs), now());
  upsertTrack(episodeId, 'orig', 'asr', 'queued', null);
  for (const lang of langs) if (lang !== 'orig') upsertTrack(episodeId, lang, 'mt', 'queued', null);
  kickWorker();
  return jobId;
}

/** Boot recovery: jobs/tracks left 'processing' by a dead process are re-queued. */
function recoverOnStartup() {
  run("UPDATE caption_jobs SET status='queued', step='queued' WHERE status='processing'");
  run("UPDATE caption_tracks SET status='queued' WHERE status='processing'");
  kickWorker();
}

function kickWorker() {
  if (workerRunning) return;
  workerRunning = true;
  (async () => {
    try {
      for (;;) {
        const job = get("SELECT * FROM caption_jobs WHERE status='queued' ORDER BY createdAt ASC LIMIT 1");
        if (!job) break;
        await processJob(job.id);
      }
    } catch (e) { console.error('[captions] worker error', e); }
    finally { workerRunning = false; }
  })();
}

async function processJob(jobId) {
  const job = get('SELECT * FROM caption_jobs WHERE id=?', jobId);
  if (!job) return;
  const episode = get('SELECT * FROM episodes WHERE id=?', job.episodeId);
  let targets = null;
  try { targets = job.targets ? JSON.parse(job.targets) : null; } catch { targets = null; }
  if (!Array.isArray(targets) || !targets.length) targets = settings.getSetting('caption_target_languages');
  try {
    if (!episode) throw new Error('Episode not found');
    run("UPDATE caption_jobs SET status='processing', step='asr' WHERE id=?", jobId);
    setTrackStatus(job.episodeId, 'orig', 'processing');
    const segments = await asrSegments(episode);
    upsertTrack(job.episodeId, 'orig', 'asr', 'ready', renderVtt(segments));
    run("UPDATE caption_jobs SET step='mt' WHERE id=?", jobId);
    for (const lang of targets) {
      if (lang === 'orig') continue;
      setTrackStatus(job.episodeId, lang, 'processing');
      const translated = await translateSegments(segments, lang);
      upsertTrack(job.episodeId, lang, 'mt', 'ready', renderVtt(translated));
    }
    run("UPDATE caption_jobs SET status='done', step='done', finishedAt=? WHERE id=?", now(), jobId);
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    try {
      run("UPDATE caption_jobs SET status='failed', step='failed', error=?, finishedAt=? WHERE id=?", msg, now(), jobId);
      // A failed REGENERATION must not destroy previously working captions:
      // tracks that still hold an older VTT go back to 'ready'; only tracks
      // with no usable VTT are marked 'failed'.
      run("UPDATE caption_tracks SET status='ready' WHERE episodeId=? AND status IN ('queued','processing') AND vtt IS NOT NULL AND vtt<>''", job.episodeId);
      run("UPDATE caption_tracks SET status='failed' WHERE episodeId=? AND status IN ('queued','processing')", job.episodeId);
    } catch { /* never throw uncaught from the worker */ }
  }
}

module.exports = {
  renderVtt, cleanSegments, demoAsrSegments, generateDemoTracksSync,
  enqueueCaptionJob, processJob, kickWorker, recoverOnStartup, readyLanguages, upsertTrack,
  sanitizeTargets, LANG_RE, assertPublicHttpUrl,
};
